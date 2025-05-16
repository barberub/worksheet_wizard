import 'package:flutter/material.dart';
import 'worksheetscreen.dart';
import 'storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner for better visuals
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget  {
  const HomeScreen({super.key});

  
  @override
  State<HomeScreen> createState() => _HomeScreenState();

}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService storage = StorageService();
  List<Map<String, dynamic>> worksheets = [];
  
  @override
  void initState() {
    super.initState();
    loadWorksheets();
  }

  Future<void> loadWorksheets() async {
    final data = await storage.readWorksheets();
    setState(() {
      worksheets = data;
    });
  }

  void addWorksheetDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Worksheet'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Enter worksheet name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newWorksheet = {
                  "worksheetTitle": name,
                  "questions": [],
                  "formatting": {
                    "layout": "single-column",
                    "columns" : 1
                  },
                  "wID" : null,
                  "lastSaved" : null,
                  "creator" : null,
                };

                final current = await storage.readWorksheets();
                current.add(newWorksheet);
                await storage.saveWorksheets(current);

                // Reload list
                await loadWorksheets();

                Navigator.pop(context); // close dialog

                // Navigate to it immediately
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SecondScreen(
                      worksheetData: newWorksheet,
                      worksheetIndex: current.length - 1,
                      allWorksheets: current,
                      onSave: loadWorksheets,
                    ),
                  ),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Wizard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Load from Cloud',
            onPressed: _loadFromCloud,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showAccountDialog,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[800],
        child: worksheets.isEmpty
            ? const Center(
                child: Text('No worksheets yet!',
                    style: TextStyle(color: Colors.white)),
              )
            : ListView.builder(
                itemCount: worksheets.length,
                itemBuilder: (context, index) {
                  final worksheet = worksheets[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      title: Text(worksheet['worksheetTitle']),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SecondScreen(
                              worksheetData: worksheets[index],
                              worksheetIndex: index,
                              allWorksheets: worksheets,
                              onSave: loadWorksheets,
                            ),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'delete_local') {
                            setState(() {
                              worksheets.removeAt(index);
                            });
                            await storage.saveWorksheets(worksheets);
                          } else if (value == 'delete_cloud') {
                            final wID = worksheet['wID'];
                            if (wID != null) {
                              await FirebaseFirestore.instance.collection('worksheets').doc(wID).delete();
                            }
                            setState(() {
                              worksheets.removeAt(index);
                            });
                            await storage.saveWorksheets(worksheets);
                          }
                        },
                        itemBuilder: (context) {
                          final items = <PopupMenuEntry<String>>[
                            const PopupMenuItem(
                              value: 'delete_local',
                              child: Text('Delete Locally'),
                            ),
                          ];

                          if (worksheet['wID'] != null) {
                            items.add(
                              const PopupMenuItem(
                                value: 'delete_cloud',
                                child: Text('Delete from Cloud + Local'),
                              ),
                            );
                          }

                          return items;
                        },
                      ),
                    ),
                  );

                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addWorksheetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAccountDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    String? errorMessage; // 👈 to store the error

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(user == null ? 'Login' : 'Account'),
            content: user == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  )
                : Text('Logged in as: ${user.email}'),
            actions: [
              if (user == null) ...[
                TextButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );
                      Navigator.pop(context); // close dialog on success
                      setState(() {}); // refresh
                      setState(() => errorMessage = null); // clear error

                      // ✅ Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully logged in!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      print('Login error: $e');
                      setState(() => errorMessage = 'Login failed: ${_formatFirebaseError(e)}');
                    }
                  },
                  child: const Text('Login'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );
                      Navigator.pop(context);
                      setState(() => errorMessage = null);
                                            // ✅ Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully signed up!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      print('Signup error: $e');
                      setState(() => errorMessage = 'Signup failed: ${_formatFirebaseError(e)}');
                    }
                  },
                  child: const Text('Sign Up'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Logout'),
                ),

                TextButton(
                  onPressed: () async {
                    storage.deleteAccount(context);
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Delete Account'),
                ),
              ]
            ],
          );
        });
      },
    );
  }

  Future<void> _loadFromCloud() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please log in to load from cloud')),
    );
    return;
  }

  try {
    final snapshot = await FirebaseFirestore.instance
      .collection('worksheets')
      .where('creator', isEqualTo: user.uid)
      .get();

    final cloudWorksheets = snapshot.docs.map((doc) {
      final data = doc.data();
      data['wID'] = doc.id; // Ensure wID is set
      return data;
    }).toList();
    final merged = [...worksheets];

    // Only add cloud ones not already in the local list by wID
    for (final cloudWS in cloudWorksheets) {
      final wID = cloudWS['wID'];
      if (wID != null && !merged.any((ws) => ws['wID'] == wID)) {
        merged.add(cloudWS);
      }
    }

    setState(() {
      worksheets = merged;
    });


    await storage.saveWorksheets(worksheets);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Worksheets loaded from cloud')),
    );
  } catch (e) {
    print('Cloud load error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load from cloud')),
    );
  }
}

  String _formatFirebaseError(dynamic e) {
    if (e is FirebaseAuthException) {
      return e.message ?? 'Unknown error';
    }
    return e.toString();
  }



}

