/// Comprehensive Animated Widgets Demo
///
/// This demo showcases AnimatedContainer, Hero, AnimatedSwitcher,
/// implicit animations, and explicit animations.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'dart:math' as math;

/// Main animated widgets demo screen.
class AnimatedDemo extends StatelessWidget {
  const AnimatedDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'AnimatedContainer',
          subtitle: 'Implicit container animations',
        ),
        _AnimatedContainerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'AnimatedSwitcher',
          subtitle: 'Widget transition animations',
        ),
        _AnimatedSwitcherSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Animated Properties',
          subtitle: 'Individual property animations',
        ),
        _AnimatedPropertiesSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Animated List',
          subtitle: 'List insert/remove animations',
        ),
        _AnimatedListSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Explicit Animations',
          subtitle: 'AnimationController-based',
        ),
        _ExplicitAnimationSection(),
        TomSizedBox(height: 48),
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
    return TomPadding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(
            subtitle,
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
      ),
    );
  }
}

// =============================================================================
// AnimatedContainer Section
// =============================================================================

class _AnimatedContainerSection extends StatefulWidget {
  const _AnimatedContainerSection();

  @override
  State<_AnimatedContainerSection> createState() =>
      _AnimatedContainerSectionState();
}

class _AnimatedContainerSectionState extends State<_AnimatedContainerSection> {
  bool _expanded = false;
  int _colorIndex = 0;
  double _borderRadius = 8;

