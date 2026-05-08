import 'dart:async';
// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/todo_item.dart';
import '../../models/trackable_metric.dart';
import '../../mood_assets.dart';
import 'todo_theme.dart';

// Bottom-sheet content for reordering items inside one priority bucket.
// Uses a standalone ReorderableListView (no nested-scroll issues) so drag
// works cleanly. Returns the reordered list via Navigator.pop on save.
class _ReorderSheet extends StatefulWidget {
  final List<TodoItem> items;
  final String priorityLabel;
  final bool overdueGroup;

  const _ReorderSheet({
    required this.items,
    required this.priorityLabel,
    required this.overdueGroup,
  });

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late final List<TodoItem> _items = [...widget.items];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: kFrostTint,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kBrown.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.swap_vert,
                            color: kBrown, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Reorder ${widget.priorityLabel}'
                          '${widget.overdueGroup ? " Â· overdue" : ""}',
                          style: TextStyle(
                            color: kBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _items.length,
                      onReorder: (oldIdx, newIdx) {
                        final adj = newIdx > oldIdx ? newIdx - 1 : newIdx;
                        setState(() {
                          final m = _items.removeAt(oldIdx);
                          _items.insert(adj, m);
                        });
                      },
                      itemBuilder: (_, i) {
                        final t = _items[i];
                        return Container(
                          key: ValueKey('rs_${t.id}'),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: kFrostTint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  kPriorityColors[t.priority].withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.drag_indicator,
                                  size: 18,
                                  color: kBrown.withValues(alpha: 0.5)),
                              SizedBox(width: 6),
                              Icon(Icons.flag,
                                  size: 14,
                                  color: kPriorityColors[t.priority]),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: TextStyle(color: kBrown),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: TextStyle(color: kLeaflitGreen)),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSunsetPetal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context, _items),
                          child: Text('Save'),
                        ),
                      ],
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
}

// Allows mouse-drag horizontal scrolling on web/desktop, where the default
// ScrollBehaviour only enables touch + trackpad.
class _DraggableScrollBehavior extends MaterialScrollBehavior {
  const _DraggableScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class TodoTab extends StatelessWidget {
  final List<TodoItem> todos;
  final List<TrackableMetric> metrics;
  final Future<void> Function(int metricId, double value) onSetMetricValue;
  final Future<void> Function(TrackableMetric m) onAddMetric;
  final Future<void> Function(TrackableMetric m) onUpdateMetric;
  final Future<void> Function(int id) onDeleteMetric;
  final Future<void> Function(TodoItem t) onCompleteHabit;
  final Future<void> Function(TodoItem t) onToggleDone;
  final Future<void> Function(TodoItem t) onEditTodo;
  final Future<void> Function(int id) onDeleteTodo;
  final Future<void> Function(TodoItem t) onDuplicateTodo;
  final Future<void> Function() onClearDone;
  final Future<void> Function(List<TodoItem> reordered) onReorderChecklist;
  final Future<void> Function(TodoItem t) onFailItem;
  final Future<void> Function(TodoItem t, DateTime? date) onReschedule;

  const TodoTab({
    super.key,
    required this.todos,
    required this.metrics,
    required this.onSetMetricValue,
    required this.onAddMetric,
    required this.onUpdateMetric,
    required this.onDeleteMetric,
    required this.onCompleteHabit,
    required this.onToggleDone,
    required this.onEditTodo,
    required this.onDeleteTodo,
    required this.onDuplicateTodo,
    required this.onClearDone,
    required this.onReorderChecklist,
    required this.onFailItem,
    required this.onReschedule,
  });

  // Sort key for the checklist: priority asc (high â†’ low), then user-set
  // order asc, then id for stable fallback when both are zero.
  int _cmp(TodoItem a, TodoItem b) {
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;
    final o = a.order.compareTo(b.order);
    if (o != 0) return o;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  // Combined checklist (due habits + active tasks) in display order.
  // Overdue items (delayed non-daily habits + tasks past their nextDue)
  // float to the top â€” within that group, sort by priority then by how
  // late they are. The remaining items sort by priority + manual order.
  List<TodoItem> get _checklist {
    final t0 = parseDate(today());
    bool overdue(TodoItem x) {
      if (x.nextDue == null) return false;
      return parseDate(x.nextDue!).isBefore(t0);
    }

    final t0Key = today();
    final items = todos.where((t) {
      if (t.isHabit) return isDue(t);
      // Today dashboard: only tasks dated today (no overdue, no future,
      // no datless tasks â€” those live on the Todo tab).
      if (t.done) return false;
      return t.nextDue == t0Key;
    }).toList();

    items.sort((a, b) {
      final aO = overdue(a);
      final bO = overdue(b);
      if (aO != bO) return aO ? -1 : 1;
      if (aO && bO) {
        final p = a.priority.compareTo(b.priority);
        if (p != 0) return p;
        // Older nextDue first (yyyy-MM-dd string compare works).
        return a.nextDue!.compareTo(b.nextDue!);
      }
      return _cmp(a, b);
    });
    return items;
  }

  List<TodoItem> get _doneTasks {
    final items = todos.where((t) => !t.isHabit && t.done).toList();
    items.sort(_cmp);
    return items;
  }

  // Open a bottom-sheet that lets the user reorder items in the same
  // priority + overdue bucket as the pivot. Drag-to-reorder works
  // reliably here because the sheet has its own scrollable layer.
  Future<void> _openReorderModal(
    BuildContext ctx,
    TodoItem pivot,
    List<TodoItem> checklist,
  ) async {
    final t0 = parseDate(today());
    bool isOverdue(TodoItem x) =>
        x.nextDue != null && parseDate(x.nextDue!).isBefore(t0);
    final pivotOverdue = isOverdue(pivot);
    final bucket = checklist
        .where((x) =>
            x.priority == pivot.priority &&
            isOverdue(x) == pivotOverdue)
        .toList();

    if (bucket.length < 2) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        backgroundColor: kBrown,
        duration: Duration(seconds: 2),
        content: Text(
          'Only one ${kPriorityLabels[pivot.priority]} '
          '${pivotOverdue ? "overdue " : ""}item â€” nothing to reorder.',
        ),
      ));
      return;
    }

