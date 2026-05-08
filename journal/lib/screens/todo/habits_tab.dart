// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../models/todo_item.dart';
import '../../models/trackable_metric.dart';
import '../../mood_assets.dart';
import 'todo_theme.dart';

class HabitsTab extends StatefulWidget {
  final List<TodoItem> todos;
  final List<TrackableMetric> metrics;
  final Map<String, List<int>> completions;
  final Future<void> Function(TodoItem) onEditTodo;
  final Future<void> Function(int) onDeleteTodo;
  final Future<void> Function() onResetToDefaults;

  const HabitsTab({
    super.key,
    required this.todos,
    required this.metrics,
    required this.completions,
    required this.onEditTodo,
    required this.onDeleteTodo,
    required this.onResetToDefaults,
  });

  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  bool _listOpen = true;

  List<TodoItem> get _habits {
    final items = widget.todos.where((t) => t.isHabit).toList();
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  bool _wasCompleted(int habitId, DateTime day) {
    final key = formatDate(day);
    final list = widget.completions[key];
    return list != null && list.contains(habitId);
  }

  // Color for a checked habit cell on a given day: mood-derived if a Mood
  // value was logged that day, otherwise navy fallback.
  Color _moodTintFor(DateTime day) {
    TrackableMetric? mood;
    for (final m in widget.metrics) {
      if (m.name.toLowerCase() == 'mood') {
        mood = m;
        break;
      }
    }
    final v = mood?.history[formatDate(day)];
    if (v == null) return Color(0xFF1A3F6F); // navy default
    final idx = (v.round() - 1).clamp(0, 4);
    return kMoodColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          // Habit timeline â€” today on the right, past scrolls in from
          // the left.
          _TimelineGrid(
            habits: habits,
            completions: widget.completions,
            wasCompleted: _wasCompleted,
            moodTintFor: _moodTintFor,
          ),
          SizedBox(height: 18),

          // Collapsible manage list
          GestureDetector(
            onTap: () => setState(() => _listOpen = !_listOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kSunsetPetal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kSunsetPetal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                      _listOpen
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: kSunsetPetal),
                  SizedBox(width: 8),
                  Text('Manage habits Â· ${habits.length}',
                      style: TextStyle(
                          color: kSunsetPetal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          if (_listOpen) ...[
            SizedBox(height: 8),
            if (habits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No habits yet. Tap + to add one.',
                    style: TextStyle(color: kBrown.withValues(alpha: 0.4)),
                  ),
                ),
              )
            else
              ...habits.map((h) => _HabitManageCard(
                    todo: h,
                    onTap: () => widget.onEditTodo(h),
                    onDelete: () => widget.onDeleteTodo(h.id!),
                  )),
            SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: kCream,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text('Reset to default habits?',
                        style: TextStyle(
                            color: kBrown, fontWeight: FontWeight.bold)),
                    content: Text(
                      'This will replace all your current habits with the default list and clear completion history.',
                      style: TextStyle(color: kBrown),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel',
                            style: TextStyle(color: kLeaflitGreen)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSunsetPetal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await widget.onResetToDefaults();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: kSunsetPetal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: kSunsetPetal.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh,
                        size: 16, color: kSunsetPetal.withValues(alpha: 0.8)),
                    SizedBox(width: 8),
                    Text('Reset to default habits',
                        style: TextStyle(
                            color: kSunsetPetal.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
    );
  }
}

// â”€â”€ Timeline grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Continuous date strip ending at today on the right edge. The user
// scrolls horizontally to reveal older days. The header label updates
// to reflect the visible month range. When completion data spans fewer
// than _minDays days, the past is padded out with empty cells so the
// grid feels populated; once data extends back further, the padding
// drops away.
class _TimelineGrid extends StatefulWidget {
  final List<TodoItem> habits;
  final Map<String, List<int>> completions;
  final bool Function(int habitId, DateTime day) wasCompleted;
  final Color Function(DateTime day) moodTintFor;

  const _TimelineGrid({
    required this.habits,
    required this.completions,
    required this.wasCompleted,
    required this.moodTintFor,
  });

  @override
  State<_TimelineGrid> createState() => _TimelineGridState();
}

class _TimelineGridState extends State<_TimelineGrid> {
  static const _minDays = 30;
  static const _cellW = 18.0;
  static const _cellGap = 1.0; // total horizontal margin per cell
  static const _cellSlot = _cellW + _cellGap;
  static const _cellH = 22.0;
  static const _labelW = 110.0;

  late ScrollController _scrollCtrl;
  double _viewportW = 0;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(() {
      setState(() => _scrollOffset = _scrollCtrl.offset);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Build the full date span. Today on the right; we walk backwards far
  // enough to include any logged completion, with a minimum padding so
  // the grid doesn't look empty on a fresh install.
  List<DateTime> _buildDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime earliest = today;
    for (final key in widget.completions.keys) {
      final d = parseDate(key);
      if (d.isBefore(earliest)) earliest = d;
    }
    final actualSpan = today.difference(earliest).inDays + 1;
    final span = actualSpan < _minDays ? _minDays : actualSpan;
    final start = today.subtract(Duration(days: span - 1));
    return List.generate(span, (i) => start.add(Duration(days: i)));
  }

  // First and last visible date based on the current scroll offset.
  // SingleChildScrollView with reverse:true means offset 0 is the right
  // edge (today) and the offset grows as the user scrolls into the past.
  ({DateTime first, DateTime last})? _visibleRange(List<DateTime> days) {
    if (_viewportW <= 0 || days.isEmpty) return null;
    final cellsInView = (_viewportW / _cellSlot).floor();
    if (cellsInView <= 0) return null;
    final scrolledCells = (_scrollOffset / _cellSlot).floor();
    final rightIdx = (days.length - 1 - scrolledCells).clamp(0, days.length - 1);
    final leftIdx = (rightIdx - cellsInView + 1).clamp(0, days.length - 1);
    return (first: days[leftIdx], last: days[rightIdx]);
  }

  String _headerLabel(List<DateTime> days) {
    final range = _visibleRange(days);
    if (range == null) {
      return DateFormat('MMMM yyyy').format(days.last);
    }
    final f = range.first;
    final l = range.last;
    if (f.year == l.year && f.month == l.month) {
      return DateFormat('MMMM yyyy').format(f);
    }
    if (f.year == l.year) {
      return '${DateFormat('MMM').format(f)} â€“ '
          '${DateFormat('MMM yyyy').format(l)}';
    }
    return '${DateFormat('MMM yyyy').format(f)} â€“ '
        '${DateFormat('MMM yyyy').format(l)}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            color: kFrostTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  _headerLabel(days),
                  style: TextStyle(
                    color: kBrown,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('Add a habit to start tracking.',
                        style:
                            TextStyle(color: kBrown.withValues(alpha: 0.4))),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed label column â€” habit names stay visible
                    // while the cells scroll horizontally next to them.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 22),
                        ...widget.habits.map((h) => Container(
                              width: _labelW,
                              height: _cellH + 2,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: kBrown,
                                    fontSize: 11,
                                    fontFamily: 'Montserrat'),
                              ),
                            )),
                      ],
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (_, constraints) {
                        final w = constraints.maxWidth;
                        if (w != _viewportW) {
                          // Schedule outside build to avoid setState-during-build.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (w != _viewportW) {
                              setState(() => _viewportW = w);
                            }
                          });
                        }
                        return SingleChildScrollView(
                          controller: _scrollCtrl,
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: days.map((d) {
                                  final isToday = _sameDay(d, today);
                                  return Container(
                                    width: _cellW,
                                    height: 18,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0.5),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${d.day}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isToday
                                            ? kSunsetPetal
                                            : kBrown.withValues(alpha: 0.45),
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(height: 4),
                              ...widget.habits.map((h) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 1),
                                  child: Row(
                                    children: days.map((d) {
                                      final isFuture = d.isAfter(today);
                                      final done = !isFuture &&
                                          widget.wasCompleted(h.id!, d);
                                      return Container(
                                        width: _cellW,
                                        height: _cellH,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 0.5),
                                        decoration: BoxDecoration(
                                          color: isFuture
                                              ? Colors.transparent
                                              : done
                                                  ? widget.moodTintFor(d)
                                                  : kBrown
                                                      .withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Habit manage card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _HabitManageCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HabitManageCard({
    required this.todo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: kFrostShadow,
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Slidable(
            key: ValueKey('habit_mgmt_${todo.id}'),
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              extentRatio: 0.2,
              children: [
                SlidableAction(
                  onPressed: (_) => onDelete(),
                  backgroundColor: kSunsetPetal,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12)),
                )
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: kFrostTint,
              ),
              child: ListTile(
              onTap: onTap,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSunsetPetal.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.repeat,
                    size: 18, color: kSunsetPetal),
              ),
              title: Row(children: [
                Icon(Icons.flag,
                    size: 14, color: kPriorityColors[todo.priority]),
                SizedBox(width: 6),
                Expanded(
                  child: Text(todo.title,
                      style: TextStyle(
                          color: kBrown, fontWeight: FontWeight.bold)),
                ),
              ]),
              subtitle: Text(
                todo.intervalDays == 1
                    ? 'Daily'
                    : 'Every ${todo.intervalDays} days',
                style: TextStyle(color: kEveningSky, fontSize: 11),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${todo.completionCount}',
                      style: TextStyle(
                          color: kLeaflitGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  Text('done',
                      style: TextStyle(
                          color: kBrown.withValues(alpha: 0.45),
                          fontSize: 10)),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
      ),
    );
  }
}
