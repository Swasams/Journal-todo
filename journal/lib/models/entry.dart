class JournalEntry {
  int? id;
  String title;
  String body;
  DateTime date;

  JournalEntry({
    this.id,
    required this.title,
    required this.body,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
  };

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
    id: map['id'],
    title: map['title'],
    body: map['body'],
    date: DateTime.parse(map['date']),
  );
}
