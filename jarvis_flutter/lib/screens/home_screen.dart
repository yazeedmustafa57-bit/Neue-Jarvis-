import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jarvis_provider.dart';
import '../widgets/brain_hologram.dart';
import '../models/chat_message.dart';
import '../core/voice_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _showUi = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleUi() {
    if (_showUi) {
      _fadeController.reverse();
    } else {
      _fadeController.forward();
    }
    setState(() => _showUi = !_showUi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(8, 2, 12, 1),
      body: GestureDetector(
        onDoubleTap: _toggleUi,
        child: Stack(
          children: [
            // ─── Full-screen Particle Brain ──────────────────────────
            const Positioned.fill(child: BrainHologram()),

            // ─── Accessibility Status Toast ───────────────────────────
            Consumer<JarvisProvider>(
              builder: (context, jarvis, _) {
                if (!jarvis.initialized) {
                  return const Center(
                    child: Text(
                      'JARVIS initialisiert …',
                      style: TextStyle(
                        color: Color.fromRGBO(255, 120, 20, 100),
                        fontFamily: 'Courier',
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // ─── Floating UI Overlay ──────────────────────────────────
            if (_showUi)
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildUiOverlay(context),
              ),

            // ─── Bottom-right: Toggle Hint ────────────────────────────
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: _toggleUi,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color.fromRGBO(255, 120, 20, 40),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                    color: const Color.fromRGBO(0, 0, 0, 120),
                  ),
                  child: Text(
                    _showUi ? 'HIDE UI' : 'SHOW UI',
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 120, 20, 60),
                      fontFamily: 'Courier',
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUiOverlay(BuildContext context) {
    return Consumer<JarvisProvider>(
      builder: (context, jarvis, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // ── Top bar: Minimal Status ──────────────────────────
                _buildTopBar(jarvis),
                const SizedBox(height: 8),

                // ── Center: Console + Chat Tabs ──────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: Task / Reminder panel (thin)
                      const Expanded(
                        flex: 3,
                        child: _TaskPanel(),
                      ),
                      const SizedBox(width: 8),

                      // Right: Chat / Command panel
                      Expanded(
                        flex: 5,
                        child: _buildChatPanel(jarvis),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(JarvisProvider jarvis) {
    final voiceActive = jarvis.voiceActive;
    final accessEnabled = jarvis.accessibilityEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromRGBO(255, 120, 20, 60),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
        color: const Color.fromRGBO(0, 0, 0, 140),
      ),
      child: Row(
        children: [
          // JARVIS logo
          const Text(
            'JARVIS',
            style: TextStyle(
              color: Color.fromRGBO(255, 140, 30, 1),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 12),
          // Status indicators
          _statusDot('CORE', true),
          const SizedBox(width: 8),
          _statusDot('AI', jarvis.voiceService.state != VoiceState.error),
          const SizedBox(width: 8),
          _statusDot('MIC', voiceActive, activeColor: const Color.fromRGBO(0, 255, 136, 1)),
          const SizedBox(width: 8),
          _statusDot('A11Y', accessEnabled, activeColor: const Color.fromRGBO(100, 200, 255, 1)),
          const Spacer(),
          // Uptime
          Text(
            'UP ${jarvis.uptime}',
            style: const TextStyle(
              color: Color.fromRGBO(255, 120, 20, 120),
              fontFamily: 'Courier',
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 12),
          // Voice toggle
          _minimalButton(
            voiceActive ? '🎤 ON' : '🎤 OFF',
            () => jarvis.toggleVoice(),
            active: voiceActive,
          ),
          const SizedBox(width: 8),
          // Accessibility request (if not enabled)
          if (!accessEnabled)
            _minimalButton(
              '🔓 A11Y',
              () => jarvis.requestAccessibilityPermission(),
              active: false,
            ),
        ],
      ),
    );
  }

  Widget _statusDot(String label, bool active,
      {Color activeColor = const Color.fromRGBO(0, 255, 100, 1)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : const Color.fromRGBO(255, 50, 50, 80),
            boxShadow: active
                ? [BoxShadow(color: activeColor.withAlpha(100), blurRadius: 4)]
                : null,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: active
                ? const Color.fromRGBO(200, 200, 200, 180)
                : const Color.fromRGBO(255, 50, 50, 100),
            fontFamily: 'Courier',
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _minimalButton(String label, VoidCallback onPressed,
      {bool active = false}) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        backgroundColor: active
            ? const Color.fromRGBO(0, 255, 100, 20)
            : const Color.fromRGBO(255, 120, 20, 20),
        foregroundColor: active
            ? const Color.fromRGBO(0, 255, 136, 1)
            : const Color.fromRGBO(255, 140, 30, 1),
        side: BorderSide(
          color: active
              ? const Color.fromRGBO(0, 255, 100, 60)
              : const Color.fromRGBO(255, 120, 20, 60),
          width: 0.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: const TextStyle(fontFamily: 'Courier', fontSize: 10)),
    );
  }

  Widget _buildChatPanel(JarvisProvider jarvis) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromRGBO(255, 120, 20, 40),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
        color: const Color.fromRGBO(0, 0, 0, 140),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color.fromRGBO(255, 120, 20, 20),
                  width: 0.5,
                ),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  '>>> TERMINAL',
                  style: TextStyle(
                    color: Color.fromRGBO(255, 140, 30, 120),
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: jarvis.messages.length,
              itemBuilder: (context, index) {
                final msg = jarvis.messages[index];
                final isUser = msg.role == MessageRole.user;
                final isAssistant = msg.role == MessageRole.assistant;
                final isSystem = msg.role == MessageRole.system;

                Color prefixColor;
                String prefix;
                if (isUser) {
                  prefixColor = const Color.fromRGBO(255, 200, 100, 180);
                  prefix = '👤 >';
                } else if (isAssistant) {
                  prefixColor = const Color.fromRGBO(255, 140, 30, 180);
                  prefix = '🤖 >';
                } else {
                  prefixColor = const Color.fromRGBO(100, 200, 255, 120);
                  prefix = '·';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$prefix ',
                          style: TextStyle(
                            color: prefixColor,
                            fontFamily: 'Courier',
                            fontSize: 10,
                          ),
                        ),
                        TextSpan(
                          text: msg.text,
                          style: TextStyle(
                            color: isSystem
                                ? const Color.fromRGBO(150, 200, 255, 120)
                                : const Color.fromRGBO(255, 170, 50, 180),
                            fontFamily: 'Courier',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Input
          Padding(
            padding: const EdgeInsets.all(4),
            child: _buildInputRow(jarvis),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(JarvisProvider jarvis) {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Color.fromRGBO(255, 170, 50, 180),
              fontFamily: 'Courier',
              fontSize: 10,
            ),
            decoration: InputDecoration(
              hintText: '>_  Befehl oder Frage …',
              hintStyle: TextStyle(
                color: const Color.fromRGBO(255, 120, 20, 40),
                fontFamily: 'Courier',
                fontSize: 10,
              ),
              filled: true,
              fillColor: const Color.fromRGBO(0, 0, 0, 60),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(255, 120, 20, 30),
                  width: 0.5,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              isDense: true,
            ),
            onSubmitted: (text) {
              if (text.trim().isNotEmpty) {
                jarvis.executeTextCommand(text.trim());
                controller.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              jarvis.executeTextCommand(text);
              controller.clear();
            }
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            backgroundColor: const Color.fromRGBO(255, 120, 20, 20),
            foregroundColor: const Color.fromRGBO(255, 140, 30, 1),
            side: const BorderSide(
              color: Color.fromRGBO(255, 120, 20, 60),
              width: 0.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('RUN',
              style: TextStyle(fontFamily: 'Courier', fontSize: 9)),
        ),
      ],
    );
  }
}

// ─── Slim Tasks & Reminders Panel ──────────────────────────────────────
class _TaskPanel extends StatefulWidget {
  const _TaskPanel();

  @override
  State<_TaskPanel> createState() => _TaskPanelState();
}

class _TaskPanelState extends State<_TaskPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _taskInput = TextEditingController();
  final _remindInput = TextEditingController();
  final _dateInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskInput.dispose();
    _remindInput.dispose();
    _dateInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromRGBO(255, 120, 20, 40),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
        color: const Color.fromRGBO(0, 0, 0, 140),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color.fromRGBO(255, 220, 100, 1),
            unselectedLabelColor: const Color.fromRGBO(255, 120, 20, 80),
            indicatorColor: const Color.fromRGBO(255, 120, 20, 100),
            labelStyle: const TextStyle(
                fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'TASKS'),
              Tab(text: 'REMIND'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(),
                _buildReminderList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskInput,
                  style: const TextStyle(
                      color: Color.fromRGBO(255, 170, 50, 180),
                      fontFamily: 'Courier',
                      fontSize: 9),
                  decoration: InputDecoration(
                    hintText: '+ Aufgabe',
                    hintStyle: const TextStyle(
                        color: Color.fromRGBO(255, 120, 20, 40),
                        fontFamily: 'Courier',
                        fontSize: 9),
                    filled: true,
                    fillColor: const Color.fromRGBO(0, 0, 0, 60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(
                          color: Color.fromRGBO(255, 120, 20, 30),
                          width: 0.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _miniBtn('+', () {
                final t = _taskInput.text.trim();
                if (t.isNotEmpty) {
                  context.read<JarvisProvider>().addTask(t);
                  _taskInput.clear();
                }
              }),
            ],
          ),
        ),
        Expanded(
          child: Consumer<JarvisProvider>(
            builder: (context, jarvis, _) {
              if (jarvis.tasks.isEmpty) {
                return const Center(
                  child: Text('∅',
                      style: TextStyle(
                          color: Color.fromRGBO(255, 120, 20, 40),
                          fontFamily: 'Courier',
                          fontSize: 18)),
                );
              }
              return ListView.builder(
                itemCount: jarvis.tasks.length,
                itemBuilder: (context, index) {
                  final task = jarvis.tasks[index];
                  final done = task.status == 'completed';
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    child: Row(
                      children: [
                        Text(
                          done ? '✓' : '○',
                          style: TextStyle(
                            color: done
                                ? const Color.fromRGBO(0, 255, 100, 120)
                                : const Color.fromRGBO(255, 120, 20, 120),
                            fontFamily: 'Courier',
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              color: done
                                  ? const Color.fromRGBO(100, 200, 100, 100)
                                  : const Color.fromRGBO(255, 170, 50, 150),
                              fontFamily: 'Courier',
                              fontSize: 9,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReminderList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _remindInput,
                  style: const TextStyle(
                      color: Color.fromRGBO(255, 170, 50, 180),
                      fontFamily: 'Courier',
                      fontSize: 9),
                  decoration: InputDecoration(
                    hintText: '+ Erinnerung',
                    hintStyle: const TextStyle(
                        color: Color.fromRGBO(255, 120, 20, 40),
                        fontFamily: 'Courier',
                        fontSize: 9),
                    filled: true,
                    fillColor: const Color.fromRGBO(0, 0, 0, 60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(
                          color: Color.fromRGBO(255, 120, 20, 30),
                          width: 0.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _miniBtn('+', () {
                final t = _remindInput.text.trim();
                if (t.isNotEmpty) {
                  context
                      .read<JarvisProvider>()
                      .addReminder(t, dueDate: _dateInput.text.trim());
                  _remindInput.clear();
                  _dateInput.clear();
                }
              }),
            ],
          ),
        ),
        Expanded(
          child: Consumer<JarvisProvider>(
            builder: (context, jarvis, _) {
              if (jarvis.reminders.isEmpty) {
                return const Center(
                  child: Text('∅',
                      style: TextStyle(
                          color: Color.fromRGBO(255, 120, 20, 40),
                          fontFamily: 'Courier',
                          fontSize: 18)),
                );
              }
              return ListView.builder(
                itemCount: jarvis.reminders.length,
                itemBuilder: (context, index) {
                  final r = jarvis.reminders[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    child: Row(
                      children: [
                        Text(
                          r.isDone ? '✓' : '○',
                          style: TextStyle(
                            color: r.isDone
                                ? const Color.fromRGBO(0, 255, 100, 120)
                                : const Color.fromRGBO(255, 120, 20, 120),
                            fontFamily: 'Courier',
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${r.title}${r.dueDate.isNotEmpty ? " [${r.dueDate}]" : ""}',
                            style: const TextStyle(
                              color: Color.fromRGBO(255, 170, 50, 150),
                              fontFamily: 'Courier',
                              fontSize: 9,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniBtn(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        backgroundColor: const Color.fromRGBO(255, 120, 20, 20),
        foregroundColor: const Color.fromRGBO(255, 140, 30, 1),
        side: const BorderSide(
            color: Color.fromRGBO(255, 120, 20, 60), width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: const TextStyle(fontFamily: 'Courier', fontSize: 9)),
    );
  }
}
