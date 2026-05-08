// ⚠️ DEV ONLY — strip this file (and the dev panel call site in
// stats_tab.dart) before shipping. Used to populate fake data so the
// charts and dashboard are testable without weeks of real input.

import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/entry.dart';
import 'db/database_helper.dart';

class DevSeed {
  // Fill the app with ~60 days of plausible data. Idempotent: existing
  // data is overwritten so calling this again gives a clean fake slate.
  static Future<void> loadFakeData() async {
    final prefs = await SharedPreferences.getInstance();
    final rng = Random(42); // deterministic so runs are repeatable
    final now = DateTime.now();
    final days = List.generate(
        60, (i) => DateTime(now.year, now.month, now.day - (59 - i)));

    // ── Habits: keep the existing list, just populate completion log.
    final todos = await DatabaseHelper.getAllTodos();
    final habits = todos.where((t) => t.isHabit).toList();
    final completions = <String, List<int>>{};
    for (final d in days) {
      final key = _dk(d);
      for (final h in habits) {
        final rate = 0.55 + (h.id! % 7) * 0.05;
        if (rng.nextDouble() < rate) {
          completions.putIfAbsent(key, () => <int>[]).add(h.id!);
        }
      }
    }
    await prefs.setString('habit_completions', jsonEncode(completions));

    for (final h in habits) {
      var count = 0;
      for (final ids in completions.values) {
        if (ids.contains(h.id)) count++;
      }
      h.completionCount = count;
    }
    await prefs.setString(
        'todos', jsonEncode(todos.map((t) => t.toMap()).toList()));

    // ── Metrics: realistic values per day for known names; generic for
    // anything else.
    final metrics = await DatabaseHelper.getAllMetrics();
    for (final m in metrics) {
      final history = <String, double>{};
      for (var i = 0; i < days.length; i++) {
        final d = days[i];
        final key = _dk(d);
        final progress = i / days.length; // 0 → 1 over 60 days
        switch (m.name.toLowerCase()) {
          case 'weight':
            final base = 70.5 - 2.7 * progress;
            history[key] =
                (base + (rng.nextDouble() - 0.5) * 0.6).toDouble();
            break;
          case 'mood':
            history[key] = (2.5 + rng.nextDouble() * 2.4).clamp(1.0, 5.0);
            break;
          case 'water':
            history[key] = 2.0 + rng.nextDouble() * 2.2;
            break;
          case 'kcal':
            history[key] = 950 + rng.nextDouble() * 350;
            break;
          case 'protein':
            history[key] = 50 + rng.nextDouble() * 40;
            break;
          case 'todos done':
            history[key] = (rng.nextInt(6)).toDouble();
            break;
          case 'habits done':
            history[key] = (rng.nextInt(habits.length + 1)).toDouble();
            break;
          default:
            final t = m.targetValue ?? 1;
            history[key] = t * (0.75 + rng.nextDouble() * 0.5);
        }
      }
      m.history = history;
    }
    await prefs.setString(
        'metrics', jsonEncode(metrics.map((m) => m.toMap()).toList()));

    // ── Journal: 8 entries with varied moods + structured content.
    final entries = <JournalEntry>[];
    final samples = _journalSamples();
    for (var i = 0; i < samples.length; i++) {
      final daysAgo = (i * 5) + rng.nextInt(3);
      final date = now.subtract(Duration(days: daysAgo));
      entries.add(JournalEntry(
        id: now.millisecondsSinceEpoch + i,
        title: samples[i]['title']!,
        body: samples[i]['body']!,
        date: date,
        mood: int.parse(samples[i]['mood']!),
        today: samples[i]['today']!,
        tomorrow: samples[i]['tomorrow']!,
        rose: samples[i]['rose']!,
        thorn: samples[i]['thorn']!,
        bud: samples[i]['bud']!,
      ));
    }
    await prefs.setString(
        'entries', jsonEncode(entries.map((e) => e.toMap()).toList()));
  }

