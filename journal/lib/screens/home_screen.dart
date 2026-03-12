import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'journal_screen.dart';
import 'todo_screen.dart';

// ── Star data (seeded so positions are consistent) ────────────
class _StarData {
  final double x, y, size, phase;
  const _StarData(this.x, this.y, this.size, this.phase);
}

final List<_StarData> _stars = () {
  final rng = math.Random(42);
  return List.generate(45, (_) => _StarData(
    rng.nextDouble(),                      // x: full width
    0.48 + rng.nextDouble() * 0.52,        // y: bottom half
    0.8 + rng.nextDouble() * 2.0,          // size: 0.8–2.8
    rng.nextDouble() * math.pi * 2,        // twinkle phase
  ));
}();

// ── Star painter (animated) ────────────────────────────────────
class _StarPainter extends CustomPainter {
  final double time;
  _StarPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final osc = math.sin(time * math.pi * 2 + s.phase);
      final opacity = (0.25 + 0.75 * (osc * 0.5 + 0.5)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(size.width * s.x, size.height * s.y),
        s.size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.time != time;
}


// ── HomeScreen ─────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Offset? _pos;
  Size _size = Size.zero;
  late AnimationController _flyCtrl;
  late AnimationController _twinkleCtrl;
  late Animation<Offset> _flyAnim;
  bool _isFlying = false;
  bool _flyingUp = true;

  @override
  void initState() {
    super.initState();

    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _flyAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_flyCtrl);
    _flyCtrl.addListener(() => setState(() {}));
    _flyCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _navigateAfterFly();
    });

    _twinkleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
    _twinkleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    _twinkleCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isFlying) return;
    final next = _pos! + d.delta;
    setState(() => _pos = Offset(
      next.dx.clamp(104.0, _size.width - 104.0),
      next.dy,
    ));
  }

  void _onDragEnd(DragEndDetails d) {
    if (_isFlying) return;
    final y = _pos!.dy / _size.height;
    if (y < 0.15) {
      _flyOff(up: true);
    } else if (y > 0.85) {
      _flyOff(up: false);
    }
  }

  void _flyOff({required bool up}) {
    _flyingUp = up;
    final end = Offset(_pos!.dx, up ? -160.0 : _size.height + 160.0);
    _flyAnim = Tween<Offset>(begin: _pos!, end: end)
        .animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeIn));
    setState(() => _isFlying = true);
    _flyCtrl.forward(from: 0);
  }

  Future<void> _navigateAfterFly() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => _flyingUp ? const TodoScreen() : const JournalScreen()));
    if (!mounted) return;
    setState(() {
      _isFlying = false;
      _pos = Offset(_size.width / 2, _size.height / 2);
    });
    _flyCtrl.reset();
  }

  void _onTap() {
    if (_isFlying || _pos == null) return;
    final y = _pos!.dy / _size.height;
    if (y < 0.42) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoScreen()));
    } else if (y > 0.58) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      _pos ??= Offset(_size.width / 2, _size.height / 2);

      final displayPos = _isFlying ? _flyAnim.value : _pos!;
      final yFrac = (displayPos.dy / _size.height).clamp(0.0, 1.0);

      final double t;
      if (yFrac <= 0.42) {
        t = 0.0;
      } else if (yFrac >= 0.58) {
        t = 1.0;
      } else {
        t = (yFrac - 0.42) / 0.16;
      }

      return Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFD94F3A),
                      Color(0xFFE8753A),
                      Color(0xFFF4A444),
                      Color(0xFF1A3F6F),
                      Color(0xFF0F2447),
                      Color(0xFF080E24),
                    ],
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // Stars (bottom — night half, twinkling)
            Positioned.fill(
              child: CustomPaint(painter: _StarPainter(_twinkleCtrl.value)),
            ),

            // TO DO label + up arrow
            Positioned(
              top: _size.height * 0.07,
              left: 0, right: 0,
              child: Column(children: [
                Icon(Icons.keyboard_arrow_up,
                    color: Colors.white.withValues(alpha: 0.4), size: 22),
                const SizedBox(height: 4),
                Text('TO DO', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13, letterSpacing: 5,
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w600,
                )),
              ]),
            ),

            // JOURNAL label + down arrow
            Positioned(
              bottom: _size.height * 0.07,
              left: 0, right: 0,
              child: Column(children: [
                Text('JOURNAL', style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13, letterSpacing: 5,
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 4),
                Icon(Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.4), size: 22),
              ]),
            ),

            // Draggable circle
            Positioned(
              left: displayPos.dx - 104,
              top:  displayPos.dy - 104,
              child: GestureDetector(
                onPanUpdate: _isFlying ? null : _onDragUpdate,
                onPanEnd:    _isFlying ? null : _onDragEnd,
                onTap:       _isFlying ? null : _onTap,
                child: _DragCircle(t: t),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Draggable circle ───────────────────────────────────────────
class _DragCircle extends StatelessWidget {
  final double t; // 0 = sun, 1 = moon
  const _DragCircle({required this.t});

  @override
  Widget build(BuildContext context) {
    final bg   = Color.lerp(const Color(0xFFF6D35A), const Color(0xFFD0E8FF), t)!;
    final glow = Color.lerp(const Color(0xFFFFBB22), const Color(0xFF7AABDA), t)!;

    return Container(
      width: 208, height: 208,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.lerp(Colors.white, bg, 0.35)!,
            bg,
            Color.lerp(bg, glow, 0.35)!,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.85),
            blurRadius: 70,
            spreadRadius: 20,
          ),
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 120,
            spreadRadius: 30,
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sun fades out toward the middle
            Opacity(
              opacity: (1.0 - t * 2).clamp(0.0, 1.0),
              child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFF7A3800), size: 90),
            ),
            // Moon fades in from the middle downward
            Opacity(
              opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
              child: const Icon(Icons.nightlight_round, color: Color(0xFF0F2447), size: 84),
            ),
          ],
        ),
      ),
    );
  }
}
