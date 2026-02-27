import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/inspection.dart';
import '../models/inspection_activity.dart';
import '../models/item.dart';

class ActivityListViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Inspection inspection;
  final String assetId;
  final String assetLabel;

  List<InspectionActivity> _activities = [];
  Map<String, int> _attachmentCounts = {};
  List<Item> _statiAsset = [];
  Item? _selectedStato;
  bool _isLoading = false;
  String? _errorMessage;

  List<InspectionActivity> get activities => _activities;
  List<Item> get statiAsset => _statiAsset;
  Item? get selectedStato => _selectedStato;
  Map<String, int> get attachmentCounts => _attachmentCounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ActivityListViewModel({
    required this.inspection,
    required this.assetId,
    required this.assetLabel,
    required List<InspectionActivity> initialActivities,
  }) {
    _activities = initialActivities;
    _initStato();
    loadAttachmentCounts();
  }

  Future<void> _initStato() async {
    _statiAsset = (await _dbHelper.queryItems('item', where: 'classid = ?', whereArgs: ['STATI_ASSET_ISP']))
        .map((m) => Item.fromMap(m))
        .toList();
    
    // Seleziona lo stato corrente basandosi sulla prima attività
    if (_activities.isNotEmpty) {
      final currentStatoId = _activities.first.getStringDetailValue('StatoAsset');
      try {
        _selectedStato = _statiAsset.firstWhere((s) => s.idext == currentStatoId);
      } catch (_) {
        // Default "In Marcia" if found
        try {
          _selectedStato = _statiAsset.firstWhere((s) => s.code?.toLowerCase() == 'in marcia');
        } catch (_) {
          if (_statiAsset.isNotEmpty) _selectedStato = _statiAsset.first;
        }
      }
    }
    notifyListeners();
  }

  int get percentage {
    if (_activities.isEmpty) return 0;
    int completed = _activities.where((a) => a.isCompleted).length;
    return (completed / _activities.length * 100).round();
  }

  String get nonInMarcia {
    if (_activities.isEmpty) return '0';
    return _activities.first.getStringDetailValue('NonInMarcia');
  }

  Future<void> selectStatoAsset(Item stato) async {
    _selectedStato = stato;
    await updateNonInMarcia(stato.idext, stato.code ?? '');
  }

  Future<void> updateNonInMarcia(String statoAssetId, String label) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Recupera il flag NON_IN_MARCIA dallo stato selezionato
      final items = await _dbHelper.queryItems('item', where: 'idext = ?', whereArgs: [statoAssetId]);
      if (items.isEmpty) return;
      
      final statoItem = Item.fromMap(items.first);
      final nonInMarciaValue = statoItem.getStringDetailValue('NON_IN_MARCIA');

      for (var act in _activities) {
        if (nonInMarciaValue == '1') {
          // Parity Android: Se non in marcia, imposta N.A. (NULL) per tipo 3 e rimuovi anomalia
          if (act.getTipoRisposta() == '3') {
            act.setRisposta('NULL');
          }
          act.setAnomalia('0');
        }

        act.setDetailValue('NonInMarcia', nonInMarciaValue);
        act.setDetailValue('StatoAsset', statoAssetId);
        act.setDetailLabel('StatoAsset', label);
        act.setSync(0);
        act.setTimestamp();
        await act.update(_dbHelper);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateActivityResponse(InspectionActivity activity, String? response, {BuildContext? context}) async {
    activity.setRisposta(response);
    
    // Se la risposta è positiva (OK), pulisci la nota come richiesto dall'utente
    if (response == 'True' || response == '1') {
      activity.setNota('');
    }

    activity.setTimestamp();
    activity.setSync(0);
    _calculateAnomalia(activity);
    await activity.update(_dbHelper);
    notifyListeners();
  }

  Future<void> updateActivityNote(InspectionActivity activity, String note) async {
    activity.setNota(note);
    activity.setTimestamp();
    activity.setSync(0);
    _calculateAnomalia(activity);
    await activity.update(_dbHelper);
    notifyListeners();
  }

  void _calculateAnomalia(InspectionActivity activity) {
    String anomalia = "0";
    String risposta = activity.getRisposta();
    
    // Logica di parity con InspectionRecyclerAdapter.java:updateAnomalia
    if (!InspectionActivity.checkAnswer(risposta)) {
      if (activity.getNota().trim().isNotEmpty) {
        anomalia = "1";
      }
    } else {
      String nonInMarcia = activity.getStringDetailValue('NonInMarcia');
      if (nonInMarcia != '1') {
        final tipo = activity.getTipoRisposta();
        final details = activity.details;

        if (tipo == '1') { // Numerico
          final constraints = activity.details.where((d) => ['<', '<=', '>', '>=', '=', '<>'].contains(d.name.toUpperCase()));
          for (var constraint in constraints) {
            double? respVal = double.tryParse(risposta.replaceAll(',', '.'));
            double? constVal = double.tryParse(constraint.value?.replaceAll(',', '.') ?? '');
            
            if (respVal == null || constVal == null) {
              anomalia = "1";
              break;
            }

            final op = constraint.name.toUpperCase();
            if (op == '<' && respVal >= constVal) anomalia = "1";
            else if (op == '<=' && respVal > constVal) anomalia = "1";
            else if (op == '>' && respVal <= constVal) anomalia = "1";
            else if (op == '>=' && respVal < constVal) anomalia = "1";
            else if (op == '=' && respVal != constVal) anomalia = "1";
            else if (op == '<>' && respVal == constVal) anomalia = "1";
            
            if (anomalia == "1") break;
          }
        } else if (tipo == '2') { // Dropdown
          // In Android: cerca se il valore selezionato ha "Accepted" != 1
          // Qui i dettagli della dropdown sono di solito memorizzati come ItemProperty con nomi tipo "VALORE_1", "VALORE_2"
          // o simili, ma la logica Android presuppone una struttura specifica in elencoValori.
          // Per ora semplifichiamo o cerchiamo di mappare la logica Android
          for (var prop in details) {
            if (prop.name == risposta) {
              // Esempio: "descrizione:codice:accepted"
              final parts = (prop.value ?? '').split(':');
              if (parts.length >= 3 && parts[2] != '1') {
                anomalia = "1";
              }
              break;
            }
          }
        } else if (tipo == '3') { // Bottoni OK/Anomalia/N.A.
          if (risposta.toLowerCase() == 'false' || risposta == '0') {
            anomalia = "1";
          }
        }
      }
    }
    activity.setAnomalia(anomalia);
  }

  InspectionActivity? checkMandatoryNotes() {
    for (var act in _activities) {
      if (act.isAnomaly && act.getNota().trim().isEmpty) {
        return act;
      }
    }
    return null;
  }

  Map<String, dynamic>? getNextIncompleteAsset(List<Map<String, dynamic>> fullAssetList) {
    // Cerca il primo asset che non sia al 100%
    try {
      return fullAssetList.firstWhere((asset) => (asset['percentage'] as int? ?? 0) < 100);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAttachmentCounts() async {
    for (var act in _activities) {
      final res = await _dbHelper.queryItems('Attachment', where: 'ItemId = ?', whereArgs: [act.idext]);
      _attachmentCounts[act.idext] = res.length;
    }
    notifyListeners();
  }

  int getAttachmentCount(String activityId) {
    return _attachmentCounts[activityId] ?? 0;
  }
}
