import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../db/database_helper.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoItem> _todos = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    final todos = await DatabaseHelper.getAllTodos();
    setState(() => _todos = todos);
  }

  Future<void> _addTodo() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await DatabaseHelper.insertTodo(TodoItem(title: text));
    _controller.clear();
    _loadTodos();
  }

  Future<void> _toggleDone(TodoItem todo) async {
    todo.done = !todo.done;
    await DatabaseHelper.updateTodo(todo);
    _loadTodos();
  }

  Future<void> _deleteTodo(int id) async {
    await DatabaseHelper.deleteTodo(id);
    _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todo List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'New task...'),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTodo,
                ),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? const Center(child: Text('No tasks yet!'))
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final t = _todos[index];
                      return ListTile(
                        leading: Checkbox(
                          value: t.done,
                          onChanged: (_) => _toggleDone(t),
                        ),
                        title: Text(
                          t.title,
                          style: TextStyle(
                            decoration: t.done ? TextDecoration.lineThrough : null,
                            color: t.done ? Colors.grey : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTodo(t.id!),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
