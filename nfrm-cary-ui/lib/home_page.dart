import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart'; // Added for unique message IDs
// Imports for PDF generation
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
// For platform checking and web-specific downloads
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'dart:typed_data'; // For Uint8List
// Conditional import for web download utility
import 'package:ai_agents_ui/src/web_download_utils_stub.dart'
    if (dart.library.html) 'package:ai_agents_ui/src/web_download_utils.dart' as web_downloader;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// Imports for user and auth services
import 'package:provider/provider.dart';
import 'package:ai_agents_ui/providers/user_provider.dart';
import 'package:ai_agents_ui/services/auth_service.dart';
import 'package:ai_agents_ui/utils/date_input_formatter.dart'; // Import the custom formatter
import 'package:ai_agents_ui/exp_review_page.dart';
import 'package:ai_agents_ui/budget_page.dart';

var uuid = Uuid();

class ChatMessage {
  final String id;
  final String text;
  final bool isUserMessage;

  ChatMessage({required this.text, required this.isUserMessage}) : id = uuid.v4();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final FlutterTts _flutterTts = FlutterTts();
  List<ChatMessage> _chatMessages = []; // For Advisor chat
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _textController = TextEditingController();
  int _selectedIndex = 0; // For BottomNavigationBar, will be updated for new tab

  // State for Horoscope Page
  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _tobController = TextEditingController();
  final TextEditingController _pobController = TextEditingController();
  // final TextEditingController _todaysFortuneController = TextEditingController(); // Replaced by a boolean for checkbox
  // String _horoscopeApiResponse = ''; // Replaced by chat messages
  bool _horoscopeIsLoading = false;
  String _horoscopeErrorMessage = '';
  bool _horoscopeDetailsSubmitted = false;
  String _horoscopeSubmittedPersonName = '';
  String _horoscopeSubmittedDob = '';
  String _horoscopeSubmittedTob = '';
  String _horoscopeSubmittedPob = '';
  bool _horoscopeIncludeTodaysFortune = false; // State for "Today's Fortune" checkbox
  List<ChatMessage> _horoscopeChatMessages = [];
  final TextEditingController _horoscopeChatInputController = TextEditingController();
  final ScrollController _horoscopeChatScrollController = ScrollController();

  // State for Numerology Page
  final TextEditingController _numerologyPersonNameController = TextEditingController();
  final TextEditingController _numerologyDobController = TextEditingController();
  bool _numerologyIsLoading = false;
  String _numerologyErrorMessage = '';
  bool _numerologyDetailsSubmitted = false;
  String _numerologySubmittedPersonName = '';
  String _numerologySubmittedDob = '';
  List<ChatMessage> _numerologyChatMessages = [];
  final TextEditingController _numerologyChatInputController = TextEditingController();
  final ScrollController _numerologyChatScrollController = ScrollController();
  final List<String> _numerologySystemChoices = [
    'Angel Investors',
    'Venture Capitalists',
    'Corporate Venture Capital',
    'Incubators',
    'Accelerators',
    'Private Equity Firms'
  ];
  late String _selectedNumerologySystem; // For the dropdown in the form
  String _numerologySubmittedSystem = ''; // For the active session
  // final List<String> _selectableApiLanguages = ['English', 'Hindi']; // Removed duplicate
  late String _selectedNumerologyApiLanguage; // Will be initialized in initState
  String _currentNumerologySessionTtsCode = 'en-US'; // Default TTS code

  bool _isGeneratingNumerologyPdf = false; // State for PDF generation
  bool _isGeneratingMantraPdf = false; // State for Mantra PDF generation
  bool _isGeneratingAdvisorPdf = false; // State for Advisor PDF generation
  bool _isSendingAdvisorEmail = false; // State for sending advisor chat email
  bool _isGeneratingHoroscopePdf = false; // State for Horoscope PDF generation
  final Map<String, String> _apiLanguageToTtsCode = {
    'English': 'en-US',
    'Hindi': 'hi-IN',
    'Spanish': 'es-ES',
  };
  // Limiting response language options to English and Hindi for Numerology and Mantra tabs
  final List<String> _selectableApiLanguages = ['English', 'Hindi']; // Sanskrit removed
  // State for Advisor Language
  final List<String> _advisorSelectableLanguages = ['English', 'Hindi', 'Spanish'];
  late String _selectedAdvisorLanguage;
  String _advisorSubmittedLanguage = 'English'; // Default for session
  String _currentAdvisorSessionTtsCode = 'en-US'; // Default TTS code for Advisor

  // TTS State
  bool _isSpeaking = false;
  String _currentlySpeakingTextId = ''; 
  bool _hasInitializedHoroscopeName = false; // To track if horoscope name has been pre-filled
  bool _hasInitializedNumerologyName = false; // To track if numerology name has been pre-filled
  bool _hasAttemptedNumerologyPreFillFromHoroscope = false; // To track if Numerology fields were pre-filled from Horoscope data
  bool _isAdvisorImageSmall = false; // To control advisor image size

  // State for Mantra Page
  final TextEditingController _mantraQueryController = TextEditingController();
  List<ChatMessage> _mantraChatMessages = [];
  bool _mantraIsLoading = false;
  String _mantraErrorMessage = '';
  bool _mantraDetailsSubmitted = false;
  String _mantraSubmittedQuery = '';
  late String _selectedMantraResponseLanguage; // For the dropdown in the form
  String _mantraSubmittedResponseLanguage = ''; // For the active session
  final TextEditingController _mantraChatInputController = TextEditingController();
  final ScrollController _mantraChatScrollController = ScrollController();
  String _currentMantraSessionTtsCode = 'en-US'; // Default TTS code for Mantra
  String? _mantraYoutubeVideoId;
  YoutubePlayerController? _mantraYoutubeController;
  
  final ScrollController _chatScrollController = ScrollController();
  // final ScrollController _horoscopeChatScrollController = ScrollController(); // Added above

