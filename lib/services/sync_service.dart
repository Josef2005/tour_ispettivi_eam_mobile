import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../core/database/database_helper.dart';
import '../models/inspection_activity.dart';
import '../models/item.dart';
import '../models/inspection.dart';
import '../models/sync_data.dart';
import '../models/version.dart';

class SyncService {
  final Dio _dio = DioClient().dio;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- SINCRONIZZAZIONE RESILIENTE (Parity Android) ---

  Future<List<String>> fullSync() async {
    final List<String> syncErrors = [];
    final stopwatch = Stopwatch()..start();
    print('SYNC: Avvio sincronizzazione completa...');
    
    try {
      // 0. Upload in parallelo invece che sequenziale
      await uploadLocalData(syncErrors);

      // 1. & 2. Parallelizziamo tutto il possibile all'inizio
      print('SYNC: Recupero versioni e anagrafiche...');
      final results = await Future.wait([
        syncItemsClass('ANAG'),
        syncItemsClass('INFO'),
        getVersions(),
        getCurrentUser(),
      ]);

      Map<String, int> serverVersions = results[2] as Map<String, int>;

      // 3. Recupero stati e categorie in parallelo
      print('SYNC: Recupero stati e categorie...');
      await Future.wait([
        syncItemsByCategory('ANAG', serverVersions), 
        syncWfeStates()
      ]);

      await changeIdsAnag();

      // 4. Download Ispezioni
      print('SYNC: Download ispezioni...');
      Map<String, String> wfeStates = await syncWfeStates();
      if (wfeStates.isNotEmpty) {
        await syncInspectionsOnly(wfeStates);
      }
      
      stopwatch.stop();
      print('SYNC: Sincronizzazione completata in ${stopwatch.elapsed.inSeconds} secondi.');
    } catch (e) {
      stopwatch.stop();
      print('SYNC ERROR: Errore fatale durante fullSync: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('Http status error [503]')) {
        syncErrors.add('Server non raggiungibile o problema di rete.');
      } else {
        syncErrors.add('Errore critico sync: ${e.toString().split('\n').first}');
      }
    }
    return syncErrors;
  }

  // --- UPLOAD DATI (PARITY ANDROID) ---

  Future<void> uploadLocalData(List<String> errors) async {
    print('Avvio invio dati locali al server (Parallelo)...');
    try {
      // Eseguiamo entrambi gli upload contemporaneamente
      await Future.wait([
        _sendEsitoIspezioniAct(errors),
        _sendIspezioniCompletate(errors),
      ]);
      print('Invio dati locali completato.');
    } catch (e) {
      print('Errore durante l\'upload dei dati: $e');
    }
  }

