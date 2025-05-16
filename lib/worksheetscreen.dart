import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'dart:typed_data';
import 'dart:ui' as ui; 
import 'package:flutter/rendering.dart'; 

import 'storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Local worksheet variable to hold changes before saving.
  late Map<String, dynamic> worksheet;
  // Worksheet preview variables
  double _expandedHeight = 100;
  final double _collapsedHeight = 100;
  final double _maxExpandedHeight = 400;
  final double _bufferSpace = 100;
  final double _paperAspectRatio = 8.5 / 11;
  bool _isExpanded = false;

  final StorageService storage = StorageService();

  // To store 
  final List<GlobalKey> _mathKeys = [];


  @override
  void initState() {
    super.initState();
    _mathKeys.clear();
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

  // Method that branches to behavior from toolbar actions
  void _onSelected(String value) async {
    // Handle dropdown menu selection
    if (value == 'print') {
      exportWorksheetWithMath();
    }

    if (value == 'layout') {

    }
  }

  Future<void> saveWorksheet() async {
    // Update the worksheet in the overall list
    widget.allWorksheets[widget.worksheetIndex] = worksheet;
    worksheet['lastModified'] = Timestamp.now();
    await storage.saveWorksheets(widget.allWorksheets);
    widget.onSave?.call(); // to refresh HomeScreen if needed
  } 

  @override
  Widget build(BuildContext context) {
    // double appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    // double remainingHeight = MediaQuery.of(context).size.height - appBarHeight - _expandedHeight;

    return PopScope(
    canPop: false, // this is like "default behavior"
    onPopInvokedWithResult: (didPop, result)  async {
      if (didPop) return; // user already popped (e.g., from gesture), skip
      
      
      // Check for unsaved changes
      final lastSaved = worksheet['lastSaved'];
      final lastModified = worksheet['lastModified'];
      final hasUnsavedChanges = lastSaved == null || lastSaved != lastModified;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (!hasUnsavedChanges) {
        Navigator.pop(context);
        return;
      }

      // If logged in.
      if (uid != null) {
        final shouldSave = await _confirmSaveToCloudDialog();

        if (shouldSave) {

            await storage.cloudSave(worksheet, uid);
            await saveWorksheet();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to cloud ✅')),
            );
        }
      }

      Navigator.pop(context);
    },
      child: Scaffold(
        
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
            // Expandable Section
            GestureDetector(
              onTap: _toggleExpansion,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _expandedHeight,
                width: double.infinity,
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
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Question ${index + 1}:'),
                                  SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      children: parseTextWithMath(
                                        question['questionText'] ?? '',
                                        textStyle: TextStyle(fontSize: 16, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

            // Bottom Section
            Expanded(
              child: Container(
                color: const Color(0xFF424242),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double availableHeight = (constraints.maxHeight - _bufferSpace).clamp(0.0, double.infinity);
                    double rectangleHeight = availableHeight * 0.75;
                    double rectangleWidth = rectangleHeight * _paperAspectRatio;

                    // Ensure the rectangle never exceeds screen width
                    if (rectangleWidth > constraints.maxWidth * 0.9) {
                      rectangleWidth = constraints.maxWidth * 0.9;
                      rectangleHeight = rectangleWidth / _paperAspectRatio;
                    }

                    // Calculate scaling factor based on A4 height
                    const double baseHeight = 842.0; // PDF page height in points
                    const double baseFontSize = 14.0;
                    final double fontScale = rectangleHeight / baseHeight;
                    final double scaledFontSize = baseFontSize * fontScale;

                    const double baseLineHeight = 1.0;
                    final double scaledLineHeight = baseLineHeight * fontScale;

                    return Center(
                      child: SizedBox(
                        width: rectangleWidth,
                        height: rectangleHeight,
                        child: Container(
                          color: Colors.white,
                          padding: EdgeInsets.all(20 * fontScale),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  worksheet['worksheetTitle'] ?? 'Untitled Worksheet',
                                  style: TextStyle(
                                    fontSize: scaledFontSize * 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16 * fontScale),
                                for (final entry in worksheet['questions'].asMap().entries) ...[

                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Question ${entry.key + 1}:',
                                        style: TextStyle(
                                          fontSize: scaledFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: parseTextWithMath(
                                            entry.value['questionText'] ?? '',
                                            textStyle: TextStyle(
                                              fontSize: scaledFontSize,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),


                                  // Filler lines
                                  for (int i = 0; i < (entry.value['fillerLines'] ?? 0); i++)
                                    SizedBox(height: 8 * fontScale),

                                  // Answer lines (if enabled)
                                  for (int i = 0; i < (entry.value['answerSpaces'] ?? 0); i++)
                                    Container(
                                      margin:  EdgeInsets.symmetric(vertical: 4 * fontScale),
                                      height: scaledLineHeight,
                                      color: (entry.value['hasAnswerLines']) ? Colors.black : Colors.white,
                                    ),
                                  // Space between questions
                                  SizedBox(height: 20 * fontScale), 
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              ),
            ),

            // Renders math widgets off screen to prepare for PDF capture
            Transform.translate(
              offset: Offset(0, 5000),
              child: Column(
                children: List.generate(worksheet['questions'].length, (index) {
                  if (_mathKeys.length <= index) {
                    _mathKeys.add(GlobalKey());
                  }

                  return CompositeMathRenderer(
                    text: worksheet['questions'][index]['questionText'] ?? '',
                    repaintKey: _mathKeys[index],
                  );
                }),
              ),
            ),

          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddDialog(),
          child: const Icon(Icons.add),
        ),
      )
    );
  }

  void _openEditDialog(int index) {
    final question = worksheet['questions'][index];

    final TextEditingController questionController =
        TextEditingController(text: question['questionText']);
    int fillerLines = question['fillerLines'];
    final TextEditingController fillerLinesController =
      TextEditingController(text: fillerLines.toString());
    bool hasAnswerLines = question['hasAnswerLines'];
    int answerSpaces = question['answerSpaces'];
    final TextEditingController answerSpacesController =
      TextEditingController(text: answerSpaces.toString());

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
              controller: fillerLinesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Filler Lines'),
              onChanged: (val) {
                fillerLines = int.tryParse(val) ?? fillerLines;
              },
            ),
            TextField(
              controller: answerSpacesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Answer Spaces'),
              onChanged: (val) {
                answerSpaces = int.tryParse(val) ?? answerSpaces;
              },
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
    final TextEditingController fillerLinesController =
      TextEditingController(text: fillerLines.toString());
    bool answerLines = true;
    
    int answerSpaces = 1;
    final TextEditingController answerSpacesController =
      TextEditingController(text: answerSpaces.toString());

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
                  controller: fillerLinesController,
                  decoration: const InputDecoration(labelText: 'Filler Lines'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: answerSpacesController,
                  decoration: const InputDecoration(labelText: 'Answer Spaces'),
                  keyboardType: TextInputType.number,
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

  // Needed to separate math equations from question text.
  static List<InlineSpan> parseTextWithMath(String input, {TextStyle? textStyle, TextStyle? mathStyle}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\$.*?\$)'); // Matches anything between single $...$

    final matches = regex.allMatches(input);
    int lastEnd = 0;

    for (final match in matches) {
      // Add plain text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: input.substring(lastEnd, match.start),
          style: textStyle,
        ));
      }

      // Extract math content without the $ delimiters
      final mathContent = match.group(0)!.substring(1, match.group(0)!.length - 1);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          mathContent,
          textStyle: mathStyle ?? textStyle,
        ),
      ));

      lastEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastEnd < input.length) {
      spans.add(TextSpan(
        text: input.substring(lastEnd),
        style: textStyle,
      ));
    }

    return spans;
  }

  void exportWorksheetWithMath() {
  if (worksheet['questions'].isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final pdf = pw.Document();
    final questions = List<Map<String, dynamic>>.from(worksheet['questions']);

    final List<(Uint8List, ui.Image)?> renderedImages = [];

    for (int i = 0; i < questions.length; i++) {
      final questionText = questions[i]['questionText'] ?? '';

      Uint8List? bytes;
      ui.Image? image;
      int retry = 0;

      while ((bytes == null || image == null) && retry < 10) {
        try {
          final result = await captureMathAsImage(_mathKeys[i]);
          bytes = result.$1;
          image = result.$2;
        } catch (_) {
          await Future.delayed(Duration(milliseconds: 50));
          retry++;
        }
      }

      if (bytes != null && image != null) {
        renderedImages.add((bytes, image));
      } else {
        renderedImages.add(null);
      }
    }

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                worksheet['worksheetTitle'] ?? 'Untitled Worksheet',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              for (int i = 0; i < questions.length; i++) ...[
                pw.Text(
                  'Question ${i + 1}:',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),

                if (renderedImages[i] != null) ...[
                  // Dynamically scale based on image dimensions
                  () {
                    final (bytes, img) = renderedImages[i]!;
                    final imgWidth = img.width.toDouble();
                    final imgHeight = img.height.toDouble();
                    final scaleFactor = 0.75;

                    const maxPdfWidth = 400.0;
                    final scale = imgWidth > maxPdfWidth
                        ? (maxPdfWidth / imgWidth) * scaleFactor
                        : 1.0 * scaleFactor;

                    final finalWidth = imgWidth * scale;
                    final finalHeight = imgHeight * scale;

                    return pw.Image(
                      pw.MemoryImage(bytes),
                      width: finalWidth,
                      height: finalHeight,
                    );
                  }(),
                ] else ...[
                  pw.Text(
                    questions[i]['questionText'] ?? '',
                    style: pw.TextStyle(fontSize: 14),
                  ),
                ],

                pw.SizedBox(height: 8),

                for (int j = 0; j < (questions[i]['fillerLines'] ?? 0); j++)
                  pw.SizedBox(height: 12),

                if (questions[i]['hasAnswerLines'] == true)
                  for (int j = 0; j < (questions[i]['answerSpaces'] ?? 0); j++)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      height: 1.5,
                      color: PdfColors.black,
                    ),

                pw.SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  });
}

  // Captures the rendered math widgets into img form.
  Future<(Uint8List, ui.Image)> captureMathAsImage(GlobalKey key) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception("Render object not found for math image capture.");

    await Future.delayed(Duration(milliseconds: 20));
    await WidgetsBinding.instance.endOfFrame;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return (bytes, image);
  }

  Future<bool> _confirmSaveToCloudDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save to Cloud?'),
        content: Text('Would you like to save this worksheet to the cloud before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Yes')),
        ],
      ),
    ) ?? false;
  }


}

// Renders math widgets off screen for pdf capture
class CompositeMathRenderer extends StatelessWidget {
  final String text;
  final GlobalKey repaintKey;

  const CompositeMathRenderer({
    Key? key,
    required this.text,
    required this.repaintKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final spans = _SecondScreenState.parseTextWithMath(
      text,
      textStyle: const TextStyle(fontSize: 18, color: Colors.black),
    );

    return RepaintBoundary(
      key: repaintKey,
      child: SizedBox(
        width: 300, // 💡 Force layout width (adjust as needed)
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: spans.map((span) {
            if (span is TextSpan) {
              return Text(span.text ?? '', style: span.style);
            } else if (span is WidgetSpan) {
              return span.child;
            } else {
              return const SizedBox.shrink();
            }
          }).toList(),
        ),
      ),
    );
  }
}





