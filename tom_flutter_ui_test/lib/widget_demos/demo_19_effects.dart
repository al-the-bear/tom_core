/// Demo 19: Effects & Filters
///
/// Comprehensive demonstration of all Tom effect and filter widgets.
/// Widgets covered: TomBackdropFilter, TomColorFiltered, TomImageFiltered,
/// TomShaderMask, TomSelectableRegion, TomSelectionArea, TomSensitiveContent.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ContentSensitivity;
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Effects & Filters demo.
class EffectsDemo extends StatelessWidget {
  const EffectsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EffectsDemoContent();
  }
}

class _EffectsDemoContent extends StatefulWidget {
  const _EffectsDemoContent();

  @override
  State<_EffectsDemoContent> createState() => _EffectsDemoContentState();
}

class _EffectsDemoContentState extends State<_EffectsDemoContent> {
  // State for interactive demos
  double _blurSigma = 5.0;
  Color _colorFilterColor = Colors.blue;
  BlendMode _colorFilterMode = BlendMode.colorBurn;
  double _imageBlurSigma = 3.0;
  bool _imageFilterEnabled = true;
  BlendMode _shaderBlendMode = BlendMode.modulate;
  ContentSensitivity _sensitivity = ContentSensitivity.autoSensitive;
  String? _selectedText;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Backdrop Filters
            _SectionHeader(
              tomId: 'demo19.section.backdrop',
            ),
            const TomSizedBox(height: 16),
            _buildBackdropFilterSection(),
            const TomSizedBox(height: 32),

            // Section 2: Image Filters
            _SectionHeader(
              tomId: 'demo19.section.image',
            ),
            const TomSizedBox(height: 16),
            _buildImageFilterSection(),
            const TomSizedBox(height: 32),

            // Section 3: Color Filters
            _SectionHeader(
              tomId: 'demo19.section.color',
            ),
            const TomSizedBox(height: 16),
            _buildColorFilterSection(),
            const TomSizedBox(height: 32),

            // Section 4: Shader Masks
            _SectionHeader(
              tomId: 'demo19.section.shader',
            ),
            const TomSizedBox(height: 16),
            _buildShaderMaskSection(),
            const TomSizedBox(height: 32),

            // Section 5: Text Selection
            _SectionHeader(
              tomId: 'demo19.section.selection',
            ),
            const TomSizedBox(height: 16),
            _buildSelectionSection(),
            const TomSizedBox(height: 32),

            // Section 6: Sensitive Content
            _SectionHeader(
              tomId: 'demo19.section.sensitive',
            ),
            const TomSizedBox(height: 16),
            _buildSensitiveContentSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Backdrop Filters
  // ===========================================================================

