import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

String starterPrompt = 'I have a paperclip, and you have fish-shaped pen that you just found on the ground. You should try to keep your pen although you are not very emotionally attached to it (you just found it), and my goal is to convince you that my paperclip is valuable enough for you to trade for it. Im not allowed to offer anything else, just the paperclip itself. However, I will try to convince you with my words that my paperclip has value, and that you should consider trading your fish-shaped pen for it. If you agree to the trade, say "[ACCEPTED]". If you dont agree, say "[DENIED]". I only have my next message to convince you, and once you make your decision, the conversation is over. Lets see if I can win you over!';
bool gameEnd = false;

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Traider',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 110, 212, 255),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(title: 'Traider'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? apiKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text.rich(TextSpan(
            text: 'Tr',
            children: <TextSpan>[
              TextSpan(text: 'ai', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              TextSpan(text: 'der')
            ]
          )
        )
      ),
      body: switch (apiKey) {
        final providedKey? => ChatWidget(apiKey: providedKey),
        _ => ApiKeyWidget(
          onSubmitted: (key) {
            setState(() => apiKey = key);
          },
        ),
      },
    );
  }
}

class ApiKeyWidget extends StatelessWidget {
  const ApiKeyWidget({required this.onSubmitted, super.key});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Convince the AI to give you a fish-shaped pen for a paperclip!\n'),
            Text('Trade details:'),
            Text('The AI just found a fish shaped pen on the ground, you only have a paperclip with you. You only have 1 message to convince the AI.\n'),
            TextButton(
              onPressed: () {
                onSubmitted('');
              },
              child: const Text('Start!'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({required this.apiKey, super.key});

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-thinking-exp-01-21',
      apiKey: 'AIzaSyDZmvbAh5FT26XomEI0IQ1blwqB-2fdfnY',
    );
    _chat = _model.startChat();
    _sendChatMessage(starterPrompt);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _chat.history.toList();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemBuilder: (context, idx) {
                final content = history[idx];
                final text = content.parts
                    .whereType<TextPart>()
                    .map<String>((e) => e.text)
                    .join('');
                return MessageWidget(
                  text: text,
                  isFromUser: content.role == 'user',
                );
              },
              itemCount: history.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
            child: Row(
              children: gameEnd ? [] : [ // Use setState() somewhere to rebuild the UI and the change will take
                Expanded(
                  child: TextField(
                    autofocus: true,
                    focusNode: _textFieldFocus,
                    decoration: textFieldDecoration(
                      context,
                      'Convince the AI...',
                    ),
                    controller: _textController,
                    onSubmitted: (String value) {
                      _sendChatMessage(value);
                      gameEnd = true;
                    },
                  ),
                ),
                const SizedBox.square(dimension: 15),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      _sendChatMessage(_textController.text);
                      gameEnd = true;
                    },
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;

      if (text == null) {
        _showError('Empty response.');
        return;
      } else {
        setState(() {
          _loading = false;
          _scrollDown();
        });
      }
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  final String text;
  final bool isFromUser;

  String formatText(String text, bool fromUser) {
    if(fromUser && text == starterPrompt){
      text = '*The chat has started*';
    }

    if(!fromUser && text.contains('[DENIED]')){
      text = text.replaceAll('[DENIED]', '*The AI has decided it does not want to trade, you lost. Reload the page to try again.*');
    }else if(!fromUser && text.contains('[ACCEPTED]')){
      text = text.replaceAll('[ACCEPTED]', '*The AI has agreed to the trade, you win. Reload the page to play again.*');
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color:
                  isFromUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 8),
            child: MarkdownBody(data: formatText(text, isFromUser)),
          ),
        ),
      ],
    );
  }
}

InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
    );
