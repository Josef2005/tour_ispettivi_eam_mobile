import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../core/database/database_helper.dart';
import '../models/attachment.dart';
import '../models/inspection_activity.dart';

class AttachmentViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();

  final String itemId; // activity idext
  final String activityName;
  List<Attachment> _attachments = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Attachment> get attachments => _attachments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AttachmentViewModel({required this.itemId, required this.activityName}) {
    loadAttachments();
  }

  Future<void> loadAttachments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _dbHelper.queryItems(
        'Attachment',
        where: 'ItemId = ?',
        whereArgs: [itemId],
      );
      _attachments = maps.map((m) => Attachment.fromMap(m)).toList();
    } catch (e) {
      _errorMessage = "Errore durante il caricamento degli allegati: $e";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        await _saveFile(File(result.files.single.path!), result.files.single.name);
      }
    } catch (e) {
      _errorMessage = "Errore durante la selezione del file: $e";
      notifyListeners();
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        await _saveFile(File(photo.path), p.basename(photo.path));
      }
    } catch (e) {
      _errorMessage = "Errore durante lo scatto della foto: $e";
      notifyListeners();
    }
  }

  Future<void> takeVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 10),
      );
      if (video != null) {
        await _saveFile(File(video.path), p.basename(video.path));
      }
    } catch (e) {
      _errorMessage = "Errore durante la registrazione del video: $e";
      notifyListeners();
    }
  }

  Future<void> _saveFile(File sourceFile, String originalName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timeStamp = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('-', '').split('.').first;
      final newFileName = "${timeStamp}_$originalName";
      final destFile = File(p.join(directory.path, newFileName));

      await sourceFile.copy(destFile.path);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('USER_ID') ?? "0";

      final mimeType = lookupMimeType(destFile.path) ?? "application/octet-stream";

      final attachment = Attachment(
        itemId: itemId,
        userId: userId,
        dateUploaded: DateTime.now().toIso8601String(),
        fileName: newFileName,
        mimeType: mimeType,
      );

      await _dbHelper.insertOrUpdateItem('Attachment', attachment.toMap(), "0");
      await loadAttachments();
    } catch (e) {
      _errorMessage = "Errore durante il salvataggio dell'allegato: $e";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteAttachment(Attachment attachment) async {
    try {
      await _dbHelper.deleteItems(
        'Attachment',
        where: 'AttachmentId = ?',
        whereArgs: [attachment.attachmentId],
      );
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, attachment.fileName));
      if (await file.exists()) {
        await file.delete();
      }
      
      await loadAttachments();
    } catch (e) {
      _errorMessage = "Errore durante l'eliminazione dell'allegato: $e";
      notifyListeners();
    }
  }

  Future<void> openAttachment(Attachment attachment) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = p.join(directory.path, attachment.fileName);
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        _errorMessage = "Impossibile aprire il file: ${result.message}";
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = "Errore durante l'apertura del file: $e";
      notifyListeners();
    }
  }
}
