import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jarvis_provider.dart';
import '../models/chat_message.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    context.read<JarvisProvider>().askAi(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Consumer<JarvisProvider>(
            builder: (context, jarvis, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });

              return ListView.builder(
                controller: _scrollController,
                itemCount: jarvis.messages.length,
                itemBuilder: (context, index) {
                  final msg = jarvis.messages[index];
                  IconData icon;
                  Color color;
                  String prefix;

                  switch (msg.role) {
                    case MessageRole.user:
                      icon = Icons.person;
                      color = const Color.fromRGBO(255, 200, 100, 1);
                      prefix = '👤 >>>';
                      break;
                    case MessageRole.assistant:
                      icon = Icons.smart_toy;
                      color = const Color.fromRGBO(255, 140, 30, 1);
                      prefix = '🤖 JARVIS >>>';
                      break;
                    case MessageRole.system:
                      icon = Icons.info;
                      color = const Color.fromRGBO(100, 200, 255, 1);
                      prefix = 'ℹ️';
                      break;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$prefix ',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: msg.text,
                            style: const TextStyle(
                              color: Color.fromRGBO(255, 170, 50, 1),
                              fontFamily: 'Courier',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(color: Color.fromRGBO(255, 120, 20, 40), height: 1),
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(
                    color: Color.fromRGBO(255, 170, 50, 1),
                    fontFamily: 'Courier',
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Frage JARVIS etwas …',
                    hintStyle: TextStyle(
                      color: Color.fromRGBO(255, 120, 20, 60),
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color.fromRGBO(0, 0, 0, 160),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: Color.fromRGBO(255, 120, 20, 60),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _neonButton('⚡', _sendMessage),
              const SizedBox(width: 4),
              _neonButton('🗑', () {
                context.read<JarvisProvider>().clearChat();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _neonButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: const Color.fromRGBO(255, 120, 20, 30),
        foregroundColor: const Color.fromRGBO(255, 140, 30, 1),
        side: const BorderSide(color: Color.fromRGBO(255, 120, 20, 120)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}
