import 'package:flutter/material.dart';
import '../models/entry.dart';
import '../db/database_helper.dart';

class EntryScreen extends StatefulWidget {
  final JournalEntry? entry;

  const EntryScreen({super.key, this.entry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _bodyController = TextEditingController(text: widget.entry?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entry = JournalEntry(
      id: widget.entry?.id,
      title: _titleController.text,
      body: _bodyController.text,
      date: DateTime.now(),
    );
    if (entry.id == null) {
      await DatabaseHelper.insertEntry(entry);
    } else {
      await DatabaseHelper.updateEntry(entry);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Entry' : 'Edit Entry'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Write your thoughts...'),
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