  Future<void> _sendEsitoIspezioniAct(List<String> errors) async {
    try {
      final allInspections = await _dbHelper.queryItems('ispezioni');
      for (var inspMap in allInspections) {
        final ispezioneId = inspMap['idext'];

        final activityMaps = await _dbHelper.queryItems(
          'ispezioni_att',
          where: 'ispezione_id = ? AND sync = 0',
          whereArgs: [ispezioneId],
        );

        if (activityMaps.isEmpty) continue;

        final activities = activityMaps
            .map((m) => InspectionActivity.fromMap(m))
            .toList();
        final payload = activities.map((a) => a.toServerTableRow()).toList();

        final response = await _dio.put(
          'api/ispezione/$ispezioneId/updateResponse',
          data: payload,
          options: Options(contentType: 'application/json'),
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          for (var act in activities) {
            await _dbHelper.insertOrUpdateItem('ispezioni_att', {
              ...act.toMap(),
              'sync': 1,
            }, act.idext);
          }
        } else {
          errors.add(
            'Errore aggiornamento attività per $ispezioneId: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('Errore _sendEsitoIspezioniAct: $e');
    }
  }

  Future<void> _sendIspezioniCompletate(List<String> errors) async {
    try {
      final completedInspections = await _dbHelper.queryItems(
        'ispezioni',
        where: 'completed = 1 AND sync = 0',
      );

      for (var inspMap in completedInspections) {
        final ispezioneId = inspMap['idext'];

        final List<Map<String, dynamic>> parameters = [
          if (inspMap['Data_Inizio_Intervento'] != null)
            {'Key': 'Data_Inizio_Intervento', 'Value': inspMap['Data_Inizio_Intervento']},
          if (inspMap['Data_Fine_Intervento'] != null)
            {'Key': 'Data_Fine_Intervento', 'Value': inspMap['Data_Fine_Intervento']},
          if (inspMap['loggedUser'] != null)
            {'Key': 'Esecutore', 'Value': inspMap['loggedUser'].toString()},
        ];

        final response = await _dio.put(
          'api/wfe/$ispezioneId/action/name/ESEGUI',
          data: parameters,
          options: Options(contentType: 'application/json'),
        );

        if (response.statusCode == 200) {
          await _dbHelper.insertOrUpdateItem('ispezioni', {
            ...inspMap,
            'sync': 1,
          }, ispezioneId);
        } else {
          errors.add('Errore chiusura tour $ispezioneId: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Errore _sendIspezioniCompletate: $e');
    }
  }

  // --- METODI PER I MENU A TENDINA (CON CACHE) ---

  Future<List<Map<String, dynamic>>> getMetadata(String anagName) async {
    try {
      final response = await _dio.get('api/items/anag/$anagName');
      if (response.statusCode == 200 && response.data is List) {
        final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
          response.data,
        );
        // Salvataggio cache locale
        await _saveMetadataToLocal(anagName, data);
        return data;
      }
    } catch (e) {
      print('Errore caricamento metadata $anagName: $e. Uso cache locale.');
    }
    // Fallback locale
    return await _getLocalMetadata(anagName);
  }

  Future<AppUser?> getCurrentUser() async {
    try {
      final response = await _dio.get('api/user/logged');
      if (response.statusCode == 200) {
        final user = AppUser.fromJson(response.data);
        // Cache utente loggato
        await _dbHelper.insertOrUpdateItem('item', {
          'idext': 'current_user_info',
          'classdescr': 'CURRENT_USER',
          'details': jsonEncode(response.data),
          'sync': 1,
        }, 'current_user_info');
        return user;
      }
    } catch (e) {
      print('Errore recupero utente loggato. Uso cache locale.');
      final local = await _dbHelper.queryItems(
        'item',
        where: 'classdescr = ?',
        whereArgs: ['CURRENT_USER'],
      );
      if (local.isNotEmpty) {
        return AppUser.fromJson(jsonDecode(local.first['details']));
      }
    }
    return null;
  }

  Future<void> _saveMetadataToLocal(
    String anagName,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      // Usiamo una transazione unica (già gestita da insertBatch in database_helper)
      await _dbHelper.deleteItems('item', where: 'classdescr = ?', whereArgs: [anagName]);

      final List<Map<String, dynamic>> itemsToInsert = data
          .map(
            (json) => {
              'idext': '${anagName}_${json['Id'] ?? json['id']}',
              'code': json['Code']?.toString(),
              'description': json['Description']?.toString(),
              'classdescr': anagName,
              'details': jsonEncode(json),
              'sync': 1,
            },
          )
          .toList();

      if (itemsToInsert.isNotEmpty) {
        await _dbHelper.insertBatch('item', itemsToInsert);
      }
    } catch (e) {
      print('Errore cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalMetadata(String anagName) async {
    try {
      final localData = await _dbHelper.queryItems(
        'item',
        where: 'classdescr = ?',
        whereArgs: [anagName],
      );
      return localData
          .map((e) => jsonDecode(e['details']) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Errore lettura cache metadata $anagName: $e');
      return [];
    }
  }

  // --- DOWNLOAD OTTIMIZZATO ---

  Future<void> syncInspectionsOnly(Map<String, String> wfeStates) async {
    final prefs = await SharedPreferences.getInstance();
    final plant = prefs.getString('IMPIANTO');

    final now = DateTime.now();
    final fromDate = DateTime(now.year, now.month, now.day - 30);
    final toDate = DateTime(now.year, now.month, now.day + 1, 23, 59, 59);

    try {
      final response = await _dio.get(
        'api/ispezione/mobile/list',
        queryParameters: {
          'filters': ['DATA_PREVISTA', 'CurrentStateId', if (plant != null) 'IMPIANTO'],
          'filterValues': [
            'from_${_formatDateSearch(fromDate)};to_${_formatDateSearch(toDate)}',
            '${wfeStates['ISPEZ_PER_ASS']},${wfeStates['ISPEZ_PER_INC']}',
            if (plant != null) plant,
          ],
          'pag': 1,
          'num': 1000,
        },
      );

      if (response.statusCode == 200) {
        await _dbHelper.deleteItems('ispezioni');
        final List<dynamic> data = response.data;

        final List<Map<String, dynamic>> inspectionsToInsert = [];
        final List<String> ids = [];
        for (var json in data) {
          final inspection = Inspection.fromJson(json);
          inspectionsToInsert.add(inspection.toMap());
          ids.add(inspection.idext);
        }
        await _dbHelper.insertBatch('ispezioni', inspectionsToInsert);
        await _syncAllActivities(ids);
      }
    } catch (e) {
      print('Errore lista ispezioni: $e');
    }
  }

  Future<void> _syncAllActivities(List<String> ids) async {
    // Aumentiamo il batch a 5 e rimuoviamo il delay inutile
    const batchSize = 5;
    for (var i = 0; i < ids.length; i += batchSize) {
      final chunk = ids.sublist(
        i,
        i + batchSize > ids.length ? ids.length : i + batchSize,
      );
      // Esegue il batch di 5 ispezioni contemporaneamente
      await Future.wait(chunk.map((id) => syncInspectionActivities(id)));
      // Rimosso Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> syncInspectionActivities(String ispezioneId) async {
    try {
      final response = await _dio.get('api/ispezione/mobile/$ispezioneId/attivita');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        print("SYNC: Ricevute ${data.length} attività dal server per $ispezioneId");

        if (data.isNotEmpty) {
          final List<Map<String, dynamic>> activitiesToInsert = [];
          for (var json in data) {
            final activity = InspectionActivity.fromJson(json, ispezioneId: ispezioneId);
            activitiesToInsert.add(activity.toMap());
          }
          await _dbHelper.insertBatch('ispezioni_att', activitiesToInsert);
        }
      } else {
        print('SYNC WARNING: Status ${response.statusCode} per attività ispezione $ispezioneId');
      }
    } catch (e) {
      print('SYNC ERROR (Attività $ispezioneId): $e');
      // Non rilanciamo per evitare di bloccare l'intero processo di sync
    }
  }

  // --- METODI ACCESSORI ---

  Future<void> syncItemsClass(String typeCode) async {
    try {
      final response = await _dio.get(
        'api/items/class',
        queryParameters: {'typeCode': typeCode, 'fullFeature': false},
      );
      if (response.statusCode == 200) {
        for (var json in response.data) {
          await _dbHelper.insertOrUpdateItem('itemclass', {
            'idext': json['Id'].toString(),
            'code': json['Code'],
            'description': json['Description'],
            'typecode': typeCode,
          }, json['Id'].toString());
        }
      }
    } catch (e) {}
  }

  Future<Map<String, int>> getVersions() async {
    try {
      final response = await _dio.get('api/versions');
      if (response.statusCode == 200) {
        return {
          for (var item in response.data) item['Info'].toString(): item['Version'] as int,
        };
      }
    } catch (e) {}
    return {};
  }

  Future<void> syncItemsByCategory(
    String typeCode,
    Map<String, int> serverVersions,
  ) async {
    try {
      final response = await _dio.get(
        'api/item/mobile/class/${typeCode.toLowerCase()}',
        queryParameters: {'pag': 1, 'num': 1000, 'allDetails': true},
      );
      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> itemsToInsert = [];
        for (var json in response.data) {
          final item = Item.fromJson(json);
          itemsToInsert.add(item.toMap());
        }
        // Unica scrittura massiva invece di 1000 scritture singole
        if (itemsToInsert.isNotEmpty) {
          await _dbHelper.insertBatch('item', itemsToInsert);
        }
      }
    } catch (e) {
      print('Errore syncItemsByCategory: $e');
    }
  }

  Future<Map<String, String>> syncWfeStates() async {
    Map<String, String> states = {};
    try {
      final response = await _dio.get('api/items/anag/WFE_State');
      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> itemsToInsert = [];
        for (var json in response.data) {
          states[json['Code']] = json['Id'].toString();
          itemsToInsert.add({
            'idext': json['Id'].toString(),
            'code': json['Code'],
            'description': json['Description'],
            'classdescr': 'WFE_State',
            'sync': 1,
          });
        }
        if (itemsToInsert.isNotEmpty) {
          await _dbHelper.insertBatch('item', itemsToInsert);
        }
      }
    } catch (e) {}
    return states;
  }

  Future<void> changeIdsAnag() async {
    try {
      final response = await _dio.get('api/items/anag/STATI_ASSET_ISP');
      if (response.statusCode == 200) {
        final localData = await _dbHelper.queryItems(
          'item',
          where: 'classdescr = ?',
          whereArgs: ['STATI_ASSET_ISP'],
        );

        final List<Map<String, dynamic>> itemsToUpdate = [];
        for (var local in localData) {
          final serverMatch = (response.data as List).firstWhere(
                (s) => s['Code'] == local['code'],
            orElse: () => null,
          );
          if (serverMatch != null) {
            itemsToUpdate.add({
              ...local,
              'idext': serverMatch['Id'].toString(),
            });
          }
        }
        if (itemsToUpdate.isNotEmpty) {
          await _dbHelper.insertBatch('item', itemsToUpdate);
        }
      }
    } catch (e) {}
  }

  String _formatDateSearch(DateTime dt) =>
      "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} 00:00:00";
}
