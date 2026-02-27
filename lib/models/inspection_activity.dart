import 'dart:convert';
import 'item.dart';

class InspectionActivity {
  final int? id;
  final String idext; // Originariamente idExt
  final String? code;
  final String? description;
  final String? ispezioneId; // Mappato su ispezione_id nel DB
  List<ItemProperty> details;
  int sync;

  InspectionActivity({
    this.id,
    required this.idext,
    this.code,
    this.description,
    this.ispezioneId,
    this.details = const [],
    this.sync = 0,
  });

  factory InspectionActivity.fromJson(Map<String, dynamic> json, {String? ispezioneId}) {
    var detailsList = json['Details'] as List? ?? [];
    return InspectionActivity(
      idext: json['Id']?.toString() ?? '',
      code: json['Code']?.toString(),
      description: json['Description']?.toString(),
      ispezioneId: ispezioneId,
      details: detailsList.map((e) => ItemProperty.fromJson(e)).toList(),
      sync: 0,
    );
  }

  factory InspectionActivity.fromMap(Map<String, dynamic> map) {
    String detailsJson = map['details'] ?? '[]';
    final item = Item.fromMap(map);
    return InspectionActivity(
      id: item.id,
      idext: item.idext,
      code: item.code,
      description: item.description,
      details: item.details,
      sync: item.sync,
      ispezioneId: map['ispezione_id'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'idext': idext,
      'code': code,
      'description': description,
      'ispezione_id': ispezioneId,
      'details': jsonEncode(details.map((e) => e.toJson()).toList()),
      'sync': sync,
    };
  }

  /*
   * Restituisce il valore di un singolo dettaglio ricercandolo per nome
   */
  String getStringDetailValue(String propName) {
    try {
      return details.firstWhere((e) => e.name.toUpperCase() == propName.toUpperCase()).value ?? '';
    } catch (_) {
      return '';
    }
  }

  /*
   * Restituisce la label (o il valore se la label manca) di un dettaglio ricercandolo per nome
   */
  String getStringDetailValueLabel(String propName) {
    try {
      final prop = details.firstWhere((e) => e.name.toUpperCase() == propName.toUpperCase());
      return prop.valueLabel ?? prop.value ?? '';
    } catch (_) {
      return '';
    }
  }

  /*
   * Verifica se l'attività è completata base a risposta, nota o stato "Non in marcia"
   */
  bool get isCompleted {
    String nonInMarcia = getStringDetailValue('NonInMarcia');
    if (nonInMarcia == '1') return true;

    String risposta = getStringDetailValue('Risposta');
    if (checkAnswer(risposta)) return true;

    String nota = getStringDetailValue('Nota');
    if (nota.trim().isNotEmpty) return true;

    return false;
  }

  void setDetailValue(String name, String value) {
    var newList = List<ItemProperty>.from(details);
    try {
      final prop = newList.firstWhere((e) => e.name.toUpperCase() == name.toUpperCase());
      int index = newList.indexOf(prop);
      newList[index] = ItemProperty(
        name: prop.name,
        value: value,
        label: prop.label,
        valueLabel: prop.valueLabel,
      );
    } catch (_) {
      newList.add(ItemProperty(name: name, value: value));
    }
    details = newList;
  }

  void setDetailLabel(String name, String label) {
    var newList = List<ItemProperty>.from(details);
    try {
      final prop = newList.firstWhere((e) => e.name.toUpperCase() == name.toUpperCase());
      int index = newList.indexOf(prop);
      newList[index] = ItemProperty(
        name: prop.name,
        value: prop.value,
        label: prop.label,
        valueLabel: label,
      );
    } catch (_) {
      newList.add(ItemProperty(name: name, valueLabel: label));
    }
    details = newList;
  }

  void setRisposta(String? value) {
    setDetailValue('Risposta', value ?? '');
  }

  void setNota(String? value) {
    setDetailValue('Nota', value ?? '');
  }

  void setAnomalia(String value) {
    setDetailValue('ANOMALIA', value);
  }

  void setSync(int value) {
    sync = value;
  }

  void setTimestamp() {
    final now = DateTime.now().toUtc().toIso8601String().replaceFirst('Z', '.000Z');
    setDetailValue('Timestamp', now);
  }

  String getTipoRisposta() {
    return getStringDetailValue('TIPO_RISPOSTA');
  }

  String getRisposta() {
    return getStringDetailValue('Risposta');
  }

  String getNota() {
    return getStringDetailValue('Nota');
  }

  String getAnomalia() {
    return getStringDetailValue('ANOMALIA');
  }

  Future<void> update(dynamic dbHelper) async {
    // Si assume che dbHelper esponga insertOrUpdateItem
    await dbHelper.insertOrUpdateItem('ispezioni_att', toMap(), idext);
  }

  /*
   * Converte l'attività nel formato TableRow richiesto dal server (Parity Android)
   */
  Map<String, dynamic> toServerTableRow() {
    final List<Map<String, dynamic>> values = [
      {'ColumnName': 'ATTIVITA', 'Value': getStringDetailValue('ATTIVITA')},
      {'ColumnName': 'Risposta', 'Value': getStringDetailValue('Risposta')},
      {'ColumnName': 'NonInMarcia', 'Value': getStringDetailValue('NonInMarcia')},
      {'ColumnName': 'Nota', 'Value': getStringDetailValue('Nota')},
      {'ColumnName': 'ANOMALIA', 'Value': getStringDetailValue('ANOMALIA')},
      {'ColumnName': 'TIPO_RISPOSTA', 'Value': getStringDetailValue('TIPO_RISPOSTA')},
      {'ColumnName': 'AssetId', 'Value': getStringDetailValue('AssetId')},
      {'ColumnName': 'TagName', 'Value': getStringDetailValue('TagName')},
      {'ColumnName': 'Timestamp', 'Value': getStringDetailValue('Timestamp')},
      {'ColumnName': 'StatoAsset', 'Value': getStringDetailValue('StatoAsset')},
      {'ColumnName': 'NumeroNotification', 'Value': getStringDetailValue('NumeroNotification')},
    ];

    return {
      'Id': int.tryParse(idext) ?? 0,
      'Values': values,
    };
  }

  /*
   * Restituisce se l'attività è in anomalia
   */
  bool get isAnomaly => getStringDetailValue('ANOMALIA') == '1';

  /*
   * Restituisce la nota dell'attività
   */
  String get note => getStringDetailValue('Nota');

  /*
   * Verifica se l'attività è in anomalia e se la nota è obbligatoria
   */
  void checkAnomalia() {
    if (isAnomaly && note.trim().isEmpty) {
      throw Exception('Nota obbligatoria per attività in anomalia: $description');
    }
  }

  /*
   * Verifica se la risposta è formalmente corretta (evita caratteri segnaposto)
   */
  static bool checkAnswer(String? answer) {
    if (answer == null) return false;
    String r = answer.trim();
    if (r.isEmpty) return false;
    return !['.', ',', '-', '+', '+.', '-.', '+,', '-,'].contains(r);
  }
}