  Widget _buildBackdropFilterSection() {
    return _DemoCard(
      tomId: 'demo19.backdropFilter',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Demo container with background content
          TomContainer(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://picsum.photos/seed/backdrop/400/300',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: TomStack(
              children: [
                // Position blur overlay
                Positioned(
                  left: 16,
                  top: 16,
                  right: 16,
                  bottom: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TomBackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: _blurSigma,
                        sigmaY: _blurSigma,
                      ),
                      child: TomContainer(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: TomCenter(
                          child: TomColumn(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.blur_on,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const TomSizedBox(height: 8),
                              Text(
                                'Blur: ${_blurSigma.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Info text at bottom
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: TomContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Backdrop blur effect applied to area above',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),
          // Blur sigma slider
          TomRow(
            children: [
              const TomText(text: 'Blur Sigma: '),
              TomExpanded(
                child: Slider(
                  value: _blurSigma,
                  min: 0,
                  max: 20,
                  divisions: 40,
                  label: _blurSigma.toStringAsFixed(1),
                  onChanged: (value) => setState(() => _blurSigma = value),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  _blurSigma.toStringAsFixed(1),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo19.backdropFilter.hint',
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
  // Section 2: Image Filters
  // ===========================================================================

  Widget _buildImageFilterSection() {
    return _DemoCard(
      tomId: 'demo19.imageFilter',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Demo with image filter
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original image
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText(
                      text: 'Original',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TomSizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'https://picsum.photos/seed/imagefilter/200/150',
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 16),
              // Filtered image
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText(
                      text: 'Filtered',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TomSizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: TomImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: _imageBlurSigma,
                          sigmaY: _imageBlurSigma,
                        ),
                        enabled: _imageFilterEnabled,
                        child: Image.network(
                          'https://picsum.photos/seed/imagefilter/200/150',
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),
          // Controls
          TomRow(
            children: [
              const TomText(text: 'Blur: '),
              TomExpanded(
                child: Slider(
                  value: _imageBlurSigma,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  label: _imageBlurSigma.toStringAsFixed(1),
                  onChanged: (value) =>
                      setState(() => _imageBlurSigma = value),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  _imageBlurSigma.toStringAsFixed(1),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          TomRow(
            children: [
              const TomText(text: 'Filter Enabled: '),
              Switch(
                value: _imageFilterEnabled,
                onChanged: (value) =>
                    setState(() => _imageFilterEnabled = value),
              ),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo19.imageFilter.hint',
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
  // Section 3: Color Filters
  // ===========================================================================

  Widget _buildColorFilterSection() {
    return _DemoCard(
      tomId: 'demo19.colorFilter',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Demo grid with different color filters
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildColorFilterExample(
                'Original',
                null,
              ),
              _buildColorFilterExample(
                'Selected',
                ColorFilter.mode(_colorFilterColor, _colorFilterMode),
              ),
              _buildColorFilterExample(
                'Grayscale',
                const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
              ),
              _buildColorFilterExample(
                'Sepia',
                const ColorFilter.matrix(<double>[
                  0.393, 0.769, 0.189, 0, 0,
                  0.349, 0.686, 0.168, 0, 0,
                  0.272, 0.534, 0.131, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
              ),
              _buildColorFilterExample(
                'Invert',
                const ColorFilter.matrix(<double>[
                  -1, 0, 0, 0, 255,
                  0, -1, 0, 0, 255,
                  0, 0, -1, 0, 255,
                  0, 0, 0, 1, 0,
                ]),
              ),
              _buildColorFilterExample(
                'High Contrast',
                const ColorFilter.matrix(<double>[
                  1.5, 0, 0, 0, -128,
                  0, 1.5, 0, 0, -128,
                  0, 0, 1.5, 0, -128,
                  0, 0, 0, 1, 0,
                ]),
              ),
            ],
          ),
          const TomSizedBox(height: 20),
          // Color picker for custom filter
          TomText(
            text: 'Custom Color Filter:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 12),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildColorChip(Colors.red, 'Red'),
              _buildColorChip(Colors.blue, 'Blue'),
              _buildColorChip(Colors.green, 'Green'),
              _buildColorChip(Colors.orange, 'Orange'),
              _buildColorChip(Colors.purple, 'Purple'),
              _buildColorChip(Colors.cyan, 'Cyan'),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            text: 'Blend Mode:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBlendModeChip(BlendMode.colorBurn, 'Color Burn'),
              _buildBlendModeChip(BlendMode.multiply, 'Multiply'),
              _buildBlendModeChip(BlendMode.overlay, 'Overlay'),
              _buildBlendModeChip(BlendMode.screen, 'Screen'),
              _buildBlendModeChip(BlendMode.softLight, 'Soft Light'),
              _buildBlendModeChip(BlendMode.color, 'Color'),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo19.colorFilter.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorFilterExample(String label, ColorFilter? filter) {
    return TomColumn(
      children: [
        TomText(
          text: label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const TomSizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: filter != null
              ? TomColorFiltered(
                  colorFilter: filter,
                  child: Image.network(
                    'https://picsum.photos/seed/colorfilter/100/80',
                    width: 100,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.network(
                  'https://picsum.photos/seed/colorfilter/100/80',
                  width: 100,
                  height: 80,
                  fit: BoxFit.cover,
                ),
        ),
      ],
    );
  }

  Widget _buildColorChip(Color color, String label) {
    final isSelected = _colorFilterColor == color;
    return FilterChip(
      selected: isSelected,
      label: TomText(text: label),
      backgroundColor: color.withValues(alpha: 0.2),
      selectedColor: color.withValues(alpha: 0.4),
      checkmarkColor: color,
      onSelected: (_) => setState(() => _colorFilterColor = color),
    );
  }

  Widget _buildBlendModeChip(BlendMode mode, String label) {
    final isSelected = _colorFilterMode == mode;
    return FilterChip(
      selected: isSelected,
      label: TomText(text: label),
      onSelected: (_) => setState(() => _colorFilterMode = mode),
    );
  }

  // ===========================================================================
  // Section 4: Shader Masks
  // ===========================================================================

  Widget _buildShaderMaskSection() {
    return _DemoCard(
      tomId: 'demo19.shaderMask',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Demo grid with different shader effects
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildShaderMaskExample(
                'Linear Gradient',
                (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                ).createShader(bounds),
              ),
              _buildShaderMaskExample(
                'Radial Gradient',
                (bounds) => RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                ).createShader(bounds),
              ),
              _buildShaderMaskExample(
                'Sweep Gradient',
                (bounds) => const SweepGradient(
                  colors: [
                    Colors.white,
                    Colors.transparent,
                    Colors.white,
                  ],
                ).createShader(bounds),
              ),
              _buildShaderMaskExample(
                'Diagonal Fade',
                (bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.transparent],
                ).createShader(bounds),
              ),
            ],
          ),
          const TomSizedBox(height: 20),
          // Blend mode selector
          TomText(
            text: 'Shader Blend Mode:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildShaderBlendModeChip(BlendMode.modulate, 'Modulate'),
              _buildShaderBlendModeChip(BlendMode.srcIn, 'Source In'),
              _buildShaderBlendModeChip(BlendMode.dstIn, 'Dest In'),
              _buildShaderBlendModeChip(BlendMode.srcATop, 'Src ATop'),
            ],
          ),
          const TomSizedBox(height: 16),
          // Interactive shader mask demo
          TomCenter(
            child: TomShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds),
              blendMode: _shaderBlendMode,
              child: TomContainer(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TomColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gradient,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const TomSizedBox(height: 8),
                    Text(
                      'Shader Masked Content',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Mode: ${_shaderBlendMode.name}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo19.shaderMask.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildShaderMaskExample(
    String label,
    ui.Shader Function(Rect) shaderCallback,
  ) {
    return TomColumn(
      children: [
        TomText(
          text: label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const TomSizedBox(height: 4),
        TomShaderMask(
          shaderCallback: shaderCallback,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://picsum.photos/seed/shadermask/100/100',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShaderBlendModeChip(BlendMode mode, String label) {
    final isSelected = _shaderBlendMode == mode;
    return FilterChip(
      selected: isSelected,
      label: TomText(text: label),
      onSelected: (_) => setState(() => _shaderBlendMode = mode),
    );
  }

  // ===========================================================================
  // Section 5: Text Selection
  // ===========================================================================

  Widget _buildSelectionSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SelectionArea demo
        _DemoCard(
          tomId: 'demo19.selectionArea',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomSelectionArea(
                onSelectionChanged: (content) {
                  setState(() => _selectedText = content?.plainText);
                },
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selection Area Demo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const TomSizedBox(height: 12),
                    const Text(
                      'This entire area is wrapped in TomSelectionArea. '
                      'You can select any text within this container by '
                      'clicking and dragging. The selection will be highlighted '
                      'and you can copy it to clipboard.',
                    ),
                    const TomSizedBox(height: 12),
                    const Text(
                      'Try selecting this paragraph as well! Multiple paragraphs '
                      'can be selected at once, and the selection spans across '
                      'different Text widgets.',
                    ),
                    const TomSizedBox(height: 12),
                    TomRow(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const TomSizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SelectionArea provides a convenient way to enable '
                            'text selection for all descendant widgets.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const TomSizedBox(height: 16),
              if (_selectedText != null && _selectedText!.isNotEmpty) ...[
                TomContainer(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected text:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const TomSizedBox(height: 4),
                      Text(
                        '"${_selectedText!.length > 100 ? '${_selectedText!.substring(0, 100)}...' : _selectedText}"',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const TomSizedBox(height: 12),
              ],
              TomText(
                tomId: 'demo19.selectionArea.hint',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),
        // SelectableRegion demo
        _DemoCard(
          tomId: 'demo19.selectableRegion',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomSelectableRegion(
                selectionControls: MaterialTextSelectionControls(),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selectable Region Demo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const TomSizedBox(height: 12),
                    const Text(
                      'TomSelectableRegion provides lower-level control over '
                      'text selection. Unlike SelectionArea, you must provide '
                      'explicit selectionControls.',
                    ),
                    const TomSizedBox(height: 12),
                    TomCard(
                      child: TomPadding(
                        padding: const EdgeInsets.all(12),
                        child: TomRow(
                          children: [
                            const Icon(Icons.code, size: 20),
                            const TomSizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'const code = "// Select this code snippet";',
                                style: TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo19.selectableRegion.hint',
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
  // Section 6: Sensitive Content
  // ===========================================================================

  Widget _buildSensitiveContentSection() {
    return _DemoCard(
      tomId: 'demo19.sensitiveContent',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sensitivity level selector
          TomText(
            text: 'Content Sensitivity Level:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 12),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSensitivityChip(
                ContentSensitivity.autoSensitive,
                'Auto Sensitive',
                Icons.auto_awesome,
              ),
              _buildSensitivityChip(
                ContentSensitivity.sensitive,
                'Sensitive',
                Icons.visibility_off,
              ),
              _buildSensitivityChip(
                ContentSensitivity.notSensitive,
                'Not Sensitive',
                Icons.visibility,
              ),
            ],
          ),
          const TomSizedBox(height: 20),
          // Demo cards for different sensitivity levels
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomExpanded(
                child: _buildSensitiveContentExample(
                  ContentSensitivity.sensitive,
                  'Sensitive Data',
                  Icons.lock,
                  Colors.red,
                  'Password: ••••••••\nSSN: •••-••-••••',
                ),
              ),
              const TomSizedBox(width: 16),
              TomExpanded(
                child: _buildSensitiveContentExample(
                  ContentSensitivity.notSensitive,
                  'Public Data',
                  Icons.public,
                  Colors.green,
                  'Name: John Doe\nEmail: john@example.com',
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),
          // Interactive demo
          TomSensitiveContent(
            sensitivity: _sensitivity,
            child: TomCard(
              child: TomPadding(
                padding: const EdgeInsets.all(16),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TomRow(
                      children: [
                        Icon(
                          _getSensitivityIcon(_sensitivity),
                          color: _getSensitivityColor(_sensitivity),
                        ),
                        const TomSizedBox(width: 12),
                        TomExpanded(
                          child: TomColumn(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interactive Demo',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Sensitivity: ${_sensitivity.name}',
                                style: TextStyle(
                                  color: _getSensitivityColor(_sensitivity),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const TomSizedBox(height: 12),
                    const TomDivider(),
                    const TomSizedBox(height: 12),
                    const Text(
                      'This content area is wrapped in TomSensitiveContent. '
                      'On supported platforms (iOS/Android), the OS may treat '
                      'this content differently based on the sensitivity level.',
                    ),
                    const TomSizedBox(height: 8),
                    TomContainer(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getSensitivityColor(_sensitivity)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getSensitivityColor(_sensitivity),
                        ),
                      ),
                      child: const Text(
                        'Credit Card: •••• •••• •••• 4242\n'
                        'Expiry: 12/26 • CVV: •••',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo19.sensitiveContent.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensitivityChip(
    ContentSensitivity sensitivity,
    String label,
    IconData icon,
  ) {
    final isSelected = _sensitivity == sensitivity;
    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 18),
      label: TomText(text: label),
      onSelected: (_) => setState(() => _sensitivity = sensitivity),
    );
  }

  Widget _buildSensitiveContentExample(
    ContentSensitivity sensitivity,
    String title,
    IconData icon,
    Color color,
    String content,
  ) {
    return TomSensitiveContent(
      sensitivity: sensitivity,
      child: TomContainer(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                Icon(icon, size: 16, color: color),
                const TomSizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSensitivityIcon(ContentSensitivity sensitivity) {
    switch (sensitivity) {
      case ContentSensitivity.autoSensitive:
        return Icons.auto_awesome;
      case ContentSensitivity.sensitive:
        return Icons.visibility_off;
      case ContentSensitivity.notSensitive:
        return Icons.visibility;
      default:
        return Icons.help_outline;
    }
  }

  Color _getSensitivityColor(ContentSensitivity sensitivity) {
    switch (sensitivity) {
      case ContentSensitivity.autoSensitive:
        return Colors.orange;
      case ContentSensitivity.sensitive:
        return Colors.red;
      case ContentSensitivity.notSensitive:
        return Colors.green;
      default:
        return Colors.grey;
    }
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
