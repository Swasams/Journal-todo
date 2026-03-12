import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';
import '../models/todo_item.dart';

class DatabaseHelper {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Journal entries ──────────────────────────────────────────

  static Future<void> insertEntry(JournalEntry entry) async {
    final prefs = await _store;
    final entries = await getAllEntries();
    entry.id = DateTime.now().millisecondsSinceEpoch;
    entries.add(entry);
    await prefs.setString('entries', jsonEncode(entries.map((e) => e.toMap()).toList()));
  }

  static Future<List<JournalEntry>> getAllEntries() async {
    final prefs = await _store;
    final raw = prefs.getString('entries');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((m) => JournalEntry.fromMap(Map<String, dynamic>.from(m))).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> updateEntry(JournalEntry entry) async {
    final prefs = await _store;
    final entries = await getAllEntries();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) entries[idx] = entry;
    await prefs.setString('entries', jsonEncode(entries.map((e) => e.toMap()).toList()));
  }

  static Future<void> deleteEntry(int id) async {
    final prefs = await _store;
    final entries = await getAllEntries();
    entries.removeWhere((e) => e.id == id);
    await prefs.setString('entries', jsonEncode(entries.map((e) => e.toMap()).toList()));
  }

  // ── Todos ────────────────────────────────────────────────────

  static Future<void> insertTodo(TodoItem todo) async {
    final prefs = await _store;
    final todos = await getAllTodos();
    todo.id = DateTime.now().millisecondsSinceEpoch;
    todos.add(todo);
    await prefs.setString('todos', jsonEncode(todos.map((t) => t.toMap()).toList()));
  }

  static Future<List<TodoItem>> getAllTodos() async {
    final prefs = await _store;
    final raw = prefs.getString('todos');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((m) => TodoItem.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  static Future<void> updateTodo(TodoItem todo) async {
    final prefs = await _store;
    final todos = await getAllTodos();
    final idx = todos.indexWhere((t) => t.id == todo.id);
    if (idx != -1) todos[idx] = todo;
    await prefs.setString('todos', jsonEncode(todos.map((t) => t.toMap()).toList()));
  }

  static Future<void> deleteTodo(int id) async {
    final prefs = await _store;
    final todos = await getAllTodos();
    todos.removeWhere((t) => t.id == id);
    await prefs.setString('todos', jsonEncode(todos.map((t) => t.toMap()).toList()));
  }

  static Future<void> clearDoneTodos() async {
    final prefs = await _store;
    final todos = await getAllTodos();
    final kept = todos.where((t) => t.isHabit || !t.done).toList();
    await prefs.setString('todos', jsonEncode(kept.map((t) => t.toMap()).toList()));
  }

  // ── Daily stats ──────────────────────────────────────────────

  static Future<Map<String, int>> getDailyStats() async {
    final prefs = await _store;
    final raw = prefs.getString('daily_stats');
    if (raw == null) return {};
    return Map<String, int>.from(jsonDecode(raw));
  }

  static Future<void> incrementDailyStat(String date, int amount) async {
    final prefs = await _store;
    final stats = await getDailyStats();
    stats[date] = (stats[date] ?? 0) + amount;
    await prefs.setString('daily_stats', jsonEncode(stats));
  }

  static Future<String?> getLastOpenDate() async {
    final prefs = await _store;
    return prefs.getString('last_open_date');
  }

  static Future<void> setLastOpenDate(String date) async {
    final prefs = await _store;
    await prefs.setString('last_open_date', date);
  }
}
