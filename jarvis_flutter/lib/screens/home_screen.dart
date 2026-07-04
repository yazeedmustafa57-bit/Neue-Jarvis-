import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jarvis_provider.dart';
import '../widgets/brain_hologram.dart';
import '../widgets/neon_container.dart';
import '../widgets/status_bar.dart';
import '../widgets/voice_button.dart';
import '../widgets/chat_panel.dart';
import '../widgets/reminder_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _consoleScroll = ScrollController();
  final List<String> _consoleLines = [];

  @override
  void dispose() {
    _cmdController.dispose();
    _consoleScroll.dispose();
    super.dispose();
  }

  void _runCommand() {
    final cmd = _cmdController.text.trim();
    if (cmd.isEmpty) return;
    _cmdController.clear();
    setState(() {
      _consoleLines.add('>>> $cmd');
    });
    context.read<JarvisProvider>().runCommand(cmd).then((result) {
      setState(() {
        _consoleLines.add(result);
        _consoleLines.add('');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(8, 2, 12, 1),
      body: SafeArea(
        child: Stack(
          children: [
            // Background: Brain Hologram
            const Positioned.fill(child: BrainHologram()),

            // Foreground: UI Panels
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Top Row: Status + Voice ──────────────────────────
                    Expanded(
                      flex: 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: NeonContainer(
                              title: 'SYSTEM STATUS',
                              child: const StatusBar(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: NeonContainer(
                              title: 'SPRACHSTEUERUNG',
                              child: const VoiceButton(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Middle Row: Tasks/Reminders + AI Chat ──────────
                    Expanded(
                      flex: 8,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 4,
                            child: NeonContainer(
                              title: 'AUFGABEN & ERINNERUNGEN',
                              child: const ReminderPanel(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: NeonContainer(
                              title: 'JARVIS KI',
                              child: const ChatPanel(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Bottom: Console ─────────────────────────────────
                    Expanded(
                      flex: 2,
                      child: NeonContainer(
                        title: 'CONSOLE',
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                controller: _consoleScroll,
                                itemCount: _consoleLines.length,
                                itemBuilder: (context, index) {
                                  return Text(
                                    _consoleLines[index],
                                    style: const TextStyle(
                                      color: Color.fromRGBO(255, 170, 50, 1),
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(
                                color: Color.fromRGBO(255, 120, 20, 40),
                                height: 1),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _cmdController,
                                    style: const TextStyle(
                                      color: Color.fromRGBO(255, 170, 50, 1),
                                      fontFamily: 'Courier',
                                      fontSize: 12,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '>_  Command …',
                                      hintStyle: TextStyle(
                                        color:
                                            Color.fromRGBO(255, 120, 20, 60),
                                        fontFamily: 'Courier',
                                        fontSize: 12,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(8),
                                    ),
                                    onSubmitted: (_) => _runCommand(),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _runCommand,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        const Color.fromRGBO(255, 140, 30, 1),
                                  ),
                                  child: const Text('▶ RUN',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