    final result = await showModalBottomSheet<List<TodoItem>>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReorderSheet(
        items: bucket,
        priorityLabel: kPriorityLabels[pivot.priority],
        overdueGroup: pivotOverdue,
      ),
    );
    if (result != null) await onReorderChecklist(result);
  }

  // Today's mood-derived accent. Black if no mood is logged for today yet.
  // Meh uses kBrown directly (no need for a yellow accent on top of the
  // already-yellow gradient).
  Color _todayMoodColor() {
    for (final m in metrics) {
      if (m.name.toLowerCase() != 'mood') continue;
      final v = m.history[today()];
      if (v == null) break;
      final idx = (v.round() - 1).clamp(0, 4);
      if (idx == 2) return kBrown;
      return kMoodColors[idx];
    }
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final checklist = _checklist;
    final doneTasks = _doneTasks;
    final dueHabitsRemaining =
        checklist.where((t) => t.isHabit).length;
    final totalHabits = todos.where((t) => t.isHabit).length;
    final habitsCompletedToday = totalHabits - dueHabitsRemaining;
    final habitPct =
        totalHabits == 0 ? 0.0 : habitsCompletedToday / totalHabits;

    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          // â”€â”€ Daily metrics row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SectionHeader(title: 'Daily metrics', subtitle: today()),
          SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: Builder(
              builder: (_) {
                // Mood always shows first, then the rest in their original order.
                final ordered = [
                  ...metrics.where((m) => m.name.toLowerCase() == 'mood'),
                  ...metrics.where((m) => m.name.toLowerCase() != 'mood'),
                ];
                // On web/desktop, default scroll behaviour blocks mouse
                // drag. Override so the metrics row is click-and-drag.
                return ScrollConfiguration(
                  behavior: const _DraggableScrollBehavior(),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ordered.length + 1,
                    itemBuilder: (_, i) {
                      if (i == ordered.length) {
                        return _AddMetricCard(onAddMetric: onAddMetric);
                      }
                      return _MetricCard(
                        metric: ordered[i],
                        onSetValue: (v) =>
                            onSetMetricValue(ordered[i].id!, v),
                        onUpdate: onUpdateMetric,
                        onDelete: () => onDeleteMetric(ordered[i].id!),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 18),

          // â”€â”€ Today summary callout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _DayCallout(
            habitsDone: habitsCompletedToday,
            habitsTotal: totalHabits,
            pct: habitPct,
            moodAccent: _todayMoodColor(),
          ),

          SizedBox(height: 10),
          _TimePerTaskPanel(
            remaining: checklist.length,
            done: habitsCompletedToday + doneTasks.length,
          ),

          SizedBox(height: 18),

          // â”€â”€ Today's checklist â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SectionHeader(
            title: "Today's checklist",
            subtitle: '${checklist.length} to go',
          ),
          SizedBox(height: 8),
          if (checklist.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nothing left for today. Nice. ðŸŒ…',
                  style: TextStyle(color: kBrown.withValues(alpha: 0.45)),
                ),
              ),
            )
          else
            // Plain list â€” reorder happens through the per-item Reorder
            // swipe action, which opens a modal scoped to that item's
            // priority bucket. Inline drag-to-reorder turned out flaky
            // on web with the Slidable + frosted-glass layout.
            ...checklist.map((t) {
              return t.isHabit
                  ? _HabitCheckCard(
                      todo: t,
                      onComplete: () => onCompleteHabit(t),
                      onTap: () => onEditTodo(t),
                      onDelete: () => onDeleteTodo(t.id!),
                      onDuplicate: () => onDuplicateTodo(t),
                      onFail: () => onFailItem(t),
                      onOpenReorder: () =>
                          _openReorderModal(context, t, checklist),
                    )
                  : _TaskCard(
                      todo: t,
                      onToggle: () => onToggleDone(t),
                      onTap: () => onEditTodo(t),
                      onDelete: () => onDeleteTodo(t.id!),
                      onDuplicate: () => onDuplicateTodo(t),
                      onFail: () => onFailItem(t),
                      onReschedule: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: t.nextDue != null
                              ? parseDate(t.nextDue!)
                              : DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          await onReschedule(t, picked);
                        }
                      },
                      onOpenReorder: () =>
                          _openReorderModal(context, t, checklist),
                    );
            }),

          if (doneTasks.isNotEmpty) ...[
            SizedBox(height: 24),
            _DoneSection(
              done: doneTasks,
              onClearDone: onClearDone,
              onToggle: onToggleDone,
              onEdit: onEditTodo,
              onDelete: (id) => onDeleteTodo(id),
            ),
          ],
        ],
    );
  }
}

