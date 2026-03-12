class TodoItem {
  int? id;
  String title;
  bool done;
  int timeSlot;
  int priority;
  bool isHabit;
  int intervalDays;
  String? nextDue;
  int completionCount;

  TodoItem({
    this.id,
    required this.title,
    this.done = false,
    this.timeSlot = 0,
    this.priority = 1,
    this.isHabit = false,
    this.intervalDays = 1,
    this.nextDue,
    this.completionCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'done': done ? 1 : 0,
    'time_slot': timeSlot,
    'priority': priority,
    'is_habit': isHabit ? 1 : 0,
    'interval_days': intervalDays,
    'next_due': nextDue,
    'completion_count': completionCount,
  };

  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(
    id: map['id'],
    title: map['title'],
    done: map['done'] == 1,
    timeSlot: map['time_slot'] ?? 0,
    priority: map['priority'] ?? 1,
    isHabit: map['is_habit'] == 1,
    intervalDays: map['interval_days'] ?? 1,
    nextDue: map['next_due'],
    completionCount: map['completion_count'] ?? 0,
  );
}
