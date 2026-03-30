/// Demo 21: Resource Resolution — Visual Styling Parameters
///
/// Demonstrates that visual styling parameters like padding, colors, textStyle,
/// elevation, etc. can be resolved from resources using tomId.
///
/// All text in this demo is resolved from resources to demonstrate
/// the complete resource resolution pattern.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Resource Resolution demo.
class ResourceResolutionDemo extends StatelessWidget {
  const ResourceResolutionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ResourceResolutionDemoContent();
  }
}

class _ResourceResolutionDemoContent extends StatefulWidget {
  const _ResourceResolutionDemoContent();

  @override
  State<_ResourceResolutionDemoContent> createState() =>
      _ResourceResolutionDemoContentState();
}

class _ResourceResolutionDemoContentState
    extends State<_ResourceResolutionDemoContent> {
  // State for toggle demos
  bool _switchValue1 = true;
  bool _switchValue2 = false;
  bool _checkboxValue1 = true;
  bool _checkboxValue2 = false;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _SectionHeader(tomId: 'demo21.section.intro'),
            const TomSizedBox(height: 16),
            _buildIntroCard(),
            const TomSizedBox(height: 32),

            // Section 1: Container Parameters
            _SectionHeader(tomId: 'demo21.section.container'),
            const TomSizedBox(height: 16),
            _buildContainerSection(),
            const TomSizedBox(height: 32),

            // Section 2: Text Style Parameters
            _SectionHeader(tomId: 'demo21.section.textStyle'),
            const TomSizedBox(height: 16),
            _buildTextStyleSection(),
            const TomSizedBox(height: 32),

            // Section 3: Color Parameters
            _SectionHeader(tomId: 'demo21.section.colors'),
            const TomSizedBox(height: 16),
            _buildColorSection(),
            const TomSizedBox(height: 32),

            // Section 4: Numeric Parameters
            _SectionHeader(tomId: 'demo21.section.numeric'),
            const TomSizedBox(height: 16),
            _buildNumericSection(),
            const TomSizedBox(height: 32),

            // Section 5: Toggle Widget Colors
            _SectionHeader(tomId: 'demo21.section.toggle'),
            const TomSizedBox(height: 16),
            _buildToggleSection(),
            const TomSizedBox(height: 32),

            // Section 6: Type Lookup Coverage
            _SectionHeader(tomId: 'demo21.section.lookup'),
            const TomSizedBox(height: 16),
            _buildLookupCoverageSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Introduction
  // ===========================================================================

  Widget _buildIntroCard() {
    return _DemoCard(
      tomId: 'demo21.intro',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo21.intro.explanation'),
          const TomSizedBox(height: 12),
          TomText(tomId: 'demo21.intro.formats'),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 1: Container Parameters (padding, margin, color, size)
  // ===========================================================================

  Widget _buildContainerSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Container with padding from resources
        _DemoCard(
          tomId: 'demo21.paddingDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.paddingDemo.info'),
              const TomSizedBox(height: 12),
              TomContainer(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: TomContainer(
                  tomId: 'demo21.paddedBox',
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomText(tomId: 'demo21.paddedBox.content'),
                ),
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Container with dimensions from resources
        _DemoCard(
          tomId: 'demo21.sizeDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.sizeDemo.info'),
              const TomSizedBox(height: 12),
              TomContainer(
                tomId: 'demo21.sizedBox',
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomCenter(child: TomText(tomId: 'demo21.sizedBox.content')),
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Container with margin from resources
        _DemoCard(
          tomId: 'demo21.marginDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.marginDemo.info'),
              const TomSizedBox(height: 12),
              TomContainer(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(4),
                child: TomContainer(
                  tomId: 'demo21.marginedBox',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomText(tomId: 'demo21.marginedBox.content'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 2: Text Style Parameters
  // ===========================================================================

  Widget _buildTextStyleSection() {
    return _DemoCard(
      tomId: 'demo21.textStyleDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo21.textStyleDemo.info'),
          const TomSizedBox(height: 16),

          // Styled text 1: Large bold blue
          TomAnimatedDefaultTextStyle(
            tomId: 'demo21.styledText1',
            style: const TextStyle(fontSize: 12), // Fallback if no resource
            duration: const Duration(milliseconds: 300),
            child: TomText(tomId: 'demo21.styledText1.content'),
          ),
          const TomSizedBox(height: 12),

          // Styled text 2: Italic purple
          TomAnimatedDefaultTextStyle(
            tomId: 'demo21.styledText2',
            style: const TextStyle(fontSize: 12),
            duration: const Duration(milliseconds: 300),
            child: TomText(tomId: 'demo21.styledText2.content'),
          ),
          const TomSizedBox(height: 12),

          // Styled text 3: Spaced green
          TomAnimatedDefaultTextStyle(
            tomId: 'demo21.styledText3',
            style: const TextStyle(fontSize: 12),
            duration: const Duration(milliseconds: 300),
            child: TomText(tomId: 'demo21.styledText3.content'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Color Parameters
  // ===========================================================================

  Widget _buildColorSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon colors
        _DemoCard(
          tomId: 'demo21.iconColorDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.iconColorDemo.info'),
              const TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomIcon(tomId: 'demo21.coloredIcon1', size: 32),
                  const TomSizedBox(width: 16),
                  TomIcon(tomId: 'demo21.coloredIcon2', size: 32),
                  const TomSizedBox(width: 16),
                  TomIcon(tomId: 'demo21.coloredIcon3', size: 32),
                  const TomSizedBox(width: 16),
                  TomIcon(tomId: 'demo21.coloredIcon4', size: 32),
                ],
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Container colors from resources
        _DemoCard(
          tomId: 'demo21.containerColorDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.containerColorDemo.info'),
              const TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomExpanded(
                    child: TomContainer(
                      tomId: 'demo21.colorBox1',
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomCenter(
                        child: TomText(
                          tomId: 'demo21.colorBox1.content',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomContainer(
                      tomId: 'demo21.colorBox2',
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomCenter(
                        child: TomText(
                          tomId: 'demo21.colorBox2.content',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomContainer(
                      tomId: 'demo21.colorBox3',
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomCenter(
                        child: TomText(
                          tomId: 'demo21.colorBox3.content',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Progress indicator colors
        _DemoCard(
          tomId: 'demo21.progressColorDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.progressColorDemo.info'),
              const TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomCircularProgressIndicator(tomId: 'demo21.progress1', value: 0.7),
                  const TomSizedBox(width: 24),
                  TomCircularProgressIndicator(tomId: 'demo21.progress2', value: 0.5),
                  const TomSizedBox(width: 24),
                  TomExpanded(
                    child: TomLinearProgressIndicator(
                      tomId: 'demo21.progress3',
                      value: 0.6,
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 4: Numeric Parameters (elevation, size, opacity)
  // ===========================================================================

  Widget _buildNumericSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card elevation
        _DemoCard(
          tomId: 'demo21.elevationDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.elevationDemo.info'),
              const TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomExpanded(
                    child: TomCard(
                      tomId: 'demo21.card1',
                      child: TomPadding(
                        padding: const EdgeInsets.all(16),
                        child: TomText(tomId: 'demo21.card1.content'),
                      ),
                    ),
                  ),
                  const TomSizedBox(width: 16),
                  TomExpanded(
                    child: TomCard(
                      tomId: 'demo21.card2',
                      child: TomPadding(
                        padding: const EdgeInsets.all(16),
                        child: TomText(tomId: 'demo21.card2.content'),
                      ),
                    ),
                  ),
                  const TomSizedBox(width: 16),
                  TomExpanded(
                    child: TomCard(
                      tomId: 'demo21.card3',
                      child: TomPadding(
                        padding: const EdgeInsets.all(16),
                        child: TomText(tomId: 'demo21.card3.content'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Icon sizes
        _DemoCard(
          tomId: 'demo21.iconSizeDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.iconSizeDemo.info'),
              const TomSizedBox(height: 12),
              TomRow(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TomIcon(tomId: 'demo21.sizedIcon1'),
                  const TomSizedBox(width: 16),
                  TomIcon(tomId: 'demo21.sizedIcon2'),
                  const TomSizedBox(width: 16),
                  TomIcon(tomId: 'demo21.sizedIcon3'),
                ],
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Opacity
        _DemoCard(
          tomId: 'demo21.opacityDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'demo21.opacityDemo.info'),
              const TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomAnimatedOpacity(
                    tomId: 'demo21.opacity1',
                    duration: const Duration(milliseconds: 300),
                    child: TomContainer(
                      width: 60,
                      height: 60,
                      color: Theme.of(context).colorScheme.primary,
                      child: TomCenter(child: TomText(tomId: 'demo21.opacity1.content')),
                    ),
                  ),
                  const TomSizedBox(width: 16),
                  TomAnimatedOpacity(
                    tomId: 'demo21.opacity2',
                    duration: const Duration(milliseconds: 300),
                    child: TomContainer(
                      width: 60,
                      height: 60,
                      color: Theme.of(context).colorScheme.primary,
                      child: TomCenter(child: TomText(tomId: 'demo21.opacity2.content')),
                    ),
                  ),
                  const TomSizedBox(width: 16),
                  TomAnimatedOpacity(
                    tomId: 'demo21.opacity3',
                    duration: const Duration(milliseconds: 300),
                    child: TomContainer(
                      width: 60,
                      height: 60,
                      color: Theme.of(context).colorScheme.primary,
                      child: TomCenter(child: TomText(tomId: 'demo21.opacity3.content')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 5: Toggle Widget Colors
  // ===========================================================================

  Widget _buildToggleSection() {
    return _DemoCard(
      tomId: 'demo21.toggleDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo21.toggleDemo.info'),
          const TomSizedBox(height: 16),

          // Switches with colors from resources
          TomRow(
            children: [
              TomSwitch(
                tomId: 'demo21.switch1',
                value: _switchValue1,
                onChanged: (v) => setState(() => _switchValue1 = v),
              ),
              const TomSizedBox(width: 8),
              TomText(tomId: 'demo21.switch1.label'),
              const TomSizedBox(width: 32),
              TomSwitch(
                tomId: 'demo21.switch2',
                value: _switchValue2,
                onChanged: (v) => setState(() => _switchValue2 = v),
              ),
              const TomSizedBox(width: 8),
              TomText(tomId: 'demo21.switch2.label'),
            ],
          ),
          const TomSizedBox(height: 16),

          // Checkboxes with colors from resources
          TomRow(
            children: [
              TomCheckbox(
                tomId: 'demo21.checkbox1',
                value: _checkboxValue1,
                onChanged: (v) => setState(() => _checkboxValue1 = v ?? false),
              ),
              const TomSizedBox(width: 8),
              TomText(tomId: 'demo21.checkbox1.label'),
              const TomSizedBox(width: 32),
              TomCheckbox(
                tomId: 'demo21.checkbox2',
                value: _checkboxValue2,
                onChanged: (v) => setState(() => _checkboxValue2 = v ?? false),
              ),
              const TomSizedBox(width: 8),
              TomText(tomId: 'demo21.checkbox2.label'),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 6: Explicit Lookup Type Coverage
  // ===========================================================================

  Widget _buildLookupCoverageSection() {
    const basePath = 'demo21.lookup';

    final textValue = TomUIResources.resolveText(basePath, 'text');
    final colorValue = TomUIResources.resolveColor(basePath, 'color');
    final iconValue = TomUIResources.resolveIcon(basePath, 'icon');
    final doubleValue = TomUIResources.resolveDouble(basePath, 'double');
    final intValue = TomUIResources.resolveInt(basePath, 'int');
    final boolValue = TomUIResources.resolveBool(basePath, 'bool');
    final edgeInsetsValue = TomUIResources.resolveEdgeInsets(basePath, 'edgeInsets');
    final listValue = TomUIResources.resolveList(basePath, 'list');
    final mapValue = TomUIResources.resolveMap(basePath, 'map');

    final colorHex = colorValue == null
        ? 'null'
        : '#${colorValue.toARGB32().toRadixString(16).toUpperCase()}';

    return _DemoCard(
      tomId: 'demo21.lookupDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo21.lookupDemo.info'),
          const TomSizedBox(height: 12),
          if (iconValue != null)
            TomRow(
              children: [
                TomIcon(icon: iconValue, size: 18, color: colorValue),
                const TomSizedBox(width: 8),
                TomText(text: 'icon resolved: $iconValue'),
              ],
            )
          else
            const TomText(text: 'icon resolved: null'),
          const TomSizedBox(height: 8),
          TomText(text: 'text: $textValue'),
          TomText(text: 'color: $colorHex'),
          TomText(text: 'double: $doubleValue'),
          TomText(text: 'int: $intValue'),
          TomText(text: 'bool: $boolValue'),
          TomText(text: 'edgeInsets: $edgeInsetsValue'),
          TomText(text: 'list: $listValue'),
          TomText(text: 'map: $mapValue'),
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header with title and subtitle from resources.
class _SectionHeader extends StatelessWidget {
  final String tomId;

  const _SectionHeader({required this.tomId});

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

/// Demo card with title, subtitle, and icon from resources.
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
      margin: const EdgeInsets.only(bottom: 8),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomIcon(tomId: '$tomId.icon', size: 24),
                const TomSizedBox(width: 12),
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
            const TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
