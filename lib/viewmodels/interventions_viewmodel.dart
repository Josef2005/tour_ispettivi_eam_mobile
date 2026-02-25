import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/inspection.dart';
import '../models/inspection_activity.dart';

class InterventionsViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Inspection> _interventions = [];
  Map<String, List<InspectionActivity>> _activitiesMap = {};
  bool _isLoading = false;

  List<Inspection> get interventions => _interventions;
  bool get isLoading => _isLoading;

  /*
   * Carica l'elenco degli interventi dal database locale
   */
  Future<void> loadInterventions() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Query sulla tabella italiana 'ispezioni'
      final maps = await _dbHelper.queryItems('ispezioni');
      _interventions = maps.map((m) => Inspection.fromMap(m)).toList();
      
      // Caricamento attività per il calcolo delle percentuali
      for (var inspection in _interventions) {
        final activityMaps = await _dbHelper.queryItems(
          'ispezioni_att', 
          where: 'ispezione_id = ?', 
          whereArgs: [inspection.idext]
        );
        _activitiesMap[inspection.idext] = activityMaps.map((m) => InspectionActivity.fromMap(m)).toList();
      }
    } catch (e) {
      print('Errore durante il caricamento degli interventi: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /*
   * Calcola la percentuale di completamento per un intervento
   */
  int getCompletionPercentage(String inspectionId) {
    final activities = _activitiesMap[inspectionId] ?? [];
    if (activities.isEmpty) return -1;
    
    int completedCount = activities.where((a) => a.isCompleted).length;
    return (completedCount / activities.length * 100).round();
  }

  /*
   * Restituisce il testo della percentuale
   */
  String getPercentageText(String inspectionId) {
    int percentage = getCompletionPercentage(inspectionId);
    if (percentage == -1) return "0%";
    return "$percentage%";
  }
}
