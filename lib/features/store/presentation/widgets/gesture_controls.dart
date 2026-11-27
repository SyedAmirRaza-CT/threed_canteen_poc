import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

enum _Role { move, look, pinch, ignored }

class _Touch {
  _Touch(this.id, this.start, this.onLeft)
    : last = start,
      down = DateTime.now();
  final int id;
  final Offset start;
  final bool onLeft;
  final DateTime down;
  Offset last;
  double travel = 0;
  _Role role = _Role.ignored;
}

class _Stick {
  const _Stick(this.origin, this.knob);
  final Offset origin;
  final Offset knob;
}

/// PUBG-style gesture controls, no buttons:
///  - touch and drag on the LEFT half: a floating joystick appears under the
///    thumb and walks you (push further = faster);
///  - drag on the RIGHT half: look around (also up and down);
///  - two fingers on the same side: pinch to zoom in / out;
///  - a quick tap: pick an item or walk to that spot.
/// A mouse drags to look; the wheel / trackpad scroll walks, trackpad pinch zooms.
class StoreGestureLayer extends StatefulWidget {
  const StoreGestureLayer({
    super.key,
    required this.child,
    required this.onMove,
    required this.onLook,
    required this.onZoom,
    required this.onTap,
    required this.onScroll,
  });

  final Widget child;
  final void Function(double x, double y) onMove;
  final void Function(Offset delta) onLook;
  final void Function(double ratio) onZoom;
  final void Function(Offset position) onTap;
  final void Function(Offset delta) onScroll;

  @override
  State<StoreGestureLayer> createState() => _StoreGestureLayerState();
}

class _StoreGestureLayerState extends State<StoreGestureLayer> {
  /// Finger travel (logical px) that equals full speed.
  static const double _radius = 64;
  static const double _tapSlop = 14;
  static const Duration _tapTime = Duration(milliseconds: 380);

  final Map<int, _Touch> _touches = {};
  final ValueNotifier<_Stick?> _stick = ValueNotifier(null);
  double _pinchDist = 0;
  double _lastPanScale = 1;

  @override
  void dispose() {
    widget.onMove(0, 0);
    _stick.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e, Size size) {
    final width = size.width;
    final onLeft =
        e.kind != PointerDeviceKind.mouse && e.localPosition.dx < width / 2;
    final t = _Touch(e.pointer, e.localPosition, onLeft);
    // Two fingers that start close together always pinch (wherever they are);
    // two thumbs far apart, one on each side, move and look at the same time.
    final reach = math.min(size.width, size.height) * 0.45;
    final mate = _touches.values
        .where(
          (o) =>
              o.role != _Role.ignored &&
              (o.onLeft == onLeft || (o.last - t.last).distance < reach),
        )
        .firstOrNull;
    if (mate != null) {
      if (mate.role == _Role.move) _stopMove();
      mate.role = _Role.pinch;
      t.role = _Role.pinch;
      _pinchDist = (mate.last - t.last).distance;
    } else {
      t.role = onLeft ? _Role.move : _Role.look;
    }
    _touches[e.pointer] = t;
  }

  void _moved(PointerMoveEvent e) {
    final t = _touches[e.pointer];
    if (t == null) return;
    t.travel += e.localDelta.distance;
    t.last = e.localPosition;
    switch (t.role) {
      case _Role.move:
        if (t.travel < 8) return;
        var v = t.last - t.start;
        final len = v.distance;
        if (len > _radius) v = v / len * _radius;
        final mag = math.min(1.0, len / _radius);
        _stick.value = _Stick(t.start, t.start + v);
        if (mag < 0.12) {
          widget.onMove(0, 0);
        } else {
          final u = v / v.distance;
          widget.onMove(u.dx * mag, -u.dy * mag);
        }
      case _Role.look:
        widget.onLook(e.localDelta);
      case _Role.pinch:
        final mate = _touches.values
            .where((o) => o.id != t.id && o.role == _Role.pinch)
            .firstOrNull;
        if (mate == null) return;
        final d = (t.last - mate.last).distance;
        if (_pinchDist > 1 && d > 1) widget.onZoom(d / _pinchDist);
        _pinchDist = d;
      case _Role.ignored:
        break;
    }
  }

  void _up(PointerEvent e, {bool cancelled = false}) {
    final t = _touches.remove(e.pointer);
    if (t == null) return;
    switch (t.role) {
      case _Role.move:
        _stopMove();
      case _Role.pinch:
        for (final o in _touches.values) {
          if (o.role == _Role.pinch) {
            o.role = _Role.ignored; // the other finger waits until lifted
          }
        }
        return;
      default:
        break;
    }
    final quick = DateTime.now().difference(t.down) < _tapTime;
    if (!cancelled && t.role != _Role.ignored && t.travel < _tapSlop && quick) {
      widget.onTap(t.start);
    }
  }

  void _stopMove() {
    _stick.value = null;
    widget.onMove(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e, size),
          onPointerMove: _moved,
          onPointerUp: _up,
          onPointerCancel: (e) => _up(e, cancelled: true),
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) widget.onScroll(e.scrollDelta);
          },
          onPointerPanZoomStart: (_) => _lastPanScale = 1,
          onPointerPanZoomUpdate: (e) {
            widget.onScroll(Offset(-e.panDelta.dx, e.panDelta.dy));
            if (_lastPanScale > 0 && e.scale > 0) {
              widget.onZoom(e.scale / _lastPanScale);
            }
            _lastPanScale = e.scale;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              IgnorePointer(
                child: ValueListenableBuilder<_Stick?>(
                  valueListenable: _stick,
                  builder: (context, s, _) => s == null
                      ? const SizedBox.shrink()
                      : CustomPaint(painter: _StickPainter(s)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The floating joystick drawn under the left thumb (feedback only).
class _StickPainter extends CustomPainter {
  _StickPainter(this.stick);
  final _Stick stick;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      stick.origin,
      64,
      Paint()..color = AppColors.hudText.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      stick.origin,
      64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.hudText.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      stick.knob,
      26,
      Paint()..color = AppColors.primary.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_StickPainter old) =>
      old.stick.knob != stick.knob || old.stick.origin != stick.origin;
}
