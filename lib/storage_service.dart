import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/worksheets.json');
  }

  Future<List<Map<String, dynamic>>> readWorksheets() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      return List<Map<String, dynamic>>.from(json.decode(contents));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveWorksheets(List<Map<String, dynamic>> worksheets) async {
    final file = await _localFile;
    await file.writeAsString(json.encode(worksheets));
  }
}