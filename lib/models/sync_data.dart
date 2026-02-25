/*
 * Rappresenta un Impianto (Plant)
 */
class Plant {
  final String id;
  final String name;
  final List<String> authTags;

  Plant({required this.id, required this.name, required this.authTags});

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: (json['Id']?.toString() ?? json['id']?.toString() ?? '0').trim(),
      name: json['Description'] ?? json['nome'] ?? '',
      authTags: _parseAuthTags(json['AuthTags'] ?? json['authTags']),
    );
  }

  /*
   * Analizza i tag di autorizzazione (AuthTags) che possono essere in vari formati (JSON array, stringa separata da virgole, o numero)
   */
  static List<String> _parseAuthTags(dynamic rawTags) {
    if (rawTags == null) return [];
    if (rawTags is List) {
      return rawTags.map((e) => e.toString().trim()).toList();
    }
    if (rawTags is String) {
      String str = rawTags.trim();
      if (str.isEmpty) return [];
      if (str.startsWith('[') && str.endsWith(']')) {
        str = str.substring(1, str.length - 1);
      }
      return str.split(',').map((e) => e.trim().replaceAll('"', '').replaceAll("'", "")).where((e) => e.isNotEmpty).toList();
    }
    if (rawTags is num) {
      return [rawTags.toString()];
    }
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Plant && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/*
 * Rappresenta un Sotto-impianto (SubPlant)
 */
class SubPlant {
  final String id;
  final List<String> referenceId;
  final String name;
  final List<String> authTags;

  SubPlant({
    required this.id,
    required this.referenceId,
    required this.name,
    required this.authTags,
  });

  factory SubPlant.fromJson(Map<String, dynamic> json) {
    var refs = json['ReferenceId'];
    List<String> referenceList = [];
    if (refs is List) {
      referenceList = refs.map((e) => e.toString().trim()).toList();
    } else if (refs is String) {
      referenceList = [refs.trim()];
    }

    return SubPlant(
      id: (json['Id']?.toString() ?? json['id']?.toString() ?? '0').trim(),
      referenceId: referenceList,
      name: json['Description'] ?? json['nome'] ?? '',
      authTags: Plant._parseAuthTags(json['AuthTags'] ?? json['authTags']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubPlant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/*
 * Rappresenta un Utente applicativo (AppUser / Manutentore)
 */
class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final List<String> authTags;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.authTags,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id']?.toString() ?? json['Id']?.toString() ?? '0').trim(),
      firstName: json['name'] ?? json['nome'] ?? json['FirstName'] ?? '',
      lastName: json['surname'] ?? json['cognome'] ?? json['LastName'] ?? '',
      username: json['username'] ?? json['UserName'] ?? '',
      authTags: Plant._parseAuthTags(json['authTags'] ?? json['AuthTags']),
    );
  }

  /*
   * Restituisce il nome completo formattato
   */
  String get displayName => "($id) $lastName $firstName";

  /*
   * Verifica se l'utente ha accesso a un elemento in base ai suoi tag di autorizzazione
   */
  bool hasAccess(List<String> itemTags) {
    if (username.toLowerCase() == 'admin') return true;
    if (itemTags.isEmpty) return true;
    if (authTags.isEmpty) return false;
    return itemTags.any((tag) => authTags.contains(tag));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => displayName;
}

/*
 * Rappresenta un Responsabile (ShiftLeader)
 */
class ShiftLeader {
  final String id;
  final String name;
  final List<String> authTags;

  ShiftLeader({required this.id, required this.name, required this.authTags});

  factory ShiftLeader.fromJson(Map<String, dynamic> json) {
    return ShiftLeader(
      id: (json['Id']?.toString() ?? json['id']?.toString() ?? '0').trim(),
      name: json['Description'] ?? json['nome'] ?? '',
      authTags: Plant._parseAuthTags(json['AuthTags'] ?? json['authTags']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftLeader && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