  @override
  void initState() {
    super.initState();
    _selectedAdvisorLanguage = _advisorSelectableLanguages[0]; // Default to English for Advisor
    _initTts();
    _selectedNumerologyApiLanguage = _selectableApiLanguages[0]; // Default to English
    _horoscopeIncludeTodaysFortune = false; // Initialize checkbox state
    _selectedNumerologySystem = _numerologySystemChoices[0]; // Default to Pythagorean
    _hasAttemptedNumerologyPreFillFromHoroscope = false;
    _selectedMantraResponseLanguage = _selectableApiLanguages[0]; // Default to English for Mantra

  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlySpeakingTextId = '';
        });
      }
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _errorMessage = "TTS Error: $msg";
          _isSpeaking = false;
          _currentlySpeakingTextId = '';
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill Horoscope Name
    if (!_hasInitializedHoroscopeName && (_selectedIndex == 1 || !_hasInitializedHoroscopeName)) { 
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = (userProvider.user?.displayName?.isNotEmpty ?? false)
          ? userProvider.user!.displayName
          : userProvider.user?.email;

      if (userName != null && userName.isNotEmpty && _personNameController.text.isEmpty) {
        // TextField listens to its controller, so direct update is fine.
        _personNameController.text = userName; 
        _hasInitializedHoroscopeName = true; 
      }
    }

    // Pre-fill Numerology Name
    if (!_hasInitializedNumerologyName && (_selectedIndex == 2 || !_hasInitializedNumerologyName)) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = (userProvider.user?.displayName?.isNotEmpty ?? false)
          ? userProvider.user!.displayName
          : userProvider.user?.email;
      
      if (userName != null && userName.isNotEmpty && _numerologyPersonNameController.text.isEmpty) {
        _numerologyPersonNameController.text = userName;
        _hasInitializedNumerologyName = true;
      }
    }

    // Pre-fill Numerology fields from Horoscope data (if not already attempted for current horoscope data state and fields are empty)
    // This runs once after initState and on dependency changes.
    if (!_hasAttemptedNumerologyPreFillFromHoroscope && _horoscopeDetailsSubmitted) {
        bool nameFilledFromHoroscopeInDCD = false;
        if (_numerologyPersonNameController.text.isEmpty && _horoscopeSubmittedPersonName.isNotEmpty) {
            _numerologyPersonNameController.text = _horoscopeSubmittedPersonName;
            nameFilledFromHoroscopeInDCD = true;
        }
        if (_numerologyDobController.text.isEmpty && _horoscopeSubmittedDob.isNotEmpty) {
            _numerologyDobController.text = _horoscopeSubmittedDob;
        }
        // Mark as attempted for this horoscope data state.
        _hasAttemptedNumerologyPreFillFromHoroscope = true; 
        if (nameFilledFromHoroscopeInDCD) {
            _hasInitializedNumerologyName = true; // Also mark user profile name as "handled" to prevent override
        }
    }
  }
  @override
  void dispose() {
    _textController.dispose();
    _personNameController.dispose();
    _dobController.dispose();
    _tobController.dispose();
    _pobController.dispose();
    // _todaysFortuneController.dispose(); // No longer needed
    _chatScrollController.dispose();
    _horoscopeChatScrollController.dispose();
    _horoscopeChatInputController.dispose();
    _numerologyPersonNameController.dispose();
    _numerologyDobController.dispose();
    _numerologyChatInputController.dispose();
    _numerologyChatScrollController.dispose();
    _mantraQueryController.dispose();
    _mantraChatInputController.dispose();
    _mantraChatScrollController.dispose();
    _mantraYoutubeController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // If switching to the Horoscope tab (index 1) and name hasn't been pre-filled or is empty
    if (index == 1 && mounted && _personNameController.text.isEmpty) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = (userProvider.user?.displayName?.isNotEmpty ?? false)
          ? userProvider.user!.displayName
          : userProvider.user?.email;

      if (userName != null && userName.isNotEmpty) {
        _personNameController.text = userName;
        // If we want to ensure this pre-fill only happens once via _onItemTapped as well
        // _hasInitializedHoroscopeName = true; // Or rely on didChangeDependencies for the one-time flag
      }
    } else if (index == 2 && mounted) { // Switched to Numerology tab
        bool nameFilledFromHoroscope = false;
        // Attempt to pre-fill Numerology fields from Horoscope data first
        if (!_hasAttemptedNumerologyPreFillFromHoroscope && _horoscopeDetailsSubmitted) {
            if (_numerologyPersonNameController.text.isEmpty && _horoscopeSubmittedPersonName.isNotEmpty) {
                _numerologyPersonNameController.text = _horoscopeSubmittedPersonName;
                nameFilledFromHoroscope = true;
            }
            if (_numerologyDobController.text.isEmpty && _horoscopeSubmittedDob.isNotEmpty) {
                _numerologyDobController.text = _horoscopeSubmittedDob;
            }
            // Mark that an attempt to use current horoscope data has been made for this "session" of horoscope data
            _hasAttemptedNumerologyPreFillFromHoroscope = true; 
        }

        // Then, attempt to pre-fill Numerology Name from User Profile if still empty and not done
        if (!_hasInitializedNumerologyName && _numerologyPersonNameController.text.isEmpty) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            final userName = (userProvider.user?.displayName?.isNotEmpty ?? false)
                ? userProvider.user!.displayName
                : userProvider.user?.email;
            if (userName != null && userName.isNotEmpty) {
                _numerologyPersonNameController.text = userName;
                _hasInitializedNumerologyName = true;
            }
        }
        
        // If numerology name was filled from horoscope in this tap action, ensure _hasInitializedNumerologyName is true
        if (nameFilledFromHoroscope) {
            _hasInitializedNumerologyName = true;
        }
    }
    setState(() {
      _selectedIndex = index;
    });

  }

    Future<void> _speakChatMessage(ChatMessage messageToSpeak, String languageCode) async {
      if (messageToSpeak.text.isEmpty) return;

      if (_isSpeaking && _currentlySpeakingTextId == messageToSpeak.id) {
        await _flutterTts.stop();
        // TTS handlers will update _isSpeaking and _currentlySpeakingTextId
      } else {
        await _flutterTts.stop(); // Stop any previous speech
        if (mounted) {
          setState(() {
            _currentlySpeakingTextId = messageToSpeak.id;
            // _isSpeaking will be set to true by the TTS startHandler
          });
        }
        await _flutterTts.setLanguage(languageCode); // e.g., "en-US"
        await _flutterTts.setPitch(1.0);
        await _flutterTts.speak(messageToSpeak.text);
      }
    }

    void _scrollToBottom(ScrollController controller) {
      if (controller.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }

    Future<void> _sendChatMessage(String textInput) async {
      if (textInput.isEmpty) {
        return;
      }
      await _flutterTts.stop(); // Stop any ongoing speech

      final userMessage = ChatMessage(text: textInput, isUserMessage: true);
      setState(() {
        _chatMessages.add(userMessage);
        _isLoading = true;
        _errorMessage = '';
        _textController.clear();
        // On the first message, lock in the language for the session
        if (_chatMessages.length == 1) {
          _advisorSubmittedLanguage = _selectedAdvisorLanguage;
          _currentAdvisorSessionTtsCode = _apiLanguageToTtsCode[_selectedAdvisorLanguage] ?? 'en-US';
        }
        _isAdvisorImageSmall = true; // Shrink image on first message
      });
      _scrollToBottom(_chatScrollController);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final loggedInUserName = userProvider.user?.displayName ?? userProvider.user?.email ?? 'Guest';
      final loggedInUserEmail = userProvider.user?.email ?? 'guest@example.com';

      // Prepare chat history, excluding the latest user message which is the current prompt
      final history = _chatMessages.length > 1
          ? _chatMessages.sublist(0, _chatMessages.length - 1).map((m) {
              return {'role': m.isUserMessage ? 'user' : 'model', 'content': m.text};
            }).toList()
          : [];

      final url = Uri.parse(
          'https://nfrm-cary-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/advise_chat'); // Use the new chat endpoint

      try {
        final response = await http.post(
          url,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'prompt': textInput,
            'user_name': loggedInUserName,
            'user_email': loggedInUserEmail,
            'history': history,
            'language': _advisorSubmittedLanguage, // Pass the submitted language
          }),
        );

        ChatMessage? aiMessage;
        if (response.statusCode == 200) {
          try {
            final decodedResponse = jsonDecode(response.body);
            print('Decoded Chat API Response: $decodedResponse');
            // The API response structure is {"response": "advice text..."}
            final adviceText = decodedResponse['response'];


            if (adviceText != null && adviceText is String) {
              aiMessage = ChatMessage(text: adviceText, isUserMessage: false);
            } else {
              _errorMessage = 'Failed to parse AI response. Structure: ${response.body}';
            }
          } catch (e) {
            print('Error decoding Chat JSON: $e');
            print('Raw Chat response body: ${response.body}');
            _errorMessage = 'Failed to parse AI response JSON: $e\nRaw: ${response.body}';
          }
        } else {
          _errorMessage = 'API Error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}';
        }

        if (mounted) {
          setState(() {
            if (aiMessage != null) {
              _chatMessages.add(aiMessage);
            }
            _isLoading = false;
          });
          _scrollToBottom(_chatScrollController);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to connect to the chat service: $e';
            _isLoading = false;
          });
        }
      }
    }

    void _restartHoroscopeSession() {
      setState(() {
        _horoscopeDetailsSubmitted = false;
        _horoscopeSubmittedPersonName = '';
        _horoscopeSubmittedDob = '';
        _horoscopeSubmittedTob = '';
        _horoscopeSubmittedPob = '';
        _horoscopeIncludeTodaysFortune = false; // Reset checkbox state
        _horoscopeChatMessages.clear();
        _horoscopeErrorMessage = '';
        _horoscopeIsLoading = false;
        _horoscopeChatInputController.clear();
        _personNameController.clear();
        _dobController.clear();
        _tobController.clear();
        _pobController.clear();
        _hasAttemptedNumerologyPreFillFromHoroscope = false; // Allow Numerology to re-evaluate pre-fill from new Horoscope data
        // No controller for checkbox to clear, its state is _horoscopeIncludeTodaysFortune
      });
      _flutterTts.stop();
    }

    Future<void> _initiateHoroscopeChat() async {
      // Reset error message at the beginning of the validation attempt
      setState(() {
        _horoscopeErrorMessage = '';
      });

      final String personName = _personNameController.text.trim();
      final String dobFromField = _dobController.text.trim(); // User's actual DOB
      final String tob = _tobController.text.trim();
      final String pob = _pobController.text.trim();

      // Validate all common fields first
      if (personName.isEmpty) {
        setState(() {
          _horoscopeErrorMessage = 'Please enter the person\'s name.';
        });
        return;
      }
      if (dobFromField.isEmpty) {
        setState(() => _horoscopeErrorMessage = 'Please enter the date of birth.');
        return;
      }
      // Enhanced Date Validation
      DateTime parsedDob;
      try {
        parsedDob = DateFormat('dd/MM/yyyy').parseStrict(dobFromField);
        final DateTime firstValidDate = DateTime(1900);
        final DateTime lastValidDate = DateTime.now();

        if (parsedDob.isBefore(firstValidDate)) {
          setState(() => _horoscopeErrorMessage = 'Date of birth cannot be before the year 1900.');
          return;
        }
        if (parsedDob.isAfter(lastValidDate)) {
          setState(() => _horoscopeErrorMessage = 'Date of birth cannot be in the future.');
          return;
        }
      } catch (e) {
        // Catches format errors (e.g., "30/02/2023", "abc")
        setState(() => _horoscopeErrorMessage = 'Invalid date format or date. Please use DD/MM/YYYY.');
        return;
      }
      if (tob.isEmpty) {
        setState(() => _horoscopeErrorMessage = 'Please enter the time of birth.');
        return;
      }
      if (pob.isEmpty) {
        setState(() => _horoscopeErrorMessage = 'Please enter the place of birth.');
        return;
      }

      // All basic validations passed, now determine the initial message
      String initialUserMessage;
      if (_horoscopeIncludeTodaysFortune) {
        final now = DateTime.now();
        String day = now.day.toString().padLeft(2, '0');
        String month = now.month.toString().padLeft(2, '0');
        String todaysDateFormatted = "$day/$month/${now.year}";
        initialUserMessage = "Based on my birth details (DOB: $dobFromField, TOB: $tob, POB: $pob), what is my fortune for today, $todaysDateFormatted?";
      } else {
        initialUserMessage = "Create my Kundali and describe my life themes based on my details (DOB: $dobFromField, TOB: $tob, POB: $pob).";
      }

      setState(() {
        _horoscopeDetailsSubmitted = true;
        _horoscopeSubmittedPersonName = personName;
        _horoscopeSubmittedDob = dobFromField; // Always use the user's entered DOB
        _horoscopeSubmittedTob = tob;
        _horoscopeSubmittedPob = pob;
        // Clear form fields after submission
        _personNameController.clear();
        _dobController.clear();
        _tobController.clear();
        _pobController.clear();
        // _horoscopeIncludeTodaysFortune remains as set by the user for the next potential submission if not reset explicitly
      });
      // Send an initial message
      _sendHoroscopeApiRequest(initialUserMessage);
    }

  Future<void> _sendHoroscopeApiRequest(String userMessageText) async {
      if (userMessageText.isEmpty && _horoscopeChatMessages.isNotEmpty) return; // Allow empty for initial message
      await _flutterTts.stop();


      final userMessage = ChatMessage(text: userMessageText, isUserMessage: true);
      setState(() {
        if(userMessageText.isNotEmpty) _horoscopeChatMessages.add(userMessage); // Don't add if it's an auto-initial message placeholder
        _horoscopeIsLoading = true;
        _horoscopeErrorMessage = '';
        _horoscopeChatInputController.clear();
      });
      _scrollToBottom(_horoscopeChatScrollController);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.user?.uid ?? 'guest';
      final loggedInUserName = userProvider.user?.displayName ?? userProvider.user?.email ?? 'Guest';
      final loggedInUserEmail = userProvider.user?.email ?? 'guest@example.com';

      String formattedDob = _horoscopeSubmittedDob;
      try {
        // The API expects "Month day year" format, e.g., "February 10 1976"
        final date = DateFormat('dd/MM/yyyy').parseStrict(_horoscopeSubmittedDob);
        formattedDob = DateFormat('MMMM d yyyy').format(date);
      } catch (e) {
        print('Error formatting date for horoscope API, sending as is: $e');
        // Fallback to sending the date as it is.
      }

      final url = Uri.parse('https://ai-agents-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/astrology_chat');

      try {
        final response = await http.post(
          url,
          headers: {'accept': 'application/json', 'Content-Type': 'application/json'},
          body: jsonEncode(<String, String>{
            'user_id': userId,
            'person_name': _horoscopeSubmittedPersonName,
            'date_of_birth': formattedDob,
            'time_of_birth': _horoscopeSubmittedTob,
            'user_name': loggedInUserName,
            'user_email': loggedInUserEmail,
            'place_of_birth': _horoscopeSubmittedPob,
            'user_message': userMessageText,
            'response_language': 'English',
          }),
        );

        ChatMessage? aiMessage;
        if (response.statusCode == 200) {
          try {
            final decodedResponse = jsonDecode(response.body);
            print('Decoded Horoscope API Response: $decodedResponse');
            final responseText = decodedResponse['response'];
            if (responseText != null && responseText is String) {
              aiMessage = ChatMessage(text: responseText, isUserMessage: false);
            } else {
              _horoscopeErrorMessage = 'Failed to parse AI response. Structure: ${response.body}';
            }
          } catch (e) {
            print('Error decoding Horoscope JSON: $e');
            print('Raw Horoscope response body: ${response.body}');
            _horoscopeErrorMessage = 'Failed to parse horoscope response: $e\nRaw: ${response.body}';
          }
        } else {
          _horoscopeErrorMessage = 'API Error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}';
        }
        if (mounted) {
          setState(() {
            if (aiMessage != null) _horoscopeChatMessages.add(aiMessage);
            _horoscopeIsLoading = false;
          });
          _scrollToBottom(_horoscopeChatScrollController);
        }
      } catch (e) {
        if (mounted) setState(() => _horoscopeErrorMessage = 'Failed to connect to the astrology service: $e');
      }
      if (mounted) setState(() => _horoscopeIsLoading = false);
    }

  // --- Numerology Methods ---
  void _restartNumerologySession() {
    setState(() {
      _numerologyDetailsSubmitted = false;
      _numerologySubmittedPersonName = '';
      _numerologySubmittedDob = '';
      _numerologyChatMessages.clear();
      _numerologyErrorMessage = '';
      _numerologyIsLoading = false;
      _numerologyChatInputController.clear();
      _numerologyPersonNameController.clear();
      _numerologyDobController.clear();
      _selectedNumerologySystem = _numerologySystemChoices[0]; // Reset system choice
      _numerologySubmittedSystem = '';
      _selectedNumerologyApiLanguage = _selectableApiLanguages[0]; // Reset language
      _hasInitializedNumerologyName = false; // Allow user profile name pre-fill again
      _hasAttemptedNumerologyPreFillFromHoroscope = false; // Allow pre-fill from horoscope data again
    });
    _flutterTts.stop();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime firstDatePickerLimit = DateTime(1900);
    final DateTime lastDatePickerLimit = DateTime.now();
    
    DateTime dateForPickerOpen; // This will be the initialDate for showDatePicker

    if (controller.text.isNotEmpty) {
      try {
        // Use parseStrict to ensure the format is exactly as expected.
        DateTime parsedDate = DateFormat('dd/MM/yyyy').parseStrict(controller.text);
        
        // Clamp the parsedDate to be within the allowed range for initialDate
        if (parsedDate.isBefore(firstDatePickerLimit)) {
          dateForPickerOpen = firstDatePickerLimit;
        } else if (parsedDate.isAfter(lastDatePickerLimit)) {
          dateForPickerOpen = lastDatePickerLimit;
        } else {
          dateForPickerOpen = parsedDate;
        }
      } catch (e) {
        // If parsing fails (e.g., invalid format or invalid date like 30/02/2023),
        // default to a safe value, like today.
        dateForPickerOpen = lastDatePickerLimit; 
      }
    } else {
      // If the field is empty, default to today.
      dateForPickerOpen = lastDatePickerLimit;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateForPickerOpen, // This is now guaranteed to be within bounds
      firstDate: firstDatePickerLimit,
      lastDate: lastDatePickerLimit,
    );

    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }
  Future<void> _initiateNumerologyChat() async {
    // Reset error message at the beginning of the validation attempt
    setState(() {
      _numerologyErrorMessage = '';
    });

    final String personName = _numerologyPersonNameController.text.trim();
    final String dob = _numerologyDobController.text.trim();

    if (personName.isEmpty) {
        setState(() {
          _numerologyErrorMessage = 'Please enter the person\'s name.';
        });
        return;
      }
    if (dob.isEmpty) {
      setState(() => _numerologyErrorMessage = 'Please enter the date of birth.');
      return;
    }
    // Enhanced Date Validation for Numerology
    DateTime parsedNumerologyDob;
    try {
      parsedNumerologyDob = DateFormat('dd/MM/yyyy').parseStrict(dob);
      final DateTime firstValidDate = DateTime(1900);
      final DateTime lastValidDate = DateTime.now();

      if (parsedNumerologyDob.isBefore(firstValidDate)) {
        setState(() => _numerologyErrorMessage = 'Date of birth cannot be before the year 1900.');
        return;
      }
      if (parsedNumerologyDob.isAfter(lastValidDate)) {
        setState(() => _numerologyErrorMessage = 'Date of birth cannot be in the future.');
        return;
      }
    } catch (e) {
      setState(() => _numerologyErrorMessage = 'Invalid date format or date. Please use DD/MM/YYYY.');
      return;
    }
    setState(() {
      _numerologyDetailsSubmitted = true;
      _numerologySubmittedPersonName = personName;
      _numerologySubmittedDob = dob;
      _numerologyErrorMessage = '';
      _numerologySubmittedSystem = _selectedNumerologySystem; // Store selected system for the session
      _currentNumerologySessionTtsCode = _apiLanguageToTtsCode[_selectedNumerologyApiLanguage] ?? 'en-US';
      // Clear form fields after submission
      // _numerologyPersonNameController.clear(); // Keep for display or clear if preferred
      // _numerologyDobController.clear();
    });
    _sendNumerologyApiRequest("Tell me about my numerology based on my details.");
  }

  Future<void> _sendNumerologyApiRequest(String userMessageText) async {
    if (userMessageText.isEmpty && _numerologyChatMessages.isNotEmpty) return;
    await _flutterTts.stop();

    final userMessage = ChatMessage(text: userMessageText, isUserMessage: true);
    setState(() {
      if(userMessageText.isNotEmpty) _numerologyChatMessages.add(userMessage);
      _numerologyIsLoading = true;
      _numerologyErrorMessage = '';
      _numerologyChatInputController.clear();
    });
    _scrollToBottom(_numerologyChatScrollController);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.uid ?? 'guest';
    final loggedInUserName = userProvider.user?.displayName ?? userProvider.user?.email ?? 'Guest';
    final loggedInUserEmail = userProvider.user?.email ?? 'guest@example.com';

    String formattedDob = _numerologySubmittedDob;
    try {
      // The API expects "Month day year" format, e.g., "February 10 1976"
      final date = DateFormat('dd/MM/yyyy').parseStrict(_numerologySubmittedDob);
      formattedDob = DateFormat('MMMM d yyyy').format(date);
    } catch (e) {
      print('Error formatting date for numerology API, sending as is: $e');
      // Fallback to sending the date as it is.
    }

    final url = Uri.parse('https://ai-agents-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/numerology_chat'); // Updated URL
    try {
      final response = await http.post(url,
        headers: {'accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'user_id': userId,
          'person_name': _numerologySubmittedPersonName,
          'user_name': loggedInUserName,
          'user_email': loggedInUserEmail,
          'date_of_birth': formattedDob,
          'user_message': userMessageText,
          'numerology_system_choice': _numerologySubmittedSystem,
          'response_language': _selectedNumerologyApiLanguage,
        }),
      );
      ChatMessage? aiMessage;
      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        final responseText = decodedResponse['response'];
        if (responseText != null && responseText is String) aiMessage = ChatMessage(text: responseText, isUserMessage: false);
        else _numerologyErrorMessage = 'Failed to parse AI response. Structure: ${response.body}';
      } else _numerologyErrorMessage = 'API Error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}';
      if (mounted) setState(() { if (aiMessage != null) _numerologyChatMessages.add(aiMessage); _numerologyIsLoading = false; });
      _scrollToBottom(_numerologyChatScrollController);
    } catch (e) { if (mounted) setState(() => _numerologyErrorMessage = 'Failed to connect: $e'); }
    if (mounted) setState(() => _numerologyIsLoading = false);
  }

  Future<void> _generateAdvisorPdf() async {
    if (_chatMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history to export.')),
      );
      return;
    }

    setState(() => _isGeneratingAdvisorPdf = true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('FinAdvisor Chat History', style: pw.Theme.of(context).header0)
          );
        },
        build: (pw.Context context) => [
          pw.Header(
            level: 1,
            text: 'Chat Log',
          ),
          ..._chatMessages.map((message) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                color: message.isUserMessage ? PdfColors.blue50 : PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              alignment: message.isUserMessage ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.Text(
                "${message.isUserMessage ? 'You' : 'FinAdvisor'}: ${message.text}",
              ),
            );
          }).toList(),
        ],
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    final String fileName = 'advisor_chat_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      web_downloader.triggerWebDownload(pdfBytes, fileName);
    } else {
      // Mobile saving and opening
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      OpenFile.open(path);
    }
    if (mounted) setState(() => _isGeneratingAdvisorPdf = false);
  }

  Future<void> _emailAdvisorChat() async {
    if (_chatMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history to email.')),
      );
      return;
    }

    setState(() => _isSendingAdvisorEmail = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing to send email...')),
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.user?.email;

      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('Could not find user email to send to.');
      }

      // The chat history is a list of ChatMessage objects. We'll convert it to a list of maps.
      final chatHistory = _chatMessages.map((m) {
        return {
          'role': m.isUserMessage ? 'user' : 'model',
          'content': m.text,
        };
      }).toList();

      // This is a hypothetical endpoint. You will need to implement this on your backend.
      // It should accept the user's email and the chat history, generate a PDF/HTML email, and send it.
      final url = Uri.parse('https://nfrm-cary-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/email-chat');

      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_email': userEmail,
          'chat_history': chatHistory,
          'session_title': 'FinAdvisor Chat History'
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history has been sent to your email.')),
        );
      } else {
        throw Exception('Failed to send email. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingAdvisorEmail = false);
      }
    }
  }

  Future<void> _generateHoroscopePdf() async {
    if (_horoscopeChatMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history to export.')),
      );
      return;
    }

    setState(() => _isGeneratingHoroscopePdf = true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('Horoscope Chat History', style: pw.Theme.of(context).header0)),
        build: (pw.Context context) => [
          pw.Header(level: 1, text: 'Session Details'),
          pw.Text('Name: $_horoscopeSubmittedPersonName'),
          pw.Text('Date of Birth: $_horoscopeSubmittedDob'),
          pw.Text('Time of Birth: $_horoscopeSubmittedTob'),
          pw.Text('Place of Birth: $_horoscopeSubmittedPob'),
          // if (_horoscopeIncludeTodaysFortune) pw.Text("Today's Fortune Requested: Yes"), // Example for PDF
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: 'Chat Log'),
          ..._horoscopeChatMessages.map((message) => pw.Container(padding: const pw.EdgeInsets.all(8), margin: const pw.EdgeInsets.symmetric(vertical: 4), decoration: pw.BoxDecoration(color: message.isUserMessage ? PdfColors.blue50 : PdfColors.grey200, borderRadius: pw.BorderRadius.circular(5)), alignment: message.isUserMessage ? pw.Alignment.centerRight : pw.Alignment.centerLeft, child: pw.Text("${message.isUserMessage ? 'You' : 'Astrology AI'}: ${message.text}"))).toList(),
        ],
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    final String fileName = 'horoscope_chat_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      web_downloader.triggerWebDownload(pdfBytes, fileName);
    } else {
      // Mobile saving and opening
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      OpenFile.open(path);
    }
    if (mounted) setState(() => _isGeneratingHoroscopePdf = false);
  }

  Future<void> _generateNumerologyPdf() async {
    if (_numerologyChatMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history to export.')),
      );
      return;
    }

    setState(() => _isGeneratingNumerologyPdf = true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Numerology Chat History', style: pw.Theme.of(context).header0)
          );
        },
        build: (pw.Context context) => [
          pw.Header(
            level: 1,
            text: 'Session Details',
          ),
          pw.Text('Name: $_numerologySubmittedPersonName'),
          pw.Text('Date of Birth: $_numerologySubmittedDob'),
          pw.Text('Numerology System: $_numerologySubmittedSystem'),
          pw.Text('Response Language: $_selectedNumerologyApiLanguage'),
          pw.SizedBox(height: 20),
          pw.Header(
            level: 1,
            text: 'Chat Log',
          ),
          ..._numerologyChatMessages.map((message) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                color: message.isUserMessage ? PdfColors.blue50 : PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              alignment: message.isUserMessage ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.Text(
                "${message.isUserMessage ? 'You' : 'Numerology AI'}: ${message.text}",
              ),
            );
          }).toList(),
        ],
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    final String fileName = 'numerology_chat_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      web_downloader.triggerWebDownload(pdfBytes, fileName);
    } else {
      // Mobile saving and opening
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      OpenFile.open(path);
    }
    if (mounted) setState(() => _isGeneratingNumerologyPdf = false);
  }

  // --- Mantra Methods ---
  void _restartMantraSession() {
    setState(() {
      _mantraDetailsSubmitted = false;
      _mantraSubmittedQuery = '';
      _mantraSubmittedResponseLanguage = '';
      _mantraChatMessages.clear();
      _mantraErrorMessage = '';
      _mantraIsLoading = false;
      _mantraQueryController.clear();
      _mantraChatInputController.clear();
      _selectedMantraResponseLanguage = _selectableApiLanguages[0]; // Reset language
      _currentMantraSessionTtsCode = _apiLanguageToTtsCode[_selectedMantraResponseLanguage] ?? 'en-US';
      _mantraYoutubeVideoId = null;
      _mantraYoutubeController?.dispose();
      _mantraYoutubeController = null;
    });
    _flutterTts.stop();
  }

  Future<void> _initiateMantraChat() async {
    setState(() {
      _mantraErrorMessage = '';
    });

    final String mantraQuery = _mantraQueryController.text.trim();

    if (mantraQuery.isEmpty) {
      setState(() {
        _mantraErrorMessage = 'Please enter some words from the mantra.';
      });
      return;
    }

    setState(() {
      _mantraDetailsSubmitted = true;
      _mantraSubmittedQuery = mantraQuery;
      _mantraSubmittedResponseLanguage = _selectedMantraResponseLanguage;
      _currentMantraSessionTtsCode = _apiLanguageToTtsCode[_selectedMantraResponseLanguage] ?? 'en-US';
      // _mantraQueryController.clear(); // Optional: clear after submission or keep for display
    });
    // Send the initial query as the first message to the API
    _sendMantraApiRequest(mantraQuery, isInitialQuery: true);
  }

  Future<void> _sendMantraApiRequest(String messageText, {bool isInitialQuery = false}) async {
    if (messageText.isEmpty) return;
    await _flutterTts.stop();

    // Add user message only if it's a follow-up. Initial query is implied.
    if (!isInitialQuery) {
      final userMessage = ChatMessage(text: messageText, isUserMessage: true);
      setState(() {
        _mantraChatMessages.add(userMessage);
      });
    }
    
    setState(() {
      _mantraIsLoading = true;
      _mantraErrorMessage = '';
      _mantraChatInputController.clear();
    });
    _scrollToBottom(_mantraChatScrollController);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.uid ?? 'guest';
    final loggedInUserName = userProvider.user?.displayName ?? userProvider.user?.email ?? 'Guest';
    final loggedInUserEmail = userProvider.user?.email ?? 'guest@example.com';

    final url = Uri.parse('https://ai-agents-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/mantra_chat');
    try {
      final response = await http.post(url,
        headers: {'accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'user_id': userId,
          'user_name': loggedInUserName,
          'user_email': loggedInUserEmail,
          'user_mantra_query': messageText, // For initial query and follow-ups
          'response_language': _mantraSubmittedResponseLanguage,
        }),
      );
      ChatMessage? aiMessage;
      String? newVideoId;
      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        final videoId = decodedResponse['youtube_video_id'];
        if (videoId != null && videoId is String && videoId.isNotEmpty) {
          newVideoId = videoId;
        } else {
          // Use a default video ID if the API doesn't provide one for now.
          newVideoId = '0HsklNB13FY'; // Example: Gayatri Mantra
        }
        final responseText = decodedResponse['response']; // Assuming API returns {"response": "..."}
        if (responseText != null && responseText is String) {
          aiMessage = ChatMessage(text: responseText, isUserMessage: false);
        } else {
          _mantraErrorMessage = 'Failed to parse AI response. Structure: ${response.body}';
        }
      } else {
        _mantraErrorMessage = 'API Error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}';
      }
      if (mounted) {
        setState(() {
          if (newVideoId != null) {
            _mantraYoutubeVideoId = newVideoId;
            _mantraYoutubeController?.dispose();
            _mantraYoutubeController = YoutubePlayerController(
              initialVideoId: _mantraYoutubeVideoId!,
              flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
            );
          }
          if (aiMessage != null) _mantraChatMessages.add(aiMessage);
          _mantraIsLoading = false;
        });
        _scrollToBottom(_mantraChatScrollController);
      }
    } catch (e) {
      if (mounted) setState(() => _mantraErrorMessage = 'Failed to connect to the mantra service: $e');
    }
    if (mounted) setState(() => _mantraIsLoading = false);
  }

  Future<void> _generateMantraPdf() async {
    if (_mantraChatMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No chat history to export.')));
      return;
    }
    setState(() => _isGeneratingMantraPdf = true);
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32),
      header: (pw.Context context) => pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('Mantra Chat History', style: pw.Theme.of(context).header0)),
      build: (pw.Context context) => [
        pw.Header(level: 1, text: 'Session Details'),
        pw.Text('Initial Mantra Query: $_mantraSubmittedQuery'),
        pw.Text('Response Language: $_mantraSubmittedResponseLanguage'),
        pw.SizedBox(height: 20),
        pw.Header(level: 1, text: 'Chat Log'),
        ..._mantraChatMessages.map((message) => pw.Container(padding: const pw.EdgeInsets.all(8), margin: const pw.EdgeInsets.symmetric(vertical: 4), decoration: pw.BoxDecoration(color: message.isUserMessage ? PdfColors.blue50 : PdfColors.grey200, borderRadius: pw.BorderRadius.circular(5)), alignment: message.isUserMessage ? pw.Alignment.centerRight : pw.Alignment.centerLeft, child: pw.Text("${message.isUserMessage ? 'You' : 'Mantra AI'}: ${message.text}"))).toList(),
      ],
    ));
    final Uint8List pdfBytes = await pdf.save();
    final String fileName = 'mantra_chat_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (kIsWeb) {
      web_downloader.triggerWebDownload(pdfBytes, fileName);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      OpenFile.open(path);
    }
    if (mounted) setState(() => _isGeneratingMantraPdf = false);
  }

  void _restartAdvisorSession() {
    setState(() {
      _chatMessages.clear();
      _isLoading = false;
      _errorMessage = '';
      _isAdvisorImageSmall = false; // This will bring back the initial view
      _selectedAdvisorLanguage = _advisorSelectableLanguages[0]; // Reset dropdown
      _textController.clear();
    });
    _flutterTts.stop();
  }

  Widget _buildPopularMantras() {
    final List<String> popularMantras = [
      'Gayatri Mantra',
      'Mahamrityunjay Mantra',
      'Om Namah Shivaya',
      'Hanuman Chalisa',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Popular Mantras',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: popularMantras.map((mantra) {
            return ActionChip(
              label: Text(mantra),
              onPressed: () {
                _mantraQueryController.text = mantra;
              },
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMantraYoutubePlayer() {
    if (_mantraYoutubeController == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Video',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          YoutubePlayer(
            controller: _mantraYoutubeController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.amber,
            progressColors: const ProgressBarColors(
              playedColor: Colors.amber,
              handleColor: Colors.amberAccent,
            ),
          ),
        ],
      ),
    );
  }


