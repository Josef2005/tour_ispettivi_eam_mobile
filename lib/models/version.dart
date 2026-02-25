/*
 * Rappresenta l'informazione sulla versione dei dati (per la sincronizzazione incrementale)
 */
class Version {
  final String info;
  final int version;

  Version({required this.info, required this.version});

  factory Version.fromJson(Map<String, dynamic> json) {
    return Version(
      info: json['Info'] ?? '',
      version: json['Version'] ?? 0,
    );
  }

  factory Version.fromMap(Map<String, dynamic> map) {
    return Version(
      info: map['info'] ?? '',
      version: map['version'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'info': info,
      'version': version,
    };
  }

  // Costanti per le tipologie di versione (derivate dall'app Android)
  static const String infoItems = 'ITEMS';
  static const String infoItemsLinks = 'ITEMS_LINKS';
  static const String infoDocumentsLinks = 'DOCUMENTS_LINKS';
  static const String infoIspezioni = 'ISPEZIONI';
}
