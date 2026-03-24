/// Comprehensive Interactions Demo
///
/// This demo showcases GestureDetector, Draggable, Dismissible,
/// InkWell, gestures, and touch interactions.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main interactions demo screen.
class InteractionsDemo extends StatelessWidget {
  const InteractionsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Tap & Press',
          subtitle: 'Basic touch interactions',
        ),
        _TapSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'InkWell & InkResponse',
          subtitle: 'Material ripple effects',
        ),
        _InkWellSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Drag & Drop',
          subtitle: 'Draggable widgets',
        ),
        _DragDropSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Swipe Gestures',
          subtitle: 'Directional swipe detection',
        ),
        _SwipeSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Multi-touch',
          subtitle: 'Pinch and scale gestures',
        ),
        _MultiTouchSection(),
        SizedBox(height: 48),
      ],
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tap Section
// =============================================================================

class _TapSection extends StatefulWidget {
  const _TapSection();

  @override
  State<_TapSection> createState() => _TapSectionState();
}

class _TapSectionState extends State<_TapSection> {
  String _lastAction = 'No action yet';
  int _tapCount = 0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'GestureDetector',
          'Tap, double tap, long press.',
          Column(
            children: [
              Text(
                _lastAction,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _lastAction = 'Single tap'),
                onDoubleTap: () => setState(() => _lastAction = 'Double tap'),
                onLongPress: () => setState(() => _lastAction = 'Long press'),
                child: Container(
                  width: 150,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap Me',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Tap Counter',
          'Count your taps.',
          GestureDetector(
            onTap: () => setState(() => _tapCount++),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$_tapCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Press State',
          'Responds to press down/up.',
          GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 120,
              height: 60,
              decoration: BoxDecoration(
                color: _isPressed ? Colors.orange.shade700 : Colors.orange,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  _isPressed ? 'Pressed!' : 'Press',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// InkWell Section
// =============================================================================

class _InkWellSection extends StatelessWidget {
  const _InkWellSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'InkWell',
          'Material ripple on tap.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Material(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 80,
                    height: 60,
                    child: Center(child: Text('Tap')),
                  ),
                ),
              ),
              Material(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {},
                  splashColor: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 80,
                    height: 60,
                    child: Center(child: Text('Green')),
                  ),
                ),
              ),
              Material(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {},
                  highlightColor: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 80,
                    height: 60,
                    child: Center(child: Text('Highlight')),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Ink Shapes',
          'Different splash shapes.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Material(
                color: Colors.red.shade100,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {},
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(child: Icon(Icons.favorite)),
                  ),
                ),
              ),
              Material(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(30),
                  child: const SizedBox(
                    width: 100,
                    height: 40,
                    child: Center(child: Text('Pill')),
                  ),
                ),
              ),
              Material(
                color: Colors.amber.shade100,
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(child: Icon(Icons.star)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Drag & Drop Section
// =============================================================================

class _DragDropSection extends StatefulWidget {
  const _DragDropSection();

  @override
  State<_DragDropSection> createState() => _DragDropSectionState();
}

class _DragDropSectionState extends State<_DragDropSection> {
  Color _targetColor = Colors.grey.shade200;
  final List<Color> _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Drag to Target',
          'Drag colored items to the target.',
          Column(
            children: [
              DragTarget<Color>(
                onAcceptWithDetails: (details) {
                  setState(() => _targetColor = details.data);
                },
                builder: (context, candidateData, rejectedData) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _targetColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: candidateData.isNotEmpty
                            ? Colors.blue
                            : Colors.grey,
                        width: candidateData.isNotEmpty ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        candidateData.isNotEmpty ? 'Drop here!' : 'Target',
                        style: TextStyle(
                          color: _targetColor.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _colors.map((color) {
                  return Draggable<Color>(
                    data: color,
                    feedback: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    childWhenDragging: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'LongPressDraggable',
          'Long press to start dragging.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              return LongPressDraggable<int>(
                data: index,
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Swipe Section
// =============================================================================

class _SwipeSection extends StatefulWidget {
  const _SwipeSection();

  @override
  State<_SwipeSection> createState() => _SwipeSectionState();
}

class _SwipeSectionState extends State<_SwipeSection> {
  String _swipeDirection = 'Swipe any direction';
  Offset _position = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Swipe Detection',
          'Detects swipe direction.',
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                setState(() => _swipeDirection = '→ Swiped Right');
              } else {
                setState(() => _swipeDirection = '← Swiped Left');
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                setState(() => _swipeDirection = '↓ Swiped Down');
              } else {
                setState(() => _swipeDirection = '↑ Swiped Up');
              }
            },
            child: Container(
              width: 200,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo),
              ),
              child: Center(
                child: Text(
                  _swipeDirection,
                  style: TextStyle(
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Pan Gesture',
          'Drag to move.',
          Stack(
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                left: 75 + _position.dx,
                top: 50 + _position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                      _position = Offset(
                        _position.dx.clamp(-75, 75),
                        _position.dy.clamp(-50, 50),
                      );
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.open_with, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Multi-touch Section
// =============================================================================

class _MultiTouchSection extends StatefulWidget {
  const _MultiTouchSection();

  @override
  State<_MultiTouchSection> createState() => _MultiTouchSectionState();
}

class _MultiTouchSectionState extends State<_MultiTouchSection> {
  double _scale = 1.0;
  double _rotation = 0.0;
  double _previousScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return _buildDemoCard(
      'Scale & Rotate',
      'Pinch to scale, rotate with two fingers.',
      GestureDetector(
        onScaleStart: (details) {
          _previousScale = _scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_previousScale * details.scale).clamp(0.5, 3.0);
            _rotation = details.rotation;
          });
        },
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Transform.scale(
              scale: _scale,
              child: Transform.rotate(
                angle: _rotation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white),
                      Text(
                        'Pinch me',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
