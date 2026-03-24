/// Common demo widgets used across ACL and Widget demos.
library;

import 'package:flutter/material.dart';

/// A simple labeled colored box for demonstration purposes.
class DemoBox extends StatelessWidget {
  final String label;
  final Color color;

  const DemoBox(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color.shade900)),
    );
  }
}

extension ColorShade on Color {
  Color get shade900 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness * 0.3).clamp(0.0, 1.0)).toColor();
  }
}

/// A code block widget that displays code with monospace font.
class CodeBlock extends StatelessWidget {
  final String code;

  const CodeBlock(this.code, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        code.trim(),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

/// A resizable container for demo content.
/// Drag edges to resize, corner grip for both axes.
class ResizableBox extends StatefulWidget {
  final Widget child;
  final double initialHeight;
  final bool showBorder;

  const ResizableBox({
    super.key,
    required this.child,
    this.initialHeight = 120,
    this.showBorder = true,
  });

  @override
  State<ResizableBox> createState() => _ResizableBoxState();
}

class _ResizableBoxState extends State<ResizableBox> {
  double? _width;
  late double _height;
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
      _width ??= constraints.hasBoundedWidth ? constraints.maxWidth : 400.0;
      final w = _width!.clamp(_minW, double.infinity);
      final h = _height;

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.showBorder
                  ? Container(
                      decoration:
                          BoxDecoration(border: Border.all(color: Colors.grey)),
                      child: widget.child,
                    )
                  : widget.child,
            ),
            // Right-edge drag handle
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
            // Bottom-edge drag handle
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
            // Corner drag handle
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
                  child: CustomPaint(painter: _GripPainter()),
                ),
              ),
            ),
            // Live size chip
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

class _GripPainter extends CustomPainter {
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

/// A styled header for demo sections.
class DemoSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const DemoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A card wrapper for individual widget showcases.
class DemoCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final String? code;
  final IconData? icon;

  const DemoCard({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.code,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
            const Divider(height: 24),
            // Widget showcase
            child,
            // Optional code snippet
            if (code != null) ...[
              const Divider(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('View Code', style: TextStyle(fontSize: 12)),
                children: [CodeBlock(code!)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget that shows a before/after comparison.
class DemoComparison extends StatelessWidget {
  final String beforeLabel;
  final String afterLabel;
  final Widget before;
  final Widget after;

  const DemoComparison({
    super.key,
    this.beforeLabel = 'Before',
    this.afterLabel = 'After',
    required this.before,
    required this.after,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beforeLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              before,
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward, color: Colors.grey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(afterLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              after,
            ],
          ),
        ),
      ],
    );
  }
}

/// A placeholder for features not yet implemented.
class DemoPlaceholder extends StatelessWidget {
  final String feature;
  final IconData icon;

  const DemoPlaceholder({
    super.key,
    required this.feature,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            feature,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
