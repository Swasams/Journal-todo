import 'package:flutter/material.dart';
import '../models/entry.dart';
import '../db/database_helper.dart';

const kNightDeep   = Color(0xFF0F2447);
const kNightNavy   = Color(0xFF1A3F6F);
const kNightBlue   = Color(0xFF3A6BB0);
const kNightSky    = Color(0xFF7AABDA);
const kNightCloud  = Color(0xFFA7C7E4);
const kNightPaper  = Color(0xFF0F2447);

const _moodLabels = ['Bad', 'Not so good', 'Meh', 'Good', 'Great'];
const _moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const _moodColors = [
  Color(0xFFE05C5C),
  Color(0xFFE0945C),
  Color(0xFF7AABDA),
  Color(0xFF5CA8D4),
  Color(0xFF5CBFA0),
];

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
    _bodyController  = TextEditingController(text: widget.entry?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final entry = JournalEntry(
      id:    widget.entry?.id,
      title: _titleController.text,
      body:  _bodyController.text,
      date:  DateTime.now(),
      mood:  widget.entry?.mood,
    );

    // Pick mood for new entries or allow re-pick for edits
    final mood = await _showMoodPicker(existingMood: entry.mood);
    if (!mounted) return;
    entry.mood = mood;

    if (entry.id == null) {
      await DatabaseHelper.insertEntry(entry);
    } else {
      await DatabaseHelper.updateEntry(entry);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<int?> _showMoodPicker({int? existingMood}) async {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: kNightNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How are you feeling?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  // i=0 is Bad, i=4 is Great — show Great first (right to left via reverse)
                  final idx = 4 - i;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, idx),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _moodColors[idx].withValues(alpha: existingMood == idx ? 1.0 : 0.25),
                            border: Border.all(
                              color: _moodColors[idx].withValues(alpha: 0.8),
                              width: existingMood == idx ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(_moodEmojis[idx], style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _moodLabels[idx],
                          style: TextStyle(
                            color: kNightCloud,
                            fontSize: 9,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(
                  'Skip',
                  style: TextStyle(color: kNightSky, fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightPaper,
      appBar: AppBar(
        backgroundColor: kNightNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.entry == null ? 'New Entry' : 'Edit Entry',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        backgroundColor: kNightBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.entry == null,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: kNightCloud),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kNightCloud)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kNightBlue, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.white, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'Write your thoughts...',
                  hintStyle: TextStyle(color: kNightCloud),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
