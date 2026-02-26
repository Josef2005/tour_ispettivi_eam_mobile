import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/inspection.dart';
import '../models/inspection_activity.dart';
import '../services/sync_service.dart';

class AssetViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  final Inspection inspection;
  List<InspectionActivity> _activities = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<InspectionActivity> get activities => _activities;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  // Raggruppamento attività per Asset
  List<Map<String, dynamic>> get assetList {
    final Map<String, List<InspectionActivity>> groups = {};

    for (var act in _activities) {
      // 1. Recupera l'ID e la Label (usa stringhe vuote come fallback)
      String assetId = act.getStringDetailValue('AssetId').trim();
      String assetLabel = act.getStringDetailValueLabel('AssetId').trim();

      // 2. Se l'ID è vuoto, usa un raggruppamento generico per non perdere l'attività
      if (assetId.isEmpty) {
        assetId = "NO_ASSET";
        assetLabel = "Attività senza Asset";
      }

      if (!groups.containsKey(assetId)) {
        groups[assetId] = [];
      }
      groups[assetId]!.add(act);
    }

    final List<Map<String, dynamic>> result = [];
    groups.forEach((assetId, acts) {
      // Usiamo la label della prima attività del gruppo
      String label = acts.first.getStringDetailValueLabel('AssetId');
      if (label.isEmpty)
        label = (assetId == "NO_ASSET") ? "Altre Attività" : "Asset $assetId";

      result.add({
        'id': assetId,
        'label': label,
        'percentage': _calculateAssetPercentage(acts),
        'activities': acts,
      });
    });
    return result;
  }

  int _calculateAssetPercentage(List<InspectionActivity> acts) {
    if (acts.isEmpty) return 0;
    int completed = acts.where((a) => a.isCompleted).length;
    return (completed / acts.length * 100).round();
  }

  AssetViewModel({required this.inspection}) {
    loadActivities();
  }

  Future<void> loadActivities({bool forceSync = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    print('AssetViewModel: Caricamento attività per ispez_id=${inspection.idext}');

    try {
      var maps = await _dbHelper.queryItems(
        'ispezioni_att',
        where: 'ispezione_id = ?',
        whereArgs: [inspection.idext],
      );

      print('AssetViewModel: Trovate ${maps.length} attività nel DB locale');

      if ((maps.isEmpty || forceSync)) {
        print(
          'AssetViewModel: Nessuna attività trovata o richiesto sync. Tentativo download dal server...',
        );
        await _syncService.syncInspectionActivities(inspection.idext);

        maps = await _dbHelper.queryItems(
          'ispezioni_att',
          where: 'ispezione_id = ?',
          whereArgs: [inspection.idext],
        );
        print('AssetViewModel: Dopo sync, trovate ${maps.length} attività nel DB');
      }

      _activities = maps.map((m) => InspectionActivity.fromMap(m)).toList();

      if (_activities.isNotEmpty) {
        print(
          'AssetViewModel: Prima attività dettagli: ${_activities.first.details.map((e) => e.name).toList()}',
        );
      }
    } catch (e) {
      print('AssetViewModel: Errore durante il caricamento: $e');
      _errorMessage = 'Errore caricamento attività: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Percentuale globale per questa ispezione
  int get totalCompletionPercentage {
    if (_activities.isEmpty) return 0;
    int completed = _activities.where((a) => a.isCompleted).length;
    return (completed / _activities.length * 100).round();
  }

  // Esempio per pulsante "NON IN CARICO"
  Future<void> releaseInspection() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Chiamata al server via SyncService
      await _syncService.releaseInspection(inspection.idext);

      // 2. Aggiornamento DB locale (Parity Android)
      // Stato passa a 'ISPEZ_PER_ASS', logUser a 0, date a null
      await _dbHelper.insertOrUpdateItem('ispezioni', {
        ...inspection.toMap(),
        'CurrentStateId': 'ISPEZ_PER_ASS', // Assunto come codice per assegnato
        'loggedUser': 0,
        'completed': 0,
        'sync': 1,
        'Data_Inizio_Intervento': null,
        'Data_Fine_Intervento': null,
      }, inspection.idext);

      // 3. Aggiornamento oggetto in memoria (opzionale se si chiude la pagina)
      inspection.setDetailValue('CurrentStateId', 'ISPEZ_PER_ASS');
      inspection.setloggedUser(0);
      inspection.setCompleted(0);
      inspection.setDataInizioIntervento(null);

    } catch (e) {
      print('AssetViewModel: Errore durante il rilascio: $e');
      // Personalizziamo l'errore per il rilascio (richiesta utente per parity/UX)
      _errorMessage = "L'ispezione ${inspection.idext} si trova attualmente nello stato \"Assegnata\"";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Esempio per "CONCLUDI ISPEZIONE"
  Future<void> completeInspection() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Verifica completamento 100%
      if (totalCompletionPercentage < 100) {
        throw Exception("Completare tutte le attività prima di chiudere.");
      }

      // 2. Verifica anomalie senza nota (Parity Android)
      for (var act in _activities) {
        act.checkAnomalia();
      }

      // 3. Segna come completata localmente
      final now = DateTime.now().toUtc().toIso8601String().replaceFirst('Z', '.000Z');
      await _dbHelper.insertOrUpdateItem('ispezioni', {
        ...inspection.toMap(),
        'completed': 1,
        'sync': 0,
        'Data_Fine_Intervento': now,
        // Assicuriamoci che Data_Inizio_Intervento sia impostata se non lo fosse
        if (inspection.getDataInizioIntervento() == null)
          'Data_Inizio_Intervento': now,
      }, inspection.idext);

      // 4. Update in memory
      inspection.setCompleted(1);
      inspection.setDataFineIntervento(now);

    } catch (e) {
      print('AssetViewModel: Errore durante la chiusura: $e');
      _errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
