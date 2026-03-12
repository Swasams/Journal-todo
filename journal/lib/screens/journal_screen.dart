import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/entry.dart';
import '../db/database_helper.dart';
import 'entry_screen.dart';

// Night-sky palette
const kNightDeep   = Color(0xFF0F2447);
const kNightNavy   = Color(0xFF1A3F6F);
const kNightBlue   = Color(0xFF3A6BB0);
const kNightSky    = Color(0xFF7AABDA);
const kNightCloud  = Color(0xFFA7C7E4);
const kNightPaper  = Color(0xFF0F2447);

const _moodLabels = ['Bad', 'Not so good', 'Meh', 'Good', 'Great'];
const _moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const _moodColors = [
  Color(0xFFE05C5C),
  Color(0xFFE0945C),
  Color(0xFF7AABDA),
  Color(0xFF5CA8D4),
  Color(0xFF5CBFA0),
];

// ── Tag extraction ────────────────────────────────────────────
// Detects proper nouns: capitalized words that are NOT the first
// word of a sentence. Covers names, places, etc.
Set<String> _extractTags(String text) {
  if (text.trim().isEmpty) return {};
  final tags = <String>{};
  // Split on sentence-ending punctuation followed by whitespace/newline
  final sentences = text.split(RegExp(r'(?<=[.!?\n])\s+'));
  for (final sentence in sentences) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    // Skip index 0 (sentence start — likely capitalized for grammar)
    for (int i = 1; i < words.length; i++) {
      // Strip punctuation from word
      final clean = words[i].replaceAll(RegExp(r"[^A-Za-z''\-]"), '');
      if (clean.length < 3) continue;
      // Must start with uppercase letter
      if (clean.isEmpty || !RegExp(r'^[A-Z]').hasMatch(clean)) continue;
      // Must not be ALL-CAPS (acronym filter)
      if (clean == clean.toUpperCase()) continue;
      tags.add(clean);
    }
  }
  return tags;
}

// Build a map: tag → list of entries containing it
Map<String, List<JournalEntry>> _buildTagIndex(List<JournalEntry> entries) {
  final index = <String, List<JournalEntry>>{};
  for (final entry in entries) {
    final text = '${entry.title} ${entry.body}';
    final tags = _extractTags(text);
    for (final tag in tags) {
      index.putIfAbsent(tag, () => []).add(entry);
    }
  }
  return index;
}

