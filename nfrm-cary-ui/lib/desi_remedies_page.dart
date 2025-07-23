import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:ai_agents_ui/providers/user_provider.dart';

class DesiRemediesPage extends StatefulWidget {
  const DesiRemediesPage({super.key});

  @override
  State<DesiRemediesPage> createState() => _DesiRemediesPageState();
}

class _DesiRemediesPageState extends State<DesiRemediesPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _healthIssueController = TextEditingController();
  // final TextEditingController _languageController = TextEditingController(); // Replaced with _selectedLanguage
  String? _selectedLanguage; // To store the selected language
  String _remedyResponse = '';
  bool _isLoading = false;
  String? _error;
  bool _isSpeaking = false;

  // Limiting response language options to English and Hindi
  final List<String> _supportedLanguages = ['English', 'Hindi'];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _error = "TTS Error: $msg";
          _isSpeaking = false;
        });
      }
    });
  }

  Future<void> _getRemedy() async {
    if (_healthIssueController.text.isEmpty || _selectedLanguage == null || _selectedLanguage!.isEmpty) {
      setState(() {
        _error = 'Please fill in both fields.';
        _remedyResponse = '';
        _flutterTts.stop(); // Stop any ongoing speech
      });
      return;
    }

    // Stop any ongoing speech before new request
    await _flutterTts.stop(); 

    setState(() {
      _isLoading = true;
      _remedyResponse = '';
      _error = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userName = userProvider.user?.displayName ?? userProvider.user?.email ?? 'Guest';
    final userEmail = userProvider.user?.email ?? 'guest@example.com';

    try {
      final response = await http.post(
        Uri.parse('https://ai-agents-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/health_remedies'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'health_issue': _healthIssueController.text,
          'response_language': _selectedLanguage,
          'user_name': userName,
          'user_email': userEmail,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Assuming the response has a key like 'remedy' or similar
        // Adjust this based on the actual API response structure
        setState(() {
          _remedyResponse = responseData['response'] ?? 'No remedy found or unexpected response format.';
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to connect to the service: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _speakRemedy(String text, String language) async {
    if (text.isEmpty) return;
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      // Map common language names to BCP 47 codes if necessary,
      // though flutter_tts often handles common names.
      // Example: "Hindi" -> "hi-IN"
      // For simplicity, we'll try the direct language string first.
      // You might need a more robust mapping for production.
      List<dynamic> languages = await _flutterTts.getLanguages;
      print("Available TTS languages: $languages"); // For debugging

      // A simple attempt to map, enhance as needed
      String langCode = mapLanguageToCode(language); // Use the helper function

      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1EA), // Added background color
      appBar: AppBar(
        // title: const Text('Home Remedies'), // Removed title
        backgroundColor: const Color(0xFFFFF1EA), // Match background color
        elevation: 0, // Optional: remove shadow for a flatter look
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Image.asset(
              'assets/images/home-remedy-img.png',
              height: 140, // Reduced height by 30% (200 * 0.7 = 140)
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10), // Spacing similar to Advisor tab
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0), // Optional: add some horizontal padding
              child: Text(
                'Home Remedies\nThat Actually Work...',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20, // Matches Advisor tab style
                  height: 1.0, // Matches Advisor tab style
                  letterSpacing: 0.0, // Matches Advisor tab style
                  color: Colors.brown[800], // Matches Advisor tab style
                ),
              ),
            ),
            const SizedBox(height: 20), // Adjusted spacing before the first text field
            // const SizedBox(height: 16), // Slightly reduced spacing // This line is replaced by the one above
            TextField(
              controller: _healthIssueController,
              decoration: const InputDecoration(
                labelText: 'Describe your health issue',
                border: OutlineInputBorder(),
                filled: true, // Added
                fillColor: Colors.white, // Added
                contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0), // Adjusted padding
              ),
              maxLines: 2, // Reduced maxLines
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Preferred language for response (e.g., Hindi)',
                border: const OutlineInputBorder(),
                filled: true, // Added
                fillColor: Colors.white, // Added
                // Adjusted padding to make it visually smaller
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              ),
              value: _selectedLanguage,
              hint: const Text('Select Language'),
              isExpanded: true,
              items: _supportedLanguages.map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(language),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                  _error = null; // Clear error when language changes
                  _remedyResponse = ''; // Clear previous response
                });
              },
            ),
            const SizedBox(height: 24),
            Align( // Align the button to the left
              alignment: Alignment.centerLeft,
              child: SizedBox( // Wrap ElevatedButton with SizedBox for width control
                width: MediaQuery.of(context).size.width * 0.5, // Set width to 50% of screen width
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _getRemedy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE733A), // Set background color
                    foregroundColor: Colors.white, // Set text color to white
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Get Remedy'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
            if (_remedyResponse.isNotEmpty && !_isLoading)
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(_remedyResponse, style: const TextStyle(fontSize: 16)),
                    ),
                    IconButton(
                      icon: Icon(_isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                      onPressed: () => _speakRemedy(_remedyResponse, _selectedLanguage ?? 'English'),
                      tooltip: _isSpeaking ? 'Stop' : 'Read aloud',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper for language mapping (optional, can be expanded)
String mapLanguageToCode(String languageName) {
  final lowerLang = languageName.toLowerCase();
  if (lowerLang == "hindi") return "hi-IN";
  if (lowerLang == "english") return "en-US";
  if (lowerLang == "bengali") return "bn-IN";
  if (lowerLang == "marathi") return "mr-IN";
  if (lowerLang == "telugu") return "te-IN";
  if (lowerLang == "tamil") return "ta-IN";
  if (lowerLang == "gujarati") return "gu-IN";
  if (lowerLang == "urdu") return "ur-IN"; // or ur-PK, depending on TTS support
  if (lowerLang == "kannada") return "kn-IN";
  if (lowerLang == "odia") return "or-IN";
  if (lowerLang == "malayalam") return "ml-IN";
  return "en-US"; // Default to English if no specific code is found
}