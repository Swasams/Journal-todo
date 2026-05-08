class JournalEntry {
  int? id;
  String title;
  String body;            // Free brain-dump (kept for backwards compat).
  DateTime date;
  int? mood;              // 4=Great, 3=Good, 2=Meh, 1=Not so good, 0=Bad
  String today;           // What did I do today?
  String tomorrow;        // What do I need to do tomorrow?
  String rose;            // Best part — counts as positive regardless of mood.
  String thorn;           // Hard part — counts as negative regardless of mood.
  String bud;             // Looking forward to — positive lean.

  JournalEntry({
    this.id,
    required this.title,
    required this.body,
    required this.date,
    this.mood,
    this.today = '',
    this.tomorrow = '',
    this.rose = '',
    this.thorn = '',
    this.bud = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
    'mood': mood,
    'today': today,
    'tomorrow': tomorrow,
    'rose': rose,
    'thorn': thorn,
    'bud': bud,
  };

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
    id: map['id'],
    title: map['title'] ?? '',
    body: map['body'] ?? '',
    date: DateTime.parse(map['date']),
    mood: map['mood'] as int?,
    today: map['today'] ?? '',
    tomorrow: map['tomorrow'] ?? '',
    rose: map['rose'] ?? '',
    thorn: map['thorn'] ?? '',
    bud: map['bud'] ?? '',
  );
}
