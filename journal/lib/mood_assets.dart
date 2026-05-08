import 'package:flutter/material.dart';

// Mood palette derived from assets/mood/{1..5}.PNG. Index 0 = mood value 1.
// Used as accent colours wherever mood appears (journal sidebars, mood
// picker rings, calendar dots, stats line tint, etc).
const kMoodColors = <Color>[
  Color(0xFF1565C0), // 1 — Depressed: deep cobalt (sad tear)
  Color(0xFF5BA341), // 2 — Bad: muted moss (sick green)
  Color(0xFFFFC107), // 3 — Meh: bright golden yellow
  Color(0xFFEF5C2A), // 4 — Good: coral orange (orange poof)
  Color(0xFFE91E48), // 5 — Great: hot pink (red heart)
];

const kMoodLabels = <String>[
  'Depressed',
  'Bad',
  'Meh',
  'Good',
  'Great',
];

// Path resolver for the mood images. Accepts mood value 1..5.
String moodAssetPath(int value) {
  final v = value.clamp(1, 5);
  return 'assets/mood/$v.PNG';
}

// Compact widget that renders the illustrated mood face.
// `value` is the 1..5 mood value (matches image filename). When `size` is
// null, the face fills its parent's box (used in flexible layouts like
// the mood calendar where the cell decides the size).
class MoodFace extends StatelessWidget {
  final int value;
  final double? size;
  const MoodFace({super.key, required this.value, this.size});

  @override
  Widget build(BuildContext context) {
    // When `size` is fixed, decode the bitmap a comfortable amount larger
    // than the display size so it stays crisp on high-DPR screens.
    // When `size` is null (fill-parent mode — used in flexible layouts
    // like the calendar grid), we don't constrain the cache size; Flutter
    // keeps the full source bitmap and downsamples at draw time with
    // high-quality filtering. Constraining it eagerly was producing the
    // pixelated look in big calendar cells.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cachePx = size != null ? (size! * dpr * 2).round() : null;
    return Image.asset(
      moodAssetPath(value),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: cachePx,
      cacheHeight: cachePx,
    );
  }
}
