class TodoItem {
  int? id;
  String title;
  bool done;

  TodoItem({this.id, required this.title, this.done = false});

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'done': done ? 1 : 0,
  };

  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(
    id: map['id'],
    title: map['title'],
    done: map['done'] == 1,
  );
}
