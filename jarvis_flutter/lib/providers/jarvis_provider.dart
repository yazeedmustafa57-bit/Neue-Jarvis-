import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/reminder.dart';
import '../models/chat_message.dart';
import '../core/database_service.dart';
import '../core/ai_service.dart';
import '../core/voice_service.dart';
import '../core/app_launcher.dart';

class JarvisProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────
  List<Task> _tasks = [];
  List<Reminder> _reminders = [];
  List<ChatMessage> _messages = [];
  final VoiceService voiceService = VoiceService();
  bool _voiceActive = false;
  bool _initialized = false;
  String _statusMessage = '';
  DateTime _startTime = DateTime.now();

  // ── Getters ────────────────────────────────────────────────────────
  List<Task> get tasks => _tasks;
  List<Reminder> get reminders => _reminders;
  List<ChatMessage> get messages => _messages;
  bool get voiceActive => _voiceActive;
  bool get initialized => _initialized;
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
      voiceService.onCommand = _onVoiceCommand;
      await refreshTasks();
      await refreshReminders();
      _initialized = true;
      _statusMessage = 'System ONLINE';
      addSystemMessage('JARVIS v1.0 gestartet. Bereit für Befehle.');
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Fehler: $e';
      debugPrint('Init error: $e');
      notifyListeners();
    }
  }

  // ── Voice ──────────────────────────────────────────────────────────
  void _onVoiceCommand(String action) {
    if (action == 'shutdown') {
      stopVoice();
      addSystemMessage('JARVIS wird beendet.');
      return;
    }
    final responses = {
      'youtube': 'Öffne YouTube.',
      'google': 'Öffne Google.',
      'chrome': 'Starte Chrome.',
      'discord': 'Öffne Discord.',
      'spotify': 'Öffne Spotify.',
      'notepad': 'Öffne Notepad.',
    };
    final reply = responses[action] ?? 'Befehl ausgeführt.';
    voiceService.speak(reply);
    AppLauncher.execute(action);
    addSystemMessage('🎤 Befehl: ${action}');
  }

  Future<void> toggleVoice() async {
    if (_voiceActive) {
      await voiceService.stopListening();
      _voiceActive = false;
    } else {
      await voiceService.startListening();
      _voiceActive = true;
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
    } catch (e) {
      _messages.removeLast();
      _messages.add(ChatMessage(
        text: '⚠️  $e',
        role: MessageRole.assistant,
      ));
    }
    notifyListeners();
  }

  void addSystemMessage(String text) {
    _messages.add(ChatMessage(text: text, role: MessageRole.system));
    notifyListeners();
  }

  void clearChat() => _messages.clear();

  // ── Tasks ──────────────────────────────────────────────────────────
  Future<void> addTask(String title, {String description = ''}) async {
    await DatabaseService.addTask(title, description: description);
    await refreshTasks();
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

  // ── Automation ────────────────────────────────────────────────────
  Future<String> runCommand(String cmd) async {
    final action = VoiceService.commands.entries
        .firstWhere((e) => cmd.contains(e.key),
            orElse: () => MapEntry('', ''))
        .value;
    if (action.isNotEmpty) {
      return AppLauncher.execute(action);
    }
    return 'Unbekannter Befehl: $cmd';
  }

  @override
  void dispose() {
    voiceService.dispose();
    super.dispose();
  }
}
