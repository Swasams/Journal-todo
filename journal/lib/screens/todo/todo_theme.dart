import 'package:flutter/material.dart';
import '../../models/todo_item.dart';

// ── Palette ───────────────────────────────────────────────────
const kSunsetPetal  = Color(0xFFD94F3A);
const kGoldenPollen = Color(0xFFF4A444);
const kEveningSky   = Color(0xFFE8873A);
const kLeaflitGreen = Color(0xFF5D7B3D);
const kRosebudBlush = Color(0xFFF4C49A);
const kCream        = Color(0xFFFDF5E0);
// Darker brown for body text on todo/habits pages — more contrast against
// the warm gradient.
const kBrown        = Color(0xFF3E1F0C);

// Warm yellow base used as the frosted-glass tint on the morning pages.
// NEVER use pure white for backgrounds — this is the substitute. The
// yellow leans away from the gradient's red/orange/amber so cards read
// distinctly instead of blending. Mix in alpha at the call site
// (typical 0.5–0.75).
const kFrostTint = Color(0xFFF5DC8B);

// Morning sky gradient — top mirrors the AppBar (sunset red) and the
// bottom matches the home-screen warm half (golden amber). When the page
// scrolls past the gradient stops, the bottom amber stays painted —
// never a flat washed-out cream.
const kMorningGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFD94F3A), // sunset red (under the AppBar)
    Color(0xFFE8753A), // burnt orange
    Color(0xFFF4A444), // golden amber (matches home-screen gradient bottom)
  ],
  stops: [0.0, 0.45, 1.0],
);

// Empty shadow list — drop shadows turned off across the app. Kept as a
// shared constant so the wrapping `DecoratedBox` structure on each card
// stays untouched; flip a tint back in here to re-enable globally.
const kFrostShadow = <BoxShadow>[];

// Saturated dark gold reserved for the Today's-Habit-Score Meh accent
// only — the regular `kMoodColors[2]` olive disappeared on the warm
// gradient. Don't use this on the habits monthly grid.
const kScoreMehYellow = Color(0xFFCFA50C);

// Frosted-glass tint reserved for the Mood card on the Daily Metrics
// row — browny instead of yellow so the mood face pops.
const kMoodFrostBrown = Color(0xFF6B3A20);

// Palette offered when picking a colour for a habit (and as the chart
// line colour for that habit on the trends graph).
const kHabitColorPalette = <int>[
  0xFFD94F3A, // sunset red
  0xFFE8753A, // burnt orange
  0xFFCFA50C, // saturated gold
  0xFF5D7B3D, // leaflit green
  0xFF1A3F6F, // night navy
  0xFF7B5EA7, // medium purple
  0xFFE91E48, // hot pink
  0xFFA67341, // light tan brown
];

const kPriorityLabels = ['High', 'Medium', 'Low'];
// Medium = purple. Yellow disappears on the warm gradient, so we pick a
// hue that stands out against amber.
const kMediumPriorityPurple = Color(0xFF7B5EA7);
const kPriorityColors = [kSunsetPetal, kMediumPriorityPurple, kLeaflitGreen];

// ── Date helpers ──────────────────────────────────────────────
String today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime parseDate(String s) => DateTime.parse(s);

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isDue(TodoItem t) {
  if (t.nextDue == null) return false;
  return !parseDate(t.nextDue!).isAfter(DateTime.now());
}

String dueLabelFor(TodoItem t) {
  if (t.nextDue == null) return '';
  final due = parseDate(t.nextDue!);
  final now = DateTime.now();
  final diff = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (diff < 0) return 'Overdue by ${-diff}d';
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  return 'In ${diff}d  ·  ${due.day}/${due.month}';
}

// ── Browser-tab indicator ─────────────────────────────────────
class BrowserTabIndicator extends Decoration {
  const BrowserTabIndicator();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _BrowserTabPainter();
}

class _BrowserTabPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        (offset & cfg.size!).inflate(1),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      Paint()..color = kCream,
    );
  }
}
