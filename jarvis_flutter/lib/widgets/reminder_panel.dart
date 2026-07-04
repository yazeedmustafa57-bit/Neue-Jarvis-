import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jarvis_provider.dart';

class ReminderPanel extends StatefulWidget {
  const ReminderPanel({super.key});

  @override
  State<ReminderPanel> createState() => _ReminderPanelState();
}

class _ReminderPanelState extends State<ReminderPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _taskInput = TextEditingController();
  final TextEditingController _reminderInput = TextEditingController();
  final TextEditingController _dateInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskInput.dispose();
    _reminderInput.dispose();
    _dateInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color.fromRGBO(255, 220, 100, 1),
          unselectedLabelColor: const Color.fromRGBO(255, 120, 20, 100),
          indicatorColor: const Color.fromRGBO(255, 120, 20, 150),
          tabs: const [
            Tab(text: 'TASKS'),
            Tab(text: 'REMINDERS'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTasksTab(),
              _buildRemindersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskInput,
                  style: _inputStyle(),
                  decoration: _inputDecoration('Neue Aufgabe …'),
                ),
              ),
              const SizedBox(width: 8),
              _smallBtn('➕', () {
                final text = _taskInput.text.trim();
                if (text.isEmpty) return;
                context.read<JarvisProvider>().addTask(text);
                _taskInput.clear();
              }),
            ],
          ),
        ),
        Expanded(
          child: Consumer<JarvisProvider>(
            builder: (context, jarvis, _) {
              final tasks = jarvis.tasks;
              if (tasks.isEmpty) {
                return const Center(
                  child: Text('Keine Aufgaben',
                      style: TextStyle(color: Color.fromRGBO(255, 120, 20, 80))),
                );
              }
              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final done = task.status == 'completed';
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done
                          ? const Color.fromRGBO(0, 255, 100, 150)
                          : const Color.fromRGBO(255, 120, 20, 150),
                      size: 18,
                    ),
                    title: Text(
                      '[${task.status.toUpperCase()}] ${task.title}',
                      style: TextStyle(
                        color: done
                            ? const Color.fromRGBO(100, 200, 100, 150)
                            : const Color.fromRGBO(255, 170, 50, 1),
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!done)
                          IconButton(
                            icon: const Icon(Icons.check, size: 16),
                            color: const Color.fromRGBO(0, 255, 100, 150),
                            onPressed: () => jarvis.completeTask(task.id!),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          color: const Color.fromRGBO(255, 50, 50, 150),
                          onPressed: () => jarvis.deleteTask(task.id!),
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

  Widget _buildRemindersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TextField(
                controller: _reminderInput,
                style: _inputStyle(),
                decoration: _inputDecoration('Erinnerung …'),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dateInput,
                      style: _inputStyle(),
                      decoration: _inputDecoration('Datum (2026-07-10)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _smallBtn('➕', () {
                    final text = _reminderInput.text.trim();
                    if (text.isEmpty) return;
                    context
                        .read<JarvisProvider>()
                        .addReminder(text, dueDate: _dateInput.text.trim());
                    _reminderInput.clear();
                    _dateInput.clear();
                  }),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<JarvisProvider>(
            builder: (context, jarvis, _) {
              final reminders = jarvis.reminders;
              if (reminders.isEmpty) {
                return const Center(
                  child: Text('Keine Erinnerungen',
                      style: TextStyle(color: Color.fromRGBO(255, 120, 20, 80))),
                );
              }
              return ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final r = reminders[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      r.isDone ? Icons.check_circle : Icons.circle_outlined,
                      color: r.isDone
                          ? const Color.fromRGBO(0, 255, 100, 150)
                          : const Color.fromRGBO(255, 120, 20, 150),
                      size: 18,
                    ),
                    title: Text(
                      '${r.isDone ? "✓" : "○"} ${r.title}${r.dueDate.isNotEmpty ? " [${r.dueDate}]" : ""}',
                      style: const TextStyle(
                        color: Color.fromRGBO(255, 170, 50, 1),
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!r.isDone)
                          IconButton(
                            icon: const Icon(Icons.check, size: 16),
                            color: const Color.fromRGBO(0, 255, 100, 150),
                            onPressed: () => jarvis.markReminderDone(r.id!),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          color: const Color.fromRGBO(255, 50, 50, 150),
                          onPressed: () => jarvis.deleteReminder(r.id!),
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

  TextStyle _inputStyle() => const TextStyle(
        color: Color.fromRGBO(255, 170, 50, 1),
        fontFamily: 'Courier',
        fontSize: 12,
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: Color.fromRGBO(255, 120, 20, 60),
            fontFamily: 'Courier',
            fontSize: 12),
        filled: true,
        fillColor: const Color.fromRGBO(0, 0, 0, 160),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color.fromRGBO(255, 120, 20, 60)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      );

  Widget _smallBtn(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        backgroundColor: const Color.fromRGBO(255, 120, 20, 30),
        foregroundColor: const Color.fromRGBO(255, 140, 30, 1),
        side: const BorderSide(color: Color.fromRGBO(255, 120, 20, 120)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
