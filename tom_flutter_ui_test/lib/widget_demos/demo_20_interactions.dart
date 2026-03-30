/// Demo 20: Interactions & Gestures
///
/// Comprehensive demonstration of all Tom interaction and gesture widgets.
/// Widgets covered: TomGestureDetector, TomInkWell, TomInkResponse,
/// TomDraggable, TomDragTarget, TomLongPressDraggable, TomAbsorbPointer,
/// TomIgnorePointer, TomMouseRegion.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Interactions & Gestures demo.
class InteractionsDemo extends StatelessWidget {
  const InteractionsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InteractionsDemoContent();
  }
}

class _InteractionsDemoContent extends StatefulWidget {
  const _InteractionsDemoContent();

  @override
  State<_InteractionsDemoContent> createState() =>
      _InteractionsDemoContentState();
}

class _InteractionsDemoContentState extends State<_InteractionsDemoContent> {
  // State for gesture detector demo
  String _gestureInfo = 'Interact with the area below';
  Offset _panPosition = Offset.zero;
  double _scale = 1.0;

  // State for ink demos
  bool _inkWellPressed = false;
  bool _inkResponsePressed = false;

  // State for drag-drop demo
  Color _draggedColor = Colors.blue;
  final List<Color> _droppedColors = [];

  // State for long press drag
  int _longPressDragCount = 0;

  // State for pointer blocking demos
  bool _absorbPointer = false;
  bool _ignorePointer = false;
  int _blockedTapCount = 0;

  // State for mouse region demo
  bool _isHovering = false;
  Offset _mousePosition = Offset.zero;
  String _mouseEvent = 'Move mouse over the region';

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Gesture Detection
            _SectionHeader(
              tomId: 'demo20.section.gesture',
            ),
            const TomSizedBox(height: 16),
            _buildGestureDetectorSection(),
            const TomSizedBox(height: 32),

            // Section 2: Ink Effects
            _SectionHeader(
              tomId: 'demo20.section.ink',
            ),
            const TomSizedBox(height: 16),
            _buildInkEffectsSection(),
            const TomSizedBox(height: 32),

            // Section 3: Drag and Drop
            _SectionHeader(
              tomId: 'demo20.section.dragdrop',
            ),
            const TomSizedBox(height: 16),
            _buildDragDropSection(),
            const TomSizedBox(height: 32),

            // Section 4: Long Press Drag
            _SectionHeader(
              tomId: 'demo20.section.longpress',
            ),
            const TomSizedBox(height: 16),
            _buildLongPressDragSection(),
            const TomSizedBox(height: 32),

            // Section 5: Pointer Blocking
            _SectionHeader(
              tomId: 'demo20.section.pointer',
            ),
            const TomSizedBox(height: 16),
            _buildPointerBlockingSection(),
            const TomSizedBox(height: 32),

            // Section 6: Mouse Region
            _SectionHeader(
              tomId: 'demo20.section.mouse',
            ),
            const TomSizedBox(height: 16),
            _buildMouseRegionSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Gesture Detection
  // ===========================================================================

