import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/todo_item.dart';
import 'todo_theme.dart';

// `_Phase.after` retired — once a task is finished (or time runs out and
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
  static const _minDuration = Duration(minutes: 15);
  static const _maxDuration = Duration(hours: 3);

  _Phase _phase = _Phase.setup;
  Duration _duration = const Duration(minutes: 30);
  Duration _remaining = Duration.zero;
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

  // ── State transitions ────────────────────────────────────────

  void _addMinutes(int delta) {
    final next = _duration + Duration(minutes: delta);
    if (next < _minDuration) return;
    if (next > _maxDuration) return;
    setState(() => _duration = next);
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= const Duration(seconds: 1)) {
        _ticker?.cancel();
        setState(() {
          _remaining = Duration.zero;
          _phase = _Phase.timeUp;
        });
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
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

  // ⚠️ DEV ONLY — fast-forward the running timer to fire timeUp on the
  // next tick. Remove with the rest of the dev affordances before release.
  void _devSkipToTimeUp() {
    if (_phase != _Phase.running) return;
    setState(() => _remaining = const Duration(seconds: 1));
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: kMorningGradient),
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
                icon: const Icon(Icons.close, color: kBrown),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          const Text('Focus timer',
              style: TextStyle(
                color: kBrown,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 8),
          // Show the pre-picked task — user can shuffle below.
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
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _task?.title ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kBrown,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            _fmt(_duration),
            style: const TextStyle(
              color: kBrown,
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                label: '−15 min',
                onTap: _duration <= _minDuration
                    ? null
                    : () => _addMinutes(-15),
              ),
              const SizedBox(width: 12),
              _StepButton(
                label: '+15 min',
                onTap: _duration >= _maxDuration
                    ? null
                    : () => _addMinutes(15),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: empty ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start',
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
          const SizedBox(height: 12),
          if (!empty && widget.pendingTasks.length > 1)
            TextButton.icon(
              onPressed: _shuffleTask,
              icon: const Icon(Icons.shuffle, size: 18),
              label: const Text('Shuffle task'),
              style: TextButton.styleFrom(foregroundColor: kBrown),
            ),
          const Spacer(),
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
                icon: const Icon(Icons.close, color: kBrown),
                onPressed: () {
                  _ticker?.cancel();
                  Navigator.of(context).pop();
                },
              ),
              const Spacer(),
              // ⚠️ DEV — fast-forward to time-up for testing.
              IconButton(
                tooltip: 'DEV: skip to time-up',
                icon: Icon(Icons.fast_forward,
                    color: kBrown.withValues(alpha: 0.5), size: 20),
                onPressed: _devSkipToTimeUp,
              ),
            ],
          ),
          const Spacer(),
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
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              task.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kBrown,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 36),
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
                  style: const TextStyle(
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
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _markCompleted,
            icon: const Icon(Icons.check),
            label: const Text('Completed',
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
          const SizedBox(height: 24),
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
          const Spacer(),
          Text(
            "⏰  Time's up",
            style: TextStyle(
              color: kBrown,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Did you finish:',
            style: TextStyle(color: kBrown.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '"${task.title}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kBrown,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _resolveTimeUp(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kSunsetPetal,
                  side: const BorderSide(color: kSunsetPetal),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Not yet',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(width: 12),
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
                child: const Text('Finished it',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const Spacer(),
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
          color: kFrostTint.withValues(alpha: 0.55),
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