// â”€â”€ Section header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: kBrown,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Montserrat')),
        Text(subtitle,
            style: TextStyle(
                color: kBrown.withValues(alpha: 0.5),
                fontSize: 11,
                fontFamily: 'Montserrat')),
      ],
    );
  }
}

// â”€â”€ Day summary callout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// â”€â”€ Time-per-task panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Text shows how many minutes/hours of the day are left per remaining
// task. Bar shows progress through today's checklist (done vs total).
class _TimePerTaskPanel extends StatefulWidget {
  final int remaining; // items still on today's checklist
  final int done;      // items completed today (tasks + habits)
  const _TimePerTaskPanel({required this.remaining, required this.done});

  @override
  State<_TimePerTaskPanel> createState() => _TimePerTaskPanelState();
}

class _TimePerTaskPanelState extends State<_TimePerTaskPanel> {
  static const _prefsKey = 'time_per_task_target'; // stored as "HH:MM"
  // Default target = midnight (00:00) → matches the original behaviour.
  TimeOfDay _target = const TimeOfDay(hour: 0, minute: 0);
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTarget();
    // Update every minute so the time math stays current.
    _ticker = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final parts = raw.split(':');
    if (parts.length != 2) return;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return;
    if (!mounted) return;
    setState(() => _target = TimeOfDay(hour: h, minute: m));
  }

  Future<void> _pickTarget() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _target,
      helpText: 'Countdown ends at',
    );
    if (picked == null || !mounted) return;
    setState(() => _target = picked);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey,
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
  }

  // Resolve _target to the next absolute DateTime: today at HH:MM if it's
  // still in the future, otherwise tomorrow at HH:MM.
  DateTime _targetDateTime() {
    final today = DateTime(_now.year, _now.month, _now.day,
        _target.hour, _target.minute);
    if (!today.isAfter(_now)) {
      return today.add(const Duration(days: 1));
    }
    return today;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.remaining + widget.done;
    if (total == 0) return const SizedBox.shrink();

    final target = _targetDateTime();
    final timeLeft = target.difference(_now);
    final hLeft = timeLeft.inHours;
    final mLeft = timeLeft.inMinutes.remainder(60);

    String label;
    if (widget.remaining == 0) {
      label = 'All done — ${hLeft}h ${mLeft.toString().padLeft(2, '0')}m left until ${_target.format(context)}';
    } else {
      final secsPerTask = timeLeft.inSeconds / widget.remaining;
      if (secsPerTask >= 3600) {
        final hPer = (secsPerTask / 3600).floor();
        label = 'You have ${hLeft}h ${mLeft.toString().padLeft(2, '0')}m '
            '— ~${hPer}h per task';
      } else {
        final mPer = (secsPerTask / 60).round();
        label = 'You have ${hLeft}h ${mLeft.toString().padLeft(2, '0')}m '
            '— ~${mPer}min per task';
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: _pickTarget,
          borderRadius: BorderRadius.circular(14),
          child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: kFrostTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: kBrown),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                          color: kBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  Text(
                    '${widget.done}/$total',
                    style: TextStyle(
                        color: kBrown.withValues(alpha: 0.7),
                        fontSize: 11),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Bar = today's checklist progress (done / total).
              // Tick marks divide the bar into one slot per task so each
              // task is visually represented.
              LayoutBuilder(builder: (_, c) {
                final w = c.maxWidth;
                final pct = total == 0 ? 0.0 : widget.done / total;
                final filledW = w * pct;
                return SizedBox(
                  height: 12,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: kBrown.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: filledW,
                        decoration: BoxDecoration(
                          color: kLeaflitGreen.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      ...List.generate(total - 1, (i) {
                        final x = w * ((i + 1) / total);
                        return Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1.5,
                            color: kBrown.withValues(alpha: 0.55),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _DayCallout extends StatelessWidget {
  final int habitsDone;
  final int habitsTotal;
  final double pct;
  final Color moodAccent;
  const _DayCallout({
    required this.habitsDone,
    required this.habitsTotal,
    required this.pct,
    required this.moodAccent,
  });

  @override
  Widget build(BuildContext context) {
    final color = moodAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: kFrostShadow,
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: kFrostTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's habit score",
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    '$habitsDone / $habitsTotal Â· ${(pct * 100).round()}%',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Stack(children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: kBrown.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// Mood faces + labels live in mood_assets.dart (kMoodColors, kMoodLabels,
// MoodFace). Mood metric stores 1..5 â€” matches the image filenames.

// â”€â”€ Metric card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MetricCard extends StatelessWidget {
  final TrackableMetric metric;
  final Future<void> Function(double) onSetValue;
  final Future<void> Function(TrackableMetric) onUpdate;
  final Future<void> Function() onDelete;

  const _MetricCard({
    required this.metric,
    required this.onSetValue,
    required this.onUpdate,
    required this.onDelete,
  });

  bool get _isMood => metric.name.toLowerCase() == 'mood';
  // Auto-tracked metrics get bumped by completions, never by user input.
  bool get _isAutoTracked {
    final n = metric.name.toLowerCase();
    return n == 'todos done' || n == 'habits done';
  }

  @override
  Widget build(BuildContext context) {
    final t = today();
    final value = metric.history[t];
    final color = Color(metric.colorValue);
    final hasTarget = metric.targetValue != null;

    return GestureDetector(
      onTap: () => _showInputDialog(context),
      child: Container(
        width: 124,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: kFrostShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.all(_isMood ? 8 : 12),
              decoration: BoxDecoration(
                // Every metric card uses the same opaque yellow now â€”
                // no Meh-specific brown override, no border.
                color: kFrostTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isMood
            // Mood card: just the face when logged, "Mood" placeholder when not.
            ? Center(
                child: value != null
                    ? MoodFace(
                        value: value.round().clamp(1, 5), size: 100)
                    : Text(
                        'Mood',
                        style: TextStyle(
                          color: kBrown.withValues(alpha: 0.45),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Montserrat',
                        ),
                      ),
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 4),
            // Centred + auto-sized â€” "1" takes the same space as "1555".
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: value != null
                      ? Text(
                          _formatValue(value),
                          style: TextStyle(
                            color: kBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                            fontFamily: 'Montserrat',
                          ),
                        )
                      : Text(
                          'Tap to log',
                          style: TextStyle(
                              color: kBrown.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontStyle: FontStyle.italic),
                        ),
                ),
              ),
            ),
            // Just the target/unit caption â€” no progress bar.
            Text(
              hasTarget
                  ? 'target ${_formatValue(metric.targetValue!)} ${metric.unit}'
                  : metric.unit,
              style: TextStyle(
                  color: kBrown.withValues(alpha: 0.6), fontSize: 10),
            ),
          ],
        ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatValue(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  Future<void> _showMoodPicker(BuildContext context) async {
    final t = today();
    final existing = metric.history[t]?.round();
    final res = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('How are you feeling?',
            style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              // 5..1 top-to-bottom (Great â†’ Bad).
              final v = 5 - i;
              final selected = existing == v;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, v),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Center(
                          child: AnimatedScale(
                            scale: selected ? 1.0 : 0.92,
                            duration: Duration(milliseconds: 150),
                            child: Opacity(
                              opacity: selected ? 1.0 : 0.85,
                              child: MoodFace(value: v, size: 100),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kMoodLabels[v - 1],
                              style: TextStyle(
                                color: selected
                                    ? kBrown
                                    : kBrown.withValues(alpha: 0.5),
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
                                    color: kMoodColors[v - 1],
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: kLeaflitGreen)),
          ),
        ],
      ),
    );
    if (res != null) await onSetValue(res.toDouble());
  }

  Future<void> _showInputDialog(BuildContext context) async {
    if (_isMood) {
      await _showMoodPicker(context);
      return;
    }
    if (_isAutoTracked) {
      // Auto-tracked metrics aren't user-editable â€” they update from
      // task/habit completions. Quiet snackbar instead of a dialog.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kBrown,
        duration: Duration(seconds: 2),
        content: Text('Auto-tracked from completions'),
      ));
      return;
    }
    final t = today();
    final ctrl = TextEditingController(
        text: metric.history[t]?.toString() ?? '');
    final res = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(
              child: Text("Log ${metric.name}",
                  style: TextStyle(
                      color: kBrown, fontWeight: FontWeight.bold)),
            ),
            // Edit metric (target, name, unit, color, delete).
            IconButton(
              tooltip: 'Edit metric',
              icon: Icon(Icons.edit_outlined,
                  color: kBrown, size: 20),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                Navigator.pop(ctx);
                await _showEditDialog(context);
              },
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            suffixText: metric.unit,
            labelText: 'Value',
            labelStyle: TextStyle(color: kSunsetPetal),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kSunsetPetal)),
          ),
          style: TextStyle(color: kBrown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: kLeaflitGreen)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kSunsetPetal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              Navigator.pop(ctx, v);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res != null) await onSetValue(res);
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final nameCtrl = TextEditingController(text: metric.name);
    final unitCtrl = TextEditingController(text: metric.unit);
    final targetCtrl =
        TextEditingController(text: metric.targetValue?.toString() ?? '');
    final palette = [
      0xFFD94F3A,
      0xFFF4A444,
      0xFFE8873A,
      0xFF5D7B3D,
      0xFF3A6BB0,
      0xFF7B5EA7,
    ];
    int colorIdx = palette.indexOf(metric.colorValue);
    if (colorIdx == -1) colorIdx = 0;

    final action = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: kCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit ${metric.name}',
              style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: kBrown),
                  decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  style: TextStyle(color: kBrown),
                  decoration: InputDecoration(
                      labelText: 'Unit',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(color: kBrown),
                  decoration: InputDecoration(
                      labelText: 'Target value (optional)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(palette.length, (i) {
                    final c = Color(palette[i]);
                    return GestureDetector(
                      onTap: () => set(() => colorIdx = i),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: colorIdx == i ? kBrown : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Text('Delete',
                  style: TextStyle(color: kSunsetPetal)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: kLeaflitGreen)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSunsetPetal,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (action == 'save') {
      metric.name = nameCtrl.text.trim().isEmpty ? metric.name : nameCtrl.text.trim();
      metric.unit = unitCtrl.text.trim();
      metric.targetValue = double.tryParse(targetCtrl.text);
      metric.colorValue = palette[colorIdx];
      await onUpdate(metric);
    } else if (action == 'delete') {
      await onDelete();
    }

    nameCtrl.dispose();
    unitCtrl.dispose();
    targetCtrl.dispose();
  }
}

// â”€â”€ Add metric card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AddMetricCard extends StatelessWidget {
  final Future<void> Function(TrackableMetric m) onAddMetric;
  const _AddMetricCard({required this.onAddMetric});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: kRosebudBlush.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: kBrown.withValues(alpha: 0.25),
              width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: kBrown.withValues(alpha: 0.5)),
              SizedBox(height: 4),
              Text('Add metric',
                  style: TextStyle(
                      color: kBrown.withValues(alpha: 0.6), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final palette = [
      0xFFD94F3A,
      0xFFF4A444,
      0xFFE8873A,
      0xFF5D7B3D,
      0xFF3A6BB0,
      0xFF7B5EA7,
    ];
    int colorIdx = 0;

    final created = await showDialog<TrackableMetric?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: kCream,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New metric',
              style:
                  TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: kBrown),
                  decoration: InputDecoration(
                      labelText: 'Name (e.g. Sleep, Steps)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  style: TextStyle(color: kBrown),
                  decoration: InputDecoration(
                      labelText: 'Unit (kg, L, hrsâ€¦)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(color: kBrown),
                  decoration: InputDecoration(
                      labelText: 'Target value (optional)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(palette.length, (i) {
                    final c = Color(palette[i]);
                    return GestureDetector(
                      onTap: () => set(() => colorIdx = i),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: colorIdx == i ? kBrown : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: kLeaflitGreen)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSunsetPetal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final m = TrackableMetric(
                  name: name,
                  unit: unitCtrl.text.trim(),
                  targetValue: double.tryParse(targetCtrl.text),
                  colorValue: palette[colorIdx],
                );
                Navigator.pop(ctx, m);
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    unitCtrl.dispose();
    targetCtrl.dispose();

    if (created != null) await onAddMetric(created);
  }
}

// â”€â”€ Task card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TaskCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenReorder;
  final VoidCallback? onFail;
  final VoidCallback? onReschedule;

  const _TaskCard({
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenReorder,
    this.onFail,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final dueLabel = _taskDueLabel(todo);
    final overdue = todo.nextDue != null &&
        parseDate(todo.nextDue!).isBefore(parseDate(today()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: kFrostShadow,
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // BackdropFilter sits OUTSIDE the Slidable so the page gradient
        // is what gets blurred â€” the action panes (which appear on swipe)
        // render as solid color blocks on top of the frosted card area.
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Slidable(
            key: ValueKey(todo.id),
            startActionPane: ActionPane(
              motion: DrawerMotion(),
              extentRatio: 0.4,
              children: [
                SlidableAction(
                  onPressed: (_) => onDuplicate(),
                  backgroundColor: kEveningSky,
                  foregroundColor: kBrown,
                  icon: Icons.copy_outlined,
                  label: 'Duplicate',
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12)),
                ),
                SlidableAction(
                  onPressed: (_) => onOpenReorder(),
                  backgroundColor: kGoldenPollen,
                  foregroundColor: kBrown,
                  icon: Icons.swap_vert,
                  label: 'Reorder',
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              extentRatio: onReschedule != null ? 0.4 : 0.2,
              children: [
                if (onReschedule != null)
                  SlidableAction(
                    onPressed: (_) => onReschedule!(),
                    backgroundColor: kGoldenPollen,
                    foregroundColor: kBrown,
                    icon: Icons.event,
                    label: 'Reschedule',
                  ),
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
                leading: Checkbox(
                  value: todo.done,
                  activeColor: kLeaflitGreen,
                  checkColor: Colors.white,
                  side: BorderSide(color: kSunsetPetal),
                  onChanged: (_) => onToggle(),
                ),
                trailing: onFail == null
                    ? null
                    : IconButton(
                        tooltip: 'Skip â€” push to tomorrow',
                        icon: Icon(Icons.close,
                            color: kSunsetPetal, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: onFail,
                      ),
                title: Row(children: [
                  Icon(Icons.flag, size: 14, color: kPriorityColors[todo.priority]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      todo.title,
                      style: TextStyle(
                        color: todo.done ? kBrown.withValues(alpha: 0.35) : kBrown,
                        decoration: todo.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ]),
                subtitle: Row(children: [
                  Text(
                    kPriorityLabels[todo.priority],
                    style: TextStyle(color: kEveningSky, fontSize: 11),
                  ),
                  if (dueLabel != null) ...[
                    SizedBox(width: 6),
                    Icon(Icons.event,
                        size: 11,
                        color: overdue ? kSunsetPetal : kEveningSky),
                    SizedBox(width: 3),
                    Text(
                      dueLabel,
                      style: TextStyle(
                        color: overdue ? kSunsetPetal : kEveningSky,
                        fontSize: 11,
                        fontWeight:
                            overdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// "Due tomorrow", "Overdue 2d", "Due May 9", or null when there's no date.
String? _taskDueLabel(TodoItem t) {
  if (t.nextDue == null) return null;
  final due = parseDate(t.nextDue!);
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  final d0 = DateTime(due.year, due.month, due.day);
  final diff = d0.difference(t0).inDays;
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  if (diff == -1) return 'Overdue 1d';
  if (diff < -1) return 'Overdue ${-diff}d';
  if (diff > 1 && diff <= 6) return 'Due in ${diff}d';
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  return 'Due ${months[due.month - 1]} ${due.day}';
}

// â”€â”€ Habit check card (Todo tab) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _HabitCheckCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onComplete;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenReorder;
  final VoidCallback? onFail;

  const _HabitCheckCard({
    required this.todo,
    required this.onComplete,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenReorder,
    this.onFail,
  });

  @override
  Widget build(BuildContext context) {
    // A non-daily habit is "delayed" if its nextDue is before today AND
    // we're still inside the delay window (snap logic at load drops missed
    // instances after a full interval has passed).
    final delayed = todo.intervalDays > 1 &&
        todo.nextDue != null &&
        parseDate(todo.nextDue!).isBefore(parseDate(today()));
    final accent = delayed ? kSunsetPetal : kLeaflitGreen;

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
            key: ValueKey('habit_${todo.id}'),
            startActionPane: ActionPane(
              motion: DrawerMotion(),
              extentRatio: 0.4,
              children: [
                SlidableAction(
                  onPressed: (_) => onDuplicate(),
                  backgroundColor: kEveningSky,
                  foregroundColor: kBrown,
                  icon: Icons.copy_outlined,
                  label: 'Duplicate',
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12)),
                ),
                SlidableAction(
                  onPressed: (_) => onOpenReorder(),
                  backgroundColor: kGoldenPollen,
                  foregroundColor: kBrown,
                  icon: Icons.swap_vert,
                  label: 'Reorder',
                ),
              ],
            ),
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
                // Habit cards lean on the habit's chosen colour as a
                // wash; no outline.
                color: kFrostTint,
              ),
              child: ListTile(
                onTap: onTap,
                leading: Checkbox(
                  value: false,
                  activeColor: kLeaflitGreen,
                  checkColor: Colors.white,
                  side: BorderSide(color: kLeaflitGreen),
                  onChanged: (_) => onComplete(),
                ),
                trailing: onFail == null
                    ? null
                    : IconButton(
                        tooltip: 'Skip â€” push to tomorrow',
                        icon: Icon(Icons.close,
                            color: kSunsetPetal, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: onFail,
                      ),
                title: Row(children: [
                  Icon(Icons.flag,
                      size: 14, color: kPriorityColors[todo.priority]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      todo.title,
                      style: TextStyle(
                        color: kBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]),
                subtitle: Row(children: [
                  Icon(Icons.repeat, size: 11, color: accent),
                  SizedBox(width: 4),
                  Text(
                    todo.intervalDays == 1
                        ? 'Daily'
                        : 'Every ${todo.intervalDays}d',
                    style: TextStyle(
                      // Daily / interval label is now thin so the title
                      // dominates.
                      color: delayed ? kSunsetPetal : kBrown,
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  if (delayed) ...[
                    SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: kSunsetPetal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kSunsetPetal.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Delayed',
                        style: TextStyle(
                          color: kSunsetPetal,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// â”€â”€ Done section (Todo tab) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DoneSection extends StatelessWidget {
  final List<TodoItem> done;
  final Future<void> Function() onClearDone;
  final Future<void> Function(TodoItem) onToggle;
  final Future<void> Function(TodoItem) onEdit;
  final void Function(int) onDelete;

  const _DoneSection({
    required this.done,
    required this.onClearDone,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kLeaflitGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Done today Â· ${done.length}',
                  style: TextStyle(
                      color: kLeaflitGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              TextButton.icon(
                onPressed: onClearDone,
                icon: Icon(Icons.delete_sweep_outlined,
                    size: 16, color: kSunsetPetal),
                label: Text('Clear all',
                    style:
                        TextStyle(color: kSunsetPetal, fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...done.map((t) => _TaskCard(
                todo: t,
                onToggle: () => onToggle(t),
                onTap: () => onEdit(t),
                onDelete: () => onDelete(t.id!),
                onDuplicate: () {},
                onOpenReorder: () {},
                // Done tasks don't need the X / reschedule affordances.
                onFail: null,
                onReschedule: null,
              )),
        ],
      ),
    );
  }
}
