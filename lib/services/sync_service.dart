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

  /*
   * Esegue la sincronizzazione completa dei dati seguendo la logica Android
   */
  Future<void> fullSync() async {
    try {
      // Prova solo questo per vedere se il problema è la prima chiamata
      print('TEST URL: ${_dio.options.baseUrl}api/items/class?typeCode=ANAG&fullFeature=false');
      await syncItemsClass('ANAG');
      print('La prima chiamata ha funzionato!');
    } catch (e) {
      print('ERRORE SULLA PRIMA CHIAMATA: $e');
    }
  }

  /*
   * Sincronizza le classi degli item (ItemClass) - api/items/class
   */
  Future<void> syncItemsClass(String typeCode) async {
    final response = await _dio.get(
      'api/items/class',
      queryParameters: {'typeCode': typeCode, 'fullFeature': false},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      for (var json in data) {
        await _dbHelper.insertOrUpdateItem('itemclass', {
          'idext': json['Id'].toString(),
          'code': json['Code'],
          'description': json['Description'],
          'typecode': typeCode,
        }, json['Id'].toString());
      }
    }
  }

  /*
   * Ottiene le versioni dal server - api/versions
   */
  Future<Map<String, int>> getVersions() async {
    final response = await _dio.get('api/versions');
    Map<String, int> versionsMap = {};
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      for (var item in data) {
        final version = Version.fromJson(item);
        versionsMap[version.info] = version.version;
      }
    }
    return versionsMap;
  }

  /*
   * Sincronizza gli item per categoria (ANAG, INFO, ecc.) in modo incrementale
   */
  Future<void> syncItemsByCategory(String typeCode, Map<String, int> serverVersions) async {
    // INFO_ITEMS è la chiave usata in Android per le versioni degli item
    const String versionKey = 'INFO_ITEMS';
    final clientVersion = await _dbHelper.getLastVersion(versionKey);
    final serverVersion = serverVersions[versionKey] ?? 0;

    // Se la versione del server è superiore, sincronizziamo (o se client è 0)
    if (serverVersion > clientVersion || clientVersion == 0) {
      final response = await _dio.get(
        'api/item/mobile/class/${typeCode.toLowerCase()}',
        queryParameters: {
          'pag': 1,
          'num': 1000,
          'clientVersion': clientVersion > 0 ? clientVersion : null,
          'serverVersion': serverVersion,
          'allDetails': true,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        for (var json in data) {
          final item = Item.fromJson(json);
          await _dbHelper.insertOrUpdateItem('item', item.toMap(), item.idext);
        }
        // Aggiorna la versione locale
        await _dbHelper.updateVersion(Version(info: versionKey, version: serverVersion));
      }
    }
  }

  /*
   * Sincronizza gli stati del workflow (WFE_State)
   */
  Future<Map<String, String>> syncWfeStates() async {
    final response = await _dio.get('api/items/anag/WFE_State');

    Map<String, String> states = {};
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      for (var json in data) {
        states[json['Code']] = json['Id'].toString();
        // Salvataggio nella tabella item per persistenza
        await _dbHelper.insertOrUpdateItem('item', {
          'idext': json['Id'].toString(),
          'code': json['Code'],
          'description': json['Description'],
          'classdescr': 'WFE_State',
          'sync': 1,
        }, json['Id'].toString());
      }
    }
    return states;
  }

  /*
   * Sincronizza le ispezioni (interventi)
   */
  Future<void> syncInspections(Map<String, String> wfeStates) async {
    final prefs = await SharedPreferences.getInstance();
    final plant = prefs.getString('IMPIANTO') ?? '';
    final subPlant = prefs.getString('SOTTO_IMPIANTO') ?? '';
    
    final now = DateTime.now();
    // Filtro da ieri a oggi (logica Android)
    final fromDate = DateTime(now.year, now.month, now.day - 1, 0, 0, 0);
    final toDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    
    String dateFrom = _formatDateSearch(fromDate);
    String dateTo = _formatDateSearch(toDate);
    
    final statesToFilter = '${wfeStates['ISPEZ_PER_ASS']},${wfeStates['ISPEZ_PER_INC']}';

    final response = await _dio.get(
      'api/ispezione/mobile/list',
      queryParameters: {
        'filters': ['DATA_PREVISTA', 'CurrentStateId', 'IMPIANTO', 'SOTTO_IMPIANTO'],
        'filterValues': [
          'from_$dateFrom;to_$dateTo',
          statesToFilter,
          plant,
          subPlant
        ],
        'pag': 1,
        'num': 1000,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      for (var json in data) {
        final inspection = Inspection.fromJson(json);
        final state = inspection.getStringDetailValue(Inspection.keyCurrentStateId);
        
        if (state == wfeStates['ISPEZ_PER_ASS']) {
          // Prendi in carico sul server
          await takeInCharge(inspection.idext);
          // Salva localmente
          await _dbHelper.insertOrUpdateItem('ispezioni', inspection.toMap(), inspection.idext);
          // Scarica attività
          await syncInspectionActivities(inspection.idext);
        } 
        else if (state == wfeStates['ISPEZ_PER_INC']) {
          // Già in carico, scarica/aggiorna locale
          await _dbHelper.insertOrUpdateItem('ispezioni', inspection.toMap(), inspection.idext);
          await syncInspectionActivities(inspection.idext);
        } 
        else {
          // Stato non gestito, rimuovi locale se presente
          await _dbHelper.deleteItems('ispezioni', where: 'idext = ?', whereArgs: [inspection.idext]);
        }
      }
    }
  }

  /*
   * Prende in carico un intervento (BPM Action)
   */
  Future<void> takeInCharge(String ispezioneId) async {
    final prefs = await SharedPreferences.getInstance();
    final responsabileId = prefs.getString('ResponsabileId') ?? '';

    // Android usa Constants.PROCESS_NAME + "Incarico" -> "ISPEZ_PERIncarico"
    const actionName = 'ISPEZ_PERIncarico';
    const idStabilimento = '2'; // Sonatrach Augusta

    final parameters = [
      {'Key': 'ResponsabileId', 'Value': responsabileId}
    ];

    await _dio.put(
      'api/wfe/${int.parse(ispezioneId)}/action/name/$actionName',
      data: parameters,
    );
  }

  /*
   * Sincronizza le attività associate a un intervento
   */
  Future<void> syncInspectionActivities(String ispezioneId) async {
    // La logica Android utilizza un placeholder nel path {ispezioneId}
    // MA passa anche il valore come Query Parameter.
    // Dalla logica Retrofit osservata e dai log dell'utente, 
    // l'approccio più robusto è passare l'ID sia nel path che nella query.
    final response = await _dio.get(
      'api/ispezione/mobile/$ispezioneId/attivita',
      queryParameters: {'ispezioneId': ispezioneId},
      options: Options(
        headers: {
          'Cache-Control': 'no-cache',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      for (var json in data) {
        final activity = InspectionActivity.fromJson(json, ispezioneId: ispezioneId);
        await _dbHelper.insertOrUpdateItem('ispezioni_att', activity.toMap(), activity.idext);
      }
    }
  }

  /*
   * Metodo per ottenere metadata (Impianti, Utenti, ecc.)
   */
  Future<List<Map<String, dynamic>>> getMetadata(String anagName) async {
    final response = await _dio.get('api/items/anag/$anagName');
    if (response.statusCode == 200 && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  /*
   * Ottiene l'utente loggato
   */
  Future<AppUser?> getCurrentUser() async {
    try {
      final response = await _dio.get('api/user/logged');
      if (response.statusCode == 200) {
        return AppUser.fromJson(response.data);
      }
    } catch (e) {
      print('Errore getCurrentUser: $e');
    }
    return null;
  }

  String _formatDateSearch(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} "
           "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }
}
