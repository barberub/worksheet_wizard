import 'package:flutter/material.dart';
import 'worksheetscreen.dart';


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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SecondScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

