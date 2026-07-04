import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/reminder.dart';
import '../models/chat_message.dart';
import '../core/database_service.dart';
import '../core/ai_service.dart';
import '../core/voice_service.dart';
import '../core/app_launcher.dart';
import '../core/task_executor.dart';
import '../core/accessibility_service.dart';

class JarvisProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────
  List<Task> _tasks = [];
  List<Reminder> _reminders = [];
  List<ChatMessage> _messages = [];
  final VoiceService voiceService = VoiceService();
  bool _voiceActive = false;
  bool _initialized = false;
  bool _accessibilityEnabled = false;
  String _statusMessage = '';
  DateTime _startTime = DateTime.now();

  // ── Getters ────────────────────────────────────────────────────────
  List<Task> get tasks => _tasks;
  List<Reminder> get reminders => _reminders;
  List<ChatMessage> get messages => _messages;
  bool get voiceActive => _voiceActive;
  bool get initialized => _initialized;
  bool get accessibilityEnabled => _accessibilityEnabled;
  String get statusMessage => _statusMessage;
  String get uptime {
    final diff = DateTime.now().difference(_startTime);
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  }

  // ── Initialization ──────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await DatabaseService.database;
      await voiceService.initialize();

      // Wire up voice callbacks
      voiceService.onCommand = _onVoiceCommand;
      voiceService.onComplexCommand = _onComplexVoiceCommand;
      voiceService.onError = (error) {
        addSystemMessage('⚠️ Sprachfehler: $error');
        notifyListeners();
      };
      voiceService.onResult = (text) {
        addSystemMessage('🎤 Erkannt: "$text"');
        notifyListeners();
      };

      // Check accessibility service
      _accessibilityEnabled = await AccessibilityService.isServiceEnabled();

      await refreshTasks();
      await refreshReminders();
      _initialized = true;
      _statusMessage = 'System ONLINE';
      addSystemMessage('🚀 JARVIS v2.0 — Autonomer Assistent aktiviert.');
      if (!_accessibilityEnabled) {
        addSystemMessage('ℹ️ Accessibility Service nicht aktiv. Für Automation: Einstellungen → Bedienungshilfen → JARVIS aktivieren.');
      }
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Fehler: $e';
      debugPrint('Init error: $e');
      notifyListeners();
    }
  }

  // ─── Accessibility ─────────────────────────────────────────────────
  Future<void> requestAccessibilityPermission() async {
    await AccessibilityService.requestPermission();
    addSystemMessage('⚙️ Accessibility-Einstellungen geöffnet. Bitte JARVIS dort aktivieren.');
    notifyListeners();
  }

  Future<void> checkAccessibilityStatus() async {
    _accessibilityEnabled = await AccessibilityService.isServiceEnabled();
    if (_accessibilityEnabled) {
      addSystemMessage('✅ Accessibility Service aktiv — Vollautomation bereit!');
    }
    notifyListeners();
  }

  // ── Voice ──────────────────────────────────────────────────────────
  void _onVoiceCommand(String action) {
    if (action == 'shutdown') {
      stopVoice();
      addSystemMessage('🔄 JARVIS wird beendet. Tschüss!');
      voiceService.speak('JARVIS wird beendet. Tschüss!');
      Future.delayed(const Duration(seconds: 3), () {
        SystemNavigator.pop();
      });
      return;
    }
    final responses = {
      'youtube': 'Öffne YouTube.',
      'google': 'Öffne Google.',
      'chrome': 'Starte Chrome.',
      'discord': 'Öffne Discord.',
      'spotify': 'Öffne Spotify.',
      'whatsapp': 'Öffne WhatsApp.',
      'telegram': 'Öffne Telegram.',
      'settings': 'Öffne Einstellungen.',
      'wifi': 'Öffne WLAN.',
      'bluetooth': 'Öffne Bluetooth.',
      'back': 'Gehe zurück.',
      'home': 'Gehe zur Startseite.',
      'notifications': 'Öffne Benachrichtigungen.',
    };
    final reply = responses[action] ?? 'Befehl ausgeführt.';
    addSystemMessage('🎤 Befehl: ${action.toUpperCase()}');
    voiceService.speak(reply);

    if (action == 'back') {
      AccessibilityService.goBack();
    } else if (action == 'home') {
      AccessibilityService.goHome();
    } else if (action == 'notifications') {
      AccessibilityService.openNotifications();
    } else {
      AppLauncher.execute(action);
    }
  }

  /// Handle complex multi-step voice commands via TaskExecutor
  void _onComplexVoiceCommand(String command) {
    addSystemMessage('🔍 Analysiere: "$command"');
    voiceService.speak('Analysiere Befehl.');

    // Run task executor
    TaskExecutor.execute(command).then((result) {
      if (result.success) {
        addSystemMessage('✅ ${result.message}');
        voiceService.speak(result.message);
      } else {
        // Fallback: try AI
        addSystemMessage('🤔 Komplexer Befehl — frage KI.');
        askAi(command);
      }
      notifyListeners();
    });
  }

  Future<void> toggleVoice() async {
    if (_voiceActive) {
      await voiceService.stopListening();
      _voiceActive = false;
      addSystemMessage('🎤 Sprachsteuerung deaktiviert.');
    } else {
      addSystemMessage('🎤 Sprachsteuerung wird aktiviert …');
      try {
        await voiceService.startListening();
        _voiceActive = voiceService.state == VoiceState.listening;
        if (_voiceActive) {
          addSystemMessage('🎤 Sprachsteuerung aktiv. Sage einen Befehl!');
        } else if (voiceService.state == VoiceState.noPermission) {
          addSystemMessage('⚠️ Keine Mikrofonberechtigung.');
        } else {
          addSystemMessage('⚠️ Sprachsteuerung konnte nicht aktiviert werden.');
        }
      } catch (e) {
        addSystemMessage('⚠️ Fehler: $e');
        _voiceActive = false;
      }
    }
    notifyListeners();
  }

  Future<void> stopVoice() async {
    if (_voiceActive) {
      await voiceService.stopListening();
      _voiceActive = false;
      notifyListeners();
    }
  }

  // ── AI Chat ────────────────────────────────────────────────────────
  Future<void> askAi(String prompt) async {
    if (prompt.isEmpty) return;
    _messages.add(ChatMessage(text: prompt, role: MessageRole.user));
    notifyListeners();

    final thinkingMsg =
        ChatMessage(text: '⏳ JARVIS denkt nach …', role: MessageRole.assistant);
    _messages.add(thinkingMsg);
    notifyListeners();

    try {
      final reply = await AiService.askAi(prompt);
      _messages.removeLast();
      _messages.add(ChatMessage(text: reply, role: MessageRole.assistant));
      if (_voiceActive) {
        voiceService.speak(reply);
      }
    } catch (e) {
      _messages.removeLast();
      _messages.add(ChatMessage(
        text: '⚠️ $e',
        role: MessageRole.assistant,
      ));
    }
    notifyListeners();
  }

  /// Execute a text command (from console or chat)
  Future<void> executeTextCommand(String command) async {
    addSystemMessage('⚡ Ausführen: $command');
    // Try direct commands first
    for (final entry in VoiceService.directCommands.entries) {
      if (command.contains(entry.key)) {
        _onVoiceCommand(entry.value);
        return;
      }
    }
    // Try task executor
    final result = await TaskExecutor.execute(command);
    if (result.success) {
      addSystemMessage('✅ ${result.message}');
    } else {
      // Fallback to AI
      askAi(command);
    }
    notifyListeners();
  }

  void addSystemMessage(String text) {
    _messages.add(ChatMessage(text: text, role: MessageRole.system));
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }

  // ── Tasks ──────────────────────────────────────────────────────────
  Future<void> addTask(String title, {String description = ''}) async {
    await DatabaseService.addTask(title, description: description);
    await refreshTasks();
    addSystemMessage('📋 Aufgabe hinzugefügt: $title');
  }

  Future<void> completeTask(int id) async {
    await DatabaseService.completeTask(id);
    await refreshTasks();
  }

  Future<void> deleteTask(int id) async {
    await DatabaseService.deleteTask(id);
    await refreshTasks();
  }

  Future<void> refreshTasks() async {
    _tasks = await DatabaseService.getTasks();
    notifyListeners();
  }

  // ── Reminders ─────────────────────────────────────────────────────
  Future<void> addReminder(String title,
      {String description = '', String dueDate = ''}) async {
    await DatabaseService.addReminder(title,
        description: description, dueDate: dueDate);
    await refreshReminders();
    addSystemMessage('🔔 Erinnerung hinzugefügt: $title');
  }

  Future<void> markReminderDone(int id) async {
    await DatabaseService.markReminderDone(id);
    await refreshReminders();
  }

  Future<void> deleteReminder(int id) async {
    await DatabaseService.deleteReminder(id);
    await refreshReminders();
  }

  Future<void> refreshReminders() async {
    _reminders = await DatabaseService.getReminders();
    notifyListeners();
  }

  // ── Console Command ───────────────────────────────────────────────
  Future<String> runCommand(String cmd) async {
    final action = VoiceService.directCommands.entries
        .firstWhere((e) => cmd.contains(e.key),
            orElse: () => MapEntry('', ''))
        .value;
    if (action.isNotEmpty && action != 'shutdown') {
      await AppLauncher.execute(action);
      return '✅ $action';
    }
    // Try complex execution
    final result = await TaskExecutor.execute(cmd);
    return result.success ? '✅ ${result.message}' : '🤖 ${result.message}';
  }

  @override
  void dispose() {
    voiceService.dispose();
    super.dispose();
  }
}
