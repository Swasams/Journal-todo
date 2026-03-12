import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/todo_item.dart';
import '../db/database_helper.dart';

// Palette — day/sunset image colours
const kSunsetPetal  = Color(0xFFD94F3A); // deep sunset red
const kGoldenPollen = Color(0xFFF4A444); // golden amber
const kEveningSky   = Color(0xFFE8873A); // warm orange (sun mid-sky)
const kLeaflitGreen = Color(0xFF5D7B3D); // kept for done/complete states
const kRosebudBlush = Color(0xFFF4C49A); // warm sand-peach (card borders)
const kCream        = Color(0xFFFDF5E0); // sandy cream
const kBrown        = Color(0xFF6B3A20); // warm dark earth brown

const kSlotLabels      = ['6–9 AM','9–12 PM','12–3 PM','3–6 PM','6–9 PM','9–12 AM'];
const kPriorityLabels  = ['High','Medium','Low'];
const kPriorityColors  = [kSunsetPetal, kGoldenPollen, kLeaflitGreen];
const kTab6hLabels     = ['6 AM–12 PM','12–6 PM','6 PM–12 AM'];
const kTab6hSlots      = [[0,1],[2,3],[4,5]];

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
DateTime _parseDate(String s) => DateTime.parse(s);
String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
bool _isDue(TodoItem t) {
  if (t.nextDue == null) return false;
  return !_parseDate(t.nextDue!).isAfter(DateTime.now());
}
String _dueLabelFor(TodoItem t) {
  if (t.nextDue == null) return '';
  final due   = _parseDate(t.nextDue!);
  final today = DateTime.now();
  final diff  = DateTime(due.year, due.month, due.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (diff < 0) return 'Overdue by ${-diff}d';
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  return 'In ${diff}d  ·  ${due.day}/${due.month}';
}

// Browser-tab indicator
class _BrowserTabIndicator extends Decoration {
  const _BrowserTabIndicator();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _BrowserTabPainter();
}
class _BrowserTabPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    canvas.drawRRect(
      RRect.fromRectAndCorners((offset & cfg.size!).inflate(1),
          topLeft: const Radius.circular(10), topRight: const Radius.circular(10)),
      Paint()..color = kCream,
    );
  }
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with TickerProviderStateMixin {
  List<TodoItem> _todos = [];
  bool _use6h = false;
  late TabController _tabController;

  int get _timeTabCount  => _use6h ? 3 : 6;
  int get _totalTabCount => _timeTabCount + 2;
  int get _habitsTabIndex  => _timeTabCount;
  int get _doneTabIndex    => _timeTabCount + 1;

  List<TodoItem> get _habitItems {
    final items = _todos.where((t) => t.isHabit).toList();
    items.sort((a, b) {
      final aDate = a.nextDue != null ? _parseDate(a.nextDue!) : DateTime(9999);
      final bDate = b.nextDue != null ? _parseDate(b.nextDue!) : DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return items;
  }

  List<TodoItem> get _completedTodos {
    final items = _todos.where((t) => !t.isHabit && t.done).toList();
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  List<TodoItem> _todosForTimeTab(int tabIndex) {
    final slots = _use6h ? kTab6hSlots[tabIndex] : [tabIndex];
    final items = _todos.where((t) {
      if (!slots.contains(t.timeSlot)) return false;
      if (t.isHabit) return _isDue(t);
      return !t.done;
    }).toList();
    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _totalTabCount, vsync: this);
    _loadTodos().then((_) => _checkDayRollover());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchMode(bool use6h) {
    if (_use6h == use6h) return;
    setState(() {
      _use6h = use6h;
      _tabController.dispose();
      _tabController = TabController(length: _totalTabCount, vsync: this);
    });
  }

  Future<void> _loadTodos() async {
    final todos = await DatabaseHelper.getAllTodos();
    setState(() => _todos = todos);
  }

  // ── Day rollover ─────────────────────────────────────────────

  Future<void> _checkDayRollover() async {
    final lastOpen = await DatabaseHelper.getLastOpenDate();
    final today    = _today();
    if (lastOpen == today) return; // same day, nothing to do

    // Count done tasks before clearing
    final doneTasks = _todos.where((t) => !t.isHabit && t.done).length;
    if (doneTasks > 0) {
      final recordDate = lastOpen ?? today;
      await DatabaseHelper.incrementDailyStat(recordDate, doneTasks);
    }
    await DatabaseHelper.clearDoneTodos();
    await DatabaseHelper.setLastOpenDate(today);
    await _loadTodos();

    if (doneTasks > 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showYesterdayPopup(lastOpen ?? 'yesterday', doneTasks);
      });
    }
  }

  void _showYesterdayPopup(String date, int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yesterday\'s wrap-up',
            style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: const TextStyle(
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
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
  }

  // ── Stats chart ───────────────────────────────────────────────

  Future<void> _showStatsSheet() async {
    final stats = await DatabaseHelper.getDailyStats();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: kCream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StatsSheet(stats: stats),
    );
  }

  // ── CRUD ─────────────────────────────────────────────────────

  Future<void> _toggleDone(TodoItem t) async {
    t.done = !t.done;
    if (t.done) {
      await DatabaseHelper.incrementDailyStat(_today(), 1);
    }
    await DatabaseHelper.updateTodo(t);
    _loadTodos();
  }

  Future<void> _completeHabit(TodoItem t) async {
    final base = t.nextDue != null ? _parseDate(t.nextDue!) : DateTime.now();
    t.nextDue = _formatDate(base.add(Duration(days: t.intervalDays)));
    t.completionCount++;
    await DatabaseHelper.incrementDailyStat(_today(), 1);
    await DatabaseHelper.updateTodo(t);
    // Add a completed copy to Done so it shows up in the count
    await DatabaseHelper.insertTodo(TodoItem(
      title: t.title,
      timeSlot: t.timeSlot,
      priority: t.priority,
      done: true,
    ));
    _loadTodos();
  }

  Future<void> _deleteTodo(int id) async {
    await DatabaseHelper.deleteTodo(id);
    _loadTodos();
  }

  Future<void> _clearAllDone() async {
    await DatabaseHelper.clearDoneTodos();
    _loadTodos();
  }

  Future<void> _duplicateTodo(TodoItem t) async {
    await DatabaseHelper.insertTodo(TodoItem(
      title: t.title, timeSlot: t.timeSlot, priority: t.priority,
      isHabit: t.isHabit, intervalDays: t.intervalDays, nextDue: t.nextDue,
    ));
    _loadTodos();
  }

  // ── Add dialog ───────────────────────────────────────────────

  Future<void> _showAddDialog(int tabIndex) async {
    final isSpecialTab = tabIndex == _habitsTabIndex || tabIndex == _doneTabIndex;
    final defaultSlot  = isSpecialTab ? 0
        : (_use6h ? kTab6hSlots[tabIndex][0] : tabIndex);

    final titleCtrl    = TextEditingController();
    final intervalCtrl = TextEditingController(text: '1');
    int  selectedSlot     = defaultSlot;
    int  selectedPriority = 1;
    bool isHabit          = tabIndex == _habitsTabIndex;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _itemDialog(
          ctx: ctx, set: set,
          titleCtrl: titleCtrl, intervalCtrl: intervalCtrl,
          selectedSlot: selectedSlot, selectedPriority: selectedPriority,
          isHabit: isHabit, isEdit: false,
          onSlotChanged: (v) => set(() => selectedSlot = v),
          onPriorityChanged: (v) => set(() => selectedPriority = v),
          onHabitChanged: (v) => set(() => isHabit = v),
          onConfirm: () async {
            final text = titleCtrl.text.trim();
            if (text.isEmpty) return;
            final days = (int.tryParse(intervalCtrl.text) ?? 1).clamp(1, 365);
            await DatabaseHelper.insertTodo(TodoItem(
              title: text, timeSlot: selectedSlot,
              priority: selectedPriority, isHabit: isHabit,
              intervalDays: days, nextDue: isHabit ? _today() : null,
            ));
            titleCtrl.clear(); intervalCtrl.text = '1';
            if (mounted) _loadTodos();
            set(() {});
          },
        ),
      ),
    );
    titleCtrl.dispose(); intervalCtrl.dispose();
  }

  // ── Edit dialog ───────────────────────────────────────────────

  Future<void> _showEditDialog(TodoItem t) async {
    final titleCtrl    = TextEditingController(text: t.title);
    final intervalCtrl = TextEditingController(text: t.intervalDays.toString());
    int  selectedSlot     = t.timeSlot;
    int  selectedPriority = t.priority;
    bool isHabit          = t.isHabit;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => _itemDialog(
          ctx: ctx, set: set,
          titleCtrl: titleCtrl, intervalCtrl: intervalCtrl,
          selectedSlot: selectedSlot, selectedPriority: selectedPriority,
          isHabit: isHabit, isEdit: true,
          onSlotChanged: (v) => set(() => selectedSlot = v),
          onPriorityChanged: (v) => set(() => selectedPriority = v),
          onHabitChanged: (v) => set(() => isHabit = v),
          onConfirm: () async {
            final text = titleCtrl.text.trim();
            if (text.isEmpty) return;
            t.title        = text;
            t.timeSlot     = selectedSlot;
            t.priority     = selectedPriority;
            t.isHabit      = isHabit;
            t.intervalDays = (int.tryParse(intervalCtrl.text) ?? 1).clamp(1, 365);
            if (isHabit && t.nextDue == null) t.nextDue = _today();
            await DatabaseHelper.updateTodo(t);
            if (mounted) { _loadTodos(); Navigator.pop(context); }
          },
          confirmLabel: 'Save',
        ),
      ),
    );
    titleCtrl.dispose(); intervalCtrl.dispose();
  }

  // ── Shared dialog widget ──────────────────────────────────────

  Widget _itemDialog({
    required BuildContext ctx,
    required StateSetter set,
    required TextEditingController titleCtrl,
    required TextEditingController intervalCtrl,
    required int selectedSlot,
    required int selectedPriority,
    required bool isHabit,
    required bool isEdit,
    required void Function(int) onSlotChanged,
    required void Function(int) onPriorityChanged,
    required void Function(bool) onHabitChanged,
    required Future<void> Function() onConfirm,
    String confirmLabel = 'Add',
  }) {
    return AlertDialog(
      backgroundColor: kCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEdit ? 'Edit Item' : 'New Item',
          style: const TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Task')),
                  ButtonSegment(value: true,  label: Text('Habit')),
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
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: kBrown),
              decoration: InputDecoration(
                labelText: isHabit ? 'Habit name' : 'Task name',
                labelStyle: const TextStyle(color: kSunsetPetal),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kSunsetPetal)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: selectedSlot,
              dropdownColor: kCream,
              style: const TextStyle(color: kBrown),
              decoration: InputDecoration(
                labelText: 'Time slot',
                labelStyle: const TextStyle(color: kSunsetPetal),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
              ),
              items: List.generate(6, (i) =>
                  DropdownMenuItem(value: i, child: Text(kSlotLabels[i]))),
              onChanged: (v) => onSlotChanged(v!),
            ),
            if (isHabit) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Text('Repeat every', style: TextStyle(color: kBrown, fontSize: 14)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: intervalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kBrown, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: kSunsetPetal)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('day(s)', style: TextStyle(color: kBrown, fontSize: 14)),
              ]),
              const SizedBox(height: 4),
              Text('1 = daily · 7 = weekly',
                  style: TextStyle(color: kBrown.withValues(alpha: 0.45), fontSize: 11)),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: selectedPriority,
              dropdownColor: kCream,
              style: const TextStyle(color: kBrown),
              decoration: InputDecoration(
                labelText: 'Priority',
                labelStyle: const TextStyle(color: kSunsetPetal),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kBrown.withValues(alpha: 0.3))),
              ),
              items: List.generate(3, (i) => DropdownMenuItem(
                value: i,
                child: Row(children: [
                  Icon(Icons.flag, size: 16, color: kPriorityColors[i]),
                  const SizedBox(width: 8),
                  Text(kPriorityLabels[i]),
                ]),
              )),
              onChanged: (v) => onPriorityChanged(v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: kLeaflitGreen)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: kSunsetPetal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: onConfirm,
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  // ── Cards ─────────────────────────────────────────────────────

  Widget _buildTaskCard(TodoItem t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          key: ValueKey(t.id),
          startActionPane: ActionPane(
            motion: const DrawerMotion(), extentRatio: 0.2,
            children: [SlidableAction(
              onPressed: (_) => _duplicateTodo(t),
              backgroundColor: kEveningSky, foregroundColor: kBrown,
              icon: Icons.copy_outlined, label: 'Duplicate',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            )],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(), extentRatio: 0.2,
            children: [SlidableAction(
              onPressed: (_) => _deleteTodo(t.id!),
              backgroundColor: kSunsetPetal, foregroundColor: Colors.white,
              icon: Icons.delete_outline, label: 'Delete',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            )],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: kSunsetPetal, width: 1.5),
            ),
            child: ListTile(
              onTap: () => _showEditDialog(t),
              leading: Checkbox(
                value: t.done,
                activeColor: kLeaflitGreen, checkColor: Colors.white,
                side: const BorderSide(color: kSunsetPetal),
                onChanged: (_) => _toggleDone(t),
              ),
              title: Row(children: [
                Icon(Icons.flag, size: 14, color: kPriorityColors[t.priority]),
                const SizedBox(width: 6),
                Expanded(child: Text(t.title, style: TextStyle(
                  color: t.done ? kBrown.withValues(alpha: 0.35) : kBrown,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                ))),
              ]),
              subtitle: Text(
                '${kPriorityLabels[t.priority]} · ${kSlotLabels[t.timeSlot]}',
                style: const TextStyle(color: kEveningSky, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitCard(TodoItem t) {
    final due     = _isDue(t);
    final overdue = t.nextDue != null && _parseDate(t.nextDue!).isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          key: ValueKey('habit_ts_${t.id}'),
          startActionPane: ActionPane(
            motion: const DrawerMotion(), extentRatio: 0.2,
            children: [SlidableAction(
              onPressed: (_) => _duplicateTodo(t),
              backgroundColor: kEveningSky, foregroundColor: kBrown,
              icon: Icons.copy_outlined, label: 'Duplicate',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            )],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(), extentRatio: 0.2,
            children: [SlidableAction(
              onPressed: (_) => _deleteTodo(t.id!),
              backgroundColor: kSunsetPetal, foregroundColor: Colors.white,
              icon: Icons.delete_outline, label: 'Delete',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            )],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: kSunsetPetal, width: 1.5),
            ),
            child: ListTile(
              onTap: () => _showEditDialog(t),
              leading: Checkbox(
                value: false,
                activeColor: kLeaflitGreen, checkColor: Colors.white,
                side: BorderSide(color: due ? kLeaflitGreen : kSunsetPetal),
                onChanged: due ? (_) => _completeHabit(t) : null,
              ),
              title: Row(children: [
                Icon(Icons.flag, size: 14, color: kPriorityColors[t.priority]),
                const SizedBox(width: 6),
                Expanded(child: Text(t.title, style: const TextStyle(color: kBrown))),
              ]),
              subtitle: Row(children: [
                Icon(Icons.repeat, size: 11,
                    color: overdue ? kSunsetPetal : due ? kLeaflitGreen : kEveningSky),
                const SizedBox(width: 4),
                Text(
                  '${t.intervalDays == 1 ? 'Daily' : 'Every ${t.intervalDays}d'} · ${_dueLabelFor(t)}',
                  style: TextStyle(
                    color: overdue ? kSunsetPetal : due ? kLeaflitGreen : kEveningSky,
                    fontSize: 11,
                    fontWeight: due ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // Habits tab management card — no checkbox, shows completion count, next due date
  Widget _buildHabitManageCard(TodoItem t) {
    final due     = _isDue(t);
    final overdue = t.nextDue != null && _parseDate(t.nextDue!).isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          key: ValueKey('habit_mgmt_${t.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(), extentRatio: 0.2,
            children: [SlidableAction(
              onPressed: (_) => _deleteTodo(t.id!),
              backgroundColor: kSunsetPetal, foregroundColor: Colors.white,
              icon: Icons.delete_outline, label: 'Delete',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            )],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: overdue ? kSunsetPetal : due ? kLeaflitGreen : kRosebudBlush,
                width: 1.5,
              ),
            ),
            child: ListTile(
              onTap: () => _showEditDialog(t),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: due ? (overdue ? kSunsetPetal : kLeaflitGreen) : Colors.transparent,
                  border: due ? null : Border.all(color: kBrown.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Icon(Icons.repeat, size: 18,
                    color: due ? Colors.white : kBrown.withValues(alpha: 0.3)),
              ),
              title: Row(children: [
                Icon(Icons.flag, size: 14, color: kPriorityColors[t.priority]),
                const SizedBox(width: 6),
                Expanded(child: Text(t.title, style: const TextStyle(color: kBrown))),
              ]),
              subtitle: Text(
                '${t.intervalDays == 1 ? 'Daily' : 'Every ${t.intervalDays}d'} · ${_dueLabelFor(t)}',
                style: TextStyle(
                  color: overdue ? kSunsetPetal : due ? kLeaflitGreen : kEveningSky,
                  fontSize: 11,
                  fontWeight: due ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${t.completionCount}',
                      style: const TextStyle(
                          color: kLeaflitGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('done', style: TextStyle(color: kBrown.withValues(alpha: 0.45), fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final completed  = _completedTodos;
    final habits     = _habitItems;
    final timeLabels = _use6h ? kTab6hLabels : kSlotLabels;
    final allTabs    = [...timeLabels, 'Habits', 'Done (${completed.length})'];

    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kSunsetPetal,
        foregroundColor: Colors.white,
        title: const Text('Todo List', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('3h')),
                ButtonSegment(value: true,  label: Text('6h')),
              ],
              selected: {_use6h},
              onSelectionChanged: (s) => _switchMode(s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? kGoldenPollen
                        : Colors.white.withValues(alpha: 0.2)),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? kBrown : Colors.white),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kSunsetPetal, kGoldenPollen],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: const _BrowserTabIndicator(),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: kBrown,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Montserrat'),
              tabs: allTabs.map((l) => Tab(text: l)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ...List.generate(_timeTabCount, (i) {
            final items = _todosForTimeTab(i);
            return _listOrEmpty(items, 'No tasks for this slot.',
                (t) => t.isHabit ? _buildHabitCard(t) : _buildTaskCard(t));
          }),
          // Habits tab — management view
          _listOrEmpty(habits, 'No habits yet. Tap + to add one.',
              (t) => _buildHabitManageCard(t)),
          // Done tab
          Container(
            color: kCream,
            child: completed.isEmpty
                ? Center(child: Text('Nothing completed yet.',
                    style: TextStyle(color: kBrown.withValues(alpha: 0.4))))
                : Column(children: [
                    // Header with clear button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: kLeaflitGreen.withValues(alpha: 0.12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${completed.length} task${completed.length == 1 ? '' : 's'} completed',
                            style: const TextStyle(color: kLeaflitGreen, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _clearAllDone,
                            icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: kSunsetPetal),
                            label: const Text('Clear all', style: TextStyle(color: kSunsetPetal, fontSize: 12)),
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero, minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: completed.length,
                        itemBuilder: (_, i) => _buildTaskCard(completed[i]),
                      ),
                    ),
                  ]),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton.small(
              heroTag: 'stats_btn',
              onPressed: _showStatsSheet,
              backgroundColor: kEveningSky,
              foregroundColor: kBrown,
              child: const Icon(Icons.show_chart),
            ),
            FloatingActionButton(
              heroTag: 'add_btn',
              onPressed: () => _showAddDialog(_tabController.index),
              backgroundColor: kGoldenPollen,
              foregroundColor: kBrown,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listOrEmpty(List<TodoItem> items, String emptyMsg,
      Widget Function(TodoItem) builder) {
    return Container(
      color: kCream,
      child: items.isEmpty
          ? Center(child: Text(emptyMsg,
              style: TextStyle(color: kBrown.withValues(alpha: 0.4))))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: items.length,
              itemBuilder: (_, i) => builder(items[i]),
            ),
    );
  }
}

// ── Stats bottom sheet ────────────────────────────────────────

class _StatsSheet extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsSheet({required this.stats});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Build all-time date range: first recorded date → today
    final List<String> days;
    if (stats.isEmpty) {
      days = [_formatDate(today)];
    } else {
      final sortedKeys = stats.keys.toList()..sort();
      final first    = _parseDate(sortedKeys.first);
      final dayCount = today.difference(first).inDays + 1;
      days = List.generate(dayCount, (i) => _formatDate(first.add(Duration(days: i))));
    }

    final spots = days.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), (stats[e.value] ?? 0).toDouble())).toList();
    final maxY  = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final total = stats.values.fold(0, (a, b) => a + b);

    // Scale label interval and chart width with number of days
    final labelInterval = days.length <= 14  ? 2.0
                        : days.length <= 60  ? 7.0
                        : days.length <= 180 ? 14.0 : 30.0;
    final chartWidth = (days.length * 22.0).clamp(300.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All-time completions',
                  style: TextStyle(color: kBrown, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('$total total',
                  style: TextStyle(color: kSunsetPetal, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: maxY == 0
                ? Center(child: Text('No data yet.',
                    style: TextStyle(color: kBrown.withValues(alpha: 0.4))))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      child: LineChart(LineChartData(
                        minY: 0,
                        maxY: maxY + 1,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: kBrown.withValues(alpha: 0.1), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, reservedSize: 28,
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: TextStyle(color: kBrown.withValues(alpha: 0.5), fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, reservedSize: 22,
                              interval: labelInterval,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                                final parts = days[idx].split('-');
                                return Text('${parts[2]}/${parts[1]}',
                                    style: TextStyle(
                                        color: kBrown.withValues(alpha: 0.5), fontSize: 9));
                              },
                            ),
                          ),
                          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: kSunsetPetal,
                            barWidth: 2.5,
                            dotData: FlDotData(
                              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                                radius: spot.y > 0 ? 4 : 2,
                                color: spot.y > 0 ? kSunsetPetal : kBrown.withValues(alpha: 0.2),
                                strokeWidth: 0,
                                strokeColor: Colors.transparent,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: kRosebudBlush.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      )),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
