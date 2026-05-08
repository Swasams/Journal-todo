import 'dart:math' as math;
// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../mood_assets.dart';
import '../models/entry.dart';
import '../db/database_helper.dart';
import 'entry_screen.dart';

// ── Browser-tab indicator (night theme) ──────────────────────
class _NightTabIndicator extends Decoration {
  const _NightTabIndicator();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _NightTabPainter();
}
class _NightTabPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    canvas.drawRRect(
      RRect.fromRectAndCorners((offset & cfg.size!).inflate(1),
          topLeft: const Radius.circular(10), topRight: const Radius.circular(10)),
      Paint()..color = kNightPaper,
    );
  }
}

// ── Stars ─────────────────────────────────────────────────────
class _StarData {
  final double x, y, size, phase;
  const _StarData(this.x, this.y, this.size, this.phase);
}

final List<_StarData> _journalStars = () {
  final rng = math.Random(99);
  return List.generate(60, (_) => _StarData(
    rng.nextDouble(),
    rng.nextDouble(),
    0.6 + rng.nextDouble() * 1.8,
    rng.nextDouble() * math.pi * 2,
  ));
}();

class _StarPainter extends CustomPainter {
  final double time;
  _StarPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _journalStars) {
      final osc = math.sin(time * math.pi * 2 + s.phase);
      final opacity = (0.15 + 0.65 * (osc * 0.5 + 0.5)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(size.width * s.x, size.height * s.y),
        s.size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.time != time;
}

// Night-sky palette
const kNightDeep   = Color(0xFF0F2447);
const kNightNavy   = Color(0xFF1A3F6F);
const kNightBlue   = Color(0xFF3A6BB0);
const kNightSky    = Color(0xFF7AABDA);
const kNightCloud  = Color(0xFFA7C7E4);
const kNightPaper  = Color(0xFF0F2447);

// Night-sky gradient — uses less of the lighter navy so the contrast
// against the AppBar stays high and the body keeps its night feel.
const kNightGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF0F2447), // deep navy (top — already darker than AppBar)
    Color(0xFF080E24), // near-black
  ],
  stops: [0.0, 0.5],
);

// Mood palette + labels now live in mood_assets.dart (kMoodColors, kMoodLabels)
// indexed for value 1..5. Journal stores mood 0..4, so map by `mood + 1`.
Color _moodColor(int mood0to4) => kMoodColors[mood0to4.clamp(0, 4)];
String _moodLabel(int mood0to4) => kMoodLabels[mood0to4.clamp(0, 4)];

// ── Tag extraction ────────────────────────────────────────────
Set<String> _extractTags(String text) {
  if (text.trim().isEmpty) return {};
  final tags = <String>{};
  final sentences = text.split(RegExp(r'(?<=[.!?\n])\s+'));
  for (final sentence in sentences) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    for (int i = 1; i < words.length; i++) {
      final clean = words[i].replaceAll(RegExp(r"[^A-Za-z''\-]"), '');
      if (clean.length < 3) continue;
      if (!RegExp(r'^[A-Z]').hasMatch(clean)) continue;
      if (clean == clean.toUpperCase()) continue;
      tags.add(clean);
    }
  }
  return tags;
}

String _entryFullText(JournalEntry e) =>
    '${e.title}. ${e.body}. ${e.today}. ${e.tomorrow}. ${e.rose}. ${e.thorn}. ${e.bud}';

