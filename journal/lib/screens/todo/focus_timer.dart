import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/todo_item.dart';
import 'todo_theme.dart';

// `_Phase.after` retired â€” once a task is finished (or time runs out and
// the user confirms it's done) we shuffle and drop straight back to
// setup so the next round starts naturally.
enum _Phase { setup, running, timeUp }

class FocusTimer extends StatefulWidget {
  final List<TodoItem> pendingTasks; // active tasks + due habits
  final Future<void> Function(TodoItem) onComplete;

  const FocusTimer({
    super.key,
    required this.pendingTasks,
    required this.onComplete,
  });

  @override
  State<FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends State<FocusTimer> {
  static const _minDuration = Duration(minutes: 1);
  static const _maxDuration = Duration(hours: 8);

  _Phase _phase = _Phase.setup;
  Duration _duration = Duration(minutes: 30);
  Duration _remaining = Duration.zero;
  // User-editable step value used by the âˆ’/+ buttons.
  int _stepMinutes = 15;
  TodoItem? _task;
  Timer? _ticker;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    // Pick a task up-front so the user can see (and shuffle) it before
    // committing to start the timer.
    _shuffleTask();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // â”€â”€ State transitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _addMinutes(int delta) {
    final next = _duration + Duration(minutes: delta);
    if (next < _minDuration) return;
    if (next > _maxDuration) return;
    setState(() => _duration = next);
  }

  Future<void> _editStep() async {
    final ctrl = TextEditingController(text: '$_stepMinutes');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Step size',
            style: TextStyle(color: kBrown, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: kBrown),
          decoration: InputDecoration(
            labelText: 'Minutes per +/âˆ’ tap',
            labelStyle: TextStyle(color: kSunsetPetal),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: kLeaflitGreen)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kSunsetPetal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result <= 0) return;
    setState(() => _stepMinutes = result.clamp(1, 120));
  }

  void _shuffleTask() {
    if (widget.pendingTasks.isEmpty) {
      setState(() => _task = null);
      return;
    }
    // If there's more than one option, avoid landing on the same one twice.
    TodoItem next;
    do {
      next = widget.pendingTasks[_rng.nextInt(widget.pendingTasks.length)];
    } while (widget.pendingTasks.length > 1 && next == _task);
    setState(() => _task = next);
  }

  void _start() {
    if (_task == null) return;
    setState(() {
      _remaining = _duration;
      _phase = _Phase.running;
    });
    _ticker = Timer.periodic(Duration(seconds: 1), (_) {
      if (_remaining <= Duration(seconds: 1)) {
        _ticker?.cancel();
        setState(() {
          _remaining = Duration.zero;
          _phase = _Phase.timeUp;
        });
      } else {
        setState(() => _remaining -= Duration(seconds: 1));
      }
    });
  }

  Future<void> _markCompleted() async {
    _ticker?.cancel();
    if (_task != null) await widget.onComplete(_task!);
    if (!mounted) return;
    _shuffleTask();
    setState(() => _phase = _Phase.setup);
  }

  Future<void> _resolveTimeUp(bool finished) async {
    if (finished && _task != null) await widget.onComplete(_task!);
    if (!mounted) return;
    _shuffleTask();
    setState(() => _phase = _Phase.setup);
  }

  // âš ï¸ DEV ONLY â€” fast-forward the running timer to fire timeUp on the
  // next tick. Remove with the rest of the dev affordances before release.
  void _devSkipToTimeUp() {
    if (_phase != _Phase.running) return;
    setState(() => _remaining = Duration(seconds: 1));
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: kMorningGradient),
        child: SafeArea(
          child: switch (_phase) {
            _Phase.setup => _buildSetup(),
            _Phase.running => _buildRunning(),
            _Phase.timeUp => _buildTimeUp(),
          },
        ),
      ),
    );
  }

  Widget _buildSetup() {
    final empty = widget.pendingTasks.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: kBrown),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Spacer(),
            ],
          ),
          Spacer(),
          Text('Focus timer',
              style: TextStyle(
                color: kBrown,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
          SizedBox(height: 8),
          // Show the pre-picked task â€” user can shuffle below.
          if (empty)
            Text(
              'Nothing to focus on right now.',
              style: TextStyle(color: kBrown.withValues(alpha: 0.6)),
            )
          else ...[
            Text(
              'You will work on',
              style: TextStyle(
                color: kBrown.withValues(alpha: 0.55),
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _task?.title ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kBrown,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          SizedBox(height: 32),
          Text(
            _fmt(_duration),
            style: TextStyle(
              color: kBrown,
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StepButton(
                label: 'âˆ’$_stepMinutes min',
                onTap: _duration <= _minDuration
                    ? null
                    : () => _addMinutes(-_stepMinutes),
              ),
              SizedBox(width: 8),
              _StepButton(label: 'Custom', onTap: _editStep),
              SizedBox(width: 8),
              _StepButton(
                label: '+$_stepMinutes min',
                onTap: _duration >= _maxDuration
                    ? null
                    : () => _addMinutes(_stepMinutes),
              ),
            ],
          ),
          SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: empty ? null : _start,
            icon: Icon(Icons.play_arrow),
            label: Text('Start',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSunsetPetal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: 12),
          if (!empty && widget.pendingTasks.length > 1)
            TextButton.icon(
              onPressed: _shuffleTask,
              icon: Icon(Icons.shuffle, size: 18),
              label: Text('Shuffle task'),
              style: TextButton.styleFrom(foregroundColor: kBrown),
            ),
          Spacer(),
        ],
      ),
    );
  }

  Widget _buildRunning() {
    final task = _task!;
    final pct = _duration.inSeconds == 0
        ? 0.0
        : 1 - (_remaining.inSeconds / _duration.inSeconds);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: kBrown),
                onPressed: () {
                  _ticker?.cancel();
                  Navigator.of(context).pop();
                },
              ),
              Spacer(),
              // âš ï¸ DEV â€” fast-forward to time-up for testing.
              IconButton(
                tooltip: 'DEV: skip to time-up',
                icon: Icon(Icons.fast_forward,
                    color: kBrown.withValues(alpha: 0.5), size: 20),
                onPressed: _devSkipToTimeUp,
              ),
            ],
          ),
          Spacer(),
          Text(
            'Focus on',
            style: TextStyle(
              color: kBrown.withValues(alpha: 0.5),
              fontSize: 12,
              letterSpacing: 2,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              task.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kBrown,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 36),
          // Circular progress ring with countdown text
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: kRosebudBlush.withValues(alpha: 0.5),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kSunsetPetal),
                  ),
                ),
                Text(
                  _fmt(_remaining),
                  style: TextStyle(
                    color: kBrown,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Spacer(),
          ElevatedButton.icon(
            onPressed: _markCompleted,
            icon: Icon(Icons.check),
            label: Text('Completed',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kLeaflitGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTimeUp() {
    final task = _task!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Spacer(),
          Text(
            "â°  Time's up",
            style: TextStyle(
              color: kBrown,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Did you finish:',
            style: TextStyle(color: kBrown.withValues(alpha: 0.6)),
          ),
          SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '"${task.title}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kBrown,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _resolveTimeUp(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kSunsetPetal,
                  side: BorderSide(color: kSunsetPetal),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Not yet',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _resolveTimeUp(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLeaflitGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Finished it',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          Spacer(),
        ],
      ),
    );
  }

}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _StepButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: kFrostTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? kBrown.withValues(alpha: 0.15)
                : kSunsetPetal.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled
                ? kBrown.withValues(alpha: 0.3)
                : kSunsetPetal,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
