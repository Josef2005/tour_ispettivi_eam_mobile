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
    // Logica per rilasciare l'ispezione (es. cambiare stato workflow a 'Non in carico' o simile)
    // Parity con Android: sposta la richiesta BPM
    print('Rilascio ispezione ${inspection.idext}');
  }

  // Esempio per "CONCLUDI ISPEZIONE"
  Future<void> completeInspection() async {
    if (totalCompletionPercentage < 100) {
      _errorMessage = "Completare tutte le attività prima di chiudere.";
      notifyListeners();
      return;
    }

    // Segna come completata localmente
    await _dbHelper.insertOrUpdateItem('ispezioni', {
      ...inspection.toMap(),
      'completed': 1,
      'sync': 0,
      'Data_Fine_Intervento': DateTime.now().toIso8601String(),
    }, inspection.idext);

    // Tenta sync immediato degli esiti se possibile (opzionale)
    // await _syncService.uploadLocalData([]);

    notifyListeners();
  }
}