Map<String, List<JournalEntry>> _buildTagIndex(List<JournalEntry> entries) {
  final index = <String, List<JournalEntry>>{};
  for (final entry in entries) {
    for (final tag in _extractTags(_entryFullText(entry))) {
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

class _JournalScreenState extends State<JournalScreen> with TickerProviderStateMixin {
  List<JournalEntry> _entries = [];
  late TabController _tabCtrl;
  late AnimationController _twinkleCtrl;
  int _moodFilter = 0; // 0=week, 1=month, 2=all time

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _twinkleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
    _twinkleCtrl.addListener(() => setState(() {}));
    _loadEntries();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _twinkleCtrl.dispose();
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

  void _showTagEntries(String tag, List<JournalEntry> tagEntries) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TagSheet(
        tag: tag,
        entries: tagEntries,
        onTap: (e) { Navigator.pop(context); _openEntry(e); },
        onDelete: (id) { Navigator.pop(context); _deleteEntry(id); },
      ),
    );
  }

  // Show all entries that mention `word` anywhere in title/body/rose/thorn/bud.
  void _showWordEntries(String word) {
    final pattern = RegExp(
        r'\b' + RegExp.escape(word.toLowerCase()) + r'\b',
        caseSensitive: false);
    final matching = _entries.where((e) {
      final hay = '${e.title} ${e.body} ${e.rose} ${e.thorn} ${e.bud}';
      return pattern.hasMatch(hay);
    }).toList();
    _showTagEntries(word, matching);
  }

  @override
  Widget build(BuildContext context) {
    final tagIndex = _buildTagIndex(_entries);
    final moodEntries = (_entries.where((e) => e.mood != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: kNightNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Journal', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kNightNavy, kNightBlue],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: const _NightTabIndicator(),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Montserrat', fontSize: 15),
              tabs: const [
                Tab(height: 52, text: 'Journal'),
                Tab(height: 52, text: 'Data'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kNightGradient),
        child: Stack(
        children: [
          // Star background
          Positioned.fill(
            child: CustomPaint(painter: _StarPainter(_twinkleCtrl.value)),
          ),
          TabBarView(
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
                entries: _entries,
                moodEntries: moodEntries,
                filter: _moodFilter,
                onFilterChanged: (v) => setState(() => _moodFilter = v),
                onWordTap: _showWordEntries,
              ),
            ],
          ),
        ],
        ),
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
    required this.entries, required this.tagIndex,
    required this.onTap, required this.onDelete, required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text('No entries yet.\nTap + to write.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 16)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return _NoteCard(
          entry: e,
          entryTags: (_extractTags(_entryFullText(e)).toList()..sort()),
          tagIndex: tagIndex,
          onTap: onTap, onDelete: onDelete, onTagTap: onTagTap,
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
    required this.entry, required this.entryTags, required this.tagIndex,
    required this.onTap, required this.onDelete, required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMood = entry.mood != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Slidable(
          key: ValueKey('note_${entry.id}'),
          // Swipe right reveals Edit + Delete (kept on a single side per request).
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.5,
            children: [
              SlidableAction(
                onPressed: (_) => onTap(entry),
                backgroundColor: kNightBlue,
                foregroundColor: Colors.white,
                icon: Icons.edit_outlined,
                label: 'Edit',
              ),
              SlidableAction(
                onPressed: (_) => onDelete(entry.id!),
                backgroundColor: const Color(0xFFE05C5C),
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: 'Delete',
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () => onTap(entry),
            child: Container(
              decoration: BoxDecoration(
                color: kNightNavy.withValues(alpha: 0.85),
                border: Border(left: BorderSide(
                  color: hasMood ? _moodColor(entry.mood!) : kNightBlue,
                  width: 4)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _cardBody(context)),
                    if (hasMood)
                      // Mood face on the right edge — fixed width so the
                      // card height is driven by body content (no overflow).
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        child: MoodFace(
                            value: entry.mood! + 1, size: 56),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title.isEmpty ? '(Untitled)' : entry.title,
            style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold,
              fontSize: 15, fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('EEEE, MMM d').format(entry.date)} · ${DateFormat('h:mm a').format(entry.date)}',
            style: TextStyle(
                color: kNightSky, fontSize: 11, fontFamily: 'Montserrat'),
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
                spacing: 6, runSpacing: 4,
                children: entryTags.map((tag) {
                  final count = tagIndex[tag]?.length ?? 0;
                  return GestureDetector(
                    onTap: () => onTagTap(tag, tagIndex[tag] ?? []),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: count > 1 ? kNightSky.withValues(alpha: 0.18) : kNightBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: count > 1 ? kNightSky.withValues(alpha: 0.6) : kNightBlue.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(tag, style: TextStyle(
                          color: count > 1 ? kNightSky : kNightCloud,
                          fontSize: 11, fontFamily: 'Montserrat',
                          fontWeight: count > 1 ? FontWeight.w600 : FontWeight.normal,
                        )),
                        if (count > 1) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: kNightSky.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count', style: TextStyle(
                              color: kNightSky, fontSize: 9, fontFamily: 'Montserrat', fontWeight: FontWeight.bold,
                            )),
                          ),
                        ],
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],
        ],
      ),
    );
  }
}

// ── Tagged body text ──────────────────────────────────────────

class _TaggedBodyText extends StatelessWidget {
  final String text;
  final Map<String, List<JournalEntry>> tagIndex;
  final void Function(String, List<JournalEntry>) onTagTap;

  const _TaggedBodyText({required this.text, required this.tagIndex, required this.onTagTap});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.5);
    if (tagIndex.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final matches = <_TagMatch>[];
    for (final tag in tagIndex.keys) {
      int start = 0;
      while (true) {
        final idx = text.indexOf(tag, start);
        if (idx == -1) break;
        final before = idx == 0 || !RegExp(r'[A-Za-z]').hasMatch(text[idx - 1]);
        final after = idx + tag.length >= text.length || !RegExp(r'[A-Za-z]').hasMatch(text[idx + tag.length]);
        if (before && after) matches.add(_TagMatch(start: idx, end: idx + tag.length, tag: tag));
        start = idx + 1;
      }
    }

    if (matches.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final deduped = <_TagMatch>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start >= cursor) { deduped.add(m); cursor = m.end; }
    }

    final spans = <InlineSpan>[];
    int pos = 0;
    for (final m in deduped) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start), style: baseStyle));
      }
      final count = tagIndex[m.tag]?.length ?? 0;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => onTagTap(m.tag, tagIndex[m.tag] ?? []),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: count > 1 ? kNightSky.withValues(alpha: 0.2) : kNightBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(m.tag, style: TextStyle(
              color: count > 1 ? kNightSky : kNightCloud,
              fontSize: 13, height: 1.5,
              fontWeight: count > 1 ? FontWeight.w600 : FontWeight.normal,
            )),
          ),
        ),
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: baseStyle));
    }

    return RichText(
      maxLines: 3, overflow: TextOverflow.ellipsis,
      text: TextSpan(style: const TextStyle(fontSize: 13, height: 1.5), children: spans),
    );
  }
}

