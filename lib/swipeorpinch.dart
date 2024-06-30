import 'package:flutter/material.dart';
import 'logger.dart';

///
/// Very simple class for swipe and pinch(zoom) gesturing. Swipe can also
/// generate "fling" given a certain velocity threshold. Customers will write
/// their own detectors or use external packages, but the basics of capturing
/// swipe and pinch common to most implementations are covered with the basic
/// GestureControl callbacks used here. Note that swipe is sometimes implemented
/// with the scale arena when there is only one point (i.e. not two fingers).
///
/// TBD: We should probably clean this up and make into two separate classes
/// and also allow scale to do both pinch and swipe.
///
class SwipeOrPinchDetector extends StatefulWidget {
  const SwipeOrPinchDetector({
    Key? key,
    this.behavior,
    this.onSwipe,
    this.onPinch,
    this.liveFeedback = false,
    this.pinch = false,
    @required this.child,
  }) : super(key: key);

  final void Function(double? scale)? onPinch;
  final bool pinch;

  /// How this gesture detector should behave during hit testing.
  ///
  /// This defaults to [HitTestBehavior.deferToChild] if [child] is not null and
  /// [HitTestBehavior.translucent] if child is null.

  final HitTestBehavior? behavior;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// Called when the user has swiped in a particular direction.
  ///
  /// - The [direction] parameter is the [SwipeDirection] of the swipe.
  /// - The [offset] parameter is the offset of the swipe in the [direction].
  final void Function(SwipeDirection direction, Offset offset)? onSwipe;

  /// If true, the callbacks are called every time the gesture gets updated
  /// and provide an [Offset] value in each callback.
  ///
  /// Otherwise, callbacks are called only when the gesture is ended.
  final bool liveFeedback;

  @override
  DetectorState createState() => DetectorState();
}

class DetectorState extends State<SwipeOrPinchDetector> {
  late Offset _startPosition;
  late Offset _updatePosition;
  double? lastScale;

  @override
  void initState() {
    super.initState();
    _startPosition = const Offset(0.0, 0.0);
    _updatePosition = const Offset(0.0, 0.0);
    lastScale = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pinch) {
      return GestureDetector(
        behavior: widget.behavior,
        onScaleStart: (ScaleStartDetails details) {
          tlLogger.v('ScaleStartDetails: ${details.toString()}');
          lastScale = null;
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          if (lastScale == null || lastScale != details.scale) {
            tlLogger
                .v('ScaleUpdateDetails scale changed: ${details.toString()}');
          }
          lastScale = details.scale;
        },
        onScaleEnd: (ScaleEndDetails details) {
          if (lastScale != null) {
            tlLogger.v(
                'ScaleEndDetails. scale: $lastScale, fingers: ${details.pointerCount}, ${details.toString()}');
            widget.onPinch?.call(lastScale);
          }
        },
        child: widget.child,
      );
    }
    return GestureDetector(
      behavior: widget.behavior,
      onPanStart: (details) {
        _startPosition = details.globalPosition;
      },
      onPanUpdate: (details) {
        _updatePosition = details.globalPosition;
        if (widget.liveFeedback) {
          _calculateAndExecute();
        }
      },
      onPanEnd: (details) {
        _calculateAndExecute();
      },
      child: widget.child,
    );
  }

  void _calculateAndExecute() {
    final offset = _updatePosition - _startPosition;
    final SwipeDirection direction = _getSwipeDirection(offset);

    widget.onSwipe?.call(direction, offset);
  }

  SwipeDirection _getSwipeDirection(Offset offset) {
    if (offset.dx.abs() > offset.dy.abs()) {
      return (offset.dx > 0) ? SwipeDirection.right : SwipeDirection.left;
    }
    return (offset.dy > 0) ? SwipeDirection.down : SwipeDirection.up;
  }
}

/// The direction of the swipe.
enum SwipeDirection {
  up, // Swipe up.
  down, // Swipe down.
  left, // Swipe left.
  right // Swipe right.
}
