part of 'acl_demos.dart';

class ResizableBox extends StatefulWidget {
  final Widget child;

  /// Initial height in logical pixels. When null the box shrinks to the
  /// child's intrinsic height on the first frame; after the user drags
  /// the bottom handle the dragged value is used instead.
  final double? initialHeight;

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
  // When null (and widget.initialHeight was null) the box uses
  // IntrinsicHeight on the child so the outer container fits the
  // content. Once the user drags the bottom-edge handle we switch to a
  // fixed SizedBox height.
  double? _height;

  // Global-position-based drag tracking so the container edge follows the
  // pointer 1:1 regardless of gesture-arena contention from parent scrollables.
  double? _panStartX;
  double? _panStartW;
  double? _panStartY;
  double? _panStartH;
  final GlobalKey _childKey = GlobalKey();

  static const double _grip = 10.0;
  static const double _minW = 100.0;
  static const double _minH = 100.0;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
  }

  double _captureIntrinsicHeight() {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return _minH;
    return box.size.height.clamp(_minH, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width ??=
          constraints.hasBoundedWidth ? constraints.maxWidth : 400.0;
      final w = _width!.clamp(_minW, double.infinity);
      final h = _height;

      final Widget contentWithBorder = widget.showBorder
          ? Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey)),
              child: KeyedSubtree(key: _childKey, child: widget.child),
            )
          : KeyedSubtree(key: _childKey, child: widget.child);
      // Until the user drags vertically, the outer box shrinks to the
      // child's intrinsic height (SizedBox(height: null) is loose, so
      // the content determines the Stack's cross-axis extent via its
      // own natural size). Afterwards (h != null) a fixed height is
      // pinned so the drag handle can freely resize larger or smaller.
      final Widget sizedContent = h != null
          ? SizedBox(width: w, height: h, child: contentWithBorder)
          : SizedBox(width: w, child: contentWithBorder);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          sizedContent,

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
                  // First drag: capture the current intrinsic height so
                  // the pointer follows 1:1 even when we started in
                  // auto-sized mode.
                  _panStartH = _height ?? _captureIntrinsicHeight();
                },
                onPanUpdate: (d) => setState(() {
                  _height = ((_panStartH ?? h ?? _captureIntrinsicHeight()) +
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
                  _panStartH = _height ?? _captureIntrinsicHeight();
                },
                onPanUpdate: (d) => setState(() {
                  _width = ((_panStartW ?? w) +
                          d.globalPosition.dx -
                          (_panStartX ?? d.globalPosition.dx))
                      .clamp(_minW, double.infinity);
                  _height = ((_panStartH ?? h ?? _captureIntrinsicHeight()) +
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
                  h == null
                      ? '${w.round()} × auto'
                      : '${w.round()} × ${h.round()}',
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