List<InlineSpan> _buildTextSpans(String text, TextStyle defaultStyle) {
  List<InlineSpan> spans = [];
  // This regex splits the string by occurrences of *content*
  // and captures the content as well as the parts outside.
  // It looks for *any characters non-greedily* then a closing *.
  final RegExp regExp = RegExp(r'(\*.*?\*)');

  text.splitMapJoin(
    regExp,
    onMatch: (Match match) {
      // This is the bold part, e.g., *text*
      String boldText = match.group(0)!;
      // Remove the asterisks for display
      spans.add(TextSpan(
        text: boldText.substring(1, boldText.length - 1),
        style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      return ''; // Return empty string as this part is handled
    },
    onNonMatch: (String nonMatch) {
      // This is the normal part
      if (nonMatch.isNotEmpty) {
        spans.add(TextSpan(text: nonMatch, style: defaultStyle));
      }
      return ''; // Return empty string as this part is handled
    },
  );
  return spans;
}

  Widget _buildChatMessageBubble(ChatMessage message, String ttsLanguageCode) {
      bool isUser = message.isUserMessage;
      // Get the default text style from the context
      final defaultStyle = DefaultTextStyle.of(context).style;

      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isUser ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text.rich( // Changed from Text to Text.rich
                  TextSpan(children: _buildTextSpans(message.text, defaultStyle)),
                ),
              ),
              if (!isUser) // Show TTS button only for AI messages
                IconButton(
                  icon: Icon(
                    _isSpeaking && _currentlySpeakingTextId == message.id
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_outlined,
                  ),
                  onPressed: () => _speakChatMessage(message, ttsLanguageCode),
                  tooltip: _isSpeaking && _currentlySpeakingTextId == message.id ? 'Stop' : 'Read aloud',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      );
    }

  @override
  Widget build(BuildContext context) {

    // Define colors based on whether the FinAdvisor tab is selected
    final screenBackgroundColor = Colors.lightBlue[50]!;
    final buttonColor = Colors.blue[700]!;
    final selectedTabColor = Colors.blue[800]!;

    FocusNode textFieldFocusNode = FocusNode();
    final List<String> imageUrls = [
      'assets/images/financial_advisor.jpg',
    ];


    // Define the content for each tab/page
    final List<Widget> _widgetOptions = <Widget>[
      // --- Advisor Page (Original Content) ---
      SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0), // Adjusted padding
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align content to the start (left)
                  children: [
                    const SizedBox(height: 5),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        crossAxisSpacing: 20.0,
                        mainAxisSpacing: 20.0,
                        mainAxisExtent: _isAdvisorImageSmall ? 62.5 : 125.0, // Conditional height
                      ),
                      itemCount: imageUrls.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Image.asset(
                          imageUrls[index],
                            color: screenBackgroundColor, // Page background color
                            colorBlendMode: BlendMode.multiply, // Blend mode to make white areas take on the color
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 50);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10), // Added spacing
                    Text(
                      'Ask Your\nFinance Advisor Anything...',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        // To use 'Bookman Old Style', ensure the font file (e.g., .ttf)
                        // is added to your project's assets folder and declared in
                        // pubspec.yaml under the flutter -> fonts section.
                        // fontFamily: 'BookmanOldStyle', 
                        fontWeight: FontWeight.bold, // Changed to bold
                        fontSize: 20, // Reduced by 20% from 36.0
                        height: 1.0, // Corresponds to line-height: 100%
                        letterSpacing: 0.0, // Corresponds to letter-spacing: 0%
                        color: Colors.brown[800], // A color that fits the theme
                      ),
                    ),
                    const SizedBox(height: 15.0), // Consistent spacing after the title text
                  ],
                ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Adjusted padding to remove top space
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_chatMessages.isEmpty) // Only show before chat starts
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Response Language',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          value: _selectedAdvisorLanguage,
                          items: _advisorSelectableLanguages.map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedAdvisorLanguage = newValue);
                            }
                          },
                          dropdownColor: Colors.white, // Explicitly set dropdown background
                        ),
                      ),
                    TextField( // Changed to a multi-line TextField (Text Area)
                      controller: _textController,
                      focusNode: textFieldFocusNode,
                      maxLines: 3, // Allows for multiple lines of input
                      decoration: InputDecoration( // Changed hintText based on _chatMessages.isNotEmpty
                        hintText: _chatMessages.isNotEmpty ? 'Can I help You with Something Else?' : "Tell us what's in your mind",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Reduced height
                        filled: true, // Ensure filled is true
                        fillColor: Colors.white, // Change to white
                      ),
                      // onSubmitted is not typically used for a multi-line text area
                      // The button will handle the submission
                    ),
                    const SizedBox(height: 15.0), // Adjusted for consistent spacing
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor, // Button color
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 11.25), // Reduced vertical padding
                      ),
                      onPressed: () {
                        if (_textController.text.isNotEmpty) {
                          _sendChatMessage(_textController.text);
                        }
                      },
                      child: Text(_chatMessages.isNotEmpty ? 'Submit' : 'Start A conversation', style: const TextStyle(color: Colors.white)), // Changed button text based on _chatMessages.isNotEmpty
                    ),
                    const SizedBox(height: 15.0), // Spacing after the button
                    if (!_isAdvisorImageSmall)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Popular Financial Questions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 14.0),
                          InkWell(
                            onTap: () {
                              _textController.text = 'What are the best long-term investment strategies for retirement?';
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                              child: const Text('What are the best long-term investment strategies for retirement?', style: TextStyle(fontSize: 14.0, color: Colors.black87)),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          InkWell(
                            onTap: () {
                              _textController.text = 'How can I create a budget and stick to it?';
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                              child: const Text('How can I create a budget and stick to it?', style: TextStyle(fontSize: 14.0, color: Colors.black87)),
                            ),
                          ),
                          const SizedBox(height: 15.0),
                        ],
                      ),
                    Expanded(
                        child: Column(
                      children: [
                        if (_chatMessages.isNotEmpty) // Header with options for the chat
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                            child: Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('FinAdvisor Session', style: Theme.of(context).textTheme.titleSmall),
                                        Text('Language: $_advisorSubmittedLanguage', style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (String result) {
                                        if (result == 'restart') _restartAdvisorSession();
                                        else if (result == 'download_pdf') _generateAdvisorPdf();
                                        else if (result == 'send_email') _emailAdvisorChat();
                                      },
                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(value: 'restart', child: Text('Restart Conversation')),
                                        PopupMenuItem<String>(value: 'download_pdf', enabled: !_isGeneratingAdvisorPdf && _chatMessages.isNotEmpty, child: Text(_isGeneratingAdvisorPdf ? 'Generating...' : 'Download PDF')),
                                        PopupMenuItem<String>(value: 'send_email', enabled: !_isSendingAdvisorEmail && _chatMessages.isNotEmpty, child: Text(_isSendingAdvisorEmail ? 'Sending...' : 'Send to Email')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: _chatMessages.isEmpty && !_isLoading && _errorMessage.isEmpty
                              ? const SizedBox.shrink() // Removed the "Ask the Vedic Advisor anything..." text
                              : ListView.builder(
                                  controller: _chatScrollController,
                                  padding: const EdgeInsets.all(8.0),
                                  itemCount: _chatMessages.length,
                                  itemBuilder: (context, index) { 
                                    final message = _chatMessages[index];
                                    return _buildChatMessageBubble(message, _currentAdvisorSessionTtsCode);
                                  },
                                ),
                        ),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: CircularProgressIndicator(),
                          ),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                          ),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const BudgetPage(),
      // --- Numerology Page ---
      
      // --- Mantra Page ---
      const ExpReviewPage(),
    ];
    return Scaffold(
      backgroundColor: screenBackgroundColor, // Added background color
      // AppBar background color will be set to match the screen
      appBar: AppBar(
        backgroundColor: screenBackgroundColor, // 1. Change AppBar color to match screen
        elevation: 0, // Optional: remove shadow for a flatter look if colors are the same
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Welcome message on the left
            Expanded( // Use Expanded to allow the text to take available space and push logout to the right
              child: Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final userName = userProvider.user?.displayName ?? userProvider.user?.email ?? 'Vinay Kumar';
                  // 2. Welcome and user name in two lines, no colon, 1:3 size ratio, horizontal line
                  return Column(
                    mainAxisSize: MainAxisSize.min, // Use min space vertically
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                    children: <Widget>[
                      Text(
                        'Welcome', // Removed colon
                        style: const TextStyle(fontSize: 12.0, color: Colors.black), // 1x size
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 18.0, color: Colors.black, fontWeight: FontWeight.bold), // 3x size, bold
                        overflow: TextOverflow.ellipsis,
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.25, // Set width to 25% of the available width
                        alignment: Alignment.centerLeft, // Align to the left
                        child: Container(
                          height: 1.0, // Thickness of the line
                          color: const Color(0xFFF15A24), // Specific color for the line
                          margin: const EdgeInsets.only(top: 1.0), // Space between username and line
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Logout button on the right
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black), // Ensure icon color contrasts with AppBar
              tooltip: 'Logout',
              onPressed: () async {
                await context.read<AuthService>().signOut();
              },
            ),
          ],
        ),
        centerTitle: false, // Important: ensures the title Row can span
        titleSpacing: NavigationToolbar.kMiddleSpacing, // Default spacing, can be adjusted if needed
        // backgroundColor: const Color(0xFFFFF1EA), // This line was from a previous diff, now moved up and uncommented
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_outlined),
            label: 'FinAdvisor',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: 'Budgeting',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long), // Icon for ExpReview
            label: 'ExpReview',
          ),
          
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: selectedTabColor, // Changed to specific color
        unselectedItemColor: Colors.grey, // Added for better UI
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        onTap: _onItemTapped,
      ),
    );
  }
}