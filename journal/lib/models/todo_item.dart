class TodoItem {
  int? id;
  String title;
  bool done;
  int priority;
  bool isHabit;
  int intervalDays;
  String? nextDue;
  int completionCount;
  int order;
  // Habit accent colour (ARGB int). Used for the card wash on the Todo
  // tab and the line colour on the trends graph. Tasks ignore this.
  // Defaults to a warm peach; user can change via the add/edit dialog.
  int colorValue;

  TodoItem({
    this.id,
    required this.title,
    this.done = false,
    this.priority = 1,
    this.isHabit = false,
    this.intervalDays = 1,
    this.nextDue,
    this.completionCount = 0,
    this.order = 0,
    this.colorValue = 0xFFEFEAE0, // off-white default
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'done': done ? 1 : 0,
    'priority': priority,
    'is_habit': isHabit ? 1 : 0,
    'interval_days': intervalDays,
    'next_due': nextDue,
    'completion_count': completionCount,
    'order': order,
    'color_value': colorValue,
  };

  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(
    id: map['id'],
    title: map['title'],
    done: map['done'] == 1,
    priority: map['priority'] ?? 1,
    isHabit: map['is_habit'] == 1,
    intervalDays: map['interval_days'] ?? 1,
    nextDue: map['next_due'],
    completionCount: map['completion_count'] ?? 0,
    order: map['order'] ?? 0,
    colorValue: map['color_value'] ?? 0xFFEFEAE0,
  );
}