  final _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Size Animation',
          'Tap to expand/collapse.',
          TomGestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: TomAnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              width: _expanded ? 200 : 100,
              height: _expanded ? 200 : 100,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TomCenter(
                child: TomIcon(
                  _expanded ? Icons.compress : Icons.expand,
                  color: Colors.white,
                  size: _expanded ? 48 : 24,
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Color Animation',
          'Tap to change color.',
          TomGestureDetector(
            onTap: () => setState(
                () => _colorIndex = (_colorIndex + 1) % _colors.length),
            child: TomAnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: 150,
              height: 100,
              decoration: BoxDecoration(
                color: _colors[_colorIndex],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TomCenter(
                child: TomText(
                  'Tap me',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Border Radius Animation',
          'Use slider to change.',
          TomColumn(
            children: [
              TomAnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 150,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
              ),
              const TomSizedBox(height: 16),
              TomSlider(
                value: _borderRadius,
                min: 0,
                max: 50,
                onChanged: (v) => setState(() => _borderRadius = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            TomCenter(child: child),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// AnimatedSwitcher Section
// =============================================================================

class _AnimatedSwitcherSection extends StatefulWidget {
  const _AnimatedSwitcherSection();

  @override
  State<_AnimatedSwitcherSection> createState() =>
      _AnimatedSwitcherSectionState();
}

class _AnimatedSwitcherSectionState extends State<_AnimatedSwitcherSection> {
  int _count = 0;
  int _iconIndex = 0;
  bool _showFirst = true;

  final _icons = [
    Icons.favorite,
    Icons.star,
    Icons.thumb_up,
    Icons.check_circle,
    Icons.lightbulb,
  ];

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Counter Animation',
          'Tap to increment.',
          TomGestureDetector(
            onTap: () => setState(() => _count++),
            child: TomContainer(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TomAnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return TomScaleTransition(scale: animation, child: child);
                },
                child: TomText(
                  '$_count',
                  key: ValueKey(_count),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Icon Animation',
          'Tap to cycle icons.',
          TomGestureDetector(
            onTap: () =>
                setState(() => _iconIndex = (_iconIndex + 1) % _icons.length),
            child: TomContainer(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: TomAnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: TomIcon(
                  _icons[_iconIndex],
                  key: ValueKey(_iconIndex),
                  size: 40,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Cross Fade',
          'Tap to toggle content.',
          TomGestureDetector(
            onTap: () => setState(() => _showFirst = !_showFirst),
            child: TomAnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _showFirst
                  ? TomContainer(
                      key: const ValueKey('first'),
                      width: 150,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TomCenter(
                        child: TomText(
                          'First',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                    )
                  : TomContainer(
                      key: const ValueKey('second'),
                      width: 150,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TomCenter(
                        child: TomText(
                          'Second',
                          style: TextStyle(color: Colors.white, fontSize: 20),
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
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            TomCenter(child: child),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Animated Properties Section
// =============================================================================

class _AnimatedPropertiesSection extends StatefulWidget {
  const _AnimatedPropertiesSection();

  @override
  State<_AnimatedPropertiesSection> createState() =>
      _AnimatedPropertiesSectionState();
}

class _AnimatedPropertiesSectionState
    extends State<_AnimatedPropertiesSection> {
  double _opacity = 1.0;
  double _padding = 8.0;
  double _rotation = 0.0;
  Alignment _alignment = Alignment.center;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'AnimatedOpacity',
          'Tap buttons to fade.',
          TomColumn(
            children: [
              TomAnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 400),
                child: TomContainer(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const TomIcon(Icons.visibility, color: Colors.white),
                ),
              ),
              const TomSizedBox(height: 16),
              TomRow(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TomFilledButton(
                    onPressed: () => setState(() => _opacity = 0.0),
                    child: const TomText('Hide'),
                  ),
                  const TomSizedBox(width: 8),
                  TomFilledButton(
                    onPressed: () => setState(() => _opacity = 1.0),
                    child: const TomText('Show'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'AnimatedPadding',
          'Tap to toggle padding.',
          TomGestureDetector(
            onTap: () => setState(
                () => _padding = _padding == 8.0 ? 32.0 : 8.0),
            child: TomContainer(
              color: Colors.green.shade100,
              child: AnimatedPadding(
                padding: EdgeInsets.all(_padding),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: TomContainer(
                  width: 80,
                  height: 80,
                  color: Colors.green,
                  child: const TomCenter(
                    child: TomText(
                      'Tap',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'AnimatedRotation',
          'Tap to rotate.',
          TomGestureDetector(
            onTap: () => setState(() => _rotation += 0.25),
            child: AnimatedRotation(
              turns: _rotation,
              duration: const Duration(milliseconds: 400),
              child: TomContainer(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TomIcon(Icons.refresh, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'AnimatedAlign',
          'Tap to move.',
          TomGestureDetector(
            onTap: () {
              final alignments = [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomRight,
                Alignment.bottomLeft,
                Alignment.center,
              ];
              final currentIndex = alignments.indexOf(_alignment);
              setState(() {
                _alignment = alignments[(currentIndex + 1) % alignments.length];
              });
            },
            child: TomContainer(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TomAnimatedAlign(
                alignment: _alignment,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                child: TomContainer(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
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
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            TomCenter(child: child),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Animated List Section
// =============================================================================

class _AnimatedListSection extends StatefulWidget {
  const _AnimatedListSection();

  @override
  State<_AnimatedListSection> createState() => _AnimatedListSectionState();
}

class _AnimatedListSectionState extends State<_AnimatedListSection> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final List<String> _items = ['Item 1', 'Item 2', 'Item 3'];
  int _counter = 3;

  void _addItem() {
    _counter++;
    final index = _items.length;
    _items.add('Item $_counter');
    _listKey.currentState?.insertItem(index);
  }

  void _removeItem(int index) {
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildItem(removed, animation),
    );
  }

  Widget _buildItem(String item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: TomCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: TomListTile(
            leading: const TomIcon(Icons.star),
            title: TomText(item),
            trailing: TomIconButton(
              icon: const TomIcon(Icons.delete),
              onPressed: () {
                final index = _items.indexOf(item);
                if (index != -1) _removeItem(index);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const TomText(
                  'AnimatedList',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                FilledButton.icon(
                  onPressed: _addItem,
                  icon: const TomIcon(Icons.add),
                  label: const TomText('Add'),
                ),
              ],
            ),
            const TomSizedBox(height: 16),
            TomAnimatedList(
              key: _listKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              initialItemCount: _items.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(_items[index], animation);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Explicit Animation Section
// =============================================================================

class _ExplicitAnimationSection extends StatelessWidget {
  const _ExplicitAnimationSection();

  @override
  Widget build(BuildContext context) {
    return TomListView(
      children: [
        _PulseAnimation(),
        TomSizedBox(height: 16),
        _SpinAnimation(),
        TomSizedBox(height: 16),
        _BounceAnimation(),
      ],
    );
  }
}

class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation();

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'Pulse Animation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 16),
            TomCenter(
              child: TomScaleTransition(
                scale: _animation,
                child: TomContainer(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const TomIcon(Icons.favorite, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinAnimation extends StatefulWidget {
  const _SpinAnimation();

  @override
  State<_SpinAnimation> createState() => _SpinAnimationState();
}

class _SpinAnimationState extends State<_SpinAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'Spin Animation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 16),
            TomCenter(
              child: TomAnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: TomContainer(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const TomIcon(Icons.settings, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BounceAnimation extends StatefulWidget {
  const _BounceAnimation();

  @override
  State<_BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<_BounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'Bounce Animation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 16),
            TomSizedBox(
              height: 80,
              child: TomCenter(
                child: TomAnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _animation.value),
                      child: child,
                    );
                  },
                  child: TomContainer(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const TomIcon(
                      Icons.arrow_upward,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
