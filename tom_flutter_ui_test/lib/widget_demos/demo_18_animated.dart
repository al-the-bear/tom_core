/// Demo 18: Animated Transitions
///
/// Comprehensive demonstration of all Tom animation and transition widgets.
/// Widgets covered: TomAnimatedContainer, TomAnimatedOpacity, TomAnimatedCrossFade,
/// TomAnimatedSwitcher, TomAnimatedPositioned, TomAnimatedAlign, TomAnimatedPadding,
/// TomAnimatedScale, TomAnimatedSlide, TomAnimatedRotation, TomAnimatedSize,
/// TomAnimatedDefaultTextStyle, TomAnimatedPhysicalModel, TomHero,
/// TomFadeTransition, TomScaleTransition, TomRotationTransition.
library;



import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Animated Transitions demo.
class AnimatedDemo extends StatelessWidget {
  const AnimatedDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AnimatedDemoContent();
  }
}

class _AnimatedDemoContent extends StatefulWidget {
  const _AnimatedDemoContent();

  @override
  State<_AnimatedDemoContent> createState() => _AnimatedDemoContentState();
}

class _AnimatedDemoContentState extends State<_AnimatedDemoContent>
    with TickerProviderStateMixin {
  // Animation controllers for transition widgets
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;

  // State variables for implicit animations
  bool _containerExpanded = false;
  double _opacity = 1.0;
  bool _showFirst = true;
  int _switcherIndex = 0;
  Alignment _alignment = Alignment.topLeft;
  EdgeInsets _padding = const EdgeInsets.all(8);
  double _scale = 1.0;
  Offset _slideOffset = Offset.zero;
  double _turns = 0.0;
  bool _sizeExpanded = false;
  bool _boldText = false;
  double _elevation = 4.0;
  CrossFadeState _crossFadeState = CrossFadeState.showFirst;

  // Hero navigation state
  bool _showHeroDetail = false;
  int _selectedHeroIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: AnimatedContainer
            _SectionHeader(tomId: 'demo18.section.container'),
            const TomSizedBox(height: 16),
            _buildAnimatedContainerSection(),
            const TomSizedBox(height: 32),

            // Section 2: Opacity & CrossFade
            _SectionHeader(tomId: 'demo18.section.opacity'),
            const TomSizedBox(height: 16),
            _buildOpacitySection(),
            const TomSizedBox(height: 24),
            _buildCrossFadeSection(),
            const TomSizedBox(height: 32),

            // Section 3: AnimatedSwitcher
            _SectionHeader(tomId: 'demo18.section.switcher'),
            const TomSizedBox(height: 16),
            _buildSwitcherSection(),
            const TomSizedBox(height: 32),

            // Section 4: Position & Alignment
            _SectionHeader(tomId: 'demo18.section.position'),
            const TomSizedBox(height: 16),
            _buildPositionedSection(),
            const TomSizedBox(height: 24),
            _buildAlignSection(),
            const TomSizedBox(height: 32),

            // Section 5: Padding & Size
            _SectionHeader(tomId: 'demo18.section.padding'),
            const TomSizedBox(height: 16),
            _buildPaddingSection(),
            const TomSizedBox(height: 24),
            _buildSizeSection(),
            const TomSizedBox(height: 32),

            // Section 6: Transform Animations
            _SectionHeader(tomId: 'demo18.section.transform'),
            const TomSizedBox(height: 16),
            _buildScaleSection(),
            const TomSizedBox(height: 24),
            _buildSlideSection(),
            const TomSizedBox(height: 24),
            _buildRotationSection(),
            const TomSizedBox(height: 32),

            // Section 7: Text & Physical Model
            _SectionHeader(tomId: 'demo18.section.text'),
            const TomSizedBox(height: 16),
            _buildTextStyleSection(),
            const TomSizedBox(height: 24),
            _buildPhysicalModelSection(),
            const TomSizedBox(height: 32),

            // Section 8: Transition Widgets
            _SectionHeader(tomId: 'demo18.section.transitions'),
            const TomSizedBox(height: 16),
            _buildFadeTransitionSection(),
            const TomSizedBox(height: 24),
            _buildScaleTransitionSection(),
            const TomSizedBox(height: 24),
            _buildRotationTransitionSection(),
            const TomSizedBox(height: 32),

            // Section 9: Hero Transitions
            _SectionHeader(tomId: 'demo18.section.hero'),
            const TomSizedBox(height: 16),
            _buildHeroSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: AnimatedContainer
  // ===========================================================================

  Widget _buildAnimatedContainerSection() {
    return _DemoCard(
      tomId: 'demo18.animatedContainer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.animatedContainer.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _containerExpanded = !_containerExpanded),
              child: TomAnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: _containerExpanded ? 250 : 150,
                height: _containerExpanded ? 180 : 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _containerExpanded
                        ? [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ]
                        : [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.secondaryContainer,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(
                    _containerExpanded ? 24 : 12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: _containerExpanded ? 0.4 : 0.2),
                      blurRadius: _containerExpanded ? 16 : 8,
                      offset: Offset(0, _containerExpanded ? 8 : 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: TomAnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 500),
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: _containerExpanded
                            ? Colors.white
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: _containerExpanded
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                  child: Text(_containerExpanded ? 'Expanded!' : 'Tap me'),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 16),
          TomText(
            tomId: 'demo18.animatedContainer.hint',
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
  // Section 2: Opacity & CrossFade
  // ===========================================================================

  Widget _buildOpacitySection() {
    return _DemoCard(
      tomId: 'demo18.animatedOpacity',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.animatedOpacity.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomExpanded(
                child: TomSlider(
                  value: _opacity,
                  onChanged: (v) => setState(() => _opacity = v),
                  label: 'Opacity: ${(_opacity * 100).toInt()}%',
                ),
              ),
              const TomSizedBox(width: 16),
              TomAnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.animatedOpacity.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossFadeSection() {
    return _DemoCard(
      tomId: 'demo18.crossFade',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.crossFade.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomAnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  crossFadeState: _crossFadeState,
                  firstChild: Container(
                    width: 200,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wb_sunny,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Day Mode',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  secondChild: Container(
                    width: 200,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.nightlight_round,
                          size: 48,
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Night Mode',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onInverseSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomFilledButton(
                  onPressed: () => setState(() {
                    _crossFadeState = _crossFadeState == CrossFadeState.showFirst
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst;
                  }),
                  child: const TomText(text: 'Toggle Day/Night'),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.crossFade.hint',
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
  // Section 3: AnimatedSwitcher
  // ===========================================================================

  Widget _buildSwitcherSection() {
    final icons = [
      Icons.home,
      Icons.favorite,
      Icons.settings,
      Icons.person,
      Icons.notifications,
    ];
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
      Colors.orange,
    ];

    return _DemoCard(
      tomId: 'demo18.switcher',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.switcher.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomAnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey(_switcherIndex),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colors[_switcherIndex].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors[_switcherIndex],
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      icons[_switcherIndex],
                      size: 48,
                      color: colors[_switcherIndex],
                    ),
                  ),
                ),
                const TomSizedBox(height: 24),
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    icons.length,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TomIconButton(
                        onPressed: () => setState(() => _switcherIndex = index),
                        style: IconButton.styleFrom(
                          backgroundColor: _switcherIndex == index
                              ? colors[index].withValues(alpha: 0.2)
                              : null,
                        ),
                        icon: TomIcon(
                          icon: icons[index],
                          color: _switcherIndex == index ? colors[index] : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.switcher.hint',
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
  // Section 4: Position & Alignment
  // ===========================================================================

  Widget _buildPositionedSection() {
    return _DemoCard(
      tomId: 'demo18.positioned',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.positioned.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Grid lines for reference
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                TomAnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutBack,
                  left: _showFirst ? 20 : null,
                  right: _showFirst ? null : 20,
                  top: _showFirst ? 20 : null,
                  bottom: _showFirst ? null : 20,
                  child: GestureDetector(
                    onTap: () => setState(() => _showFirst = !_showFirst),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .shadow
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.positioned.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignSection() {
    final alignments = [
      Alignment.topLeft,
      Alignment.topCenter,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.center,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomCenter,
      Alignment.bottomRight,
    ];

    return _DemoCard(
      tomId: 'demo18.align',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.align.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3x3 alignment grid
              TomColumn(
                children: [
                  for (var row = 0; row < 3; row++)
                    TomRow(
                      children: [
                        for (var col = 0; col < 3; col++)
                          Padding(
                            padding: const EdgeInsets.all(2),
                            child: GestureDetector(
                              onTap: () => setState(() =>
                                  _alignment = alignments[row * 3 + col]),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _alignment == alignments[row * 3 + col]
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const TomSizedBox(width: 24),
              // Demo area
              TomExpanded(
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomAnimatedAlign(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    alignment: _alignment,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.align.hint',
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
  // Section 5: Padding & Size
  // ===========================================================================

  Widget _buildPaddingSection() {
    return _DemoCard(
      tomId: 'demo18.padding',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.padding.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                Container(
                  width: 200,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TomAnimatedPadding(
                    duration: const Duration(milliseconds: 400),
                    padding: _padding,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const TomText(text: 'Content'),
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomWrap(
                  spacing: 8,
                  children: [
                    TomFilledButton(tonal: true,
                      onPressed: () => setState(
                        () => _padding = const EdgeInsets.all(8),
                      ),
                      child: const TomText(text: 'Small'),
                    ),
                    TomFilledButton(tonal: true,
                      onPressed: () => setState(
                        () => _padding = const EdgeInsets.all(24),
                      ),
                      child: const TomText(text: 'Medium'),
                    ),
                    TomFilledButton(tonal: true,
                      onPressed: () => setState(
                        () => _padding = const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                      ),
                      child: const TomText(text: 'Asymmetric'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.padding.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSection() {
    return _DemoCard(
      tomId: 'demo18.size',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.size.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomAnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: _sizeExpanded ? 250 : 150,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TomColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomText(
                          text: 'Expandable Content',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (_sizeExpanded) ...[
                          const TomSizedBox(height: 8),
                          TomText(
                            text:
                                'This additional content appears when expanded, and AnimatedSize smoothly animates the height change.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomFilledButton(
                  onPressed: () => setState(() => _sizeExpanded = !_sizeExpanded),
                  child: TomText(text: _sizeExpanded ? 'Collapse' : 'Expand'),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.size.hint',
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
  // Section 6: Transform Animations
  // ===========================================================================

  Widget _buildScaleSection() {
    return _DemoCard(
      tomId: 'demo18.scale',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.scale.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomExpanded(
                child: TomSlider(
                  value: _scale,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  onChanged: (v) => setState(() => _scale = v),
                  label: 'Scale: ${_scale.toStringAsFixed(1)}x',
                ),
              ),
              const TomSizedBox(width: 24),
              TomAnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.scale.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideSection() {
    return _DemoCard(
      tomId: 'demo18.slide',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.slide.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                Container(
                  width: 200,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: TomAnimatedSlide(
                      offset: _slideOffset,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutBack,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomWrap(
                  spacing: 8,
                  children: [
                    TomIconButton.filled(
                      onPressed: () => setState(
                        () => _slideOffset = const Offset(-0.5, 0),
                      ),
                      icon: const TomIcon(icon: Icons.arrow_back),
                    ),
                    TomIconButton.filled(
                      onPressed: () => setState(
                        () => _slideOffset = Offset.zero,
                      ),
                      icon: const TomIcon(icon: Icons.center_focus_strong),
                    ),
                    TomIconButton.filled(
                      onPressed: () => setState(
                        () => _slideOffset = const Offset(0.5, 0),
                      ),
                      icon: const TomIcon(icon: Icons.arrow_forward),
                    ),
                    TomIconButton.filled(
                      onPressed: () => setState(
                        () => _slideOffset = const Offset(0, -0.5),
                      ),
                      icon: const TomIcon(icon: Icons.arrow_upward),
                    ),
                    TomIconButton.filled(
                      onPressed: () => setState(
                        () => _slideOffset = const Offset(0, 0.5),
                      ),
                      icon: const TomIcon(icon: Icons.arrow_downward),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.slide.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationSection() {
    return _DemoCard(
      tomId: 'demo18.rotation',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.rotation.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomExpanded(
                child: TomSlider(
                  value: _turns,
                  min: 0,
                  max: 2,
                  onChanged: (v) => setState(() => _turns = v),
                  label: 'Turns: ${_turns.toStringAsFixed(2)}',
                ),
              ),
              const TomSizedBox(width: 24),
              TomAnimatedRotation(
                turns: _turns,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.rotate_right,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),
          TomWrap(
            spacing: 8,
            children: [
              TomFilledButton(tonal: true,
                onPressed: () => setState(() => _turns = 0),
                child: const TomText(text: '0°'),
              ),
              TomFilledButton(tonal: true,
                onPressed: () => setState(() => _turns = 0.25),
                child: const TomText(text: '90°'),
              ),
              TomFilledButton(tonal: true,
                onPressed: () => setState(() => _turns = 0.5),
                child: const TomText(text: '180°'),
              ),
              TomFilledButton(tonal: true,
                onPressed: () => setState(() => _turns = 1),
                child: const TomText(text: '360°'),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.rotation.hint',
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
  // Section 7: Text & Physical Model
  // ===========================================================================

  Widget _buildTextStyleSection() {
    return _DemoCard(
      tomId: 'demo18.textStyle',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.textStyle.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomAnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: _boldText
                      ? Theme.of(context).textTheme.headlineMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 2,
                          )
                      : Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                  child: const Text('Animated Text Style'),
                ),
                const TomSizedBox(height: 16),
                TomSwitch(
                  value: _boldText,
                  onChanged: (v) => setState(() => _boldText = v),
                ),
                const TomSizedBox(height: 8),
                TomText(
                  text: _boldText ? 'Bold & Large' : 'Normal',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.textStyle.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalModelSection() {
    return _DemoCard(
      tomId: 'demo18.physicalModel',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.physicalModel.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomExpanded(
                child: TomSlider(
                  value: _elevation,
                  min: 0,
                  max: 24,
                  divisions: 24,
                  onChanged: (v) => setState(() => _elevation = v),
                  label: 'Elevation: ${_elevation.toInt()}',
                ),
              ),
              const TomSizedBox(width: 24),
              TomAnimatedPhysicalModel(
                duration: const Duration(milliseconds: 300),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(16),
                elevation: _elevation,
                color: Theme.of(context).colorScheme.surface,
                shadowColor: Theme.of(context).colorScheme.shadow,
                child: Container(
                  width: 100,
                  height: 100,
                  alignment: Alignment.center,
                  child: TomColumn(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.layers,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const TomSizedBox(height: 4),
                      TomText(
                        text: '${_elevation.toInt()}dp',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.physicalModel.hint',
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
  // Section 8: Transition Widgets
  // ===========================================================================

  Widget _buildFadeTransitionSection() {
    return _DemoCard(
      tomId: 'demo18.fadeTransition',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.fadeTransition.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomFadeTransition(
                  opacity: _fadeController,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.gradient,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TomFilledButton(tonal: true,
                      onPressed: () => _fadeController.forward(),
                      child: const TomText(text: 'Fade In'),
                    ),
                    const TomSizedBox(width: 8),
                    TomFilledButton(tonal: true,
                      onPressed: () => _fadeController.reverse(),
                      child: const TomText(text: 'Fade Out'),
                    ),
                    const TomSizedBox(width: 8),
                    TomIconButton.filledTonal(
                      onPressed: () {
                        if (_fadeController.isCompleted) {
                          _fadeController.reverse();
                        } else {
                          _fadeController.forward();
                        }
                      },
                      icon: const TomIcon(icon: Icons.replay),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.fadeTransition.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleTransitionSection() {
    return _DemoCard(
      tomId: 'demo18.scaleTransition',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.scaleTransition.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomScaleTransition(
                  scale: CurvedAnimation(
                    parent: _scaleController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.zoom_out_map,
                      size: 40,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TomFilledButton(tonal: true,
                      onPressed: () => _scaleController.forward(),
                      child: const TomText(text: 'Scale Up'),
                    ),
                    const TomSizedBox(width: 8),
                    TomFilledButton(tonal: true,
                      onPressed: () => _scaleController.reverse(),
                      child: const TomText(text: 'Scale Down'),
                    ),
                    const TomSizedBox(width: 8),
                    TomIconButton.filledTonal(
                      onPressed: () => _scaleController
                        ..reset()
                        ..forward(),
                      icon: const TomIcon(icon: Icons.replay),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.scaleTransition.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationTransitionSection() {
    return _DemoCard(
      tomId: 'demo18.rotationTransition',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.rotationTransition.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          Center(
            child: TomColumn(
              children: [
                TomRotationTransition(
                  turns: CurvedAnimation(
                    parent: _rotationController,
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sync,
                      size: 40,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ),
                const TomSizedBox(height: 16),
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TomFilledButton(tonal: true,
                      onPressed: () => _rotationController.forward(),
                      child: const TomText(text: 'Rotate'),
                    ),
                    const TomSizedBox(width: 8),
                    TomFilledButton(tonal: true,
                      onPressed: () => _rotationController.reverse(),
                      child: const TomText(text: 'Reverse'),
                    ),
                    const TomSizedBox(width: 8),
                    TomFilledButton(tonal: true,
                      onPressed: () => _rotationController.repeat(),
                      child: const TomText(text: 'Loop'),
                    ),
                    const TomSizedBox(width: 8),
                    TomIconButton.filledTonal(
                      onPressed: () => _rotationController.stop(),
                      icon: const TomIcon(icon: Icons.stop),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.rotationTransition.hint',
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
  // Section 9: Hero Transitions
  // ===========================================================================

  Widget _buildHeroSection() {
    final heroItems = [
      _HeroItem(
        'Nature',
        Icons.landscape,
        Theme.of(context).colorScheme.primary,
      ),
      _HeroItem(
        'City',
        Icons.location_city,
        Theme.of(context).colorScheme.secondary,
      ),
      _HeroItem(
        'Travel',
        Icons.flight,
        Theme.of(context).colorScheme.tertiary,
      ),
    ];

    return _DemoCard(
      tomId: 'demo18.hero',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo18.hero.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 16),
          TomAnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showHeroDetail
                ? _buildHeroDetail(heroItems[_selectedHeroIndex])
                : _buildHeroGrid(heroItems),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo18.hero.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroGrid(List<_HeroItem> items) {
    return TomRow(
      key: const ValueKey('grid'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        items.length,
        (index) => GestureDetector(
          onTap: () => setState(() {
            _selectedHeroIndex = index;
            _showHeroDetail = true;
          }),
          child: TomHero(
            tag: 'hero_$index',
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: items[index].color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: items[index].color, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[index].icon, color: items[index].color),
                  const SizedBox(height: 4),
                  Text(
                    items[index].label,
                    style: TextStyle(
                      fontSize: 10,
                      color: items[index].color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDetail(_HeroItem item) {
    return Container(
      key: const ValueKey('detail'),
      padding: const EdgeInsets.all(16),
      child: TomColumn(
        children: [
          TomHero(
            tag: 'hero_$_selectedHeroIndex',
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: item.color, width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 64, color: item.color),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 16),
          TomText(
            text: 'Details for ${item.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const TomSizedBox(height: 8),
          TomText(
            text: 'Hero animations create smooth transitions between shared elements.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const TomSizedBox(height: 16),
          TomFilledButton(tonal: true,
            onPressed: () => setState(() => _showHeroDetail = false),
            child: const TomText(text: 'Back to Grid'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Classes
// =============================================================================

class _HeroItem {
  final String label;
  final IconData icon;
  final Color color;

  _HeroItem(this.label, this.icon, this.color);
}

/// Grid painter for AnimatedPositioned demo.
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (var x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

// =============================================================================
// Section Header & Demo Card (Local Helpers)
// =============================================================================

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
