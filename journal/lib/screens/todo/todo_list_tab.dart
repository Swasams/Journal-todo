// "All todos" tab â€” every task grouped by its due date with collapsible
// sections, plus a "No due date" group at the bottom. Habits never show
// here; this is purely the task list.

// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../models/todo_item.dart';
import 'todo_theme.dart';

class TodoListTab extends StatefulWidget {
  final List<TodoItem> todos;
  final Future<void> Function(TodoItem) onToggleDone;
  final Future<void> Function(TodoItem) onEditTodo;
  final Future<void> Function(int) onDeleteTodo;
  final Future<void> Function(TodoItem) onDuplicateTodo;
  final Future<void> Function(TodoItem) onFailItem;
  final Future<void> Function(TodoItem, DateTime?) onReschedule;

  const TodoListTab({
    super.key,
    required this.todos,
    required this.onToggleDone,
    required this.onEditTodo,
    required this.onDeleteTodo,
    required this.onDuplicateTodo,
    required this.onFailItem,
    required this.onReschedule,
  });

  @override
  State<TodoListTab> createState() => _TodoListTabState();
}

class _TodoListTabState extends State<TodoListTab> {
  // Tracks which date sections are collapsed; default open.
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    // Tasks only â€” habits live on Today + Habits tabs.
    final tasks = widget.todos.where((t) => !t.isHabit && !t.done).toList();

    // Bucket by date string (or `__none__` for missing).
    final buckets = <String, List<TodoItem>>{};
    for (final t in tasks) {
      final key = t.nextDue ?? '__none__';
      buckets.putIfAbsent(key, () => <TodoItem>[]).add(t);
    }

    // Sort each bucket by priority then order.
    for (final list in buckets.values) {
      list.sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        if (p != 0) return p;
        return a.order.compareTo(b.order);
      });
    }

    // Order date keys ascending; '__none__' sinks to bottom.
    final dateKeys = buckets.keys.where((k) => k != '__none__').toList()
      ..sort();
    if (buckets.containsKey('__none__')) dateKeys.add('__none__');

    if (dateKeys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No todos yet.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: kBrown.withValues(alpha: 0.55), fontSize: 16),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        for (final key in dateKeys)
          _DateGroup(
            label: _labelForKey(key),
            count: buckets[key]!.length,
            collapsed: _collapsed.contains(key),
            onToggle: () => setState(() {
              if (_collapsed.contains(key)) {
                _collapsed.remove(key);
              } else {
                _collapsed.add(key);
              }
            }),
            children: [
              for (final t in buckets[key]!)
                _ListTaskCard(
                  todo: t,
                  onToggle: () => widget.onToggleDone(t),
                  onTap: () => widget.onEditTodo(t),
                  onDelete: () => widget.onDeleteTodo(t.id!),
                  onDuplicate: () => widget.onDuplicateTodo(t),
                  onFail: () => widget.onFailItem(t),
                  onReschedule: () async {
                    final picked = await _pickDate(context, t.nextDue);
                    if (picked != null) {
                      await widget.onReschedule(t, picked);
                    }
                  },
                ),
            ],
          ),
      ],
    );
  }

  String _labelForKey(String key) {
    if (key == '__none__') return 'No due date';
    final d = parseDate(key);
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(t0).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < -1) return 'Overdue Â· ${DateFormat('EEE, MMM d').format(d)}';
    return DateFormat('EEE, MMM d').format(d);
  }

  Future<DateTime?> _pickDate(BuildContext ctx, String? current) async {
    final now = DateTime.now();
    final initial = current != null ? parseDate(current) : now;
    return showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: now.subtract(Duration(days: 365)),
      lastDate: now.add(Duration(days: 365 * 3)),
    );
  }
}

// â”€â”€ Date group (collapsible) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DateGroup extends StatelessWidget {
  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _DateGroup({
    required this.label,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: kFrostTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          collapsed
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_down,
                          color: kBrown),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(label,
                            style: TextStyle(
                                color: kBrown,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      Text('$count',
                          style: TextStyle(
                              color: kBrown.withValues(alpha: 0.55),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!collapsed) ...[
            SizedBox(height: 8),
            ...children,
          ],
        ],
      ),
    );
  }
}

// â”€â”€ Task card on the all-todos list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Slimmer than the dashboard variant â€” no checkbox-fill animation,
// no priority flag inline (priority shown via left border instead),
// swipe LEFT to reschedule + delete.
class _ListTaskCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onFail;
  final VoidCallback onReschedule;

  const _ListTaskCard({
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onFail,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Slidable(
            key: ValueKey('list_${todo.id}'),
            startActionPane: ActionPane(
              motion: DrawerMotion(),
              extentRatio: 0.2,
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
              ],
            ),
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              extentRatio: 0.4,
              children: [
                SlidableAction(
                  onPressed: (_) => onReschedule(),
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
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: kFrostTint,
                border: Border(
                  left: BorderSide(
                      color: kPriorityColors[todo.priority], width: 4),
                ),
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
                trailing: IconButton(
                  tooltip: 'Skip â€” push to tomorrow',
                  icon: Icon(Icons.close,
                      color: kSunsetPetal, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: onFail,
                ),
                title: Text(todo.title,
                    style: TextStyle(color: kBrown)),
                subtitle: Text(
                  '${kPriorityLabels[todo.priority]} priority',
                  style: TextStyle(color: kEveningSky, fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
