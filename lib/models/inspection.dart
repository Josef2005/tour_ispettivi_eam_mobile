import 'dart:convert';
import 'inspection_activity.dart';
import 'item.dart';

class Inspection extends Item {
  final int completed;
  final int? loggedUser;
  final String? dataInizioInt; // Mappato su Data_Inizio_Intervento nel DB
  final String? dataFineInt;   // Mappato su Data_Fine_Intervento nel DB

  Inspection({
    super.id,
    required super.idext,
    super.code,
    super.description,
    super.details,
    super.sync,
    this.completed = 0,
    this.loggedUser,
    this.dataInizioInt,
    this.dataFineInt,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    final item = Item.fromJson(json);
    return Inspection(
      idext: item.idext,
      code: item.code,
      description: item.description,
      details: item.details,
      sync: 0,
      completed: 0,
    );
  }

  factory Inspection.fromMap(Map<String, dynamic> map) {
    final item = Item.fromMap(map);
    return Inspection(
      id: item.id,
      idext: item.idext,
      code: item.code,
      description: item.description,
      details: item.details,
      sync: item.sync,
      completed: map['completed'] ?? 0,
      loggedUser: map['loggedUser'],
      dataInizioInt: map['Data_Inizio_Intervento'],
      dataFineInt: map['Data_Fine_Intervento'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'completed': completed,
      'loggedUser': loggedUser,
      'Data_Inizio_Intervento': dataInizioInt,
      'Data_Fine_Intervento': dataFineInt,
    });
    return map;
  }

  // Costanti per le chiavi dei dettagli dal progetto Android
  static const String keyCurrentStateId = 'CurrentStateId';
  static const String KEY_X_ID_MAN_SCHEDA_A_STATO = "X_ID_MAN_SCHEDA_A_STATO";
  static const String keyInspectionTour = 'TOUR_ISPETTIVO';
  static const String keyPlant = 'IMPIANTO';
  static const String keySubPlant = 'SOTTO_IMPIANTO';
  static const String keyPlannedDate = 'DATA_PREVISTA';

  /*
   * Calcola la percentuale di completamento basata sulle attività caricate
   */
  int getCompletionPercentage(List<InspectionActivity> activities) {
    if (activities.isEmpty) return -1;
    
    int completedCount = activities.where((a) => a.isCompleted).length;
    return (completedCount / activities.length * 100).round();
  }

  /*
   * Restituisce il testo descrittivo della percentuale di completamento
   */
  String getCompletionText(List<InspectionActivity> activities) {
    int percentage = getCompletionPercentage(activities);
    if (percentage == -1) return "Nessuna attività";
    return "$percentage %";
  }
}