// ── JournalScreen ─────────────────────────────────────────────

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> with SingleTickerProviderStateMixin {
  List<JournalEntry> _entries = [];
  late TabController _tabCtrl;
  int _moodFilter = 0; // 0=week, 1=month, 2=all time

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadEntries();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper.getAllEntries();
    setState(() => _entries = entries);
  }

  Future<void> _openEntry([JournalEntry? entry]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
    );
    if (result == true) _loadEntries();
  }

  Future<void> _deleteEntry(int id) async {
    await DatabaseHelper.deleteEntry(id);
    _loadEntries();
  }

  List<JournalEntry> _filteredForMood() {
    final now = DateTime.now();
    return _entries.where((e) {
      if (e.mood == null) return false;
      if (_moodFilter == 0) return now.difference(e.date).inDays < 7;
      if (_moodFilter == 1) return now.difference(e.date).inDays < 30;
      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void _showTagEntries(String tag, List<JournalEntry> tagEntries) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TagSheet(
        tag: tag,
        entries: tagEntries,
        onTap: (e) {
          Navigator.pop(context);
          _openEntry(e);
        },
        onDelete: (id) {
          Navigator.pop(context);
          _deleteEntry(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagIndex = _buildTagIndex(_entries);

    return Scaffold(
      backgroundColor: kNightPaper,
      appBar: AppBar(
        backgroundColor: kNightNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Journal', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: kNightCloud,
          indicatorColor: kNightSky,
          labelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Journal'),
            Tab(text: 'Data'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _JournalTab(
            entries: _entries,
            tagIndex: tagIndex,
            onTap: _openEntry,
            onDelete: _deleteEntry,
            onTagTap: _showTagEntries,
          ),
          _DataTab(
            entries: _filteredForMood(),
            filter: _moodFilter,
            onFilterChanged: (v) => setState(() => _moodFilter = v),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEntry(),
        backgroundColor: kNightBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Journal tab ───────────────────────────────────────────────

class _JournalTab extends StatelessWidget {
  final List<JournalEntry> entries;
  final Map<String, List<JournalEntry>> tagIndex;
  final void Function(JournalEntry) onTap;
  final void Function(int) onDelete;
  final void Function(String, List<JournalEntry>) onTagTap;

  const _JournalTab({
    required this.entries,
    required this.tagIndex,
    required this.onTap,
    required this.onDelete,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No entries yet.\nTap + to write.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        final entryTags = _extractTags('${e.title} ${e.body}').toList()..sort();
        return _NoteCard(
          entry: e,
          entryTags: entryTags,
          tagIndex: tagIndex,
          onTap: onTap,
          onDelete: onDelete,
          onTagTap: onTagTap,
        );
      },
    );
  }
}

// ── Note card ─────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final JournalEntry entry;
  final List<String> entryTags;
  final Map<String, List<JournalEntry>> tagIndex;
  final void Function(JournalEntry) onTap;
  final void Function(int) onDelete;
  final void Function(String, List<JournalEntry>) onTagTap;

  const _NoteCard({
    required this.entry,
    required this.entryTags,
    required this.tagIndex,
    required this.onTap,
    required this.onDelete,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMood = entry.mood != null;
    final dateStr = DateFormat('EEEE, MMM d').format(entry.date);
    final timeStr = DateFormat('h:mm a').format(entry.date);

    return GestureDetector(
      onTap: () => onTap(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        decoration: BoxDecoration(
          color: kNightNavy.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: hasMood ? _moodColors[entry.mood!] : kNightBlue,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title.isEmpty ? '(Untitled)' : entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
                if (hasMood) ...[
                  const SizedBox(width: 8),
                  Text(_moodEmojis[entry.mood!], style: const TextStyle(fontSize: 18)),
                ],
                IconButton(
                  icon: Icon(Icons.delete_outline, color: kNightCloud.withValues(alpha: 0.4), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onDelete(entry.id!),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$dateStr · $timeStr',
              style: TextStyle(color: kNightSky, fontSize: 11, fontFamily: 'Montserrat'),
            ),
            if (entry.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TaggedBodyText(
                text: entry.body.length > 160
                    ? '${entry.body.substring(0, 160)}…'
                    : entry.body,
                tagIndex: tagIndex,
                onTagTap: onTagTap,
              ),
            ],
            if (entryTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: entryTags.map((tag) {
                  final count = tagIndex[tag]?.length ?? 0;
                  return GestureDetector(
                    onTap: () => onTagTap(tag, tagIndex[tag] ?? []),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: count > 1
                            ? kNightSky.withValues(alpha: 0.18)
                            : kNightBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: count > 1
                              ? kNightSky.withValues(alpha: 0.6)
                              : kNightBlue.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              color: count > 1 ? kNightSky : kNightCloud,
                              fontSize: 11,
                              fontFamily: 'Montserrat',
                              fontWeight: count > 1 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (count > 1) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: kNightSky.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: kNightSky,
                                  fontSize: 9,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tagged body text (inline highlights) ─────────────────────

class _TaggedBodyText extends StatelessWidget {
  final String text;
  final Map<String, List<JournalEntry>> tagIndex;
  final void Function(String, List<JournalEntry>) onTagTap;

  const _TaggedBodyText({
    required this.text,
    required this.tagIndex,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tagIndex.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.5),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Build a sorted list of (start, end, tag) matches
    final matches = <_TagMatch>[];
    for (final tag in tagIndex.keys) {
      int start = 0;
      while (true) {
        // Case-sensitive whole-word search
        final idx = text.indexOf(tag, start);
        if (idx == -1) break;
        // Ensure it's a whole word
        final before = idx == 0 || !RegExp(r'[A-Za-z]').hasMatch(text[idx - 1]);
        final after = idx + tag.length >= text.length ||
            !RegExp(r'[A-Za-z]').hasMatch(text[idx + tag.length]);
        if (before && after) {
          matches.add(_TagMatch(start: idx, end: idx + tag.length, tag: tag));
        }
        start = idx + 1;
      }
    }

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.5),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Sort by start position, remove overlaps
    matches.sort((a, b) => a.start.compareTo(b.start));
    final deduped = <_TagMatch>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start >= cursor) {
        deduped.add(m);
        cursor = m.end;
      }
    }

    // Build TextSpan tree
    final spans = <InlineSpan>[];
    int pos = 0;
    for (final m in deduped) {
      if (m.start > pos) {
        spans.add(TextSpan(
          text: text.substring(pos, m.start),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        ));
      }
      final count = tagIndex[m.tag]?.length ?? 0;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => onTagTap(m.tag, tagIndex[m.tag] ?? []),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
            decoration: BoxDecoration(
              color: count > 1
                  ? kNightSky.withValues(alpha: 0.2)
                  : kNightBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              m.tag,
              style: TextStyle(
                color: count > 1 ? kNightSky : kNightCloud,
                fontSize: 13,
                height: 1.5,
                fontWeight: count > 1 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(
        text: text.substring(pos),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      ));
    }

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.5),
        children: spans,
      ),
    );
  }
}

class _TagMatch {
  final int start, end;
  final String tag;
  const _TagMatch({required this.start, required this.end, required this.tag});
}

// ── Tag sheet (all entries for a tag) ────────────────────────

class _TagSheet extends StatelessWidget {
  final String tag;
  final List<JournalEntry> entries;
  final void Function(JournalEntry) onTap;
  final void Function(int) onDelete;

  const _TagSheet({
    required this.tag,
    required this.entries,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: kNightNavy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: kNightCloud.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.label_outline, color: kNightSky, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kNightSky.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(color: kNightSky, fontSize: 12, fontFamily: 'Montserrat'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0x22FFFFFF), height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final dateStr = DateFormat('MMM d, yyyy · EEEE').format(e.date);
                  return GestureDetector(
                    onTap: () => onTap(e),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kNightPaper.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: e.mood != null ? _moodColors[e.mood!] : kNightBlue,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.title.isEmpty ? '(Untitled)' : e.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (e.mood != null)
                                Text(_moodEmojis[e.mood!], style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(dateStr, style: TextStyle(color: kNightSky, fontSize: 11, fontFamily: 'Montserrat')),
                          if (e.body.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              e.body.length > 100 ? '${e.body.substring(0, 100)}…' : e.body,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data tab ─────────────────────────────────────────────────

class _DataTab extends StatelessWidget {
  final List<JournalEntry> entries;
  final int filter;
  final void Function(int) onFilterChanged;

  const _DataTab({
    required this.entries,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Week')),
                ButtonSegment(value: 1, label: Text('Month')),
                ButtonSegment(value: 2, label: Text('All time')),
              ],
              selected: {filter},
              onSelectionChanged: (s) => onFilterChanged(s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return kNightBlue;
                  return kNightNavy;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return kNightCloud;
                }),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                side: WidgetStateProperty.all(BorderSide(color: kNightBlue.withValues(alpha: 0.5))),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  'No mood data yet.\nWrite a journal entry to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 15),
                ),
              ),
            )
          else ...[
            Text(
              'Mood over time',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 12),
            _MoodChart(entries: entries),
            const SizedBox(height: 24),
            _MoodSummary(entries: entries),
          ],
        ],
      ),
    );
  }
}

// ── Mood chart ────────────────────────────────────────────────

class _MoodChart extends StatelessWidget {
  final List<JournalEntry> entries;
  const _MoodChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.mood!.toDouble());
    }).toList();

    final chartWidth = (entries.length * 40.0).clamp(300.0, double.infinity);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      decoration: BoxDecoration(
        color: kNightNavy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNightBlue.withValues(alpha: 0.4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 4,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: kNightBlue.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx > 4) return const SizedBox.shrink();
                      return Text(_moodEmojis[idx], style: const TextStyle(fontSize: 12));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('M/d').format(entries[idx].date),
                          style: TextStyle(color: kNightCloud, fontSize: 9, fontFamily: 'Montserrat'),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: kNightSky,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                      radius: 5,
                      color: _moodColors[spot.y.toInt()],
                      strokeWidth: 1.5,
                      strokeColor: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kNightSky.withValues(alpha: 0.25),
                        kNightSky.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mood summary ──────────────────────────────────────────────

class _MoodSummary extends StatelessWidget {
  final List<JournalEntry> entries;
  const _MoodSummary({required this.entries});

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final avg = entries.fold(0, (sum, e) => sum + e.mood!) / total;
    final avgLabel = _moodLabels[(avg.round()).clamp(0, 4)];
    final avgEmoji = _moodEmojis[(avg.round()).clamp(0, 4)];

    final counts = List.filled(5, 0);
    for (final e in entries) {
      counts[e.mood!]++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kNightNavy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNightBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(avgEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average mood: $avgLabel',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                  ),
                  Text(
                    '$total entries tracked',
                    style: TextStyle(color: kNightSky, fontSize: 12, fontFamily: 'Montserrat'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(5, (i) {
            final idx = 4 - i;
            final pct = total > 0 ? counts[idx] / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(_moodEmojis[idx], style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: kNightBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: _moodColors[idx],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${counts[idx]}',
                      style: TextStyle(color: kNightCloud, fontSize: 11, fontFamily: 'Montserrat'),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
