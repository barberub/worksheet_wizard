import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


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
      final rawList = List<Map<String, dynamic>>.from(json.decode(contents));

      // Convert timestamps back to DateTime
      return rawList.map(_restoreFromLocal).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveWorksheets(List<Map<String, dynamic>> worksheets) async {
    final file = await _localFile;

    // Convert all worksheets to be JSON-safe
    final cleanWorksheets = worksheets.map(_prepareForLocal).toList();

    await file.writeAsString(json.encode(cleanWorksheets));
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

  Map<String, dynamic> _prepareForLocal(Map<String, dynamic> worksheet) {
    final copy = Map<String, dynamic>.from(worksheet);

    if (copy['lastSaved'] is Timestamp) {
      copy['lastSaved'] = (copy['lastSaved'] as Timestamp).toDate().toIso8601String();
    }

    if (copy['lastModified'] is Timestamp) {
      copy['lastModified'] = (copy['lastModified'] as Timestamp).toDate().toIso8601String();
    }

    return copy;
  }

  Map<String, dynamic> _restoreFromLocal(Map<String, dynamic> worksheet) {
    final copy = Map<String, dynamic>.from(worksheet);

    if (copy['lastSaved'] is String) {
      try {
        copy['lastSaved'] = DateTime.parse(copy['lastSaved']);
      } catch (_) {
        // Leave as-is if parsing fails
      }
    }

    return copy;
  }


  void deleteAccount(BuildContext context) async {
    
    bool confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  ) ?? false;

    if (confirmed) {

      final collection = FirebaseFirestore.instance.collection('worksheets');

      final snapshot = await collection.where('creator', isEqualTo: FirebaseAuth.instance.currentUser?.uid).get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      try {
        await FirebaseAuth.instance.currentUser?.delete();

      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // 🔁 Show reauth dialog
          _showReauthDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: ${e.message}')),
          );
        }
      }
    }
  }

  void _showReauthDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Re-authenticate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter your email and password to confirm.'),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final credential = EmailAuthProvider.credential(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                );

                final user = FirebaseAuth.instance.currentUser;
                await user?.reauthenticateWithCredential(credential);

                // Try deletion again
                await user?.delete();
                Navigator.pop(context); // close dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Account deleted successfully!')),
                );
              } catch (e) {
                print('Reauth failed: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Re-authentication failed.')),
                );
              }
            },
            child: Text('Confirm & Delete'),
          ),
        ],
      ),
    );
  }

}