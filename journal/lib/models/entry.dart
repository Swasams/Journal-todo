class JournalEntry {
  int? id;
  String title;
  String body;
  DateTime date;
  int? mood; // 4=Great, 3=Good, 2=Meh, 1=Not so good, 0=Bad

  JournalEntry({
    this.id,
    required this.title,
    required this.body,
    required this.date,
    this.mood,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
    'mood': mood,
  };

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
    id: map['id'],
    title: map['title'],
    body: map['body'],
    date: DateTime.parse(map['date']),
    mood: map['mood'] as int?,
  );
}
