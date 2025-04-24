import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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

  Future<void> cloudSave(Map<String, dynamic> worksheet, String uid) async {
    final collection = FirebaseFirestore.instance.collection('worksheets');
    final isNew = worksheet['wID'] == null;

    final docRef = isNew ? collection.doc() : collection.doc(worksheet['wID']);

    final now = Timestamp.now();

    // This is what gets stored in Firestore
    final worksheetToSave = {
      ...worksheet,
      'wID': docRef.id,
      'lastSaved': now,
      'creator': uid,
    };

    await docRef.set(worksheetToSave, SetOptions(merge: true));

    // 🔁 Update original worksheet (local copy) too
    worksheet['wID'] = docRef.id;
    worksheet['lastSaved'] = now;
    worksheet['creator'] = uid;
  } 

  Future<List<Map<String, dynamic>>> cloudLoad(
    String uid,
    List<Map<String, dynamic>> localWorksheets,
  ) async {
    final collection = FirebaseFirestore.instance.collection('worksheets');
    final snapshot = await collection
        .where('creator', isEqualTo: uid)
        .orderBy('lastSaved', descending: true)
        .get();

    final cloudWorksheets = snapshot.docs.map((doc) => doc.data()).toList();

    // Build a set of existing wIDs from local
    final localWIDs = localWorksheets
        .where((w) => w['wID'] != null)
        .map((w) => w['wID'] as String)
        .toSet();

    // Only add cloud worksheets that are not already in local list
    final newWorksheets = cloudWorksheets
        .where((w) => w['wID'] != null && !localWIDs.contains(w['wID']))
        .toList();

    return [...localWorksheets, ...newWorksheets];
  }

}