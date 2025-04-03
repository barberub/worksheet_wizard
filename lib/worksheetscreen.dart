import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SecondScreen extends StatefulWidget {
  const SecondScreen({super.key});

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  double _expandedHeight = 100;
  final double _collapsedHeight = 100;
  final double _maxExpandedHeight = 400;
  final double _bufferSpace = 100;
  final double _paperAspectRatio = 8.5 / 11;
  bool _isExpanded = false;

  List<Question> _questions = [];

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
      if (_questions.isEmpty) return;

      final question = _questions.first;
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Question 1:', style: pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 8),
                pw.Text(question.text, style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 8),
                ...List.generate(question.answerLineCount, (_) => 
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

  @override
  Widget build(BuildContext context) {
    // double appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    // double remainingHeight = MediaQuery.of(context).size.height - appBarHeight - _expandedHeight;

    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Title'),
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
                      child: _questions.isEmpty
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
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return ListTile(
                            title: Text('Question ${index + 1}: ${question.text}'),
                            trailing: IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _openEditDialog(context, index),
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
        onPressed: () => _openAddDialog(context),
        child: const Icon(Icons.add),
      ),
      
    );
  }

  void _openEditDialog(BuildContext context, int index) {
    final question = _questions[index];

    // Controllers initialized with existing values
    final textController = TextEditingController(text: question.text);
    final qaSpaceController = TextEditingController(text: question.qaSpace.toString());
    bool hasLines = question.hasAnswerLines;
    final answerLineCountController = TextEditingController(text: question.answerLineCount.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Question'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: textController,
                  minLines: 1,
                  maxLines: null,
                  decoration: InputDecoration(labelText: 'Question Text'),
                ),
                TextField(
                  controller: qaSpaceController,
                  decoration: InputDecoration(labelText: 'QA Space'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: Text('Has Answer Lines'),
                  value: hasLines,
                  onChanged: (val) {
                    hasLines = val;
                    // Rebuild the dialog to reflect changes if needed
                    (context as Element).markNeedsBuild();
                  },
                ),
                if (hasLines)
                  TextField(
                    controller: answerLineCountController,
                    decoration: InputDecoration(labelText: 'Answer Line Count'),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _questions[index] = Question(
                    text: textController.text,
                    qaSpace: int.tryParse(qaSpaceController.text) ?? 0,
                    hasAnswerLines: hasLines,
                    answerLineCount: hasLines
                        ? int.tryParse(answerLineCountController.text) ?? 0
                        : 0,
                  );
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _openAddDialog(BuildContext context) {

    // Controllers initialized with existing values
    final textController = TextEditingController(text: '');
    final qaSpaceController = TextEditingController(text: '1');
    bool hasLines = false;
    final answerLineCountController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Question'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: textController,
                  minLines: 1,
                  maxLines: null,
                  decoration: InputDecoration(labelText: 'Question Text'),
                ),
                TextField(
                  controller: qaSpaceController,
                  decoration: InputDecoration(labelText: 'QA Space'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: Text('Has Answer Lines'),
                  value: hasLines,
                  onChanged: (val) {
                    hasLines = val;
                    // Rebuild the dialog to reflect changes if needed
                    (context as Element).markNeedsBuild();
                  },
                ),
                if (hasLines)
                  TextField(
                    controller: answerLineCountController,
                    decoration: InputDecoration(labelText: 'Answer Line Count'),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _questions.add(Question(
                    text: textController.text,
                    qaSpace: int.tryParse(qaSpaceController.text) ?? 0,
                    hasAnswerLines: hasLines,
                    answerLineCount: hasLines
                        ? int.tryParse(answerLineCountController.text) ?? 0
                        : 0,
                  ));
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  
}



class Question {
  final String text;
  final int qaSpace;
  final bool hasAnswerLines;
  final int answerLineCount;

  Question({
    required this.text,
    required this.qaSpace,
    required this.hasAnswerLines,
    required this.answerLineCount,
  });

  // JSON serialization for Firestore/local storage
  Map<String, dynamic> toJson() => {
    'text': text,
    'qaSpace': qaSpace,
    'hasAnswerLines': hasAnswerLines,
    'answerLineCount': answerLineCount,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    text: json['text'] ?? '',
    qaSpace: json['qaSpace'] ?? 0,
    hasAnswerLines: json['hasAnswerLines'] ?? false,
    answerLineCount: json['answerLineCount'] ?? 0,
  );

}