import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';
import '../models/todo_item.dart';
import '../models/trackable_metric.dart';

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
    await _syncJournalMoodToMetric(entry);
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
    await _syncJournalMoodToMetric(entry);
  }

  // Push a journal entry's mood into the Mood metric history so the Stats
  // graph picks it up. Mood is 0..4; metric stores 1..5 to match its /5 unit.
  static Future<void> _syncJournalMoodToMetric(JournalEntry entry) async {
    if (entry.mood == null) return;
    final metrics = await getAllMetrics();
    TrackableMetric? mood;
    for (final m in metrics) {
      if (m.name.toLowerCase() == 'mood') {
        mood = m;
        break;
      }
    }
    if (mood == null) return;
    final d = entry.date;
    final dateKey =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await setMetricValue(mood.id!, dateKey, (entry.mood! + 1).toDouble());
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

    // First-run seed: only kicks in when this device has no todos
    // stored. Once the flag is set we *never* touch the user's data —
    // bumping the version key in future builds is a no-op for anyone
    // already past the first launch. (To add a new default habit
    // without wiping, follow the additive pattern used for the Protein
    // metric: a separate flag that inserts the missing item if absent.)
    const seedKey = 'default_habits_seeded_v5';
    final raw = prefs.getString('todos');
    final flagSet = prefs.getBool(seedKey) ?? false;

    if (!flagSet) {
      final hasExisting =
          raw != null && (jsonDecode(raw) as List).isNotEmpty;
      if (!hasExisting) {
        final seeded = _defaultHabits();
        await prefs.setString(
            'todos', jsonEncode(seeded.map((t) => t.toMap()).toList()));
        await prefs.setBool(seedKey, true);
        return seeded;
      }
      // Existing data on this device — mark the flag so we never try
      // again, but leave the user's todos alone.
      await prefs.setBool(seedKey, true);
    }

    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((m) => TodoItem.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<void> updateTodo(TodoItem todo) async {
    final prefs = await _store;
    final todos = await getAllTodos();
    final idx = todos.indexWhere((t) => t.id == todo.id);
    if (idx != -1) todos[idx] = todo;
    await prefs.setString('todos', jsonEncode(todos.map((t) => t.toMap()).toList()));
  }

  // Persist all todos in one write — useful for bulk reorder.
  static Future<void> bulkUpdateTodos(List<TodoItem> todos) async {
    final prefs = await _store;
    await prefs.setString(
        'todos', jsonEncode(todos.map((t) => t.toMap()).toList()));
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

  // ── Daily stats (legacy total-completions counter) ───────────

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

  // ── Per-habit completion log ─────────────────────────────────
  // {yyyy-MM-dd: [habitId, habitId, ...]}

  static Future<Map<String, List<int>>> getHabitCompletions() async {
    final prefs = await _store;
    final raw = prefs.getString('habit_completions');
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, (v as List).map((e) => e as int).toList()),
    );
  }

  static Future<void> recordHabitCompletion(int habitId, String date) async {
    final prefs = await _store;
    final all = await getHabitCompletions();
    final list = all[date] ?? <int>[];
    if (!list.contains(habitId)) {
      list.add(habitId);
      all[date] = list;
      await prefs.setString('habit_completions', jsonEncode(all));
    }
  }

  static Future<void> removeHabitCompletion(int habitId, String date) async {
    final prefs = await _store;
    final all = await getHabitCompletions();
    final list = all[date];
    if (list == null) return;
    list.remove(habitId);
    if (list.isEmpty) {
      all.remove(date);
    } else {
      all[date] = list;
    }
    await prefs.setString('habit_completions', jsonEncode(all));
  }

  // ── Trackable metrics ────────────────────────────────────────

  static Future<List<TrackableMetric>> getAllMetrics() async {
    final prefs = await _store;
    final raw = prefs.getString('metrics');
    final existing = raw == null
        ? <TrackableMetric>[]
        : (jsonDecode(raw) as List)
            .map((m) => TrackableMetric.fromMap(Map<String, dynamic>.from(m)))
            .toList();

    var changed = false;

    // First-run seed: full default set.
    if (raw == null) {
      existing.addAll(_defaultMetrics());
      changed = true;
    }

    // v2 seed: ensure Protein metric exists once. If user later deletes it,
    // it stays gone because the flag is set.
    const proteinKey = 'metrics_seeded_protein_v2';
    if (!(prefs.getBool(proteinKey) ?? false)) {
      if (!existing.any((m) => m.name.toLowerCase() == 'protein')) {
        existing.add(TrackableMetric(
          id: DateTime.now().millisecondsSinceEpoch + 5,
          name: 'Protein',
          unit: 'g',
          targetValue: 70,
          colorValue: 0xFFE8873A, // evening sky
        ));
        changed = true;
      }
      await prefs.setBool(proteinKey, true);
    }

    // One-shot recolour of the existing Weight metric to kBrown (the
    // body-text brown). Bump the version key any time this default
    // changes and you want existing data to follow.
    const weightColorKey = 'metrics_weight_recolored_v2';
    if (!(prefs.getBool(weightColorKey) ?? false)) {
      for (final m in existing) {
        if (m.name.toLowerCase() == 'weight') {
          m.colorValue = 0xFF3E1F0C;
          changed = true;
        }
      }
      await prefs.setBool(weightColorKey, true);
    }

    if (changed) {
      await prefs.setString(
          'metrics', jsonEncode(existing.map((m) => m.toMap()).toList()));
    }
    return existing;
  }

  static Future<void> insertMetric(TrackableMetric metric) async {
    final prefs = await _store;
    final metrics = await getAllMetrics();
    metric.id = DateTime.now().millisecondsSinceEpoch;
    metrics.add(metric);
    await prefs.setString('metrics', jsonEncode(metrics.map((m) => m.toMap()).toList()));
  }

  static Future<void> updateMetric(TrackableMetric metric) async {
    final prefs = await _store;
    final metrics = await getAllMetrics();
    final idx = metrics.indexWhere((m) => m.id == metric.id);
    if (idx != -1) metrics[idx] = metric;
    await prefs.setString('metrics', jsonEncode(metrics.map((m) => m.toMap()).toList()));
  }

  static Future<void> deleteMetric(int id) async {
    final prefs = await _store;
    final metrics = await getAllMetrics();
    metrics.removeWhere((m) => m.id == id);
    await prefs.setString('metrics', jsonEncode(metrics.map((m) => m.toMap()).toList()));
  }

  static Future<void> setMetricValue(int metricId, String date, double value) async {
    final prefs = await _store;
    final metrics = await getAllMetrics();
    final idx = metrics.indexWhere((m) => m.id == metricId);
    if (idx == -1) return;
    metrics[idx].history[date] = value;
    await prefs.setString('metrics', jsonEncode(metrics.map((m) => m.toMap()).toList()));
  }

  static Future<void> clearMetricValue(int metricId, String date) async {
    final prefs = await _store;
    final metrics = await getAllMetrics();
    final idx = metrics.indexWhere((m) => m.id == metricId);
    if (idx == -1) return;
    metrics[idx].history.remove(date);
    await prefs.setString('metrics', jsonEncode(metrics.map((m) => m.toMap()).toList()));
  }

  static List<TodoItem> _defaultHabits() {
    final base = DateTime.now().millisecondsSinceEpoch;
    final t = today();
    // priority: 0=High, 1=Medium, 2=Low.
    final defs = <List<dynamic>>[
      // [title, priority]
      ['Morning Routine', 1],
      ['Water Reset', 1],
      ['Meds', 0],
      ['Run', 0],
      ['Gym', 0],
      ['Stretch', 1],
      ['Walking Pad', 1],
      ['Personal Projects', 1],
      ['Work', 0],
      ['Visa', 0],
      ['Hindi', 1],
      ['Social', 2],
      ['Emails', 2],
      ['WhatsApp', 2],
      ['Instagram', 2],
      ['Discord', 2],
      ['Night Routine', 1],
    ];
    return List.generate(defs.length, (i) {
      return TodoItem(
        id: base + i,
        title: defs[i][0] as String,
        priority: defs[i][1] as int,
        isHabit: true,
        intervalDays: 1,
        nextDue: t,
      );
    });
  }

  // Helper for seed default-habit nextDue date.
  static String today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static List<TrackableMetric> _defaultMetrics() {
    final base = DateTime.now().millisecondsSinceEpoch;
    return [
      TrackableMetric(
        id: base,
        name: 'Weight',
        unit: 'kg',
        targetValue: 55,
        colorValue: 0xFF3E1F0C, // kBrown — matches body text colour
      ),
      TrackableMetric(
        id: base + 1,
        name: 'Mood',
        unit: '/5',
        targetValue: 4,
        colorValue: 0xFFF4A444, // golden amber
      ),
      TrackableMetric(
        id: base + 2,
        name: 'Water',
        unit: 'L',
        targetValue: 3,
        colorValue: 0xFF3A6BB0, // night blue
      ),
      TrackableMetric(
        id: base + 3,
        name: 'Kcal',
        unit: 'kcal',
        targetValue: 1200,
        colorValue: 0xFF5D7B3D, // leaflit green
      ),
    ];
  }
}
