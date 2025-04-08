import 'package:flutter/material.dart';
import 'worksheetscreen.dart';
import 'storage_service.dart';


void main() {
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

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Wizard'),
      ),
      body: Container(
        color: Colors.grey[800],
        alignment: Alignment.center,
        child: const Text(
          'Center Content',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
                  onPressed: () => Navigator.pop(context), // Cancel
                    child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(context); // Close dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SecondScreen(worksheetName: name),
                        ),
                      );
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }*/
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
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
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
                      }
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

}

