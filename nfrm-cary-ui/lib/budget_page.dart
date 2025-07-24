import 'dart:convert';
import 'package:ai_agents_ui/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

class ChatMessage {
  final String id;
  final String text;
  final bool isUserMessage;

  ChatMessage({required this.text, required this.isUserMessage}) : id = uuid.v4();
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _sessionStarted = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    // For the very first message, we don't add a user message bubble
    // because it's the automatic "start budget planning session" message.
    // For all subsequent messages, we add the user's message.
    if (_chatMessages.isNotEmpty || text != "start budget planning session") {
      final userMessage = ChatMessage(text: text, isUserMessage: true);
      setState(() {
        _chatMessages.add(userMessage);
        _textController.clear();
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _scrollToBottom();

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = userProvider.user?.displayName ?? 'string';
      final userEmail = userProvider.user?.email ?? 'string';

      final history = _chatMessages.isNotEmpty
          ? _chatMessages.map((m) {
              return {'role': m.isUserMessage ? 'user' : 'model', 'content': m.text};
            }).toList()
          : [];

      final url = Uri.parse(
          'https://nfrm-cary-services-app-503377404374.us-east1.run.app/api/v1/ai-agents/budget_planner_chat');
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "prompt": text,
          "user_name": userName,
          "user_email": userEmail,
          "history": history,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final aiResponseText = responseBody['response'];

        if (aiResponseText != null) {
          setState(() {
            _chatMessages.add(ChatMessage(text: aiResponseText, isUserMessage: false));
          });
        } else {
          throw Exception('Failed to parse AI response.');
        }
      } else {
        throw Exception(
            'Failed to get response. Status code: ${response.statusCode}\nBody: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _startBudgetSession() async {
    setState(() {
      _sessionStarted = true;
      _chatMessages.clear();
      _errorMessage = null;
    });
    // Send the initial, silent prompt to kick off the conversation
    await _sendMessage("start budget planning session");
  }

  void _restartSession() {
    setState(() {
      _sessionStarted = false;
      _chatMessages.clear();
      _errorMessage = null;
      _textController.clear();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _sessionStarted ? _buildChatView() : _buildInitialView(),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center( // Wrap SizedBox with Center to center the image
            child: SizedBox(
              height: 150.0, // Consistent height with exp_review tab
              child: Image.asset(
                'assets/images/personalized_budget2.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 10), // Spacing similar to exp_review tab
          const Text(
            'Create a Personalized Budget',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Answer a few questions to generate a detailed budget tailored to your needs.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isLoading ? null : _startBudgetSession,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Start Budget Session'),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: CircularProgressIndicator(),
            ),
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
              'Budgeting Session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Restart Session',
              onPressed: _restartSession,
            )
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final message = _chatMessages[index];
              return _buildChatMessageBubble(message);
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: CircularProgressIndicator(),
          ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 10),
        _buildMessageInputField(),
      ],
    );
  }

  Widget _buildChatMessageBubble(ChatMessage message) {
    bool isUser = message.isUserMessage;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(message.text),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Type your response...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onSubmitted: _isLoading ? null : _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isLoading ? null : () => _sendMessage(_textController.text),
          ),
        ],
      ),
    );
  }
}