class _TagMatch {
  final int start, end;
  final String tag;
  const _TagMatch({required this.start, required this.end, required this.tag});
}

// ── Tag sheet ─────────────────────────────────────────────────

class _TagSheet extends StatelessWidget {
  final String tag;
  final List<JournalEntry> entries;
  final void Function(JournalEntry) onTap;
  final void Function(int) onDelete;

  const _TagSheet({required this.tag, required this.entries, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final withMood = entries.where((e) => e.mood != null).toList();
    final goodDays  = withMood.where((e) => e.mood! >= 3).length;
    final mehDays   = withMood.where((e) => e.mood == 2).length;
    final badDays   = withMood.where((e) => e.mood! <= 1).length;

    // Section breakdown — independent of mood. Counts entries where the
    // tag appears as a tag-eligible word in that specific section.
    int countIn(String Function(JournalEntry) section) {
      var n = 0;
      for (final e in entries) {
        if (_extractTags(section(e)).contains(tag)) n++;
      }
      return n;
    }
    final roseCount  = countIn((e) => e.rose);
    final thornCount = countIn((e) => e.thorn);
    final budCount   = countIn((e) => e.bud);
    final hasSectionStats =
        roseCount > 0 || thornCount > 0 || budCount > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: kNightNavy.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: kNightCloud.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Icon(Icons.label_outline, color: kNightSky, size: 18),
                const SizedBox(width: 8),
                Text(tag, style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold, fontFamily: 'Montserrat',
                )),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Mood stats ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kNightPaper.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kNightBlue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total mentions
                    Row(children: [
                      Icon(Icons.format_quote_rounded, color: kNightCloud, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Mentioned $total ${total == 1 ? 'time' : 'times'}',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600,
                          fontSize: 13, fontFamily: 'Montserrat',
                        ),
                      ),
                    ]),

