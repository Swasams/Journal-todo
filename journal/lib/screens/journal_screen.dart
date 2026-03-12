import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../db/database_helper.dart';
import 'entry_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper.getAllEntries();
    setState(() => _entries = entries);
  }

  Future<void> _openEntry([JournalEntry? entry]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
    );
    if (result == true) _loadEntries();
  }

  Future<void> _deleteEntry(int id) async {
    await DatabaseHelper.deleteEntry(id);
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: _entries.isEmpty
          ? const Center(child: Text('No entries yet. Tap + to write!'))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final e = _entries[index];
                return ListTile(
                  title: Text(e.title),
                  subtitle: Text(DateFormat.yMMMd().format(e.date)),
                  onTap: () => _openEntry(e),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteEntry(e.id!),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEntry(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
