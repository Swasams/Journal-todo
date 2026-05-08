import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../db/database_helper.dart';
import '../models/todo_item.dart';
import '../models/trackable_metric.dart';
import 'todo/todo_theme.dart';
import 'todo/todo_tab.dart';
import 'todo/todo_list_tab.dart';
import 'todo/habits_tab.dart';
import 'todo/stats_tab.dart';
import 'todo/focus_timer.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with TickerProviderStateMixin {
  List<TodoItem> _todos = [];
  List<TrackableMetric> _metrics = [];
  Map<String, List<int>> _habitCompletions = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll().then((_) => _checkDayRollover());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final todos = await DatabaseHelper.getAllTodos();
    final metrics = await DatabaseHelper.getAllMetrics();
    final completions = await DatabaseHelper.getHabitCompletions();
    setState(() {
      _todos = todos;
      _metrics = metrics;
      _habitCompletions = completions;
    });
  }

  // â”€â”€ Day rollover â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _checkDayRollover() async {
    final lastOpen = await DatabaseHelper.getLastOpenDate();
    final t = today();
    if (lastOpen == t) return;

    final doneTasks = _todos.where((x) => !x.isHabit && x.done).length;
    if (doneTasks > 0) {
      await DatabaseHelper.incrementDailyStat(lastOpen ?? t, doneTasks);
    }
    await DatabaseHelper.clearDoneTodos();
    await _snapHabitDueDates();
    await DatabaseHelper.setLastOpenDate(t);
    await _loadAll();

    if (doneTasks > 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showYesterdayPopup(lastOpen ?? 'yesterday', doneTasks);
      });
    }
  }

  // Snap habit nextDue forward when it falls outside the delay window.
  // - Daily habits: any past nextDue â†’ today.
  // - Non-daily: if (today - nextDue) >= intervalDays, the missed instance
  //   is dropped and a fresh one is treated as due today.
  Future<void> _snapHabitDueDates() async {
    final t = parseDate(today());
    var changed = false;
    final list = await DatabaseHelper.getAllTodos();
    for (final h in list) {
      if (!h.isHabit || h.nextDue == null) continue;
      final due = parseDate(h.nextDue!);
      final daysLate = t.difference(due).inDays;
      if (daysLate <= 0) continue;
      if (h.intervalDays <= 1 || daysLate >= h.intervalDays) {
        h.nextDue = today();
        changed = true;
      }
    }
    if (changed) await DatabaseHelper.bulkUpdateTodos(list);
  }

  void _showYesterdayPopup(String date, int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Yesterday\'s wrap-up',
            style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 56, fontWeight: FontWeight.bold, color: kLeaflitGreen)),
            Text('task${count == 1 ? '' : 's'} completed on $date',
                style: TextStyle(color: kBrown.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kSunsetPetal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: Text('Nice!'),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Todo / habit mutations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // Bumps an auto-tracked metric (matched by name, case-insensitive)
  // by `delta` for today. Negative deltas decrement; clamped to >= 0.
  Future<void> _bumpAutoMetric(String name, int delta) async {
    final lc = name.toLowerCase();
    for (final m in _metrics) {
      if (m.name.toLowerCase() != lc) continue;
      final cur = m.history[today()] ?? 0.0;
      final next = (cur + delta).clamp(0, 9999).toDouble();
      await DatabaseHelper.setMetricValue(m.id!, today(), next);
      return;
    }
  }

  Future<void> _toggleDone(TodoItem t) async {
    final wasDone = t.done;
    t.done = !t.done;
    if (t.done) {
      await DatabaseHelper.incrementDailyStat(today(), 1);
      await _bumpAutoMetric('Todos Done', 1);
    } else if (wasDone) {
      await _bumpAutoMetric('Todos Done', -1);
    }
    await DatabaseHelper.updateTodo(t);
    await _loadAll();
  }

  Future<void> _completeHabit(TodoItem t) async {
    // Always advance from today â€” so a delayed every-2-days habit completed
    // today shows up again two days from now, not two days from the missed
    // due date.
    final from = parseDate(today());
    t.nextDue = formatDate(from.add(Duration(days: t.intervalDays)));
    t.completionCount++;
    await DatabaseHelper.recordHabitCompletion(t.id!, today());
    await DatabaseHelper.incrementDailyStat(today(), 1);
    await _bumpAutoMetric('Habits Done', 1);
    await DatabaseHelper.updateTodo(t);
    await _loadAll();
  }

  Future<void> _deleteTodo(int id) async {
    await DatabaseHelper.deleteTodo(id);
    await _loadAll();
  }

  Future<void> _duplicateTodo(TodoItem t) async {
    await DatabaseHelper.insertTodo(TodoItem(
      title: t.title,
      priority: t.priority,
      isHabit: t.isHabit,
      intervalDays: t.intervalDays,
      nextDue: t.nextDue,
    ));
    await _loadAll();
  }

  Future<void> _resetHabitsToDefaults() async {
    await DatabaseHelper.resetHabitsToDefaults();
    await _loadAll();
  }

  Future<void> _clearAllDone() async {
    await DatabaseHelper.clearDoneTodos();
    await _loadAll();
  }

  // Skip an item â€” pushes it to tomorrow without recording a completion.
  // Daily habit X'd â†’ instance dropped, next instance is tomorrow.
  // Non-daily habit X'd â†’ next instance moved to tomorrow.
  // Task X'd â†’ due date moved to tomorrow.
  Future<void> _failItem(TodoItem t) async {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    t.nextDue = formatDate(tomorrow);
    await DatabaseHelper.updateTodo(t);
    await _loadAll();
  }

  // Reschedule a task to a specific date (or clear it). Only used for
  // tasks â€” habits manage their own nextDue via interval logic.
  Future<void> _rescheduleItem(TodoItem t, DateTime? newDate) async {
    t.nextDue = newDate != null ? formatDate(newDate) : null;
    await DatabaseHelper.updateTodo(t);
    await _loadAll();
  }

  // Persist a new order for the checklist. The caller has already
  // validated that priorities are still non-decreasing.
  Future<void> _reorderChecklist(List<TodoItem> reordered) async {
    // Rewrite `order` for each moved item by its new position.
    for (var i = 0; i < reordered.length; i++) {
      reordered[i].order = i;
    }
    // Merge back into the full todo list (others keep their state).
    final full = [..._todos];
    for (final r in reordered) {
      final idx = full.indexWhere((t) => t.id == r.id);
      if (idx != -1) full[idx] = r;
    }
    await DatabaseHelper.bulkUpdateTodos(full);
    await _loadAll();
  }

  // â”€â”€ Metric mutations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _setMetricValue(int metricId, double value) async {
    await DatabaseHelper.setMetricValue(metricId, today(), value);
    await _loadAll();
  }

  Future<void> _deleteMetric(int id) async {
    await DatabaseHelper.deleteMetric(id);
    await _loadAll();
  }

  Future<void> _addMetric(TrackableMetric m) async {
    await DatabaseHelper.insertMetric(m);
    await _loadAll();
  }

  Future<void> _updateMetric(TrackableMetric m) async {
    await DatabaseHelper.updateMetric(m);
    await _loadAll();
  }

  // â”€â”€ Add / edit dialogs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showAddDialog() async {
    // Habits tab is now index 2 (Today=0, Todo=1, Habits=2, Stats=3).
    final isHabitsTab = _tabController.index == 2;
    final titleCtrl = TextEditingController();
    final intervalCtrl = TextEditingController(text: '1');
    int selectedPriority = 1;
    bool isHabit = isHabitsTab;
    int selectedColor = kHabitColorPalette.first;
    // New tasks default to a today due date â€” user can clear it on the
    // dialog if they want a date-less task.
    final now = DateTime.now();
    DateTime? selectedDueDate = DateTime(now.year, now.month, now.day);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _itemDialog(
          ctx: ctx,
          titleCtrl: titleCtrl,
          intervalCtrl: intervalCtrl,
          selectedPriority: selectedPriority,
          isHabit: isHabit,
          isEdit: false,
          selectedDueDate: selectedDueDate,
          selectedColor: selectedColor,
          onPriorityChanged: (v) => set(() => selectedPriority = v),
          onHabitChanged: (v) => set(() => isHabit = v),
          onDueDateChanged: (v) => set(() => selectedDueDate = v),
          onColorChanged: (v) => set(() => selectedColor = v),
          onConfirm: () async {
            final text = titleCtrl.text.trim();
            if (text.isEmpty) return;
            final days = (int.tryParse(intervalCtrl.text) ?? 1).clamp(1, 365);
            await DatabaseHelper.insertTodo(TodoItem(
              title: text,
              priority: selectedPriority,
              isHabit: isHabit,
              intervalDays: days,
              nextDue: isHabit
                  ? today()
                  : (selectedDueDate != null
                      ? formatDate(selectedDueDate!)
                      : null),
              colorValue: selectedColor,
            ));
            titleCtrl.clear();
            intervalCtrl.text = '1';
            await _loadAll();
            set(() {});
          },
        ),
      ),
    );
    titleCtrl.dispose();
    intervalCtrl.dispose();
  }

  Future<void> _showEditDialog(TodoItem t) async {
    final titleCtrl = TextEditingController(text: t.title);
    final intervalCtrl = TextEditingController(text: t.intervalDays.toString());
    int selectedPriority = t.priority;
    bool isHabit = t.isHabit;
    int selectedColor = t.colorValue;
    DateTime? selectedDueDate = (!t.isHabit && t.nextDue != null)
        ? parseDate(t.nextDue!)
        : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _itemDialog(
          ctx: ctx,
          titleCtrl: titleCtrl,
          intervalCtrl: intervalCtrl,
          selectedPriority: selectedPriority,
          isHabit: isHabit,
          isEdit: true,
          selectedDueDate: selectedDueDate,
          selectedColor: selectedColor,
          onPriorityChanged: (v) => set(() => selectedPriority = v),
          onHabitChanged: (v) => set(() => isHabit = v),
          onDueDateChanged: (v) => set(() => selectedDueDate = v),
          onColorChanged: (v) => set(() => selectedColor = v),
          onConfirm: () async {
            final text = titleCtrl.text.trim();
            if (text.isEmpty) return;
            t.title = text;
            t.priority = selectedPriority;
            t.isHabit = isHabit;
            t.intervalDays = (int.tryParse(intervalCtrl.text) ?? 1).clamp(1, 365);
            t.colorValue = selectedColor;
            if (isHabit && t.nextDue == null) t.nextDue = today();
            if (!isHabit) {
              t.nextDue = selectedDueDate != null
                  ? formatDate(selectedDueDate!)
                  : null;
            }
            await DatabaseHelper.updateTodo(t);
            if (mounted) {
              await _loadAll();
              if (mounted) Navigator.pop(context);
            }
          },
          confirmLabel: 'Save',
        ),
      ),
    );
    titleCtrl.dispose();
    intervalCtrl.dispose();
  }

  // Open the HSV colour picker. Returns the picked colour as ARGB int,
  // or null if cancelled.
  Future<int?> _pickHabitColor(BuildContext ctx, Color current) async {
    var picked = current;
    final saved = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pick a habit colour',
            style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child:
                Text('Cancel', style: TextStyle(color: kLeaflitGreen)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kSunsetPetal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Use'),
          ),
        ],
      ),
    );
    if (saved != true) return null;
    return picked.toARGB32();
  }

  // Friendly label for the due-date button.
  String _humanDueDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pick = DateTime(d.year, d.month, d.day);
    final diff = pick.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff <= 6) return 'In $diff days';
    if (diff < -1 && diff >= -6) return '${-diff} days ago';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Widget _itemDialog({
    required BuildContext ctx,
    required TextEditingController titleCtrl,
    required TextEditingController intervalCtrl,
    required int selectedPriority,
    required bool isHabit,
    required bool isEdit,
    required DateTime? selectedDueDate,
    required int selectedColor,
    required void Function(int) onPriorityChanged,
    required void Function(bool) onHabitChanged,
    required void Function(DateTime?) onDueDateChanged,
    required void Function(int) onColorChanged,
    required Future<void> Function() onConfirm,
    String confirmLabel = 'Add',
  }) {
    return AlertDialog(
      backgroundColor: kCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEdit ? 'Edit Item' : 'New Item',
          style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Task')),
                  ButtonSegment(value: true, label: Text('Habit')),
                ],
                selected: {isHabit},
                onSelectionChanged: (s) => onHabitChanged(s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? kSunsetPetal : Colors.white),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? Colors.white : kBrown),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: TextStyle(color: kBrown),
              decoration: InputDecoration(
                labelText: isHabit ? 'Habit name' : 'Task name',
                labelStyle: TextStyle(color: kSunsetPetal),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kSunsetPetal)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
              ),
            ),
            if (!isHabit) ...[
              SizedBox(height: 16),
              Row(children: [
                Text('Due',
                    style: TextStyle(color: kBrown, fontSize: 14)),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.calendar_today,
                        size: 14, color: kSunsetPetal),
                    label: Text(
                      selectedDueDate == null
                          ? 'No due date'
                          : _humanDueDate(selectedDueDate),
                      style: TextStyle(
                        color: selectedDueDate == null
                            ? kBrown.withValues(alpha: 0.5)
                            : kBrown,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: kBrown.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDueDate ?? now,
                        firstDate: now.subtract(Duration(days: 365)),
                        lastDate: now.add(Duration(days: 365 * 3)),
                      );
                      if (picked != null) onDueDateChanged(picked);
                    },
                  ),
                ),
                if (selectedDueDate != null)
                  IconButton(
                    icon: Icon(Icons.clear,
                        size: 18, color: kSunsetPetal),
                    tooltip: 'Clear due date',
                    onPressed: () => onDueDateChanged(null),
                  ),
              ]),
            ],
            if (isHabit) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Colour',
                      style: TextStyle(color: kBrown, fontSize: 14)),
                  SizedBox(width: 12),
                  // Current colour swatch + button to open the picker.
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickHabitColor(
                          ctx, Color(selectedColor));
                      if (picked != null) onColorChanged(picked);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(selectedColor),
                        border: Border.all(
                            color: kBrown.withValues(alpha: 0.5),
                            width: 1.5),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await _pickHabitColor(
                          ctx, Color(selectedColor));
                      if (picked != null) onColorChanged(picked);
                    },
                    icon: Icon(Icons.colorize,
                        size: 16, color: kSunsetPetal),
                    label: Text('Pick',
                        style: TextStyle(color: kSunsetPetal)),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(children: [
                Text('Repeat every',
                    style: TextStyle(color: kBrown, fontSize: 14)),
                SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: intervalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kBrown, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: kSunsetPetal)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text('day(s)', style: TextStyle(color: kBrown, fontSize: 14)),
              ]),
              SizedBox(height: 4),
              Text('1 = daily Â· 7 = weekly',
                  style: TextStyle(color: kBrown.withValues(alpha: 0.45), fontSize: 11)),
            ],
            SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: selectedPriority,
              dropdownColor: kCream,
              style: TextStyle(color: kBrown),
              decoration: InputDecoration(
                labelText: 'Priority',
                labelStyle: TextStyle(color: kSunsetPetal),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
              ),
              items: List.generate(
                3,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Row(children: [
                    Icon(Icons.flag, size: 16, color: kPriorityColors[i]),
                    SizedBox(width: 8),
                    Text(kPriorityLabels[i]),
                  ]),
                ),
              ),
              onChanged: (v) => onPriorityChanged(v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: TextStyle(color: kLeaflitGreen)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kSunsetPetal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onConfirm,
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  // â”€â”€ Focus timer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _openFocusTimer() {
    // Pool = active tasks (not done) + due habits.
    final pool = _todos.where((t) {
      if (t.isHabit) return isDue(t);
      return !t.done;
    }).toList();

    Future<void> handleComplete(TodoItem item) {
      return item.isHabit ? _completeHabit(item) : _toggleDone(item);
    }

    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FocusTimer(
        pendingTasks: pool,
        onComplete: handleComplete,
      ),
    ));
  }


  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: kMorningTop,
        foregroundColor: Colors.white,
        title: Text('Todo & Habits',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // âš ï¸ DEV-only panel-tint picker. Strip with the rest of the
          // dev tooling once a final hex is chosen.
          IconButton(
            tooltip: 'Focus timer',
            icon: Icon(Icons.timer_outlined),
            onPressed: _openFocusTimer,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kMorningTop, kGoldenPollen],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BrowserTabIndicator(),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: kBrown,
              unselectedLabelColor: Colors.white,
              labelStyle: TextStyle(
                  fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
              unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal, fontFamily: 'Montserrat'),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'Todo'),
                Tab(text: 'Habits'),
                Tab(text: 'Stats'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kMorningGradient),
        child: TabBarView(
          controller: _tabController,
          children: [
          TodoTab(
            todos: _todos,
            metrics: _metrics,
            onSetMetricValue: _setMetricValue,
            onAddMetric: _addMetric,
            onUpdateMetric: _updateMetric,
            onDeleteMetric: _deleteMetric,
            onCompleteHabit: _completeHabit,
            onToggleDone: _toggleDone,
            onEditTodo: _showEditDialog,
            onDeleteTodo: _deleteTodo,
            onDuplicateTodo: _duplicateTodo,
            onClearDone: _clearAllDone,
            onReorderChecklist: _reorderChecklist,
            onFailItem: _failItem,
            onReschedule: _rescheduleItem,
          ),
          TodoListTab(
            todos: _todos,
            onToggleDone: _toggleDone,
            onEditTodo: _showEditDialog,
            onDeleteTodo: _deleteTodo,
            onDuplicateTodo: _duplicateTodo,
            onFailItem: _failItem,
            onReschedule: _rescheduleItem,
          ),
          HabitsTab(
            todos: _todos,
            metrics: _metrics,
            completions: _habitCompletions,
            onEditTodo: _showEditDialog,
            onDeleteTodo: _deleteTodo,
            onResetToDefaults: _resetHabitsToDefaults,
          ),
          StatsTab(
            todos: _todos,
            metrics: _metrics,
            completions: _habitCompletions,
            onUpdateMetric: _updateMetric,
            onDeleteMetric: _deleteMetric,
            onReload: _loadAll,
          ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_btn',
        onPressed: _showAddDialog,
        backgroundColor: kGoldenPollen,
        foregroundColor: kBrown,
        child: Icon(Icons.add),
      ),
    );
  }
}