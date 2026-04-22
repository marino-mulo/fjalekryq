import 'package:flutter/material.dart';

/// Animated pointing-finger used by the tutorial to tell the player which
/// cell or button to tap next. Bobs gently on the chosen axis so it reads
/// as "tap here" at a glance.
enum FingerDirection { down, up, left, right }

class TutorialFinger extends StatefulWidget {
  final FingerDirection direction;
  final double size;

  const TutorialFinger({
    super.key,
    this.direction = FingerDirection.down,
    this.size = 28,
  });

  @override
  State<TutorialFinger> createState() => _TutorialFingerState();
}

class _TutorialFingerState extends State<TutorialFinger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _emoji {
    switch (widget.direction) {
      case FingerDirection.down:
        return '\u{1F447}';
      case FingerDirection.up:
        return '\u{1F446}';
      case FingerDirection.left:
        return '\u{1F448}';
      case FingerDirection.right:
        return '\u{1F449}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        const travel = 6.0;
        final dx = switch (widget.direction) {
          FingerDirection.left => -travel * t,
          FingerDirection.right => travel * t,
          _ => 0.0,
        };
        final dy = switch (widget.direction) {
          FingerDirection.up => -travel * t,
          FingerDirection.down => travel * t,
          _ => 0.0,
        };
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: Text(
        _emoji,
        style: TextStyle(fontSize: widget.size),
      ),
    );
  }
}
