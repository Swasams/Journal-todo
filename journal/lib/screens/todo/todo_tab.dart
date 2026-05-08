// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
              // Deep burnt-orange surface — same family as the AppBar /
              // gradient top, so the sheet feels anchored to the page.
              color: const Color(0xFFE8753A).withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: kBrown.withValues(alpha: 0.25)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kBrown.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_vert,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Reorder ${widget.priorityLabel}'
                          '${widget.overdueGroup ? " · overdue" : ""}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                            color: kFrostTint.withValues(alpha: 0.7),
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
                              const SizedBox(width: 6),
                              Icon(Icons.flag,
                                  size: 14,
                                  color: kPriorityColors[t.priority]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: const TextStyle(color: kBrown),
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
                          child: const Text('Cancel',
                              style: TextStyle(color: kLeaflitGreen)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSunsetPetal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(context, _items),
                          child: const Text('Save'),
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
  });

  // Sort key for the checklist: priority asc (high → low), then user-set
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
  // float to the top — within that group, sort by priority then by how
  // late they are. The remaining items sort by priority + manual order.
  List<TodoItem> get _checklist {
    final t0 = parseDate(today());
    bool overdue(TodoItem x) {
      if (x.nextDue == null) return false;
      return parseDate(x.nextDue!).isBefore(t0);
    }

    final items = todos.where((t) {
      if (t.isHabit) return isDue(t);
      return !t.done;
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
        duration: const Duration(seconds: 2),
        content: Text(
          'Only one ${kPriorityLabels[pivot.priority]} '
          '${pivotOverdue ? "overdue " : ""}item — nothing to reorder.',
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
          // ── Daily metrics row ──────────────────────────────
          _SectionHeader(title: 'Daily metrics', subtitle: today()),
          const SizedBox(height: 8),
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

          const SizedBox(height: 18),

          // ── Today summary callout ──────────────────────────
          _DayCallout(
            habitsDone: habitsCompletedToday,
            habitsTotal: totalHabits,
            pct: habitPct,
            moodAccent: _todayMoodColor(),
          ),

          const SizedBox(height: 18),

          // ── Today's checklist ──────────────────────────────
          _SectionHeader(
            title: "Today's checklist",
            subtitle: '${checklist.length} to go',
          ),
          const SizedBox(height: 8),
          if (checklist.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nothing left for today. Nice. 🌅',
                  style: TextStyle(color: kBrown.withValues(alpha: 0.45)),
                ),
              ),
            )
          else
            // Plain list — reorder happens through the per-item Reorder
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
                      onOpenReorder: () =>
                          _openReorderModal(context, t, checklist),
                    )
                  : _TaskCard(
                      todo: t,
                      onToggle: () => onToggleDone(t),
                      onTap: () => onEditTodo(t),
                      onDelete: () => onDeleteTodo(t.id!),
                      onDuplicate: () => onDuplicateTodo(t),
                      onOpenReorder: () =>
                          _openReorderModal(context, t, checklist),
                    );
            }),

          if (doneTasks.isNotEmpty) ...[
            const SizedBox(height: 24),
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

// ── Section header ──────────────────────────────────────────────
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
            style: const TextStyle(
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

// ── Day summary callout ─────────────────────────────────────────
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
            color: kFrostTint.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
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
                    '$habitsDone / $habitsTotal · ${(pct * 100).round()}%',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
// MoodFace). Mood metric stores 1..5 — matches the image filenames.

// ── Metric card ─────────────────────────────────────────────────
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
                // Mood card flips to brown only when the value is Meh —
                // the olive face needs higher contrast. All other moods
                // (and the empty state) keep the standard yellow frost.
                color: (_isMood && value != null && value.round() == 3)
                    ? kMoodFrostBrown.withValues(alpha: 0.55)
                    : kFrostTint.withValues(alpha: 0.7),
                border:
                    Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
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
            const SizedBox(height: 4),
            if (value != null)
              Text(
                _formatValue(value),
                style: const TextStyle(
                  color: kBrown,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'Montserrat',
                ),
              )
            else
              Text(
                'Tap to log',
                style: TextStyle(
                    color: kBrown.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            const Spacer(),
            // Just the target/unit caption — no progress bar.
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
        title: const Text('How are you feeling?',
            style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              // 5..1 top-to-bottom (Great → Bad).
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
                            duration: const Duration(milliseconds: 150),
                            child: Opacity(
                              opacity: selected ? 1.0 : 0.85,
                              child: MoodFace(value: v, size: 100),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                const Text('Cancel', style: TextStyle(color: kLeaflitGreen)),
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
                  style: const TextStyle(
                      color: kBrown, fontWeight: FontWeight.bold)),
            ),
            // Edit metric (target, name, unit, color, delete).
            IconButton(
              tooltip: 'Edit metric',
              icon: const Icon(Icons.edit_outlined,
                  color: kBrown, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
            labelStyle: const TextStyle(color: kSunsetPetal),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: kSunsetPetal)),
          ),
          style: const TextStyle(color: kBrown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
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
            child: const Text('Save'),
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
              style: const TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: kBrown),
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  style: const TextStyle(color: kBrown),
                  decoration: const InputDecoration(
                      labelText: 'Unit',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(color: kBrown),
                  decoration: const InputDecoration(
                      labelText: 'Target value (optional)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                const SizedBox(height: 12),
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
              child: const Text('Delete',
                  style: TextStyle(color: kSunsetPetal)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: kLeaflitGreen)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSunsetPetal,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save'),
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

// ── Add metric card ─────────────────────────────────────────────
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
              const SizedBox(height: 4),
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
          title: const Text('New metric',
              style:
                  TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: kBrown),
                  decoration: const InputDecoration(
                      labelText: 'Name (e.g. Sleep, Steps)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  style: const TextStyle(color: kBrown),
                  decoration: const InputDecoration(
                      labelText: 'Unit (kg, L, hrs…)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(color: kBrown),
                  decoration: const InputDecoration(
                      labelText: 'Target value (optional)',
                      labelStyle: TextStyle(color: kSunsetPetal)),
                ),
                const SizedBox(height: 12),
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
              child: const Text('Cancel',
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
              child: const Text('Add'),
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

// ── Task card ───────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenReorder;

  const _TaskCard({
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenReorder,
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
        // is what gets blurred — the action panes (which appear on swipe)
        // render as solid color blocks on top of the frosted card area.
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Slidable(
            key: ValueKey(todo.id),
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
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
              motion: const DrawerMotion(),
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
                color: kFrostTint.withValues(alpha: 0.7),
              ),
              child: ListTile(
                onTap: onTap,
                leading: Checkbox(
                  value: todo.done,
                  activeColor: kLeaflitGreen,
                  checkColor: Colors.white,
                  side: const BorderSide(color: kSunsetPetal),
                  onChanged: (_) => onToggle(),
                ),
                title: Row(children: [
                  Icon(Icons.flag, size: 14, color: kPriorityColors[todo.priority]),
                  const SizedBox(width: 6),
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
                    style: const TextStyle(color: kEveningSky, fontSize: 11),
                  ),
                  if (dueLabel != null) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.event,
                        size: 11,
                        color: overdue ? kSunsetPetal : kEveningSky),
                    const SizedBox(width: 3),
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

// ── Habit check card (Todo tab) ─────────────────────────────────
class _HabitCheckCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onComplete;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenReorder;

  const _HabitCheckCard({
    required this.todo,
    required this.onComplete,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenReorder,
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
              motion: const DrawerMotion(),
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
              motion: const DrawerMotion(),
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
                color: Color(todo.colorValue).withValues(alpha: 0.4),
              ),
              child: ListTile(
                onTap: onTap,
                leading: Checkbox(
                  value: false,
                  activeColor: kLeaflitGreen,
                  checkColor: Colors.white,
                  side: const BorderSide(color: kLeaflitGreen),
                  onChanged: (_) => onComplete(),
                ),
                title: Row(children: [
                  Icon(Icons.flag, size: 14, color: kPriorityColors[todo.priority]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      todo.title,
                      style: const TextStyle(
                        // Title carries the visual weight now.
                        color: kBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]),
                subtitle: Row(children: [
                  Icon(Icons.repeat, size: 11, color: accent),
                  const SizedBox(width: 4),
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: kSunsetPetal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kSunsetPetal.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
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

// ── Done section (Todo tab) ─────────────────────────────────────
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
              Text('Done today · ${done.length}',
                  style: const TextStyle(
                      color: kLeaflitGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              TextButton.icon(
                onPressed: onClearDone,
                icon: const Icon(Icons.delete_sweep_outlined,
                    size: 16, color: kSunsetPetal),
                label: const Text('Clear all',
                    style:
                        TextStyle(color: kSunsetPetal, fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...done.map((t) => _TaskCard(
                todo: t,
                onToggle: () => onToggle(t),
                onTap: () => onEdit(t),
                onDelete: () => onDelete(t.id!),
                onDuplicate: () {},
                onOpenReorder: () {},
              )),
        ],
      ),
    );
  }
}
