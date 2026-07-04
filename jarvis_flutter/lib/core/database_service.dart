import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/reminder.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'jarvis.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT DEFAULT '',
            status TEXT DEFAULT 'pending',
            created_at TEXT DEFAULT (datetime('now')),
            updated_at TEXT DEFAULT (datetime('now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT DEFAULT '',
            due_date TEXT DEFAULT '',
            is_done INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now'))
          )
        ''');
      },
    );
  }

  // ── Tasks ──────────────────────────────────────────────────────────

  static Future<int> addTask(String title, {String description = ''}) async {
    final db = await database;
    return db.insert('tasks', {
      'title': title,
      'description': description,
    });
  }

  static Future<List<Task>> getTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'created_at DESC');
    return rows.map((r) => Task.fromMap(r)).toList();
  }

  static Future<void> completeTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'status': 'completed', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ── Reminders ──────────────────────────────────────────────────────

  static Future<int> addReminder(String title,
      {String description = '', String dueDate = ''}) async {
    final db = await database;
    return db.insert('reminders', {
      'title': title,
      'description': description,
      'due_date': dueDate,
    });
  }

  static Future<List<Reminder>> getReminders({bool includeDone = false}) async {
    final db = await database;
    final rows = includeDone
        ? await db.query('reminders', orderBy: 'is_done ASC, created_at DESC')
        : await db.query('reminders',
            where: 'is_done = 0', orderBy: 'created_at DESC');
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  static Future<void> markReminderDone(int id) async {
    final db = await database;
    await db.update('reminders', {'is_done': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteReminder(int id) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }
}
