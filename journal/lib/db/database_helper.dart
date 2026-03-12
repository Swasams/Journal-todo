import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/entry.dart';
import '../models/todo_item.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'journal.db');
    return openDatabase(path, version: 2, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          body TEXT,
          date TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          done INTEGER
        )
      ''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            done INTEGER
          )
        ''');
      }
    });
  }

  // Journal entries
  static Future<int> insertEntry(JournalEntry entry) async {
    final db = await database;
    return db.insert('entries', entry.toMap());
  }

  static Future<List<JournalEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('entries', orderBy: 'date DESC');
    return maps.map((m) => JournalEntry.fromMap(m)).toList();
  }

  static Future<int> updateEntry(JournalEntry entry) async {
    final db = await database;
    return db.update('entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  static Future<int> deleteEntry(int id) async {
    final db = await database;
    return db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  // Todos
  static Future<int> insertTodo(TodoItem todo) async {
    final db = await database;
    return db.insert('todos', todo.toMap());
  }

  static Future<List<TodoItem>> getAllTodos() async {
    final db = await database;
    final maps = await db.query('todos', orderBy: 'id ASC');
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  static Future<int> updateTodo(TodoItem todo) async {
    final db = await database;
    return db.update('todos', todo.toMap(), where: 'id = ?', whereArgs: [todo.id]);
  }

  static Future<int> deleteTodo(int id) async {
    final db = await database;
    return db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }
}
