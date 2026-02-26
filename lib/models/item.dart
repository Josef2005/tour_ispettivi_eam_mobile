import 'dart:convert';

class ItemProperty {
  final String name;
  final String? value;
  final String? label;
  final String? valueLabel;

  ItemProperty({
    required this.name,
    this.value,
    this.label,
    this.valueLabel,
  });

  factory ItemProperty.fromJson(Map<String, dynamic> json) {
    return ItemProperty(
      name: json['Name'] ?? '',
      value: json['Value']?.toString(),
      label: json['Label']?.toString(),
      valueLabel: json['ValueLabel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Value': value,
      'Label': label,
      'ValueLabel': valueLabel,
    };
  }
}

class Item {
  final int? id;
  final String idext; // Originariamente idExt, rinominato per coerenza con il DB e Android
  final String? code;
  final String? description;
  final String? classId;
  final String? classDescr;
  List<ItemProperty> details;
  final int sync;

  Item({
    this.id,
    required this.idext,
    this.code,
    this.description,
    this.classId,
    this.classDescr,
    this.details = const [],
    this.sync = 0,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    var detailsList = json['Details'] as List? ?? [];
    return Item(
      idext: json['Id']?.toString() ?? '',
      code: json['Code']?.toString(),
      description: json['Description']?.toString(),
      classId: json['TypeId']?.toString(),
      classDescr: json['TypeDescr']?.toString(),
      details: detailsList.map((e) => ItemProperty.fromJson(e)).toList(),
      sync: 0,
    );
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    String detailsJson = map['details'] ?? '[]';
    List<dynamic> detailsList = jsonDecode(detailsJson);
    
    return Item(
      id: map['id'],
      idext: map['idext'] ?? '',
      code: map['code'],
      description: map['description'],
      classId: map['classid'],
      classDescr: map['classdescr'],
      details: detailsList.map((e) => ItemProperty.fromJson(e)).toList(),
      sync: map['sync'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idext': idext,
      'code': code,
      'description': description,
      'classid': classId,
      'classdescr': classDescr,
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

  void setDetailValue(String name, String value) {
    try {
      final prop = details.firstWhere((e) => e.name.toUpperCase() == name.toUpperCase());
      // Creiamo una nuova lista se quella attuale è const
      final newList = List<ItemProperty>.from(details);
      newList.remove(prop);
      newList.add(ItemProperty(
          name: prop.name,
          value: value,
          label: prop.label,
          valueLabel: prop.valueLabel));
      details = newList;
    } catch (_) {
      final newList = List<ItemProperty>.from(details);
      newList.add(ItemProperty(name: name, value: value));
      details = newList;
    }
  }
}