                    // Section breakdown — Rose / Thorn / Bud are explicit
                    // sentiment labels and stand on their own, separate
                    // from the entry's mood.
                    if (hasSectionStats) ...[
                      const SizedBox(height: 12),
                      if (roseCount > 0)
                        _MoodStatRow(
                          icon: const Text('🌹', style: TextStyle(fontSize: 14)),
                          color: const Color(0xFFE05C5C),
                          label: 'as a Rose',
                          count: roseCount,
                          total: total,
                        ),
                      if (thornCount > 0) ...[
                        const SizedBox(height: 6),
                        _MoodStatRow(
                          icon: const Text('🌵', style: TextStyle(fontSize: 14)),
                          color: const Color(0xFFA7A7A7),
                          label: 'as a Thorn',
                          count: thornCount,
                          total: total,
                        ),
                      ],
                      if (budCount > 0) ...[
                        const SizedBox(height: 6),
                        _MoodStatRow(
                          icon: const Text('🌱', style: TextStyle(fontSize: 14)),
                          color: const Color(0xFF5CBFA0),
                          label: 'as a Bud',
                          count: budCount,
                          total: total,
                        ),
                      ],
                    ],

                    if (withMood.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      if (hasSectionStats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            height: 1,
                            color: kNightBlue.withValues(alpha: 0.2),
                          ),
                        ),
                      if (goodDays > 0)
                        _MoodStatRow(
                          icon: const MoodFace(value: 4, size: 18),
                          color: kMoodColors[3],
                          label: 'on a good day',
                          count: goodDays,
                          total: total,
                        ),
                      if (mehDays > 0) ...[
                        const SizedBox(height: 6),
                        _MoodStatRow(
                          icon: const MoodFace(value: 3, size: 18),
                          color: kMoodColors[2],
                          label: 'on a meh day',
                          count: mehDays,
                          total: total,
                        ),
                      ],
                      if (badDays > 0) ...[
                        const SizedBox(height: 6),
                        _MoodStatRow(
                          icon: const MoodFace(value: 2, size: 18),
                          color: kMoodColors[1],
                          label: 'on a bad day',
                          count: badDays,
                          total: total,
                        ),
                      ],
                    ],
                  ],
                ),
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
                  // Section context: where does this tag appear in this entry?
                  final inRose = _extractTags(e.rose).contains(tag);
                  final inThorn = _extractTags(e.thorn).contains(tag);
                  final inBud = _extractTags(e.bud).contains(tag);

                  // Pick badge + accent color: Rose/Thorn/Bud win over mood.
                  Widget badge;
                  Color accent;
                  if (inRose) {
                    badge = const Text('🌹', style: TextStyle(fontSize: 22));
                    accent = const Color(0xFFE05C5C);
                  } else if (inThorn) {
                    badge = const Text('🌵', style: TextStyle(fontSize: 22));
                    accent = const Color(0xFFA7A7A7);
                  } else if (inBud) {
                    badge = const Text('🌱', style: TextStyle(fontSize: 22));
                    accent = const Color(0xFF5CBFA0);
                  } else if (e.mood != null) {
                    badge = MoodFace(value: e.mood! + 1, size: 22);
                    accent = _moodColor(e.mood!);
                  } else {
                    badge = const SizedBox.shrink();
                    accent = kNightBlue;
                  }

                  return GestureDetector(
                    onTap: () => onTap(e),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kNightPaper.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: accent, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(
                              e.title.isEmpty ? '(Untitled)' : e.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat', fontSize: 14),
                            )),
                            badge,
                          ]),
                          const SizedBox(height: 4),
                          Text(DateFormat('MMM d, yyyy · EEEE').format(e.date),
                            style: TextStyle(color: kNightSky, fontSize: 11, fontFamily: 'Montserrat')),
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
        ),
      ),
    );
  }
}

