import 'dart:io';

class Attachment {
  final int? attachmentId;
  final int? idExt;
  final String itemId; // activity idext
  final String userId;
  final String dateUploaded;
  final String fileName;
  final String mimeType;
  final int sync;

  Attachment({
    this.attachmentId,
    this.idExt,
    required this.itemId,
    required this.userId,
    required this.dateUploaded,
    required this.fileName,
    required this.mimeType,
    this.sync = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'AttachmentId': attachmentId,
      'IdExt': idExt,
      'ItemId': itemId,
      'UserId': userId,
      'DateUploaded': dateUploaded,
      'FileName': fileName,
      'MIMEType': mimeType,
      'Sync': sync,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      attachmentId: map['AttachmentId'],
      idExt: map['IdExt'],
      itemId: map['ItemId']?.toString() ?? '',
      userId: map['UserId']?.toString() ?? '',
      dateUploaded: map['DateUploaded'] ?? '',
      fileName: map['FileName'] ?? '',
      mimeType: map['MIMEType'] ?? '',
      sync: map['Sync'] ?? 0,
    );
  }

  File getFile(String appDocumentsDir) {
    return File('$appDocumentsDir/$fileName');
  }
}
