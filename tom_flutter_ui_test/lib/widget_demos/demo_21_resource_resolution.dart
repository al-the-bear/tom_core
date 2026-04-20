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
class ResourceResolutionDemo extends TomStatelessWidget {
  ResourceResolutionDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ResourceResolutionDemoContent();

  }
}

class _ResourceResolutionDemoContent extends TomStatefulWidget {
  _ResourceResolutionDemoContent();

  @override
  State<_ResourceResolutionDemoContent> createState() =>
      _ResourceResolutionDemoContentState();
}

class _ResourceResolutionDemoContentState
    extends TomState<_ResourceResolutionDemoContent> {
  // State for toggle demos
  bool _switchValue1 = true;
  bool _switchValue2 = false;
  bool _checkboxValue1 = true;
  bool _checkboxValue2 = false;

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _SectionHeader(tomId: 'section.intro'),
            TomSizedBox(height: 16),
            _buildIntroCard(),
            TomSizedBox(height: 32),

            // Section 1: Container Parameters
            _SectionHeader(tomId: 'section.container'),
            TomSizedBox(height: 16),
            _buildContainerSection(),
            TomSizedBox(height: 32),

            // Section 2: Text Style Parameters
            _SectionHeader(tomId: 'section.textStyle'),
            TomSizedBox(height: 16),
            _buildTextStyleSection(),
            TomSizedBox(height: 32),

            // Section 3: Color Parameters
            _SectionHeader(tomId: 'section.colors'),
            TomSizedBox(height: 16),
            _buildColorSection(),
            TomSizedBox(height: 32),

            // Section 4: Numeric Parameters
            _SectionHeader(tomId: 'section.numeric'),
            TomSizedBox(height: 16),
            _buildNumericSection(),
            TomSizedBox(height: 32),

            // Section 5: Toggle Widget Colors
            _SectionHeader(tomId: 'section.toggle'),
            TomSizedBox(height: 16),
            _buildToggleSection(),
            TomSizedBox(height: 32),

            // Section 6: Type Lookup Coverage
            _SectionHeader(tomId: 'section.lookup'),
            TomSizedBox(height: 16),
            _buildLookupCoverageSection(),
            TomSizedBox(height: 48),
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
      tomId: 'intro',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'intro.explanation'),
          TomSizedBox(height: 12),
          TomText(tomId: 'intro.formats'),
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
          tomId: 'paddingDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'paddingDemo.info'),
              TomSizedBox(height: 12),
              TomContainer(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: TomContainer(
                  tomId: 'paddedBox',
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomText(tomId: 'paddedBox.content'),
                ),
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // Container with dimensions from resources
        _DemoCard(
          tomId: 'sizeDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'sizeDemo.info'),
              TomSizedBox(height: 12),
              TomContainer(
                tomId: 'sizedBox',
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomCenter(child: TomText(tomId: 'sizedBox.content')),
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // Container with margin from resources
        _DemoCard(
          tomId: 'marginDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'marginDemo.info'),
              TomSizedBox(height: 12),
              TomContainer(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(4),
                child: TomContainer(
                  tomId: 'marginedBox',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomText(tomId: 'marginedBox.content'),
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
      tomId: 'textStyleDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'textStyleDemo.info'),
          TomSizedBox(height: 16),

          // Styled text 1: Large bold blue
          TomAnimatedDefaultTextStyle(
            tomId: 'styledText1',
            style: const TextStyle(fontSize: 12), // Fallback if no resource
            duration: const Duration(milliseconds: 300),
            child: TomText(tomId: 'styledText1.content'),
          ),
          TomSizedBox(height: 12),

          // Styled text 2: Italic purple
          TomAnimatedDefaultTextStyle(
            tomId: 'styledText2',
            style: const TextStyle(fontSize: 12),
            duration: const Duration(milliseconds: 300),
            child: TomText(tomId: 'styledText2.content'),
          ),
          TomSizedBox(height: 12),

          // Styled text 3: Spaced green
          TomAnimatedDefaultTextStyle(
            tomId: 'styledText3',
            style: const TextStyle(fontSize: 12),
            duration: const Duration(milliseconds: 300),
            child: TomText(tomId: 'styledText3.content'),
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
        // Icon + color both resolved from resources. Every TomIcon is
        // built with just tomId: the .icon resource selects which glyph
        // gets drawn, and the .color resource paints it.
        _DemoCard(
          tomId: 'iconColorDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'iconColorDemo.info'),
              TomSizedBox(height: 12),
              TomRow(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _iconWithCaption('coloredIcon1'),
                  TomSizedBox(width: 24),
                  _iconWithCaption('coloredIcon2'),
                  TomSizedBox(width: 24),
                  _iconWithCaption('coloredIcon3'),
                  TomSizedBox(width: 24),
                  _iconWithCaption('coloredIcon4'),
                ],
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // Container colors from resources
        _DemoCard(
          tomId: 'containerColorDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'containerColorDemo.info'),
              TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomExpanded(
                    child: TomContainer(
                      tomId: 'colorBox1',
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomCenter(
                        child: TomText(
                          tomId: 'colorBox1.content',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomContainer(
                      tomId: 'colorBox2',
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomCenter(
                        child: TomText(
                          tomId: 'colorBox2.content',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomContainer(
                      tomId: 'colorBox3',
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomCenter(
                        child: TomText(
                          tomId: 'colorBox3.content',
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
        TomSizedBox(height: 16),

        // Progress indicator colors
        _DemoCard(
          tomId: 'progressColorDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'progressColorDemo.info'),
              TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomCircularProgressIndicator(tomId: 'progress1', value: 0.7),
                  TomSizedBox(width: 24),
                  TomCircularProgressIndicator(tomId: 'progress2', value: 0.5),
                  TomSizedBox(width: 24),
                  TomExpanded(
                    child: TomLinearProgressIndicator(
                      tomId: 'progress3',
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

  /// Renders a resource-driven TomIcon plus a caption that names the
  /// icon and the color — the caption's text itself comes from the
  /// resource `<tomId>.caption.label`, so the entire row's data model
  /// (glyph, color, label text) is resolved from resources.
  Widget _iconWithCaption(String tomId) {
    return TomColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TomIcon(tomId: tomId, size: 32),
        TomSizedBox(height: 6),
        TomText(
          tomId: '$tomId.caption',
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            height: 1.3,
          ),
          textAlign: TextAlign.center,
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
          tomId: 'elevationDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'elevationDemo.info'),
              TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomExpanded(
                    child: TomCard(
                      tomId: 'card1',
                      child: TomPadding(
                        padding: const EdgeInsets.all(16),
                        child: TomText(tomId: 'card1.content'),
                      ),
                    ),
                  ),
                  TomSizedBox(width: 16),
                  TomExpanded(
                    child: TomCard(
                      tomId: 'card2',
                      child: TomPadding(
                        padding: const EdgeInsets.all(16),
                        child: TomText(tomId: 'card2.content'),
                      ),
                    ),
                  ),
                  TomSizedBox(width: 16),
                  TomExpanded(
                    child: TomCard(
                      tomId: 'card3',
                      child: TomPadding(
                        padding: const EdgeInsets.all(16),
                        child: TomText(tomId: 'card3.content'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // Icon sizes
        _DemoCard(
          tomId: 'iconSizeDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'iconSizeDemo.info'),
              TomSizedBox(height: 12),
              TomRow(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TomIcon(tomId: 'sizedIcon1'),
                  TomSizedBox(width: 16),
                  TomIcon(tomId: 'sizedIcon2'),
                  TomSizedBox(width: 16),
                  TomIcon(tomId: 'sizedIcon3'),
                ],
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // Opacity
        _DemoCard(
          tomId: 'opacityDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(tomId: 'opacityDemo.info'),
              TomSizedBox(height: 12),
              TomRow(
                children: [
                  TomAnimatedOpacity(
                    tomId: 'opacity1',
                    duration: const Duration(milliseconds: 300),
                    child: TomContainer(
                      width: 60,
                      height: 60,
                      color: Theme.of(context).colorScheme.primary,
                      child: TomCenter(child: TomText(tomId: 'opacity1.content')),
                    ),
                  ),
                  TomSizedBox(width: 16),
                  TomAnimatedOpacity(
                    tomId: 'opacity2',
                    duration: const Duration(milliseconds: 300),
                    child: TomContainer(
                      width: 60,
                      height: 60,
                      color: Theme.of(context).colorScheme.primary,
                      child: TomCenter(child: TomText(tomId: 'opacity2.content')),
                    ),
                  ),
                  TomSizedBox(width: 16),
                  TomAnimatedOpacity(
                    tomId: 'opacity3',
                    duration: const Duration(milliseconds: 300),
                    child: TomContainer(
                      width: 60,
                      height: 60,
                      color: Theme.of(context).colorScheme.primary,
                      child: TomCenter(child: TomText(tomId: 'opacity3.content')),
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
      tomId: 'toggleDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'toggleDemo.info'),
          TomSizedBox(height: 16),

          // Switches with colors from resources
          TomRow(
            children: [
              TomSwitch(
                tomId: 'switch1',
                value: _switchValue1,
                onChanged: (v) => setState(() => _switchValue1 = v),
              ),
              TomSizedBox(width: 8),
              TomText(tomId: 'switch1.label'),
              TomSizedBox(width: 32),
              TomSwitch(
                tomId: 'switch2',
                value: _switchValue2,
                onChanged: (v) => setState(() => _switchValue2 = v),
              ),
              TomSizedBox(width: 8),
              TomText(tomId: 'switch2.label'),
            ],
          ),
          TomSizedBox(height: 16),

          // Checkboxes with colors from resources
          TomRow(
            children: [
              TomCheckbox(
                tomId: 'checkbox1',
                value: _checkboxValue1,
                onChanged: (v) => setState(() => _checkboxValue1 = v ?? false),
              ),
              TomSizedBox(width: 8),
              TomText(tomId: 'checkbox1.label'),
              TomSizedBox(width: 32),
              TomCheckbox(
                tomId: 'checkbox2',
                value: _checkboxValue2,
                onChanged: (v) => setState(() => _checkboxValue2 = v ?? false),
              ),
              TomSizedBox(width: 8),
              TomText(tomId: 'checkbox2.label'),
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

    final textValue = TomCtr.text(basePath, 'text');
    final colorValue = TomCtr.color(basePath, 'color');
    final iconValue = TomCtr.icon(basePath, 'icon');
    final doubleValue = TomCtr.doubleVal(basePath, 'double');
    final intValue = TomCtr.intVal(basePath, 'int');
    final boolValue = TomCtr.boolVal(basePath, 'bool');
    final edgeInsetsValue = TomCtr.edgeInsets(basePath, 'edgeInsets');
    final listValue = TomCtr.list(basePath, 'list');
    final mapValue = TomCtr.map(basePath, 'map');

    final colorHex = colorValue == null
        ? 'null'
        : '#${colorValue.toARGB32().toRadixString(16).toUpperCase()}';

    return _DemoCard(
      tomId: 'lookupDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'lookupDemo.info'),
          TomSizedBox(height: 12),
          if (iconValue != null)
            TomRow(
              children: [
                TomIcon(icon: iconValue, size: 18, color: colorValue),
                TomSizedBox(width: 8),
                TomText(text: 'icon resolved: $iconValue'),
              ],
            )
          else
            TomText(text: 'icon resolved: null'),
          TomSizedBox(height: 8),
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

  _DemoCard({
    required this.tomId,
    required this.child,
  });

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