class _MoodStatRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final int count, total;

  const _MoodStatRow({
    required this.icon, required this.label,
    required this.color, required this.count, required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = count / total;
    return Row(children: [
      SizedBox(
        width: 22,
        height: 22,
        child: Center(child: icon),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Mentioned ', style: TextStyle(color: kNightCloud, fontSize: 12, fontFamily: 'Montserrat')),
              Text('$count×', style: TextStyle(color: color, fontSize: 12, fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
              Text(' $label', style: TextStyle(color: kNightCloud, fontSize: 12, fontFamily: 'Montserrat')),
            ]),
            const SizedBox(height: 4),
            Stack(children: [
              Container(
                height: 5, decoration: BoxDecoration(
                  color: kNightBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 5, decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    ]);
  }
}

// ── Data tab ─────────────────────────────────────────────────

class _DataTab extends StatelessWidget {
  final List<JournalEntry> entries;     // all entries
  final List<JournalEntry> moodEntries; // entries with mood != null, sorted asc
  final int filter;
  final void Function(int) onFilterChanged;
  final void Function(String) onWordTap;

  const _DataTab({
    required this.entries,
    required this.moodEntries,
    required this.filter,
    required this.onFilterChanged,
    required this.onWordTap,
  });

  List<JournalEntry> get _summaryEntries {
    final now = DateTime.now();
    return moodEntries.where((e) {
      if (filter == 0) return now.difference(e.date).inDays < 7;
      if (filter == 1) return now.difference(e.date).inDays < 30;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summaryEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar always shows all data — navigate by month
          Text('Mood Calendar', style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8), fontSize: 14,
            fontWeight: FontWeight.w600, fontFamily: 'Montserrat',
          )),
          const SizedBox(height: 12),
          _MoodCalendar(entries: moodEntries),
          const SizedBox(height: 24),

          // Filter toggle for summary only
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('This week')),
                ButtonSegment(value: 1, label: Text('This month')),
                ButtonSegment(value: 2, label: Text('All time')),
              ],
              selected: {filter},
              onSelectionChanged: (s) => onFilterChanged(s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? kNightBlue : kNightNavy),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Colors.white : kNightCloud),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontFamily: 'Montserrat', fontSize: 11)),
                side: WidgetStateProperty.all(BorderSide(color: kNightBlue.withValues(alpha: 0.5))),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (summary.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No mood data for this period.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 15),
              ),
            ))
          else
            _MoodSummary(entries: summary),

          const SizedBox(height: 24),
          _WordLeaderboard(entries: entries, onWordTap: onWordTap),
        ],
      ),
    );
  }
}

// ── Word leaderboard ─────────────────────────────────────────
// Words from rose/bud always count toward Good; words from thorn always
// toward Bad. Title + body use the entry's mood (>=3 good, <=1 bad).

const _kLeaderStop = {
  'about', 'above', 'after', 'again', 'against', 'also', 'been', 'before',
  'being', 'below', 'between', 'both', 'cannot', 'could', 'doing', 'down',
  'during', 'each', 'every', 'from', 'further', 'have', 'having', 'here',
  'hers', 'into', 'just', 'like', 'more', 'most', 'much', 'myself', 'never',
  'often', 'once', 'only', 'other', 'ought', 'over', 'really', 'some',
  'such', 'than', 'that', 'their', 'them', 'then', 'there', 'these',
  'they', 'this', 'those', 'through', 'today', 'under', 'until', 'very',
  'were', 'what', 'when', 'where', 'which', 'while', 'will', 'with',
  'would', 'your', 'yours', 'yourself', 'still', 'going', 'made', 'make',
  'thing', 'things', 'feel', 'felt', 'know', 'think', 'thought',
  'said', 'wanted', 'because',
};

