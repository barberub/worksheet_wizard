import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'storage_service.dart';

class SecondScreen extends StatefulWidget {
  final Map<String, dynamic> worksheetData;
  final int worksheetIndex;
  final List<Map<String, dynamic>> allWorksheets;
  final VoidCallback? onSave;

  const SecondScreen({
    super.key,
    required this.worksheetData,
    required this.worksheetIndex,
    required this.allWorksheets,
    this.onSave,
  });

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}


class _SecondScreenState extends State<SecondScreen> {
  late Map<String, dynamic> worksheet;
  double _expandedHeight = 100;
  final double _collapsedHeight = 100;
  final double _maxExpandedHeight = 400;
  final double _bufferSpace = 100;
  final double _paperAspectRatio = 8.5 / 11;
  bool _isExpanded = false;
  final StorageService storage = StorageService();


  @override
  void initState() {
    super.initState();
    worksheet = Map<String, dynamic>.from(widget.worksheetData);
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      _expandedHeight = _isExpanded ? _maxExpandedHeight : _collapsedHeight;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _expandedHeight += details.delta.dy;
      _expandedHeight = _expandedHeight.clamp(_collapsedHeight, _maxExpandedHeight);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isExpanded = _expandedHeight > (_collapsedHeight + _maxExpandedHeight) / 2;
      _expandedHeight = _isExpanded ? _maxExpandedHeight : _collapsedHeight;
    });
  }

    void _onSelected(String value) async {
    // Handle dropdown menu selection
    if (value == 'print') {
      if (worksheet['questions'].isEmpty) return;

      final question = worksheet['questions'][0];
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Question 1:', style: pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 8),
                pw.Text(question['questionText'], style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 8),
                ...List.generate(question['answerSpaces'], (_) => 
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    height: 2,
                    color: PdfColors.black,
                  )
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }

    if (value == 'layout') {

    }
  }

  Future<void> saveWorksheet() async {
    // Update the worksheet in the overall list
    widget.allWorksheets[widget.worksheetIndex] = worksheet;
    await storage.saveWorksheets(widget.allWorksheets);
    widget.onSave?.call(); // to refresh HomeScreen if needed
  }

  @override
  Widget build(BuildContext context) {
    // double appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    // double remainingHeight = MediaQuery.of(context).size.height - appBarHeight - _expandedHeight;

    
    return Scaffold(
      appBar: AppBar(
        title: Text(worksheet['worksheetTitle']),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onSelected,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'print', child: Text('Print')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Expandable Section (Now Lighter)
          GestureDetector(
            onTap: _toggleExpansion,
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _expandedHeight,
              width: double.infinity, // Prevents overflow
              decoration: const BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show "Questions" only when collapsed
                  if (!_isExpanded)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        "Questions",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),

                  // Expandable Content
                  if (_isExpanded)
                    Expanded(
                      child: worksheet['questions'].isEmpty
                      ? Center(
                        child: Text(
                          'No Questions!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          )
                          ),
                        )
                      : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: worksheet['questions'].length,
                        itemBuilder: (context, index) {
                          final question = worksheet['questions'][index];
                          return ListTile(
                            title: Text('Question ${index + 1}: ${question['questionText']}'),
                            trailing: IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _openEditDialog(index),
                            ),
                          );
                        },
                      ),
                    ),

                  // Notch (Inside)
                  Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Section (Now Darker)
          Expanded(
            child: Container(
              color: const Color(0xFF424242),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double availableHeight = constraints.maxHeight - _bufferSpace;
                  double rectangleHeight = availableHeight * 0.75;
                  double rectangleWidth = rectangleHeight * _paperAspectRatio;

                  // Ensure the rectangle never exceeds screen width
                  if (rectangleWidth > constraints.maxWidth * 0.9) {
                    rectangleWidth = constraints.maxWidth * 0.9;
                    rectangleHeight = rectangleWidth / _paperAspectRatio;
                  }

                  return Center(
                    child: SizedBox(
                      width: rectangleWidth,
                      height: rectangleHeight,
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDialog(),
        child: const Icon(Icons.add),
      ),
      
    );
  }

  void _openEditDialog(int index) {
    final question = worksheet['questions'][index];

    final TextEditingController questionController =
        TextEditingController(text: question['questionText']);
    int fillerLines = question['fillerLines'];
    bool hasAnswerLines = question['hasAnswerLines'];
    int answerSpaces = question['answerSpaces'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: 'Question Text'),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Filler Lines'),
              onChanged: (val) => fillerLines = int.tryParse(val) ?? fillerLines,
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Answer Spaces'),
              onChanged: (val) => answerSpaces = int.tryParse(val) ?? answerSpaces,
            ),
            Row(
              children: [
                const Text('Include Answer Lines?'),
                Switch(
                  value: hasAnswerLines,
                  onChanged: (val) => setState(() => hasAnswerLines = val),
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = questionController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  worksheet['questions'][index] = {
                    'questionText': text,
                    'fillerLines': fillerLines,
                    'hasAnswerLines': hasAnswerLines,
                    'answerSpaces': answerSpaces,
                  };
                });
                Navigator.pop(context);
                await saveWorksheet(); // save to file
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


void _openAddDialog() {
  final TextEditingController questionController = TextEditingController();
  int fillerLines = 1;
  bool answerLines = true;
  int answerSpaces = 1;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Question'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question Text'),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Filler Lines'),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  fillerLines = int.tryParse(val) ?? 1;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Answer Spaces'),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  answerSpaces = int.tryParse(val) ?? 1;
                },
              ),
              Row(
                children: [
                  const Text('Answer Lines'),
                  const Spacer(),
                  Switch(
                    value: answerLines,
                    onChanged: (val) {
                      setState(() => answerLines = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = questionController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    worksheet['questions'].add({
                      'questionText': text,
                      'fillerLines': fillerLines,
                      'hasAnswerLines': answerLines,
                      'answerSpaces': answerSpaces,
                    });
                  });

                  Navigator.pop(context);
                  await saveWorksheet(); // Save to file
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    },
  );
}



  
}



