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

  const HabitsTab({
    super.key,
    required this.todos,
    required this.metrics,
    required this.completions,
    required this.onEditTodo,
    required this.onDeleteTodo,
  });

  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  late DateTime _month;
  bool _listOpen = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

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
    if (v == null) return const Color(0xFF1A3F6F); // navy default
    final idx = (v.round() - 1).clamp(0, 4);
    return kMoodColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          // Month grid
          _MonthGrid(
            habits: habits,
            month: _month,
            onPrev: () =>
                setState(() => _month = DateTime(_month.year, _month.month - 1)),
            onNext: () =>
                setState(() => _month = DateTime(_month.year, _month.month + 1)),
            wasCompleted: _wasCompleted,
            moodTintFor: _moodTintFor,
          ),
          const SizedBox(height: 18),

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
                  const SizedBox(width: 8),
                  Text('Manage habits · ${habits.length}',
                      style: const TextStyle(
                          color: kSunsetPetal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          if (_listOpen) ...[
            const SizedBox(height: 8),
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
          ],
        ],
    );
  }
}

// ── Month grid ──────────────────────────────────────────────────
class _MonthGrid extends StatelessWidget {
  final List<TodoItem> habits;
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool Function(int habitId, DateTime day) wasCompleted;
  final Color Function(DateTime day) moodTintFor;

  const _MonthGrid({
    required this.habits,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.wasCompleted,
    required this.moodTintFor,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final canGoForward =
        month.isBefore(DateTime(now.year, now.month));

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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            color: kFrostTint.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kRosebudBlush, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left, color: kBrown),
                visualDensity: VisualDensity.compact,
              ),
              Text(DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(
                      color: kBrown,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              IconButton(
                onPressed: canGoForward ? onNext : null,
                icon: Icon(Icons.chevron_right,
                    color: canGoForward
                        ? kBrown
                        : kBrown.withValues(alpha: 0.2)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Add a habit to start tracking.',
                    style: TextStyle(color: kBrown.withValues(alpha: 0.4))),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _gridBody(daysInMonth, now),
            ),
        ],
      ),
        ),
      ),
      ),
    );
  }

  Widget _gridBody(int daysInMonth, DateTime now) {
    const labelW = 110.0;
    const cellW = 18.0;
    const cellH = 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-number header row — must use the same horizontal margin as
        // the cells below so each label sits over its column.
        Row(
          children: [
            const SizedBox(width: labelW),
            ...List.generate(daysInMonth, (i) {
              final day = i + 1;
              final isToday = month.year == now.year &&
                  month.month == now.month &&
                  day == now.day;
              return Container(
                width: cellW,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday
                        ? kSunsetPetal
                        : kBrown.withValues(alpha: 0.45),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
        // Habit rows
        ...habits.map((h) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                SizedBox(
                  width: labelW,
                  child: Text(
                    h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: kBrown,
                        fontSize: 11,
                        fontFamily: 'Montserrat'),
                  ),
                ),
                ...List.generate(daysInMonth, (i) {
                  final day = i + 1;
                  final thisDay = DateTime(month.year, month.month, day);
                  final isFuture = thisDay.isAfter(now);
                  final done = !isFuture && wasCompleted(h.id!, thisDay);
                  return Container(
                    width: cellW,
                    height: cellH,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: isFuture
                          ? Colors.transparent
                          : done
                              ? moodTintFor(thisDay)
                              : kBrown.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Habit manage card ───────────────────────────────────────────
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
                color: Color(todo.colorValue).withValues(alpha: 0.4),
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
                const SizedBox(width: 6),
                Expanded(
                  child: Text(todo.title,
                      style: const TextStyle(
                          color: kBrown, fontWeight: FontWeight.bold)),
                ),
              ]),
              subtitle: Text(
                todo.intervalDays == 1
                    ? 'Daily'
                    : 'Every ${todo.intervalDays} days',
                style: const TextStyle(color: kEveningSky, fontSize: 11),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${todo.completionCount}',
                      style: const TextStyle(
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
