/// Demo 23: Builders, Clips & Base Widgets
///
/// Demonstrates Tom builder widgets, clip widgets, and base-level primitives
/// that were not yet covered in previous demos.
///
/// Widgets covered: TomFutureBuilder, TomStreamBuilder,
/// TomValueListenableBuilder, TomListenableBuilder, TomLayoutBuilder,
/// TomOrientationBuilder, TomStatefulBuilder, TomTweenAnimationBuilder,
/// TomAnimatedBuilder, TomAnimatedFractionallySizedBox,
/// TomAnimatedPositionedDirectional, TomClipOval, TomClipPath,
/// TomClipRect, TomClipRRect, TomClipRSuperellipse,
/// TomOpacity, TomRawChip, TomEditableText.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Builders, Clips & Base Widgets demo.
class BuildersClipsDemo extends TomStatelessWidget {
  BuildersClipsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _BuildersClipsDemoContent();
  }
}

class _BuildersClipsDemoContent extends TomStatefulWidget {
  _BuildersClipsDemoContent();

  @override
  State<_BuildersClipsDemoContent> createState() =>
      _BuildersClipsDemoContentState();
}

class _BuildersClipsDemoContentState extends TomState<_BuildersClipsDemoContent>
    with TickerProviderStateMixin {
  // For FutureBuilder demo
  late Future<String> _futureData;

  // For StreamBuilder demo
  late StreamController<int> _streamController;
  int _streamValue = 0;
  Timer? _streamTimer;

  // For ValueListenableBuilder demo
  final ValueNotifier<int> _counter = ValueNotifier<int>(0);

  // For ListenableBuilder demo
  final ValueNotifier<double> _sliderValue = ValueNotifier<double>(0.5);

  // For AnimatedBuilder demo
  late AnimationController _animController;

  // For AnimatedFractionallySizedBox demo
  bool _expanded = false;

  // For AnimatedPositionedDirectional demo
  bool _moved = false;

  // For clip demos
  bool _showClips = true;

  // For TweenAnimationBuilder demo
  double _tweenTarget = 0.0;

  // For EditableText demo
  final TextEditingController _editController = TextEditingController(
    text: 'Editable text here',
  );
  final FocusNode _editFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _futureData = _loadData();
    _streamController = StreamController<int>.broadcast();
    _streamTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_streamController.isClosed) {
        _streamValue++;
        _streamController.add(_streamValue);
      }
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<String> _loadData() async {
    await Future.delayed(const Duration(seconds: 2));
    return 'Data loaded successfully!';
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _streamController.close();
    _counter.dispose();
    _sliderValue.dispose();
    _animController.dispose();
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Async Builders
            _SectionHeader(tomId: 'section.asyncBuilders'),
            TomSizedBox(height: 16),
            _buildFutureBuilderSection(),
            TomSizedBox(height: 16),
            _buildStreamBuilderSection(),
            TomSizedBox(height: 32),

            // Section 2: Listenable Builders
            _SectionHeader(tomId: 'section.listenableBuilders'),
            TomSizedBox(height: 16),
            _buildValueListenableBuilderSection(),
            TomSizedBox(height: 16),
            _buildListenableBuilderSection(),
            TomSizedBox(height: 32),

            // Section 3: Layout & State Builders
            _SectionHeader(tomId: 'section.layoutBuilders'),
            TomSizedBox(height: 16),
            _buildLayoutBuilderSection(),
            TomSizedBox(height: 16),
            _buildOrientationBuilderSection(),
            TomSizedBox(height: 16),
            _buildStatefulBuilderSection(),
            TomSizedBox(height: 32),

            // Section 4: Animation Builders
            _SectionHeader(tomId: 'section.animationBuilders'),
            TomSizedBox(height: 16),
            _buildAnimatedBuilderSection(),
            TomSizedBox(height: 16),
            _buildTweenAnimationBuilderSection(),
            TomSizedBox(height: 16),
            _buildAnimatedFractionallySizedBoxSection(),
            TomSizedBox(height: 16),
            _buildAnimatedPositionedDirectionalSection(),
            TomSizedBox(height: 32),

            // Section 5: Clips
            _SectionHeader(tomId: 'section.clips'),
            TomSizedBox(height: 16),
            _buildClipSection(),
            TomSizedBox(height: 32),

            // Section 6: Base Widgets
            _SectionHeader(tomId: 'section.baseWidgets'),
            TomSizedBox(height: 16),
            _buildOpacitySection(),
            TomSizedBox(height: 16),
            _buildRawChipSection(),
            TomSizedBox(height: 16),
            _buildEditableTextSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Async Builders
  // ===========================================================================

  Widget _buildFutureBuilderSection() {
    return _DemoCard(
      tomId: 'demo.futureBuilder',
      child: TomColumn(
        children: [
          TomFutureBuilder<String>(
            tomId: 'futureBuilder.demo',
            future: _futureData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return TomCircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              return TomCard(
                child: TomPadding(
                  padding: const EdgeInsets.all(16),
                  child: TomRow(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      TomSizedBox(width: 12),
                      Text(snapshot.data ?? 'No data'),
                    ],
                  ),
                ),
              );
            },
          ),
          TomSizedBox(height: 8),
          TomElevatedButton(
            onPressed: () {
              setState(() {
                _futureData = _loadData();
              });
            },
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamBuilderSection() {
    return _DemoCard(
      tomId: 'demo.streamBuilder',
      child: TomStreamBuilder<int>(
        tomId: 'streamBuilder.demo',
        stream: _streamController.stream,
        initialData: 0,
        builder: (context, snapshot) {
          return TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer),
              TomSizedBox(width: 8),
              Text(
                'Stream value: ${snapshot.data}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Section 2: Listenable Builders
  // ===========================================================================

  Widget _buildValueListenableBuilderSection() {
    return _DemoCard(
      tomId: 'demo.valueListenable',
      child: TomColumn(
        children: [
          TomValueListenableBuilder<int>(
            tomId: 'valueListenable.demo',
            valueListenable: _counter,
            builder: (context, value, child) {
              return Text(
                'Counter: $value',
                style: Theme.of(context).textTheme.headlineMedium,
              );
            },
          ),
          TomSizedBox(height: 8),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomIconButton(
                tomId: 'counter.decrement',
                onPressed: () => _counter.value--,
                icon: const Icon(Icons.remove),
              ),
              TomSizedBox(width: 16),
              TomIconButton(
                tomId: 'counter.increment',
                onPressed: () => _counter.value++,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListenableBuilderSection() {
    return _DemoCard(
      tomId: 'demo.listenableBuilder',
      child: TomColumn(
        children: [
          TomListenableBuilder(
            tomId: 'listenableBuilder.demo',
            listenable: _sliderValue,
            builder: (context, child) {
              return TomContainer(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withValues(alpha: _sliderValue.value),
                      Colors.purple.withValues(alpha: _sliderValue.value),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    'Opacity: ${_sliderValue.value.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          TomSizedBox(height: 8),
          Slider(
            value: _sliderValue.value,
            onChanged: (v) {
              _sliderValue.value = v;
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Layout & State Builders
  // ===========================================================================

  Widget _buildLayoutBuilderSection() {
    return _DemoCard(
      tomId: 'demo.layoutBuilder',
      child: TomLayoutBuilder(
        tomId: 'layoutBuilder.demo',
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 400;
          return TomContainer(
            height: 60,
            decoration: BoxDecoration(
              color: isWide ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isWide
                    ? 'Wide: ${constraints.maxWidth.toStringAsFixed(0)}px'
                    : 'Narrow: ${constraints.maxWidth.toStringAsFixed(0)}px',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrientationBuilderSection() {
    return _DemoCard(
      tomId: 'demo.orientationBuilder',
      child: TomSizedBox(
        height: 60,
        child: TomOrientationBuilder(
          tomId: 'orientationBuilder.demo',
          builder: (context, orientation) {
            return TomContainer(
              decoration: BoxDecoration(
                color: orientation == Orientation.portrait
                    ? Colors.blue.shade100
                    : Colors.teal.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Orientation: ${orientation.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatefulBuilderSection() {
    return _DemoCard(
      tomId: 'demo.statefulBuilder',
      child: TomStatefulBuilder(
        tomId: 'statefulBuilder.demo',
        builder: (context, localSetState) {
          int localCount = 0;
          return TomColumn(
            children: [
              Text('Local state: $localCount'),
              TomSizedBox(height: 8),
              TomElevatedButton(
                onPressed: () {
                  localSetState(() {
                    localCount++;
                  });
                },
                child: const Text('Increment local'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Section 4: Animation Builders
  // ===========================================================================

  Widget _buildAnimatedBuilderSection() {
    return _DemoCard(
      tomId: 'demo.animatedBuilder',
      child: TomSizedBox(
        height: 100,
        child: Center(
          child: TomAnimatedBuilder(
            tomId: 'animatedBuilder.demo',
            animation: _animController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animController.value * 6.28,
                child: child,
              );
            },
            child: const Icon(Icons.settings, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildTweenAnimationBuilderSection() {
    return _DemoCard(
      tomId: 'demo.tweenAnimation',
      child: TomColumn(
        children: [
          TomTweenAnimationBuilder<double>(
            tomId: 'tweenAnimation.demo',
            tween: Tween<double>(begin: 0, end: _tweenTarget),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return TomContainer(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Color.lerp(
                    Colors.blue.shade100,
                    Colors.red.shade100,
                    value,
                  ),
                ),
                child: Center(
                  child: Text('Tween: ${value.toStringAsFixed(2)}'),
                ),
              );
            },
          ),
          TomSizedBox(height: 8),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomElevatedButton(
                onPressed: () => setState(() => _tweenTarget = 0.0),
                child: const Text('Start'),
              ),
              TomSizedBox(width: 8),
              TomElevatedButton(
                onPressed: () => setState(() => _tweenTarget = 1.0),
                child: const Text('End'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFractionallySizedBoxSection() {
    return _DemoCard(
      tomId: 'demo.animatedFractional',
      child: TomColumn(
        children: [
          TomContainer(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomAnimatedFractionallySizedBox(
              tomId: 'animatedFractional.demo',
              widthFactor: _expanded ? 1.0 : 0.3,
              heightFactor: 1.0,
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: TomContainer(
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('Animated')),
              ),
            ),
          ),
          TomSizedBox(height: 8),
          TomElevatedButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Shrink' : 'Expand'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPositionedDirectionalSection() {
    return _DemoCard(
      tomId: 'demo.animatedPositioned',
      child: TomColumn(
        children: [
          TomSizedBox(
            height: 100,
            child: TomStack(
              children: [
                TomContainer(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                TomAnimatedPositionedDirectional(
                  tomId: 'animatedPositioned.demo',
                  start: _moved ? 150 : 10,
                  top: _moved ? 10 : 40,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  child: TomContainer(
                    width: 60,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.star, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TomSizedBox(height: 8),
          TomElevatedButton(
            onPressed: () => setState(() => _moved = !_moved),
            child: Text(_moved ? 'Move back' : 'Move'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: Clips
  // ===========================================================================

  Widget _buildClipSection() {
    final sampleChild = TomContainer(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.star, color: Colors.white, size: 32),
      ),
    );

    return _DemoCard(
      tomId: 'demo.clips',
      child: TomColumn(
        children: [
          TomRow(
            children: [
              TomElevatedButton(
                onPressed: () => setState(() => _showClips = !_showClips),
                child: Text(_showClips ? 'Hide clips' : 'Show clips'),
              ),
            ],
          ),
          TomSizedBox(height: 16),
          if (_showClips)
            TomWrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                // TomClipOval
                TomColumn(
                  children: [
                    TomClipOval(tomId: 'clip.oval', child: sampleChild),
                    TomSizedBox(height: 4),
                    const Text('ClipOval', style: TextStyle(fontSize: 12)),
                  ],
                ),
                // TomClipRRect
                TomColumn(
                  children: [
                    TomClipRRect(
                      tomId: 'clip.rrect',
                      borderRadius: BorderRadius.circular(20),
                      child: sampleChild,
                    ),
                    TomSizedBox(height: 4),
                    const Text('ClipRRect', style: TextStyle(fontSize: 12)),
                  ],
                ),
                // TomClipRect
                TomColumn(
                  children: [
                    TomClipRect(
                      tomId: 'clip.rect',
                      child: TomSizedBox(
                        width: 80,
                        height: 80,
                        child: TomOverflowBox(
                          maxWidth: 120,
                          maxHeight: 120,
                          child: sampleChild,
                        ),
                      ),
                    ),
                    TomSizedBox(height: 4),
                    const Text('ClipRect', style: TextStyle(fontSize: 12)),
                  ],
                ),
                // TomClipPath
                TomColumn(
                  children: [
                    TomClipPath(
                      tomId: 'clip.path',
                      clipper: const _DiamondClipper(),
                      child: sampleChild,
                    ),
                    TomSizedBox(height: 4),
                    const Text('ClipPath', style: TextStyle(fontSize: 12)),
                  ],
                ),
                // TomClipRSuperellipse
                TomColumn(
                  children: [
                    TomClipRSuperellipse(
                      tomId: 'clip.superellipse',
                      borderRadius: BorderRadius.circular(20),
                      child: sampleChild,
                    ),
                    TomSizedBox(height: 4),
                    const Text('ClipRSuper', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 6: Base Widgets
  // ===========================================================================

  Widget _buildOpacitySection() {
    return _DemoCard(
      tomId: 'demo.opacity',
      child: TomRow(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TomOpacity(
            tomId: 'opacity.full',
            opacity: 1.0,
            child: TomContainer(
              width: 60,
              height: 60,
              color: Colors.blue,
              child: const Center(
                child: Text('1.0', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          TomOpacity(
            tomId: 'opacity.half',
            opacity: 0.5,
            child: TomContainer(
              width: 60,
              height: 60,
              color: Colors.blue,
              child: const Center(
                child: Text('0.5', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          TomOpacity(
            tomId: 'opacity.quarter',
            opacity: 0.25,
            child: TomContainer(
              width: 60,
              height: 60,
              color: Colors.blue,
              child: const Center(
                child: Text('0.25', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawChipSection() {
    return _DemoCard(
      tomId: 'demo.rawChip',
      child: TomWrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TomRawChip(tomId: 'rawChip.basic', label: const Text('Raw Chip')),
          TomRawChip(
            tomId: 'rawChip.avatar',
            avatar: const Icon(Icons.person, size: 18),
            label: const Text('With Avatar'),
          ),
          TomRawChip(
            tomId: 'rawChip.selected',
            label: const Text('Selected'),
            selected: true,
          ),
          TomRawChip(
            tomId: 'rawChip.deletable',
            label: const Text('Deletable'),
            onDeleted: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTextSection() {
    return _DemoCard(
      tomId: 'demo.editableText',
      child: TomContainer(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TomEditableText(
          tomId: 'editableText.demo',
          controller: _editController,
          focusNode: _editFocusNode,
          style: Theme.of(context).textTheme.bodyLarge!,
          cursorColor: Theme.of(context).colorScheme.primary,
          backgroundCursorColor: Colors.grey,
        ),
      ),
    );
  }
}

// =============================================================================
// Custom Clipper for ClipPath demo
// =============================================================================

class _DiamondClipper extends CustomClipper<Path> {
  const _DiamondClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// =============================================================================
// Shared Helpers
// =============================================================================

/// Section header with title and subtitle from resources.
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({required this.tomId});

  @override
  Widget buildContent(BuildContext context) {
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
        TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TomSizedBox(height: 8),
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

/// Demo card with title, subtitle, and icon from resources.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomIcon(tomId: tomId, size: 24),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.subtitle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
