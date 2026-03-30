/// Demo 07: Layout Containers
///
/// Comprehensive demonstration of Tom layout container widgets for
/// flex layouts, stack positioning, size constraints, and alignment.
/// Widgets covered: TomColumn, TomRow, TomExpanded, TomFlexible, TomSpacer,
/// TomWrap, TomStack, TomPositioned, TomPositionedDirectional, TomIndexedStack,
/// TomSizedBox, TomConstrainedBox, TomFractionallySizedBox, TomAspectRatio,
/// TomFittedBox, TomIntrinsicHeight, TomIntrinsicWidth, TomLimitedBox,
/// TomUnconstrainedBox, TomOverflowBox, TomCenter, TomAlign, TomPadding,
/// TomBaseline, TomDivider, TomVerticalDivider.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Layout Containers demo.
class LayoutContainersDemo extends StatelessWidget {
  const LayoutContainersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LayoutDemoContent();
  }
}

class _LayoutDemoContent extends StatefulWidget {
  const _LayoutDemoContent();

  @override
  State<_LayoutDemoContent> createState() => _LayoutDemoContentState();
}

class _LayoutDemoContentState extends State<_LayoutDemoContent> {
  // ===========================================================================
  // Section 2: Stack & Positioned state
  // ===========================================================================
  int _indexedStackIndex = 0;

  // ===========================================================================
  // Section 5: ACL state
  // ===========================================================================
  MainAxisAlignment _aclMainAxis = MainAxisAlignment.start;
  CrossAxisAlignment _aclCrossAxis = CrossAxisAlignment.start;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Flex Layouts
            _SectionHeader(tomId: 'demo07.section.flex'),
            const TomSizedBox(height: 16),
            _buildColumnSection(),
            const TomSizedBox(height: 24),
            _buildRowSection(),
            const TomSizedBox(height: 24),
            _buildExpandedFlexibleSection(),
            const TomSizedBox(height: 24),
            _buildSpacerSection(),
            const TomSizedBox(height: 24),
            _buildWrapSection(),
            const TomSizedBox(height: 32),

            // Section 2: Stack & Positioned
            _SectionHeader(tomId: 'demo07.section.stack'),
            const TomSizedBox(height: 16),
            _buildStackSection(),
            const TomSizedBox(height: 24),
            _buildPositionedSection(),
            const TomSizedBox(height: 24),
            _buildIndexedStackSection(),
            const TomSizedBox(height: 32),

            // Section 3: Size & Constraint Widgets
            _SectionHeader(tomId: 'demo07.section.size'),
            const TomSizedBox(height: 16),
            _buildSizedBoxSection(),
            const TomSizedBox(height: 24),
            _buildConstrainedBoxSection(),
            const TomSizedBox(height: 24),
            _buildFractionallySizedBoxSection(),
            const TomSizedBox(height: 24),
            _buildAspectRatioSection(),
            const TomSizedBox(height: 24),
            _buildFittedBoxSection(),
            const TomSizedBox(height: 24),
            _buildIntrinsicSection(),
            const TomSizedBox(height: 24),
            _buildMiscConstraintSection(),
            const TomSizedBox(height: 32),

            // Section 4: Alignment & Spacing
            _SectionHeader(tomId: 'demo07.section.alignment'),
            const TomSizedBox(height: 16),
            _buildCenterAlignSection(),
            const TomSizedBox(height: 24),
            _buildPaddingSection(),
            const TomSizedBox(height: 24),
            _buildBaselineSection(),
            const TomSizedBox(height: 24),
            _buildDividerSection(),
            const TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo
            _SectionHeader(tomId: 'demo07.section.acl'),
            const TomSizedBox(height: 16),
            _buildAclLayoutSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Flex Layouts
  // ===========================================================================

