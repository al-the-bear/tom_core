part of 'acl_demos.dart';

class ResizableBox extends StatefulWidget {
  final Widget child;

  /// Initial height in logical pixels.
  final double initialHeight;

  /// Whether to draw the thin grey border around the content.
  /// Set to false when the child already provides its own visible border
  /// (e.g. an AclBuilder with title/borderStyle).
  final bool showBorder;

  const ResizableBox({
    super.key,
    required this.child,
    this.initialHeight = 120,
    this.showBorder = true,
  });

  @override
  State<ResizableBox> createState() => ResizableBoxState();
}

class ResizableBoxState extends State<ResizableBox> {
  double? _width; // seeded on first layout from available constraints
  late double _height;

  // Global-position-based drag tracking so the container edge follows the
  // pointer 1:1 regardless of gesture-arena contention from parent scrollables.
  double? _panStartX;
  double? _panStartW;
  double? _panStartY;
  double? _panStartH;

  static const double _grip = 10.0;
  static const double _minW = 100.0;
  static const double _minH = 100.0;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width ??=
          constraints.hasBoundedWidth ? constraints.maxWidth : 400.0;
      final w = _width!.clamp(_minW, double.infinity);
      final h = _height;

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // ── Content (optionally with grey border) ──────────────────
            Positioned.fill(
              child: widget.showBorder
                  ? Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey)),
                      child: widget.child,
                    )
                  : widget.child,
            ),

            // ── Right-edge drag handle ───────────────────────────────────
            Positioned(
              top: 0,
              right: 0,
              bottom: _grip,
              width: _grip,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) {
                    _panStartX = d.globalPosition.dx;
                    _panStartW = _width;
                  },
                  onPanUpdate: (d) => setState(() {
                    _width = ((_panStartW ?? w) +
                            d.globalPosition.dx -
                            (_panStartX ?? d.globalPosition.dx))
                        .clamp(_minW, double.infinity);
                  }),
                ),
              ),
            ),

            // ── Bottom-edge drag handle ──────────────────────────────────
            Positioned(
              left: 0,
              right: _grip,
              bottom: 0,
              height: _grip,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) {
                    _panStartY = d.globalPosition.dy;
                    _panStartH = _height;
                  },
                  onPanUpdate: (d) => setState(() {
                    _height = ((_panStartH ?? h) +
                            d.globalPosition.dy -
                            (_panStartY ?? d.globalPosition.dy))
                        .clamp(_minH, double.infinity);
                  }),
                ),
              ),
            ),

            // ── Corner drag handle (visual grip + resize both axes) ──────
            Positioned(
              right: 0,
              bottom: 0,
              width: _grip * 2,
              height: _grip * 2,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) {
                    _panStartX = d.globalPosition.dx;
                    _panStartW = _width;
                    _panStartY = d.globalPosition.dy;
                    _panStartH = _height;
                  },
                  onPanUpdate: (d) => setState(() {
                    _width = ((_panStartW ?? w) +
                            d.globalPosition.dx -
                            (_panStartX ?? d.globalPosition.dx))
                        .clamp(_minW, double.infinity);
                    _height = ((_panStartH ?? h) +
                            d.globalPosition.dy -
                            (_panStartY ?? d.globalPosition.dy))
                        .clamp(_minH, double.infinity);
                  }),
                  child: CustomPaint(painter: GripPainter()),
                ),
              ),
            ),

            // ── Live size chip ───────────────────────────────────────────
            Positioned(
              right: _grip * 2 + 2,
              bottom: _grip + 2,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${w.round()} × ${h.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Paints a classic 3-line resize grip in the bottom-right corner.
class GripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 3; i++) {
      final offset = i * 4.0;
      canvas.drawLine(
        Offset(size.width - offset, size.height),
        Offset(size.width, size.height - offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