  Widget _buildGestureDetectorSection() {
    return _DemoCard(
      tomId: 'demo20.gestureDetector',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gesture info display
          TomContainer(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              children: [
                Icon(
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    text: _gestureInfo,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),
          // Tap gestures demo
          TomText(
            text: 'Tap Gestures:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomGestureDetector(
                onTap: () => setState(() => _gestureInfo = 'Single tap detected'),
                child: _buildGestureBox('Tap', Icons.touch_app),
              ),
              TomGestureDetector(
                onDoubleTap: () =>
                    setState(() => _gestureInfo = 'Double tap detected'),
                child: _buildGestureBox('Double Tap', Icons.double_arrow),
              ),
              TomGestureDetector(
                onLongPress: () =>
                    setState(() => _gestureInfo = 'Long press detected'),
                child: _buildGestureBox('Long Press', Icons.timer),
              ),
              TomGestureDetector(
                onSecondaryTap: () =>
                    setState(() => _gestureInfo = 'Secondary tap (right-click)'),
                child: _buildGestureBox('Right Click', Icons.mouse),
              ),
            ],
          ),
          const TomSizedBox(height: 20),
          // Pan gesture demo
          TomText(
            text: 'Pan/Drag Gesture:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomGestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _panPosition += details.delta;
                _gestureInfo =
                    'Pan: (${_panPosition.dx.toStringAsFixed(0)}, ${_panPosition.dy.toStringAsFixed(0)})';
              });
            },
            onPanEnd: (_) => setState(() => _panPosition = Offset.zero),
            child: TomContainer(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TomStack(
                children: [
                  TomCenter(
                    child: TomText(
                      text: 'Drag anywhere in this area',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 75 + _panPosition.dx,
                    top: 50 + _panPosition.dy,
                    child: TomContainer(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.open_with,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 20),
          // Scale gesture demo
          TomText(
            text: 'Scale/Pinch Gesture:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomGestureDetector(
            onScaleUpdate: (details) {
              setState(() {
                _scale = details.scale.clamp(0.5, 3.0);
                _gestureInfo = 'Scale: ${_scale.toStringAsFixed(2)}x';
              });
            },
            onScaleEnd: (_) => setState(() => _scale = 1.0),
            child: TomContainer(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TomCenter(
                child: Transform.scale(
                  scale: _scale,
                  child: TomContainer(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.zoom_out_map,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo20.gestureDetector.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureBox(String label, IconData icon) {
    return TomContainer(
      width: 90,
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: TomColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const TomSizedBox(height: 4),
          TomText(
            text: label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Ink Effects
  // ===========================================================================

  Widget _buildInkEffectsSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // InkWell demo
        _DemoCard(
          tomId: 'demo20.inkWell',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomWrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Basic InkWell
                  _buildInkWellExample(
                    'Default',
                    null,
                    null,
                  ),
                  // Custom splash color
                  _buildInkWellExample(
                    'Custom Splash',
                    Colors.purple.withValues(alpha: 0.3),
                    Colors.purple.withValues(alpha: 0.1),
                  ),
                  // Custom highlight
                  _buildInkWellExample(
                    'Custom Highlight',
                    Colors.green.withValues(alpha: 0.3),
                    Colors.green.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const TomSizedBox(height: 16),
              // Interactive InkWell with state display
              TomInkWell(
                onTap: () => setState(() => _inkWellPressed = !_inkWellPressed),
                onHighlightChanged: (highlighted) {
                  // Optional highlight callback
                },
                borderRadius: BorderRadius.circular(12),
                splashColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                highlightColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: TomContainer(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _inkWellPressed
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      width: _inkWellPressed ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TomRow(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _inkWellPressed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _inkWellPressed
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const TomSizedBox(width: 12),
                      TomText(
                        text:
                            _inkWellPressed ? 'Activated!' : 'Tap for ink splash',
                        style: TextStyle(
                          color: _inkWellPressed
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight:
                              _inkWellPressed ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo20.inkWell.hint',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),
        // InkResponse demo
        _DemoCard(
          tomId: 'demo20.inkResponse',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomWrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Circle InkResponse
                  TomInkResponse(
                    onTap: () =>
                        setState(() => _inkResponsePressed = !_inkResponsePressed),
                    highlightShape: BoxShape.circle,
                    radius: 40,
                    splashColor: Colors.blue.withValues(alpha: 0.3),
                    child: TomContainer(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _inkResponsePressed
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lens_blur, size: 32),
                    ),
                  ),
                  // Rectangle InkResponse with custom border
                  TomInkResponse(
                    onTap: () {},
                    containedInkWell: true,
                    highlightShape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    splashColor: Colors.orange.withValues(alpha: 0.3),
                    child: TomContainer(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.crop_square, size: 32),
                    ),
                  ),
                  // Custom splash factory hint
                  TomContainer(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.brush, size: 24),
                        TomSizedBox(height: 4),
                        TomText(
                          text: 'Custom\nFactory',
                          style: TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo20.inkResponse.hint',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInkWellExample(
    String label,
    Color? splashColor,
    Color? highlightColor,
  ) {
    return TomColumn(
      children: [
        Material(
          color: Colors.transparent,
          child: TomInkWell(
            onTap: () {},
            splashColor: splashColor,
            highlightColor: highlightColor,
            borderRadius: BorderRadius.circular(8),
            child: TomContainer(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TomCenter(
                child: Icon(Icons.water_drop, size: 28),
              ),
            ),
          ),
        ),
        const TomSizedBox(height: 4),
        TomText(
          text: label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 3: Drag and Drop
  // ===========================================================================

  Widget _buildDragDropSection() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    return _DemoCard(
      tomId: 'demo20.dragDrop',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            text: 'Drag colors to the target area:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 12),
          // Draggable sources
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((color) {
              return TomDraggable<Color>(
                data: color,
                feedback: TomContainer(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                childWhenDragging: TomContainer(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
                onDragStarted: () =>
                    setState(() => _draggedColor = color),
                child: TomContainer(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.drag_indicator,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
              );
            }).toList(),
          ),
          const TomSizedBox(height: 20),
          // Drag target
          TomDragTarget<Color>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              setState(() {
                if (!_droppedColors.contains(details.data)) {
                  _droppedColors.add(details.data);
                }
              });
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 100,
                decoration: BoxDecoration(
                  color: isHovering
                      ? _draggedColor.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHovering
                        ? _draggedColor
                        : Theme.of(context).colorScheme.outline,
                    width: isHovering ? 2 : 1,
                  ),
                ),
                child: TomCenter(
                  child: _droppedColors.isEmpty
                      ? TomColumn(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isHovering ? Icons.download : Icons.add_circle_outline,
                              size: 32,
                              color: isHovering
                                  ? _draggedColor
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const TomSizedBox(height: 8),
                            TomText(
                              text: isHovering ? 'Release to drop' : 'Drop colors here',
                              style: TextStyle(
                                color: isHovering
                                    ? _draggedColor
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : TomWrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: _droppedColors.map((color) {
                            return TomContainer(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                ),
              );
            },
          ),
          const TomSizedBox(height: 12),
          if (_droppedColors.isNotEmpty)
            TomFilledButton(
              tonal: true,
              onPressed: () => setState(() {
                _droppedColors.clear();
              }),
              child: const TomText(text: 'Reset'),
            ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo20.dragDrop.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Long Press Drag
  // ===========================================================================

  Widget _buildLongPressDragSection() {
    return _DemoCard(
      tomId: 'demo20.longPressDrag',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              // Long press draggable items
              TomExpanded(
                child: TomColumn(
                  children: [
                    TomText(
                      text: 'Long press to drag:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const TomSizedBox(height: 12),
                    TomWrap(
                      spacing: 12,
                      children: [
                        _buildLongPressDraggableItem(Icons.star, Colors.amber),
                        _buildLongPressDraggableItem(Icons.favorite, Colors.red),
                        _buildLongPressDraggableItem(Icons.bolt, Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 16),
              // Drop counter
              TomDragTarget<IconData>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (_) {
                  setState(() => _longPressDragCount++);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  return TomContainer(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isHovering
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHovering
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: isHovering ? 2 : 1,
                      ),
                    ),
                    child: TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TomText(
                          text: '$_longPressDragCount',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const TomText(
                          text: 'Dropped',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo20.longPressDrag.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongPressDraggableItem(IconData icon, Color color) {
    return TomLongPressDraggable<IconData>(
      data: icon,
      hapticFeedbackOnStart: true,
      feedback: TomContainer(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
      childWhenDragging: TomContainer(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      ),
      child: TomContainer(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // ===========================================================================
  // Section 5: Pointer Blocking
  // ===========================================================================

  Widget _buildPointerBlockingSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AbsorbPointer demo
        _DemoCard(
          tomId: 'demo20.absorbPointer',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomRow(
                children: [
                  const TomText(text: 'Absorb Pointer: '),
                  Switch(
                    value: _absorbPointer,
                    onChanged: (value) => setState(() => _absorbPointer = value),
                  ),
                  const TomSizedBox(width: 8),
                  Chip(
                    label: TomText(
                      text: _absorbPointer ? 'Blocking' : 'Passing',
                    ),
                    backgroundColor: _absorbPointer
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const TomSizedBox(height: 12),
              TomStack(
                children: [
                  TomContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TomWrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        TomFilledButton(
                          onPressed: () =>
                              setState(() => _blockedTapCount++),
                          child: const TomText(text: 'Button 1'),
                        ),
                        TomFilledButton(
                          tonal: true,
                          onPressed: () =>
                              setState(() => _blockedTapCount++),
                          child: const TomText(text: 'Button 2'),
                        ),
                        TomOutlinedButton(
                          onPressed: () =>
                              setState(() => _blockedTapCount++),
                          child: const TomText(text: 'Button 3'),
                        ),
                      ],
                    ),
                  ),
                  if (_absorbPointer)
                    Positioned.fill(
                      child: TomAbsorbPointer(
                        absorbing: true,
                        child: TomContainer(
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const TomCenter(
                            child: TomColumn(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block, size: 32, color: Colors.red),
                                TomSizedBox(height: 8),
                                TomText(
                                  text: 'Pointer absorbed',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const TomSizedBox(height: 8),
              TomText(
                text: 'Tap count: $_blockedTapCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo20.absorbPointer.hint',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),
        // IgnorePointer demo
        _DemoCard(
          tomId: 'demo20.ignorePointer',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomRow(
                children: [
                  const TomText(text: 'Ignore Pointer: '),
                  Switch(
                    value: _ignorePointer,
                    onChanged: (value) => setState(() => _ignorePointer = value),
                  ),
                  const TomSizedBox(width: 8),
                  Chip(
                    label: TomText(
                      text: _ignorePointer ? 'Ignoring' : 'Handling',
                    ),
                    backgroundColor: _ignorePointer
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const TomSizedBox(height: 12),
              TomContainer(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: TomStack(
                  children: [
                    // Background layer with tap handler
                    Positioned.fill(
                      child: TomInkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Background tapped!'),
                              duration: Duration(milliseconds: 500),
                            ),
                          );
                        },
                        child: const TomCenter(
                          child: TomText(
                            text: 'Background Layer (tap me)',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ),
                    ),
                    // Overlay that may ignore pointer
                    TomCenter(
                      child: TomIgnorePointer(
                        ignoring: _ignorePointer,
                        child: TomContainer(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _ignorePointer
                                ? Colors.transparent
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _ignorePointer
                                  ? Colors.orange
                                  : Colors.grey,
                              style: _ignorePointer
                                  ? BorderStyle.solid
                                  : BorderStyle.solid,
                            ),
                          ),
                          child: TomColumn(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _ignorePointer
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color:
                                    _ignorePointer ? Colors.orange : Colors.grey,
                              ),
                              const TomSizedBox(height: 4),
                              TomText(
                                text: _ignorePointer
                                    ? 'Pass through'
                                    : 'Blocking clicks',
                                style: TextStyle(
                                  color: _ignorePointer
                                      ? Colors.orange
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo20.ignorePointer.hint',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 6: Mouse Region
  // ===========================================================================

  Widget _buildMouseRegionSection() {
    return _DemoCard(
      tomId: 'demo20.mouseRegion',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mouse event display
          TomContainer(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isHovering
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              children: [
                Icon(
                  _isHovering ? Icons.mouse : Icons.mouse_outlined,
                  color: _isHovering
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    text: _mouseEvent,
                    style: TextStyle(
                      color: _isHovering
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_isHovering)
                  TomText(
                    text:
                        '(${_mousePosition.dx.toStringAsFixed(0)}, ${_mousePosition.dy.toStringAsFixed(0)})',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),
          // Mouse region demo area
          TomMouseRegion(
            onEnter: (event) => setState(() {
              _isHovering = true;
              _mouseEvent = 'Mouse entered the region';
            }),
            onExit: (event) => setState(() {
              _isHovering = false;
              _mouseEvent = 'Mouse exited the region';
            }),
            onHover: (event) => setState(() {
              _mousePosition = event.localPosition;
              _mouseEvent = 'Mouse hover at position';
            }),
            cursor: SystemMouseCursors.precise,
            child: TomContainer(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isHovering
                      ? [
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.1),
                        ]
                      : [
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHovering
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: _isHovering ? 2 : 1,
                ),
              ),
              child: TomStack(
                children: [
                  TomCenter(
                    child: TomColumn(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.track_changes,
                          size: 48,
                          color: _isHovering
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const TomSizedBox(height: 8),
                        TomText(
                          text: _isHovering
                              ? 'Tracking mouse position'
                              : 'Move mouse here to track',
                          style: TextStyle(
                            color: _isHovering
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isHovering)
                    Positioned(
                      left: _mousePosition.dx - 8,
                      top: _mousePosition.dy - 8,
                      child: TomContainer(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 16),
          // Cursor examples
          TomText(
            text: 'Cursor Examples:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildCursorExample('Click', SystemMouseCursors.click),
              _buildCursorExample('Text', SystemMouseCursors.text),
              _buildCursorExample('Grab', SystemMouseCursors.grab),
              _buildCursorExample('Move', SystemMouseCursors.move),
              _buildCursorExample('Resize', SystemMouseCursors.resizeColumn),
              _buildCursorExample('Wait', SystemMouseCursors.wait),
              _buildCursorExample('Help', SystemMouseCursors.help),
              _buildCursorExample('Forbidden', SystemMouseCursors.forbidden),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo20.mouseRegion.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCursorExample(String label, MouseCursor cursor) {
    return TomMouseRegion(
      cursor: cursor,
      child: TomContainer(
        width: 70,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: TomCenter(
          child: TomText(
            text: label,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header widget for demo sections.
class _SectionHeader extends StatelessWidget {
  final String tomId;

  const _SectionHeader({
    required this.tomId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          tomId: '$tomId.title',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const TomSizedBox(height: 8),
        TomContainer(
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
    );
  }
}

/// Demo card widget for individual widget showcases.
class _DemoCard extends StatelessWidget {
  final String tomId;
  final Widget child;

  const _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomIcon(tomId: '$tomId.icon'),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    tomId: '$tomId.title',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 8),
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const TomSizedBox(height: 16),
            const TomDivider(),
            const TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
