import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _fileName = null;
      _fileContent = null;
      _imageBytes = null;
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                _buildPreview(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_imageBytes != null) {
      return Column(
        children: [
          const Text("Image Preview:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Image.memory(
            _imageBytes!,
            height: 400,
            fit: BoxFit.contain,
          ),
        ],
      );
    }

    if (_fileContent != null) {
      return Column(
        children: [
          const Text("File Content Preview:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            height: 400,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: SingleChildScrollView(
              child: Text(_fileContent!),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink(); // No preview available
  }
}