  // Wipe everything (real and fake). Resets seed flags so next launch
  // re-seeds the default habits + metrics from scratch.
  static Future<void> wipeAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      'todos',
      'metrics',
      'entries',
      'habit_completions',
      'daily_stats',
      'last_open_date',
      'default_habits_seeded_v5',
      'metrics_seeded_protein_v2',
      'metrics_weight_recolored_v2',
      'metrics_seeded_todos_done_v1',
      'metrics_seeded_habits_done_v1',
      'metrics_mood_recolored_pink_v1',
    ]) {
      await prefs.remove(k);
    }
  }

  static String _dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<Map<String, String>> _journalSamples() => [
        {
          'title': 'Best run in months',
          'mood': '4',
          'today':
              'Ran 7k along the river, did the gym chest day, hit my protein target.',
          'tomorrow': 'Long run on the seawall. Submit visa form.',
          'rose': 'Crushed the run, felt strong, met sunshine and energy.',
          'thorn': '',
          'bud': 'Long weekend coming up, planning a sunrise hike.',
          'body':
              'Felt like everything clicked. Sleep was great, food was on point.',
        },
        {
          'title': 'Stuck at work',
          'mood': '1',
          'today': 'Work day full of meetings, very little ship time.',
          'tomorrow': 'Block the morning, push the launch fix.',
          'rose': '',
          'thorn': 'Endless meetings, anxious about the visa stall, exhausted.',
          'bud': 'Friend visit on Saturday.',
          'body':
              'Tired and stressed about the visa paperwork sitting on someone else\'s desk.',
        },
        {
          'title': 'Quiet good day',
          'mood': '3',
          'today': 'Walked, journaled, cooked a quiet dinner.',
          'tomorrow': 'Run, then long focus block on personal project.',
          'rose': 'Calm afternoon with tea and a book, lovely.',
          'thorn': '',
          'bud': 'Possible trip planning weekend.',
          'body': 'Steady, peaceful, gentle.',
        },
        {
          'title': 'Anxious morning',
          'mood': '0',
          'today':
              'Woke up anxious, struggled to start, only got the basics done.',
          'tomorrow': 'Be gentle. Run, then nap if needed.',
          'rose': '',
          'thorn': 'Anxious, stuck, restless, body tense, hard to focus.',
          'bud': 'Therapy session this week.',
          'body':
              'Anxiety winning today. Trying to remember it passes.',
        },
        {
          'title': 'Weekend hike',
          'mood': '4',
          'today': 'Hiked with friends, sun was perfect, laughed a lot.',
          'tomorrow': 'Recovery walk, easy yoga, reading.',
          'rose': 'Sunshine, friends, laughter, mountain views, picnic.',
          'thorn': '',
          'bud': 'Another hike planned for next weekend!',
          'body': 'Best kind of day. Tired in the right way.',
        },
        {
          'title': 'Mid-week slump',
          'mood': '2',
          'today': 'Got through it. Not great, not terrible.',
          'tomorrow': 'Reset early bedtime, run in morning.',
          'rose': 'Made a really good dal.',
          'thorn': 'Felt foggy, work felt slow.',
          'bud': 'Friday night off planned.',
          'body': 'Just a meh day. Onward.',
        },
        {
          'title': 'Visa progress',
          'mood': '3',
          'today': 'Got confirmation that the visa is moving forward.',
          'tomorrow': 'Send remaining documents.',
          'rose': 'Relief, progress, finally moving.',
          'thorn': '',
          'bud': 'Travel plans starting to feel real.',
          'body': 'A weight off. Slept better.',
        },
        {
          'title': 'Bad sleep, low energy',
          'mood': '1',
          'today': 'Tired all day, skipped gym, ate poorly.',
          'tomorrow': 'Strict sleep hygiene, no screens after 9.',
          'rose': '',
          'thorn': 'Tired, cranky, sluggish, headache.',
          'bud': 'Resting tonight feels good.',
          'body': 'Low energy across the board. Body needs rest.',
        },
      ];
}