  Widget _buildColumnSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.column',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column with different alignments
          TomText(tomId: 'demo07.column.startLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomColumn(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildColorBox('A', theme.colorScheme.primary),
                _buildColorBox('B', theme.colorScheme.secondary),
                _buildColorBox('C', theme.colorScheme.tertiary),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.column.centerLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomColumn(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildColorBox('A', theme.colorScheme.primary),
                _buildColorBox('B', theme.colorScheme.secondary),
                _buildColorBox('C', theme.colorScheme.tertiary),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.column.spaceBetweenLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomColumn(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildColorBox('A', theme.colorScheme.primary),
                _buildColorBox('B', theme.colorScheme.secondary),
                _buildColorBox('C', theme.colorScheme.tertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.row',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.row.startLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildColorBox('1', theme.colorScheme.primary),
                _buildColorBox('2', theme.colorScheme.secondary),
                _buildColorBox('3', theme.colorScheme.tertiary),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.row.spaceEvenlyLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorBox('1', theme.colorScheme.primary),
                _buildColorBox('2', theme.colorScheme.secondary),
                _buildColorBox('3', theme.colorScheme.tertiary),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.row.endLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildColorBox('1', theme.colorScheme.primary),
                _buildColorBox('2', theme.colorScheme.secondary),
                _buildColorBox('3', theme.colorScheme.tertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedFlexibleSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.expandedFlexible',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed + Expanded
          TomText(tomId: 'demo07.expandedFlexible.fixedExpandedLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 40,
            child: TomRow(
              children: [
                TomContainer(
                  width: 60,
                  color: theme.colorScheme.primary,
                  child: TomCenter(
                    child: TomText(
                      text: 'Fixed',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(width: 4),
                TomExpanded(
                  child: TomContainer(
                    color: theme.colorScheme.secondary,
                    child: TomCenter(
                      child: TomText(
                        text: 'Expanded',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          // Flex ratios
          TomText(tomId: 'demo07.expandedFlexible.flexRatioLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 40,
            child: TomRow(
              children: [
                TomExpanded(
                  child: TomContainer(
                    color: theme.colorScheme.primary,
                    child: TomCenter(
                      child: TomText(
                        text: 'flex: 1',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(width: 4),
                TomExpanded(
                  flex: 2,
                  child: TomContainer(
                    color: theme.colorScheme.secondary,
                    child: TomCenter(
                      child: TomText(
                        text: 'flex: 2',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(width: 4),
                TomExpanded(
                  flex: 3,
                  child: TomContainer(
                    color: theme.colorScheme.tertiary,
                    child: TomCenter(
                      child: TomText(
                        text: 'flex: 3',
                        style: TextStyle(
                          color: theme.colorScheme.onTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          // Flexible with FlexFit
          TomText(tomId: 'demo07.expandedFlexible.flexibleLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 40,
            child: TomRow(
              children: [
                TomFlexible(
                  fit: FlexFit.loose,
                  child: TomContainer(
                    width: 80,
                    color: theme.colorScheme.primaryContainer,
                    child: TomCenter(
                      child: TomText(
                        text: 'Loose',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(width: 4),
                TomFlexible(
                  fit: FlexFit.tight,
                  child: TomContainer(
                    color: theme.colorScheme.secondaryContainer,
                    child: TomCenter(
                      child: TomText(
                        text: 'Tight',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacerSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.spacer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.spacer.demoLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 40,
            child: TomRow(
              children: [
                TomContainer(
                  width: 60,
                  color: theme.colorScheme.primary,
                  child: TomCenter(
                    child: TomText(
                      text: 'Left',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const TomSpacer(),
                TomContainer(
                  width: 60,
                  color: theme.colorScheme.tertiary,
                  child: TomCenter(
                    child: TomText(
                      text: 'Right',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.spacer.ratioLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 40,
            child: TomRow(
              children: [
                TomContainer(
                  width: 60,
                  color: theme.colorScheme.primary,
                  child: TomCenter(
                    child: TomText(
                      text: 'A',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const TomSpacer(),
                TomContainer(
                  width: 60,
                  color: theme.colorScheme.secondary,
                  child: TomCenter(
                    child: TomText(
                      text: 'B',
                      style: TextStyle(
                        color: theme.colorScheme.onSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const TomSpacer(flex: 2),
                TomContainer(
                  width: 60,
                  color: theme.colorScheme.tertiary,
                  child: TomCenter(
                    child: TomText(
                      text: 'C',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrapSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.wrap',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.wrap.demoLabel'),
          const TomSizedBox(height: 8),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(12, (i) {
              final colors = [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                theme.colorScheme.tertiary,
                theme.colorScheme.error,
              ];
              return TomContainer(
                width: 60 + (i % 3) * 20,
                height: 32,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TomCenter(
                  child: TomText(
                    text: 'Tag ${i + 1}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Stack & Positioned
  // ===========================================================================

  Widget _buildStackSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.stack',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.stack.layeredLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 150,
            width: double.infinity,
            child: TomStack(
              children: [
                // Background layer
                TomContainer(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Middle layer
                TomCenter(
                  child: TomContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: TomText(
                      tomId: 'demo07.stack.centeredText',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                // Top layer: badge
                TomPositioned(
                  top: 8,
                  right: 8,
                  child: TomContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TomText(
                      text: '3',
                      style: TextStyle(
                        color: theme.colorScheme.onError,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionedSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.positioned',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.positioned.cornersLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 160,
            width: double.infinity,
            child: TomStack(
              children: [
                TomContainer(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                TomPositioned(
                  top: 8,
                  left: 8,
                  child: _buildPositionLabel('TL', theme.colorScheme.primary),
                ),
                TomPositioned(
                  top: 8,
                  right: 8,
                  child: _buildPositionLabel('TR', theme.colorScheme.secondary),
                ),
                TomPositioned(
                  bottom: 8,
                  left: 8,
                  child: _buildPositionLabel('BL', theme.colorScheme.tertiary),
                ),
                TomPositioned(
                  bottom: 8,
                  right: 8,
                  child: _buildPositionLabel('BR', theme.colorScheme.error),
                ),
                TomCenter(
                  child:
                      _buildPositionLabel('C', theme.colorScheme.inverseSurface),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          // PositionedDirectional
          TomText(tomId: 'demo07.positioned.directionalLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 80,
            width: double.infinity,
            child: TomStack(
              children: [
                TomContainer(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                TomPositionedDirectional(
                  start: 8,
                  top: 8,
                  child: _buildPositionLabel(
                    'Start',
                    theme.colorScheme.primary,
                  ),
                ),
                TomPositionedDirectional(
                  end: 8,
                  bottom: 8,
                  child: _buildPositionLabel(
                    'End',
                    theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexedStackSection() {
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];
    final labels = ['Page A', 'Page B', 'Page C', 'Page D'];

    return _DemoCard(
      tomId: 'demo07.indexedStack',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.indexedStack.selectorLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              return TomPadding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TomFilledButton(
                  tonal: _indexedStackIndex != i,
                  onPressed: () => setState(() => _indexedStackIndex = i),
                  child: TomText(text: '$i'),
                ),
              );
            }),
          ),
          const TomSizedBox(height: 12),
          TomSizedBox(
            height: 80,
            width: double.infinity,
            child: TomIndexedStack(
              index: _indexedStackIndex,
              children: List.generate(4, (i) {
                return TomContainer(
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors[i]),
                  ),
                  child: TomCenter(
                    child: TomText(
                      text: labels[i],
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors[i],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Size & Constraint Widgets
  // ===========================================================================

  Widget _buildSizedBoxSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.sizedBox',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.sizedBox.fixedLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomSizedBox(
                width: 100,
                height: 50,
                child: TomContainer(
                  color: theme.colorScheme.primaryContainer,
                  child: TomCenter(
                    child: TomText(
                      text: '100×50',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 8),
              TomSizedBox(
                width: 60,
                height: 60,
                child: TomContainer(
                  color: theme.colorScheme.secondaryContainer,
                  child: TomCenter(
                    child: TomText(
                      text: '60×60',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.sizedBox.expandLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            width: double.infinity,
            height: 40,
            child: TomContainer(
              color: theme.colorScheme.tertiaryContainer,
              child: TomCenter(
                child: TomText(
                  tomId: 'demo07.sizedBox.expandText',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstrainedBoxSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.constrainedBox',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.constrainedBox.demoLabel'),
          const TomSizedBox(height: 8),
          TomConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 100,
              maxWidth: 300,
              minHeight: 50,
            ),
            child: TomContainer(
              color: theme.colorScheme.primaryContainer,
              child: TomPadding(
                padding: const EdgeInsets.all(12),
                child: TomText(
                  tomId: 'demo07.constrainedBox.contentText',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFractionallySizedBoxSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.fractionallySized',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.fractionallySized.demoLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomFractionallySizedBox(
              widthFactor: 0.8,
              child: TomContainer(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TomCenter(
                  child: TomText(
                    text: '80%',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomFractionallySizedBox(
              widthFactor: 0.5,
              child: TomContainer(
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TomCenter(
                  child: TomText(
                    text: '50%',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectRatioSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.aspectRatio',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.aspectRatio.demoLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomExpanded(
                flex: 3,
                child: TomAspectRatio(
                  aspectRatio: 16 / 9,
                  child: TomContainer(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TomCenter(
                      child: TomText(
                        text: '16:9',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 12),
              TomExpanded(
                flex: 2,
                child: TomAspectRatio(
                  aspectRatio: 1,
                  child: TomContainer(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TomCenter(
                      child: TomText(
                        text: '1:1',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFittedBoxSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.fittedBox',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.fittedBox.demoLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomExpanded(
                child: TomSizedBox(
                  height: 60,
                  child: TomFittedBox(
                    fit: BoxFit.contain,
                    child: TomText(
                      text: 'Contain',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomSizedBox(
                  height: 60,
                  child: TomFittedBox(
                    fit: BoxFit.scaleDown,
                    child: TomText(
                      text: 'Scale Down',
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntrinsicSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.intrinsic',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.intrinsic.heightLabel'),
          const TomSizedBox(height: 8),
          TomIntrinsicHeight(
            child: TomRow(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TomExpanded(
                  child: TomContainer(
                    color: theme.colorScheme.primaryContainer,
                    child: TomCenter(
                      child: TomText(
                        tomId: 'demo07.intrinsic.shortText',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(width: 4),
                TomExpanded(
                  child: TomContainer(
                    color: theme.colorScheme.secondaryContainer,
                    child: TomPadding(
                      padding: const EdgeInsets.all(12),
                      child: TomText(
                        tomId: 'demo07.intrinsic.tallText',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo07.intrinsic.widthLabel'),
          const TomSizedBox(height: 8),
          TomIntrinsicWidth(
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TomContainer(
                  color: theme.colorScheme.tertiaryContainer,
                  child: TomPadding(
                    padding: const EdgeInsets.all(8),
                    child: TomText(
                      tomId: 'demo07.intrinsic.wideText',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(height: 4),
                TomContainer(
                  color: theme.colorScheme.primaryContainer,
                  child: TomPadding(
                    padding: const EdgeInsets.all(8),
                    child: TomText(
                      text: 'Short',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiscConstraintSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.miscConstraint',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LimitedBox
          TomText(tomId: 'demo07.miscConstraint.limitedLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomLimitedBox(
                maxWidth: 100,
                maxHeight: 40,
                child: TomContainer(
                  color: theme.colorScheme.primaryContainer,
                  child: TomCenter(
                    child: TomText(
                      text: 'Limited',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // OverflowBox
          TomText(tomId: 'demo07.miscConstraint.overflowLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 60,
            width: double.infinity,
            child: TomContainer(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.hardEdge,
              child: TomOverflowBox(
                maxWidth: 400,
                maxHeight: 80,
                child: TomContainer(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.5,
                  ),
                  child: TomCenter(
                    child: TomText(
                      tomId: 'demo07.miscConstraint.overflowText',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Alignment & Spacing
  // ===========================================================================

  Widget _buildCenterAlignSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.centerAlign',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TomCenter
          TomText(tomId: 'demo07.centerAlign.centerLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomCenter(
              child: TomContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TomText(
                  tomId: 'demo07.centerAlign.centeredText',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // TomAlign with various alignments
          TomText(tomId: 'demo07.centerAlign.alignLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomStack(
              children: [
                TomAlign(
                  alignment: Alignment.topLeft,
                  child: _buildAlignLabel('topLeft', theme),
                ),
                TomAlign(
                  alignment: Alignment.topRight,
                  child: _buildAlignLabel('topRight', theme),
                ),
                TomAlign(
                  alignment: Alignment.center,
                  child: _buildAlignLabel('center', theme),
                ),
                TomAlign(
                  alignment: Alignment.bottomLeft,
                  child: _buildAlignLabel('bottomLeft', theme),
                ),
                TomAlign(
                  alignment: Alignment.bottomRight,
                  child: _buildAlignLabel('bottomRight', theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaddingSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.padding',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.padding.uniformLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomContainer(
                color: theme.colorScheme.primaryContainer,
                child: TomPadding(
                  padding: const EdgeInsets.all(12),
                  child: TomText(
                    text: 'all(16)',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 12),

          TomText(tomId: 'demo07.padding.symmetricLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 8,
              ),
              child: TomContainer(
                color: theme.colorScheme.secondaryContainer,
                child: TomPadding(
                  padding: const EdgeInsets.all(12),
                  child: TomText(
                    text: 'symmetric(h: 32, v: 8)',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 12),

          TomText(tomId: 'demo07.padding.onlyLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomPadding(
              padding: const EdgeInsets.only(left: 40, top: 20),
              child: TomContainer(
                color: theme.colorScheme.tertiaryContainer,
                child: TomPadding(
                  padding: const EdgeInsets.all(12),
                  child: TomText(
                    text: 'only(left: 40, top: 20)',
                    style: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.baseline',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo07.baseline.demoLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TomText(
                  text: 'Big',
                  style: TextStyle(
                    fontSize: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const TomSizedBox(width: 12),
                TomText(
                  text: 'Medium',
                  style: TextStyle(
                    fontSize: 20,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const TomSizedBox(width: 12),
                TomText(
                  text: 'Small',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo07.divider',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal dividers
          TomText(tomId: 'demo07.divider.horizontalLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomPadding(
              padding: const EdgeInsets.all(12),
              child: TomColumn(
                children: [
                  TomText(
                    tomId: 'demo07.divider.section1',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const TomDivider(),
                  TomText(
                    tomId: 'demo07.divider.section2',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TomDivider(
                    thickness: 2,
                    color: theme.colorScheme.primary,
                    indent: 16,
                    endIndent: 16,
                  ),
                  TomText(
                    tomId: 'demo07.divider.section3',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Vertical dividers
          TomText(tomId: 'demo07.divider.verticalLabel'),
          const TomSizedBox(height: 8),
          TomSizedBox(
            height: 48,
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TomText(
                  tomId: 'demo07.divider.col1',
                  style: theme.textTheme.bodyMedium,
                ),
                const TomVerticalDivider(),
                TomText(
                  tomId: 'demo07.divider.col2',
                  style: theme.textTheme.bodyMedium,
                ),
                TomVerticalDivider(
                  thickness: 2,
                  color: theme.colorScheme.primary,
                ),
                TomText(
                  tomId: 'demo07.divider.col3',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo
  // ===========================================================================

  Widget _buildAclLayoutSection() {
    final theme = Theme.of(context);
    final mainAxisOptions = MainAxisAlignment.values;
    final crossAxisOptions = CrossAxisAlignment.values;

    return _DemoCard(
      tomId: 'demo07.aclLayout',
      child: AclBuilder()
          // Row 1: Main axis alignment selector
          .append(TomText(tomId: 'demo07.aclLayout.mainAxisLabel'))
          .append(
            TomExpanded(
              child: TomWrap(
                spacing: 4,
                runSpacing: 4,
                children: mainAxisOptions.map((alignment) {
                  final isSelected = alignment == _aclMainAxis;
                  return TomFilledButton(
                    tonal: !isSelected,
                    onPressed: () =>
                        setState(() => _aclMainAxis = alignment),
                    child: TomText(
                      text: alignment.name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            ),
            dist: 8,
          )
          .newRow(dist: 12)
          // Row 2: Cross axis alignment selector
          .append(TomText(tomId: 'demo07.aclLayout.crossAxisLabel'))
          .append(
            TomExpanded(
              child: TomWrap(
                spacing: 4,
                runSpacing: 4,
                children: crossAxisOptions.map((alignment) {
                  final isSelected = alignment == _aclCrossAxis;
                  return TomFilledButton(
                    tonal: !isSelected,
                    onPressed: () =>
                        setState(() => _aclCrossAxis = alignment),
                    child: TomText(
                      text: alignment.name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            ),
            dist: 8,
          )
          .newRow(dist: 16)
          // Row 3: Preview
          .append(
            TomExpanded(
              child: TomContainer(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomRow(
                  mainAxisAlignment: _aclMainAxis,
                  crossAxisAlignment: _aclCrossAxis,
                  children: [
                    _buildColorBox('A', theme.colorScheme.primary, size: 30),
                    _buildColorBox('B', theme.colorScheme.secondary, size: 45),
                    _buildColorBox('C', theme.colorScheme.tertiary, size: 35),
                  ],
                ),
              ),
            ),
          )
          .newRow(dist: 12)
          // Row 4: Reset button
          .append(
            TomTextButton(
              tomId: 'demo07.aclLayout.reset',
              onPressed: () {
                setState(() {
                  _aclMainAxis = MainAxisAlignment.start;
                  _aclCrossAxis = CrossAxisAlignment.start;
                });
              },
            ),
          )
          .gap()
          .append(
            TomFilledButton(
              tomId: 'demo07.aclLayout.apply',
              onPressed: () {},
            ),
            dist: 8,
          )
          .build(),
    );
  }

  // ===========================================================================
  // Helper methods
  // ===========================================================================

  Widget _buildColorBox(String label, Color color, {double size = 24}) {
    return TomContainer(
      width: size,
      height: size,
      color: color,
      child: TomCenter(
        child: TomText(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size > 30 ? 12 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPositionLabel(String text, Color color) {
    return TomContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: TomText(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAlignLabel(String text, ThemeData theme) {
    return TomPadding(
      padding: const EdgeInsets.all(4),
      child: TomText(
        text: text,
        style: TextStyle(
          fontSize: 10,
          color: theme.colorScheme.primary,
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
      elevation: 2,
      child: TomPadding(
        padding: const EdgeInsets.all(20),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomContainer(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomIcon(
                    tomId: '$tomId.icon',
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.description',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 16),
            TomDivider(color: theme.colorScheme.outlineVariant),
            const TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
