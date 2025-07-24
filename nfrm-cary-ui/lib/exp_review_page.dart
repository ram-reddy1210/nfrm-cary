import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_agents_ui/providers/user_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class ChatMessage {
  final String text;
  final bool isUserMessage;
  ChatMessage({required this.text, required this.isUserMessage});
}

class ExpReviewPage extends StatefulWidget {
  const ExpReviewPage({super.key});

  @override
  State<ExpReviewPage> createState() => _ExpReviewPageState();
}

class _ExpReviewPageState extends State<ExpReviewPage> {
  String? _fileName;
  String? _fileContent;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isAnalysing = false;
  String? _analysisError;

  // Chat state
  bool _analysisComplete = false;
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _followUpController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  void _resetAnalysisState() {
    setState(() {
      _analysisComplete = false;
      _chatMessages.clear();
      _analysisError = null;
      _followUpController.clear();
    });
  }

  Future<void> _analyseWithAI() async {
    if (_fileContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file content to analyze.')),
      );
      return;
    }

    setState(() {
      _isAnalysing = true;
      _analysisError = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = userProvider.user?.displayName ?? 'string';
      final userEmail = userProvider.user?.email ?? 'string';

      final url =
          Uri.parse('https://nfrm-cary-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/review_document_chat');
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "document_content": _fileContent,
          "prompt":
              "Review the attached document, provide a summary, and suggest ideas on how I can save more.",
          "user_name": userName,
          "user_email": userEmail,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final aiResponseText = responseBody['response'];

        if (aiResponseText != null) {
          setState(() {
            _chatMessages
                .add(ChatMessage(text: aiResponseText, isUserMessage: false));
            _analysisComplete = true;
          });
        } else {
          throw Exception('Failed to parse AI response.');
        }
      } else {
        throw Exception(
            'Failed to get analysis. Status code: ${response.statusCode}\nBody: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _analysisError = e.toString();
      });
    } finally {
      setState(() {
        _isAnalysing = false;
      });
    }
  }

  Future<void> _sendFollowUp(String prompt) async {
    if (prompt.isEmpty || _fileContent == null) return;

    setState(() {
      _chatMessages.add(ChatMessage(text: prompt, isUserMessage: true));
      _isAnalysing = true;
      _analysisError = null;
      _followUpController.clear();
    });
    _scrollToBottom();

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = userProvider.user?.displayName ?? 'string';
      final userEmail = userProvider.user?.email ?? 'string';

      final url = Uri.parse(
          'https://nfrm-cary-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/review_document_chat');
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "document_content": _fileContent,
          "prompt": prompt,
          "user_name": userName,
          "user_email": userEmail,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final aiResponseText = responseBody['response'];

        if (aiResponseText != null) {
          setState(() {
            _chatMessages
                .add(ChatMessage(text: aiResponseText, isUserMessage: false));
          });
        } else {
          throw Exception('Failed to parse AI response.');
        }
      } else {
        throw Exception(
            'Failed to get analysis. Status code: ${response.statusCode}\nBody: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _analysisError = e.toString();
      });
    } finally {
      setState(() {
        _isAnalysing = false;
      });
      _scrollToBottom();
    }
  }

  void _restartSession() {
    setState(() {
      _fileName = null;
      _fileContent = null;
      _imageBytes = null;
      _analysisComplete = false;
      _chatMessages.clear();
      _analysisError = null;
      _followUpController.clear();
    });
  }

  Future<void> _downloadPdf() async {
    final PdfDocument document = PdfDocument();
    PdfPage page = document.pages.add();
    final Size pageSize = page.getClientSize();
    PdfLayoutResult? result;

    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);

    for (final message in _chatMessages) {
      final text = '${message.isUserMessage ? 'You' : 'AI'}: ${message.text}\n\n';
      final textElement = PdfTextElement(
        text: text,
        font: font,
      );

      result = textElement.draw(
        page: result?.page ?? page,
        bounds: Rect.fromLTWH(
            0, result?.bounds.bottom ?? 0, pageSize.width, pageSize.height),
      );
    }

    final List<int> bytes = await document.save();
    document.dispose();

    await _saveAndLaunchFile(bytes, 'ChatHistory.pdf');
  }

  Future<void> _saveAndLaunchFile(List<int> bytes, String fileName) async {
    // For mobile platforms, save the file and open it.
    // Web implementation would differ.
    if (!kIsWeb) {
      final path = (await getApplicationDocumentsDirectory()).path;
      final file = File('$path/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      OpenFile.open('$path/$fileName');
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _fileName = null;
      _fileContent = null;
      _imageBytes = null;
      _resetAnalysisState();
    });

    try {
      // `withData: true` is crucial to get file bytes on all platforms
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'txt'],
        withData: true,
      );

      if (result != null) {
        PlatformFile file = result.files.first;

        setState(() {
          _fileName = file.name;
        });

        if (file.bytes == null) {
          throw Exception("File bytes are null, cannot read content.");
        }

        final fileExtension = file.extension?.toLowerCase();
        String content = '';
        Uint8List? image;

        switch (fileExtension) {
          case 'pdf':
            try {
              final pdfDoc = PdfDocument(inputBytes: file.bytes!);
              content = PdfTextExtractor(pdfDoc).extractText();
              pdfDoc.dispose();
            } catch (e) {
              content = "Error reading PDF file: $e";
            }
            break;
          case 'txt':
            content = utf8.decode(file.bytes!);
            break;
          case 'png':
          case 'jpg':
          case 'jpeg':
            image = file.bytes;
            break;
          case 'doc':
          case 'docx':
            content =
                "Preview for .doc and .docx files is not yet supported. Please use PDF or TXT.";
            break;
          default:
            content = "Unsupported file type for preview: .$fileExtension";
        }

        if (mounted) {
          setState(() {
            _fileContent = content.isNotEmpty ? content : null;
            _imageBytes = image;
          });
        }
      } else {
        // User canceled the picker
      }
    } catch (e) {
      // Handle exceptions
      print('Error picking or reading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking or reading file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _analysisComplete ? _buildChatView() : _buildUploadView(),
    );
  }

  Widget _buildUploadView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Upload Your Expense Report for Review',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Select File to Upload'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading) const CircularProgressIndicator(),
          if (_fileName != null) ...[
            Text('Selected file: $_fileName'),
            const SizedBox(height: 20),
            if (_isAnalysing)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _analyseWithAI,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Analyse with AI'),
              ),
          ],
          if (_analysisError != null) ...[
            const SizedBox(height: 20),
            Text(
              'Error: $_analysisError',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Review Session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restart') {
                  _restartSession();
                } else if (value == 'download') {
                  _downloadPdf();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                    value: 'restart', child: Text('Restart Session')),
                const PopupMenuItem<String>(
                    value: 'download', child: Text('Download PDF')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              return _buildChatMessage(_chatMessages[index]);
            },
          ),
        ),
        if (_isAnalysing)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        if (_analysisError != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: $_analysisError',
                style: const TextStyle(color: Colors.red)),
          ),
        const Divider(height: 1.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _followUpController,
                  decoration: const InputDecoration.collapsed(
                      hintText: 'Ask a follow-up question...'),
                  onSubmitted: _sendFollowUp,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendFollowUp(_followUpController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Align(
      alignment:
          message.isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: message.isUserMessage
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}