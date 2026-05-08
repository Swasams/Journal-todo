import 'dart:ui';
import 'package:flutter/material.dart';
import '../mood_assets.dart';
import '../models/entry.dart';
import '../db/database_helper.dart';

const kNightDeep   = Color(0xFF0F2447);
const kNightNavy   = Color(0xFF1A3F6F);
const kNightBlue   = Color(0xFF3A6BB0);
const kNightSky    = Color(0xFF7AABDA);
const kNightCloud  = Color(0xFFA7C7E4);
const kNightPaper  = Color(0xFF0F2447);

class EntryScreen extends StatefulWidget {
  final JournalEntry? entry;

  const EntryScreen({super.key, this.entry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late TextEditingController _titleController;
  late TextEditingController _todayController;
  late TextEditingController _tomorrowController;
  late TextEditingController _roseController;
  late TextEditingController _thornController;
  late TextEditingController _budController;
  late TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleController    = TextEditingController(text: e?.title ?? '');
    _todayController    = TextEditingController(text: e?.today ?? '');
    _tomorrowController = TextEditingController(text: e?.tomorrow ?? '');
    _roseController     = TextEditingController(text: e?.rose ?? '');
    _thornController    = TextEditingController(text: e?.thorn ?? '');
    _budController      = TextEditingController(text: e?.bud ?? '');
    _bodyController     = TextEditingController(text: e?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _todayController.dispose();
    _tomorrowController.dispose();
    _roseController.dispose();
    _thornController.dispose();
    _budController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entry = JournalEntry(
      id:       widget.entry?.id,
      title:    _titleController.text,
      body:     _bodyController.text,
      date:     widget.entry?.date ?? DateTime.now(),
      mood:     widget.entry?.mood,
      today:    _todayController.text,
      tomorrow: _tomorrowController.text,
      rose:     _roseController.text,
      thorn:    _thornController.text,
      bud:      _budController.text,
    );

    // If the Mood metric is already set for today, inherit it silently —
    // user can always change today's mood from the daily-metrics row on
    // the Todo tab. Only ask via the picker when there's no value yet.
    final metrics = await DatabaseHelper.getAllMetrics();
    final d = entry.date;
    final dateKey =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    double? metricMood;
    for (final m in metrics) {
      if (m.name.toLowerCase() == 'mood') {
        metricMood = m.history[dateKey];
        break;
      }
    }
    if (metricMood != null) {
      entry.mood = (metricMood.round() - 1).clamp(0, 4);
    } else {
      final mood = await _showMoodPicker(existingMood: entry.mood);
      if (!mounted) return;
      entry.mood = mood;
    }

    if (entry.id == null) {
      await DatabaseHelper.insertEntry(entry);
    } else {
      await DatabaseHelper.updateEntry(entry);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<int?> _showMoodPicker({int? existingMood}) async {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: kNightNavy.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How are you feeling?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 20),
              // Big stacked mood picker — face on the left, label on the right.
              // Great → Bad top-to-bottom.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final idx = 4 - i;
                  final selected = existingMood == idx;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, idx),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Fixed-width slot keeps each face's centre on
                          // the same x — without it the source PNGs
                          // (heart, drop, blob…) drift left/right because
                          // their visual centres differ from the bounding
                          // box centres.
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Center(
                              child: AnimatedScale(
                                scale: selected ? 1.0 : 0.92,
                                duration: const Duration(milliseconds: 150),
                                child: Opacity(
                                  opacity: selected ? 1.0 : 0.85,
                                  child: MoodFace(value: idx + 1, size: 100),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                kMoodLabels[idx],
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : kNightCloud.withValues(alpha: 0.7),
                                  fontSize: 18,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              if (selected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    height: 2,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      color: kMoodColors[idx],
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(
                  'Skip',
                  style: TextStyle(color: kNightSky, fontFamily: 'Montserrat'),
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightPaper,
      appBar: AppBar(
        backgroundColor: kNightNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.entry == null ? 'New Entry' : 'Edit Entry',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        backgroundColor: kNightBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.entry == null,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: kNightCloud),
                enabledBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: kNightCloud)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kNightBlue, width: 2)),
              ),
            ),
            const SizedBox(height: 18),

            _Section(
              icon: '📝',
              label: 'Today',
              hint: 'What did I do today?',
              controller: _todayController,
              minLines: 3,
            ),
            const SizedBox(height: 14),
            _Section(
              icon: '📋',
              label: 'Tomorrow',
              hint: 'What do I need to do tomorrow?',
              controller: _tomorrowController,
              minLines: 3,
            ),

            const SizedBox(height: 18),
            const _Heading(text: '🌹  🌵  🌱   Rose · Thorn · Bud'),
            const SizedBox(height: 10),

            _Section(
              icon: '🌹',
              label: 'Rose',
              hint: 'Best part of today',
              controller: _roseController,
              accentColor: const Color(0xFFE05C5C),
              minLines: 2,
            ),
            const SizedBox(height: 12),
            _Section(
              icon: '🌵',
              label: 'Thorn',
              hint: 'What was hard',
              controller: _thornController,
              accentColor: const Color(0xFFA7A7A7),
              minLines: 2,
            ),
            const SizedBox(height: 12),
            _Section(
              icon: '🌱',
              label: 'Bud',
              hint: 'Something to look forward to',
              controller: _budController,
              accentColor: const Color(0xFF5CBFA0),
              minLines: 2,
            ),

            const SizedBox(height: 18),
            const _Heading(text: '💭  Brain dump'),
            const SizedBox(height: 8),
            _Section(
              icon: '',
              label: '',
              hint: 'Anything else on your mind…',
              controller: _bodyController,
              minLines: 4,
              hideHeader: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────
class _Section extends StatelessWidget {
  final String icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final Color? accentColor;
  final bool hideHeader;

  const _Section({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.minLines = 3,
    this.accentColor,
    this.hideHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? kNightSky;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: kNightNavy.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                if (icon.isNotEmpty) ...[
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    letterSpacing: 0.4,
                  ),
                ),
              ]),
            ),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: null,
            style: const TextStyle(color: Colors.white, height: 1.45),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: kNightCloud.withValues(alpha: 0.55)),
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
        letterSpacing: 0.6,
      ),
    );
  }
}
