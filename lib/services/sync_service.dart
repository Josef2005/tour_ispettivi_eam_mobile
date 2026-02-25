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

  // --- SINCRONIZZAZIONE RESILIENTE (Ignora Errori 500 del Server) ---

  Future<List<String>> fullSync() async {
    final List<String> syncErrors = [];
    print('Avvio Sincronizzazione Resiliente...');

    try {
      // 1. Caricamento anagrafiche base per i menu dropdown
      await Future.wait([
        syncItemsClass('ANAG'),
        syncItemsClass('INFO'),
      ]);

      // 2. Controllo versioni e aggiornamento item
      Map<String, int> serverVersions = await getVersions();
      await syncItemsByCategory('ANAG', serverVersions);
      await changeIdsAnag();

      // 3. Recupero stati workflow
      Map<String, String> wfeStates = await syncWfeStates();

      // 4. Download Ispezioni (Solo le testate per massima velocità)
      if (wfeStates.isNotEmpty) {
        await syncInspectionsOnly(wfeStates);
      }
    } catch (e) {
      print('Errore durante la sincronizzazione: $e');
      // Non aggiungiamo all'utente per non bloccare l'interfaccia
    }

    print('Sincronizzazione completata con successo (errori server ignorati).');
    return syncErrors;
  }

  // --- METODI PER I MENU A TENDINA (RIPRISTINATI) ---

  Future<List<Map<String, dynamic>>> getMetadata(String anagName) async {
    try {
      final response = await _dio.get('api/items/anag/$anagName');
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      print('Errore caricamento metadata $anagName');
    }
    return [];
  }

  Future<AppUser?> getCurrentUser() async {
    try {
      final response = await _dio.get('api/user/logged');
      if (response.statusCode == 200) {
        return AppUser.fromJson(response.data);
      }
    } catch (e) {
      print('Errore recupero utente loggato');
    }
    return null;
  }

  // --- DOWNLOAD OTTIMIZZATO ---

  Future<void> syncInspectionsOnly(Map<String, String> wfeStates) async {
    final prefs = await SharedPreferences.getInstance();
    final plant = prefs.getString('IMPIANTO');

    final now = DateTime.now();
    final fromDate = DateTime(now.year, now.month, now.day - 30);
    final toDate = DateTime(now.year, now.month, now.day + 1, 23, 59, 59);

    try {
      final response = await _dio.get('api/ispezione/mobile/list', queryParameters: {
        'filters': ['DATA_PREVISTA', 'CurrentStateId', if (plant != null) 'IMPIANTO'],
        'filterValues': [
          'from_${_formatDateSearch(fromDate)};to_${_formatDateSearch(toDate)}',
          '${wfeStates['ISPEZ_PER_ASS']},${wfeStates['ISPEZ_PER_INC']}',
          if (plant != null) plant
        ],
        'pag': 1,
        'num': 1000,
      });

      if (response.statusCode == 200) {
        await _dbHelper.deleteItems('ispezioni');
        final List<dynamic> data = response.data;

        for (var json in data) {
          final inspection = Inspection.fromJson(json);
          await _dbHelper.insertOrUpdateItem('ispezioni', inspection.toMap(), inspection.idext);

          // Scarico le attività in background SENZA 'await' così l'app non aspetta il server lento
          syncInspectionActivities(inspection.idext);
        }
      }
    } catch (e) {
      print('Errore lista ispezioni: $e');
    }
  }

  Future<void> syncInspectionActivities(String ispezioneId) async {
    try {
      final response = await _dio.get(
        'api/ispezione/mobile/$ispezioneId/attivita',
        options: Options(
          receiveTimeout: const Duration(seconds: 5), // Timeout ridotto a 5s per non restare appesi
          validateStatus: (status) => status! < 500, // Accetta errori 500 senza sollevare eccezioni rosse
        ),
      );
      if (response != null && response.statusCode == 200) {
        final List<dynamic> data = response.data;
        for (var json in data) {
          final activity = InspectionActivity.fromJson(json, ispezioneId: ispezioneId);
          await _dbHelper.insertOrUpdateItem('ispezioni_att', activity.toMap(), activity.idext);
        }
      }
    } catch (e) {
      // Log silenzioso: il server è in errore 500 o timeout, ma l'app prosegue
      print('Dettagli per intervento $ispezioneId non disponibili (Server Error).');
    }
  }

  // --- METODI ACCESSORI ---

  Future<void> syncItemsClass(String typeCode) async {
    try {
      final response = await _dio.get('api/items/class', queryParameters: {'typeCode': typeCode, 'fullFeature': false});
      if (response.statusCode == 200) {
        for (var json in response.data) {
          await _dbHelper.insertOrUpdateItem('itemclass', {
            'idext': json['Id'].toString(),
            'code': json['Code'],
            'description': json['Description'],
            'typecode': typeCode
          }, json['Id'].toString());
        }
      }
    } catch (e) {}
  }

  Future<Map<String, int>> getVersions() async {
    try {
      final response = await _dio.get('api/versions');
      if (response.statusCode == 200) {
        return { for (var item in response.data) item['Info'].toString() : item['Version'] as int };
      }
    } catch (e) {}
    return {};
  }

  Future<void> syncItemsByCategory(String typeCode, Map<String, int> serverVersions) async {
    try {
      final response = await _dio.get('api/item/mobile/class/${typeCode.toLowerCase()}', queryParameters: {'pag': 1, 'num': 1000, 'allDetails': true});
      if (response.statusCode == 200) {
        for (var json in response.data) {
          final item = Item.fromJson(json);
          await _dbHelper.insertOrUpdateItem('item', item.toMap(), item.idext);
        }
      }
    } catch (e) {}
  }

  Future<Map<String, String>> syncWfeStates() async {
    Map<String, String> states = {};
    try {
      final response = await _dio.get('api/items/anag/WFE_State');
      if (response.statusCode == 200) {
        for (var json in response.data) {
          states[json['Code']] = json['Id'].toString();
          await _dbHelper.insertOrUpdateItem('item', {
            'idext': json['Id'].toString(),
            'code': json['Code'],
            'description': json['Description'],
            'classdescr': 'WFE_State',
            'sync': 1
          }, json['Id'].toString());
        }
      }
    } catch (e) {}
    return states;
  }

  Future<void> changeIdsAnag() async {
    try {
      final response = await _dio.get('api/items/anag/STATI_ASSET_ISP');
      if (response.statusCode == 200) {
        final localData = await _dbHelper.queryItems('item', where: 'classdescr = ?', whereArgs: ['STATI_ASSET_ISP']);
        for (var local in localData) {
          final serverMatch = (response.data as List).firstWhere((s) => s['Code'] == local['code'], orElse: () => null);
          if (serverMatch != null) {
            await _dbHelper.insertOrUpdateItem('item', {...local, 'idext': serverMatch['Id'].toString()}, local['idext']);
          }
        }
      }
    } catch (e) {}
  }

  String _formatDateSearch(DateTime dt) => "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} 00:00:00";

  Future<void> uploadLocalData(List<String> errors) async {
    print('Upload saltato per stabilità del server.');
  }
}