void _addLeaderWords(Map<String, int> counts, String text) {
  if (text.isEmpty) return;
  final words = text.toLowerCase().split(RegExp(r"[^a-z']+"));
  for (final w in words) {
    if (w.length < 4) continue;
    if (_kLeaderStop.contains(w)) continue;
    counts[w] = (counts[w] ?? 0) + 1;
  }
}

class _WordLeaderboard extends StatelessWidget {
  final List<JournalEntry> entries;
  final void Function(String) onWordTap;

  const _WordLeaderboard({required this.entries, required this.onWordTap});

  @override
  Widget build(BuildContext context) {
    final goodCounts = <String, int>{};
    final badCounts = <String, int>{};
    for (final e in entries) {
      _addLeaderWords(goodCounts, e.rose);
      _addLeaderWords(goodCounts, e.bud);
      _addLeaderWords(badCounts, e.thorn);
      if (e.mood != null) {
        if (e.mood! >= 3) {
          _addLeaderWords(goodCounts, e.title);
          _addLeaderWords(goodCounts, e.body);
        } else if (e.mood! <= 1) {
          _addLeaderWords(badCounts, e.title);
          _addLeaderWords(badCounts, e.body);
        }
      }
    }

    int goodScore(String w) => (goodCounts[w] ?? 0) - (badCounts[w] ?? 0);
    int badScore(String w) => (badCounts[w] ?? 0) - (goodCounts[w] ?? 0);

    final goodTop = (goodCounts.keys.toList()
          ..sort((a, b) => goodScore(b).compareTo(goodScore(a))))
        .where((w) => goodScore(w) > 0)
        .take(8)
        .toList();
    final badTop = (badCounts.keys.toList()
          ..sort((a, b) => badScore(b).compareTo(badScore(a))))
        .where((w) => badScore(w) > 0)
        .take(8)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: kNightNavy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNightBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Word leaderboard',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Montserrat'),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a word to see entries that mention it.',
            style: TextStyle(
                color: kNightCloud.withValues(alpha: 0.65),
                fontSize: 11,
                fontFamily: 'Montserrat'),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LeaderColumn(
                  title: '🌅 Good days',
                  color: const Color(0xFF8BC34A),
                  words: goodTop,
                  countFor: (w) => goodCounts[w] ?? 0,
                  onTap: onWordTap,
                  emptyHint: badCounts.isEmpty
                      ? 'Add a Rose or write on a good-mood day.'
                      : 'Not enough good-day text yet.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LeaderColumn(
                  title: '🌧️ Bad days',
                  color: const Color(0xFFE05C5C),
                  words: badTop,
                  countFor: (w) => badCounts[w] ?? 0,
                  onTap: onWordTap,
                  emptyHint: goodCounts.isEmpty
                      ? 'Add a Thorn or write on a bad-mood day.'
                      : 'Not enough bad-day text yet.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderColumn extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> words;
  final int Function(String) countFor;
  final void Function(String) onTap;
  final String emptyHint;

  const _LeaderColumn({
    required this.title,
    required this.color,
    required this.words,
    required this.countFor,
    required this.onTap,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Montserrat')),
        const SizedBox(height: 6),
        if (words.isEmpty)
          Text(emptyHint,
              style: TextStyle(
                  color: kNightCloud.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Montserrat'))
        else
          ...List.generate(words.length, (i) {
            final w = words[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () => onTap(w),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text(w,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500)),
                    ),
                    Text('${countFor(w)}×',
                        style: TextStyle(
                            color: color.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontFamily: 'Montserrat')),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── Mood calendar ─────────────────────────────────────────────

class _MoodCalendar extends StatefulWidget {
  final List<JournalEntry> entries;
  const _MoodCalendar({required this.entries});

  @override
  State<_MoodCalendar> createState() => _MoodCalendarState();
}

class _MoodCalendarState extends State<_MoodCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  // date key → averaged mood
  Map<String, int> get _dayMoods {
    final raw = <String, List<int>>{};
    for (final e in widget.entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      raw.putIfAbsent(key, () => []).add(e.mood!);
    }
    return raw.map((k, v) => MapEntry(k, (v.reduce((a, b) => a + b) / v.length).round()));
  }

  bool get _canGoBack {
    if (widget.entries.isEmpty) return false;
    final oldest = widget.entries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    return _month.isAfter(DateTime(oldest.year, oldest.month));
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  @override
  Widget build(BuildContext context) {
    final dayMoods = _dayMoods;
    final now = DateTime.now();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // weekday: Mon=1..Sun=7; we want Sun=0 offset
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final startOffset = firstWeekday % 7; // Sun=7→0, Mon=1→1, ..., Sat=6→6

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: kNightNavy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNightBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Month nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                enabled: _canGoBack,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_month),
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat', fontSize: 14,
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right,
                enabled: _canGoForward,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Day-of-week headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => Expanded(
              child: Center(
                child: Text(d, style: TextStyle(
                  color: kNightCloud.withValues(alpha: 0.45),
                  fontSize: 10, fontFamily: 'Montserrat',
                )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();
              final day = index - startOffset + 1;
              final thisDay = DateTime(_month.year, _month.month, day);
              final isFuture = thisDay.isAfter(now);
              final isToday = _month.year == now.year && _month.month == now.month && day == now.day;
              final dateKey = DateFormat('yyyy-MM-dd').format(thisDay);
              final mood = dayMoods[dateKey];

              // When a mood is logged, just show the illustrated face —
              // it fills the cell crisply (size: null in MoodFace).
              if (mood != null && !isFuture) {
                return MoodFace(value: mood + 1);
              }
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFuture
                      ? Colors.transparent
                      : kNightBlue.withValues(alpha: 0.12),
                  border: isToday
                      ? Border.all(color: kNightSky, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isFuture
                          ? Colors.transparent
                          : kNightCloud.withValues(alpha: 0.3),
                      fontSize: 10,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Legend — illustrated mood faces, Great → Bad.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final v = 5 - i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  MoodFace(value: v, size: 16),
                  const SizedBox(width: 3),
                  Text(kMoodLabels[v - 1],
                      style: TextStyle(
                          color: kNightCloud.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontFamily: 'Montserrat')),
                ]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: enabled ? kNightCloud : kNightCloud.withValues(alpha: 0.2), size: 22),
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
    final avgIdx = avg.round().clamp(0, 4);
    final counts = List.filled(5, 0);
    for (final e in entries) { counts[e.mood!]++; }

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
          Text('Summary', style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8), fontSize: 14,
            fontWeight: FontWeight.w600, fontFamily: 'Montserrat',
          )),
          const SizedBox(height: 12),
          Row(children: [
            MoodFace(value: avgIdx + 1, size: 40),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Average: ${_moodLabel(avgIdx)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
              Text('$total entries tracked',
                style: TextStyle(color: kNightSky, fontSize: 12, fontFamily: 'Montserrat')),
            ]),
          ]),
          const SizedBox(height: 14),
          ...List.generate(5, (i) {
            final idx = 4 - i;
            final pct = counts[idx] / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                MoodFace(value: idx + 1, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Stack(children: [
                  Container(height: 8, decoration: BoxDecoration(
                    color: kNightBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(height: 8, decoration: BoxDecoration(
                      color: _moodColor(idx), borderRadius: BorderRadius.circular(4))),
                  ),
                ])),
                const SizedBox(width: 8),
                SizedBox(width: 22, child: Text('${counts[idx]}',
                  style: TextStyle(color: kNightCloud, fontSize: 11, fontFamily: 'Montserrat'),
                  textAlign: TextAlign.right)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
