/// Comprehensive Slider Widgets Demo
///
/// This demo showcases all Flutter slider widgets including basic sliders,
/// range sliders, custom track/thumb styling, and discrete/continuous modes.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main sliders demo screen with all slider categories.
class SlidersDemo extends StatelessWidget {
  const SlidersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Slider',
          subtitle: 'Single value selection within a range',
        ),
        _SliderSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'RangeSlider',
          subtitle: 'Select a range of values',
        ),
        _RangeSliderSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Discrete Sliders',
          subtitle: 'Sliders with defined step values',
        ),
        _DiscreteSliderSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Slider Theming',
          subtitle: 'Custom colors and shapes',
        ),
        _SliderThemingSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Custom Track & Thumb',
          subtitle: 'Advanced slider customization',
        ),
        _CustomSliderSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Practical Examples',
          subtitle: 'Real-world slider applications',
        ),
        _PracticalExamplesSection(),
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
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const TomSizedBox(height: 4),
          Text(
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
// Demo Card
// =============================================================================

class _DemoCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final String? code;

  const _DemoCard({
    required this.title,
    this.description,
    required this.child,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const TomSizedBox(height: 4),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const TomSizedBox(height: 16),
            child,
            if (code != null) ...[
              const TomSizedBox(height: 16),
              _CodeSnippet(code: code!),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Code Snippet
// =============================================================================

class _CodeSnippet extends StatefulWidget {
  final String code;

  const _CodeSnippet({required this.code});

  @override
  State<_CodeSnippet> createState() => _CodeSnippetState();
}

class _CodeSnippetState extends State<_CodeSnippet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: TomPadding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TomRow(
              children: [
                TomIcon(
                  _expanded ? Icons.code_off : Icons.code,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const TomSizedBox(width: 8),
                Text(
                  _expanded ? 'Hide code' : 'Show code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const TomSpacer(),
                TomIcon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const TomSizedBox(height: 8),
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              widget.code.trim(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Slider Section
// =============================================================================

class _SliderSection extends StatefulWidget {
  const _SliderSection();

  @override
  State<_SliderSection> createState() => _SliderSectionState();
}

class _SliderSectionState extends State<_SliderSection> {
  double _basicValue = 50;
  double _labelValue = 0.5;
  double _overlayValue = 75;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Slider',
          description: 'Simple continuous slider from 0 to 100.',
          child: TomColumn(
            children: [
              TomSlider(
                tomId: 'demo.slider.basic',
                value: _basicValue,
                min: 0,
                max: 100,
                onChanged: (value) => setState(() => _basicValue = value),
              ),
              Text(
                'Value: ${_basicValue.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          code: '''
TomSlider(
  tomId: 'app.volume',
  value: _value,
  min: 0,
  max: 100,
  onChanged: (value) => setState(() => _value = value),
)''',
        ),
        _DemoCard(
          title: 'Slider with Label',
          description: 'Shows value in a popup while sliding.',
          child: TomColumn(
            children: [
              TomSlider(
                tomId: 'demo.slider.label',
                value: _labelValue,
                min: 0,
                max: 1,
                label: '${(_labelValue * 100).round()}%',
                onChanged: (value) => setState(() => _labelValue = value),
              ),
              LinearProgressIndicator(
                value: _labelValue,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const TomSizedBox(height: 8),
              Text('Opacity: ${(_labelValue * 100).round()}%'),
            ],
          ),
          code: '''
TomSlider(
  tomId: 'app.opacity',
  value: _value,
  min: 0,
  max: 1,
  label: '\${(_value * 100).round()}%',
  onChanged: (value) => setState(() => _value = value),
)''',
        ),
        _DemoCard(
          title: 'Slider with Overlay Color',
          description: 'Custom overlay shown when interacting.',
          child: TomColumn(
            children: [
              TomSlider(
                tomId: 'demo.slider.overlay',
                value: _overlayValue,
                min: 0,
                max: 100,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.dragged)) {
                    return Colors.purple.withValues(alpha: 0.3);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return Colors.purple.withValues(alpha: 0.1);
                  }
                  return null;
                }),
                onChanged: (value) => setState(() => _overlayValue = value),
              ),
              Text('Value: ${_overlayValue.toStringAsFixed(0)}'),
            ],
          ),
        ),
        const _SliderCallbacksDemo(),
      ],
    );
  }
}

class _SliderCallbacksDemo extends StatefulWidget {
  const _SliderCallbacksDemo();

  @override
  State<_SliderCallbacksDemo> createState() => _SliderCallbacksDemoState();
}

class _SliderCallbacksDemoState extends State<_SliderCallbacksDemo> {
  double _value = 50;
  String _status = 'Idle';

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Slider Callbacks',
      description: 'Track slider interaction states.',
      child: TomColumn(
        children: [
          TomSlider(
            tomId: 'demo.slider.callbacks',
            value: _value,
            min: 0,
            max: 100,
            onChanged: (value) {
              setState(() {
                _value = value;
                _status = 'Changing...';
              });
            },
            onChangeStart: (value) {
              setState(() => _status = 'Started at ${value.toStringAsFixed(0)}');
            },
            onChangeEnd: (value) {
              setState(() => _status = 'Ended at ${value.toStringAsFixed(0)}');
              // This is where you'd typically save the value
            },
          ),
          TomContainer(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Value: ${_value.toStringAsFixed(0)}'),
                Text(
                  'Status: $_status',
                  style: TextStyle(
                    color: _status.contains('Changing') ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      code: '''
TomSlider(
  tomId: 'app.slider.interactive',
  value: _value,
  onChanged: (value) => setState(() => _value = value),
  onChangeStart: (value) {
    // Called when user starts dragging
  },
  onChangeEnd: (value) {
    // Called when user stops dragging - save value here
  },
)''',
    );
  }
}

// =============================================================================
// RangeSlider Section
// =============================================================================

class _RangeSliderSection extends StatefulWidget {
  const _RangeSliderSection();

  @override
  State<_RangeSliderSection> createState() => _RangeSliderSectionState();
}

class _RangeSliderSectionState extends State<_RangeSliderSection> {
  RangeValues _basicRange = const RangeValues(20, 80);
  RangeValues _priceRange = const RangeValues(100, 500);
  RangeValues _ageRange = const RangeValues(25, 45);

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic RangeSlider',
          description: 'Select a range of values between min and max.',
          child: TomColumn(
            children: [
              TomRangeSlider(
                tomId: 'demo.slider.range.basic',
                values: _basicRange,
                min: 0,
                max: 100,
                onChanged: (values) => setState(() => _basicRange = values),
              ),
              Text(
                'Range: ${_basicRange.start.toStringAsFixed(0)} - ${_basicRange.end.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          code: '''
TomRangeSlider(
  tomId: 'app.filter.range',
  values: _rangeValues,
  min: 0,
  max: 100,
  onChanged: (values) => setState(() => _rangeValues = values),
)''',
        ),
        _DemoCard(
          title: 'Price Range Filter',
          description: 'Practical example for e-commerce filtering.',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${_priceRange.start.round()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('Price Range'),
                  Text(
                    '\$${_priceRange.end.round()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TomRangeSlider(
                tomId: 'demo.slider.range.price',
                values: _priceRange,
                min: 0,
                max: 1000,
                divisions: 20,
                labels: RangeLabels(
                  '\$${_priceRange.start.round()}',
                  '\$${_priceRange.end.round()}',
                ),
                onChanged: (values) => setState(() => _priceRange = values),
              ),
              const TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('\$0'), Text('\$1,000')],
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Age Range Selector',
          description: 'Discrete range slider with divisions.',
          child: TomColumn(
            children: [
              TomRangeSlider(
                tomId: 'demo.slider.range.age',
                values: _ageRange,
                min: 18,
                max: 65,
                divisions: 47,
                labels: RangeLabels(
                  '${_ageRange.start.round()}',
                  '${_ageRange.end.round()}',
                ),
                onChanged: (values) => setState(() => _ageRange = values),
              ),
              TomContainer(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TomIcon(Icons.people, size: 20),
                    const TomSizedBox(width: 8),
                    Text(
                      'Ages ${_ageRange.start.round()} to ${_ageRange.end.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Discrete Slider Section
// =============================================================================

class _DiscreteSliderSection extends StatefulWidget {
  const _DiscreteSliderSection();

  @override
  State<_DiscreteSliderSection> createState() => _DiscreteSliderSectionState();
}

class _DiscreteSliderSectionState extends State<_DiscreteSliderSection> {
  int _rating = 3;
  double _quantity = 5;
  double _temperature = 22;

  final _ratingLabels = ['Terrible', 'Bad', 'Okay', 'Good', 'Great'];

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Rating Slider',
          description: 'Discrete 5-point rating with labels.',
          child: TomColumn(
            children: [
              TomSlider(
                tomId: 'demo.slider.discrete.rating',
                value: _rating.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: _ratingLabels[_rating - 1],
                onChanged: (value) => setState(() => _rating = value.round()),
              ),
              const TomSizedBox(height: 8),
              TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (index) {
                  final isSelected = index + 1 <= _rating;
                  return TomIcon(
                    Icons.star,
                    color: isSelected ? Colors.amber : Colors.grey.shade300,
                    size: 32,
                  );
                }),
              ),
              const TomSizedBox(height: 8),
              Text(
                _ratingLabels[_rating - 1],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          code: '''
TomSlider(
  tomId: 'app.rating',
  value: _rating.toDouble(),
  min: 1,
  max: 5,
  divisions: 4,
  label: _labels[_rating - 1],
  onChanged: (value) => setState(() => _rating = value.round()),
)''',
        ),
        _DemoCard(
          title: 'Quantity Selector',
          description: 'Step slider with numeric display.',
          child: TomColumn(
            children: [
              TomRow(
                children: [
                  IconButton(
                    onPressed:
                        _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                    icon: const TomIcon(Icons.remove_circle),
                  ),
                  TomExpanded(
                    child: TomSlider(
                      tomId: 'demo.slider.discrete.quantity',
                      value: _quantity,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _quantity.round().toString(),
                      onChanged: (value) => setState(() => _quantity = value),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _quantity < 10
                            ? () => setState(() => _quantity++)
                            : null,
                    icon: const TomIcon(Icons.add_circle),
                  ),
                ],
              ),
              TomContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Quantity: ${_quantity.round()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Temperature Control',
          description: 'Slider with unit display and visual feedback.',
          child: TomColumn(
            children: [
              TomRow(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TomIcon(
                  _temperature < 20
                        ? Icons.ac_unit
                        : (_temperature > 25 ? Icons.whatshot : Icons.thermostat),
                    color:
                        _temperature < 20
                            ? Colors.blue
                            : (_temperature > 25 ? Colors.red : Colors.green),
                    size: 32,
                  ),
                  const TomSizedBox(width: 8),
                  Text(
                    '${_temperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const TomSizedBox(height: 8),
              TomSlider(
                tomId: 'demo.slider.discrete.temp',
                value: _temperature,
                min: 16,
                max: 30,
                divisions: 14,
                label: '${_temperature.round()}°C',
                onChanged: (value) => setState(() => _temperature = value),
                activeColor:
                    _temperature < 20
                        ? Colors.blue
                        : (_temperature > 25 ? Colors.red : Colors.green),
              ),
              TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('16°C'),
                  Text(
                    _getTemperatureLabel(),
                    style: TextStyle(
                      color:
                          _temperature < 20
                              ? Colors.blue
                              : (_temperature > 25 ? Colors.red : Colors.green),
                    ),
                  ),
                  const Text('30°C'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTemperatureLabel() {
    if (_temperature < 18) return 'Cold';
    if (_temperature < 20) return 'Cool';
    if (_temperature < 24) return 'Comfortable';
    if (_temperature < 26) return 'Warm';
    return 'Hot';
  }
}

// =============================================================================
// Slider Theming Section
// =============================================================================

class _SliderThemingSection extends StatefulWidget {
  const _SliderThemingSection();

  @override
  State<_SliderThemingSection> createState() => _SliderThemingSectionState();
}

class _SliderThemingSectionState extends State<_SliderThemingSection> {
  final _values = [50.0, 50.0, 50.0, 50.0];

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Active & Inactive Colors',
          description: 'Customize track and thumb colors.',
          child: TomColumn(
            children: [
              // Default theme colors
              _buildColoredSlider(
                'Primary',
                0,
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
              // Custom green
              _buildColoredSlider(
                'Success',
                1,
                Colors.green,
                Colors.green.shade100,
              ),
              // Custom red
              _buildColoredSlider(
                'Danger',
                2,
                Colors.red,
                Colors.red.shade100,
              ),
              // Custom purple
              _buildColoredSlider(
                'Purple',
                3,
                Colors.purple,
                Colors.purple.shade100,
              ),
            ],
          ),
        ),
        const _ThumbShapesDemo(),
        const _TrackShapesDemo(),
      ],
    );
  }

  Widget _buildColoredSlider(
    String label,
    int index,
    Color activeColor,
    Color inactiveColor,
  ) {
    return TomPadding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TomRow(
        children: [
          TomSizedBox(width: 60, child: Text(label)),
          TomExpanded(
            child: TomSlider(
              value: _values[index],
              min: 0,
              max: 100,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              onChanged: (value) => setState(() => _values[index] = value),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbShapesDemo extends StatefulWidget {
  const _ThumbShapesDemo();

  @override
  State<_ThumbShapesDemo> createState() => _ThumbShapesDemoState();
}

class _ThumbShapesDemoState extends State<_ThumbShapesDemo> {
  double _value1 = 50;
  double _value2 = 50;
  double _value3 = 50;

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Custom Thumb Shapes',
      description: 'Different thumb designs using SliderTheme.',
      child: TomColumn(
        children: [
          // Rounded rectangle thumb
          SliderTheme(
            data: SliderThemeData(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              thumbColor: Colors.indigo,
              overlayColor: Colors.indigo.withValues(alpha: 0.2),
            ),
            child: TomSlider(
              value: _value1,
              onChanged: (v) => setState(() => _value1 = v),
            ),
          ),
          const Text('Large Round Thumb'),
          const TomSizedBox(height: 8),
          // Custom square-ish thumb
          SliderTheme(
            data: SliderThemeData(
              thumbShape:
                  const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    pressedElevation: 8,
                  ),
              thumbColor: Colors.orange,
              overlayColor: Colors.orange.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: TomSlider(
              value: _value2,
              onChanged: (v) => setState(() => _value2 = v),
            ),
          ),
          const Text('Elevated on Press'),
          const TomSizedBox(height: 8),
          // Small thumb
          SliderTheme(
            data: SliderThemeData(
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                disabledThumbRadius: 4,
              ),
              thumbColor: Colors.teal,
              overlayColor: Colors.teal.withValues(alpha: 0.2),
              trackHeight: 2,
            ),
            child: TomSlider(
              value: _value3,
              onChanged: (v) => setState(() => _value3 = v),
            ),
          ),
          const Text('Small & Minimal'),
        ],
      ),
    );
  }
}

class _TrackShapesDemo extends StatefulWidget {
  const _TrackShapesDemo();

  @override
  State<_TrackShapesDemo> createState() => _TrackShapesDemoState();
}

class _TrackShapesDemoState extends State<_TrackShapesDemo> {
  double _value1 = 50;
  double _value2 = 50;

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Custom Track Heights',
      description: 'Varying track thickness for different looks.',
      child: TomColumn(
        children: [
          // Thick track
          SliderTheme(
            data: const SliderThemeData(
              trackHeight: 12,
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.blue,
            ),
            child: TomSlider(
              value: _value1,
              onChanged: (v) => setState(() => _value1 = v),
            ),
          ),
          const Text('Thick Track (12px)'),
          const TomSizedBox(height: 16),
          // Thin track
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: Colors.deepPurple,
              inactiveTrackColor: Colors.deepPurple.shade100,
            ),
            child: TomSlider(
              value: _value2,
              onChanged: (v) => setState(() => _value2 = v),
            ),
          ),
          const Text('Thin Track (2px)'),
        ],
      ),
    );
  }
}

// =============================================================================
// Custom Slider Section
// =============================================================================

class _CustomSliderSection extends StatefulWidget {
  const _CustomSliderSection();

  @override
  State<_CustomSliderSection> createState() => _CustomSliderSectionState();
}

class _CustomSliderSectionState extends State<_CustomSliderSection> {
  double _gradientValue = 0.5;
  double _volumeValue = 0.6;
  double _downloadValue = 0.35;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Gradient Track Slider',
          description: 'Custom painted track with gradient.',
          child: TomColumn(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackShape: const _GradientRectSliderTrackShape(),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 14),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 24),
                  tickMarkShape: const RoundSliderTickMarkShape(),
                  activeTickMarkColor: Colors.white,
                  inactiveTickMarkColor: Colors.white54,
                ),
                child: TomSlider(
                  value: _gradientValue,
                  onChanged: (v) => setState(() => _gradientValue = v),
                ),
              ),
              Text(
                '${(_gradientValue * 100).round()}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Volume Slider',
          description: 'Custom slider with icon integration.',
          child: TomRow(
            children: [
              IconButton(
                onPressed: () => setState(() => _volumeValue = 0),
                icon: TomIcon(
                  _volumeValue == 0 ? Icons.volume_off : Icons.volume_down,
                  color: Colors.grey,
                ),
              ),
              TomExpanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: Colors.blue,
                    overlayColor: Colors.blue.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: TomSlider(
                    value: _volumeValue,
                    onChanged: (v) => setState(() => _volumeValue = v),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _volumeValue = 1),
                icon: TomIcon(
                  Icons.volume_up,
                  color: _volumeValue > 0.5 ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Download Progress Slider',
          description: 'Read-only slider showing progress.',
          child: TomColumn(
            children: [
              TomRow(
                children: [
                  TomExpanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        activeTrackColor: Colors.green,
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: Colors.green,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: TomSlider(
                        value: _downloadValue,
                        onChanged: (v) => setState(() => _downloadValue = v),
                      ),
                    ),
                  ),
                  const TomSizedBox(width: 8),
                  TomSizedBox(
                    width: 50,
                    child: Text(
                      '${(_downloadValue * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const TomSizedBox(height: 8),
              const TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('downloading_file.zip', style: TextStyle(fontSize: 12)),
                  Text('3.5 MB / 10 MB', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom track shape with gradient painting.
class _GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _GradientRectSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;

    final trackRect = Rect.fromLTWH(
      trackLeft,
      trackTop,
      trackWidth,
      trackHeight,
    );

    final gradient = const LinearGradient(
      colors: [Colors.blue, Colors.purple, Colors.red],
    );

    final paint =
        Paint()
          ..shader = gradient.createShader(trackRect)
          ..style = PaintingStyle.fill;

    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(trackHeight / 2),
    );

    context.canvas.drawRRect(trackRRect, paint);
  }
}

// =============================================================================
// Practical Examples Section
// =============================================================================

class _PracticalExamplesSection extends StatefulWidget {
  const _PracticalExamplesSection();

  @override
  State<_PracticalExamplesSection> createState() =>
      _PracticalExamplesSectionState();
}

class _PracticalExamplesSectionState extends State<_PracticalExamplesSection> {
  // Color picker
  double _hue = 180;
  double _saturation = 100;
  double _lightness = 50;

  // Brightness
  double _brightness = 0.7;

  // Video seek
  double _videoPosition = 0.3;
  bool _isPlaying = false;

  Color get _selectedColor => HSLColor.fromAHSL(
    1.0,
    _hue,
    _saturation / 100,
    _lightness / 100,
  ).toColor();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'HSL Color Picker',
          description: 'Three sliders for hue, saturation, and lightness.',
          child: TomColumn(
            children: [
              TomContainer(
                height: 60,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TomCenter(
                  child: Text(
                    '#${_selectedColor.toHex()}',
                    style: TextStyle(
                      color:
                          _lightness > 50 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const TomSizedBox(height: 16),
              _buildHueSlider(),
              _buildSaturationSlider(),
              _buildLightnessSlider(),
            ],
          ),
        ),
        _DemoCard(
          title: 'Brightness Control',
          description: 'Slider styled like a device brightness control.',
          child: TomColumn(
            children: [
              TomContainer(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 1 - _brightness),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TomIcon(
                  Icons.wb_sunny,
                  color: Colors.yellow.withValues(alpha: _brightness),
                  size: 48,
                ),
              ),
              const TomSizedBox(height: 16),
              TomRow(
                children: [
                  const TomIcon(Icons.brightness_low),
                  TomExpanded(
                    child: TomSlider(
                      tomId: 'demo.slider.practical.brightness',
                      value: _brightness,
                      onChanged: (v) => setState(() => _brightness = v),
                      activeColor: Colors.amber,
                    ),
                  ),
                  const TomIcon(Icons.brightness_high),
                ],
              ),
              Text('${(_brightness * 100).round()}%'),
            ],
          ),
        ),
        _DemoCard(
          title: 'Video Seek Bar',
          description: 'Timeline slider with play/pause controls.',
          child: TomColumn(
            children: [
              TomContainer(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomCenter(
                  child: TomIcon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const TomSizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.grey.shade400,
                  thumbColor: Colors.red,
                ),
                child: TomSlider(
                  tomId: 'demo.slider.practical.video',
                  value: _videoPosition,
                  onChanged: (v) => setState(() => _videoPosition = v),
                ),
              ),
              TomPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TomRow(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(
                        Duration(seconds: (_videoPosition * 600).round()),
                      ),
                    ),
                    TomRow(
                      children: [
                        IconButton(
                          icon: const TomIcon(Icons.replay_10),
                          onPressed: () {
                            setState(() {
                              _videoPosition =
                                  (_videoPosition - 10 / 600).clamp(0.0, 1.0);
                            });
                          },
                        ),
                        IconButton(
                          icon: TomIcon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: () =>
                              setState(() => _isPlaying = !_isPlaying),
                        ),
                        IconButton(
                          icon: const TomIcon(Icons.forward_10),
                          onPressed: () {
                            setState(() {
                              _videoPosition =
                                  (_videoPosition + 10 / 600).clamp(0.0, 1.0);
                            });
                          },
                        ),
                      ],
                    ),
                    const Text('10:00'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _AudioEqualizerDemo(),
      ],
    );
  }

  Widget _buildHueSlider() {
    return TomRow(
      children: [
        const TomSizedBox(width: 40, child: Text('H')),
        TomExpanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: const _HueTrackShape(),
              thumbColor: HSLColor.fromAHSL(1.0, _hue, 1.0, 0.5).toColor(),
            ),
            child: TomSlider(
              value: _hue,
              min: 0,
              max: 360,
              onChanged: (v) => setState(() => _hue = v),
            ),
          ),
        ),
        TomSizedBox(width: 40, child: Text('${_hue.round()}°')),
      ],
    );
  }

  Widget _buildSaturationSlider() {
    return TomRow(
      children: [
        const TomSizedBox(width: 40, child: Text('S')),
        TomExpanded(
          child: TomSlider(
            value: _saturation,
            min: 0,
            max: 100,
            activeColor: _selectedColor,
            onChanged: (v) => setState(() => _saturation = v),
          ),
        ),
        TomSizedBox(width: 40, child: Text('${_saturation.round()}%')),
      ],
    );
  }

  Widget _buildLightnessSlider() {
    return TomRow(
      children: [
        const TomSizedBox(width: 40, child: Text('L')),
        TomExpanded(
          child: TomSlider(
            value: _lightness,
            min: 0,
            max: 100,
            activeColor: _selectedColor,
            onChanged: (v) => setState(() => _lightness = v),
          ),
        ),
        TomSizedBox(width: 40, child: Text('${_lightness.round()}%')),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _HueTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _HueTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;

    final trackRect = Rect.fromLTWH(
      trackLeft,
      trackTop,
      trackWidth,
      trackHeight,
    );

    final colors = [
      const Color(0xFFFF0000), // Red
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFF00FF00), // Green
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFF0000FF), // Blue
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFF0000), // Red (wrap around)
    ];

    final gradient = LinearGradient(colors: colors);
    final paint =
        Paint()
          ..shader = gradient.createShader(trackRect)
          ..style = PaintingStyle.fill;

    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(trackHeight / 2),
    );

    context.canvas.drawRRect(trackRRect, paint);
  }
}

class _AudioEqualizerDemo extends StatefulWidget {
  const _AudioEqualizerDemo();

  @override
  State<_AudioEqualizerDemo> createState() => _AudioEqualizerDemoState();
}

class _AudioEqualizerDemoState extends State<_AudioEqualizerDemo> {
  final _bands = [0.5, 0.7, 0.4, 0.8, 0.6, 0.5, 0.3];
  final _frequencies = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz'];

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Audio Equalizer',
      description: 'Vertical sliders for frequency band adjustment.',
      child: TomColumn(
        children: [
          TomSizedBox(
            height: 180,
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_bands.length, (index) {
                return TomColumn(
                  children: [
                    Text('+12', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    TomExpanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape:
                                const RoundSliderThumbShape(enabledThumbRadius: 8),
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: Colors.grey.shade300,
                          ),
                          child: TomSlider(
                            value: _bands[index],
                            onChanged: (v) => setState(() => _bands[index] = v),
                          ),
                        ),
                      ),
                    ),
                    Text('-12', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    const TomSizedBox(height: 4),
                    Text(
                      _frequencies[index],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                );
              }),
            ),
          ),
          const TomSizedBox(height: 8),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    for (int i = 0; i < _bands.length; i++) {
                      _bands[i] = 0.5;
                    }
                  });
                },
                icon: const TomIcon(Icons.restart_alt, size: 16),
                label: const Text('Reset'),
              ),
              const TomSizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  // Simulate preset
                  setState(() {
                    _bands[0] = 0.7;
                    _bands[1] = 0.8;
                    _bands[2] = 0.5;
                    _bands[3] = 0.4;
                    _bands[4] = 0.5;
                    _bands[5] = 0.7;
                    _bands[6] = 0.8;
                  });
                },
                icon: const TomIcon(Icons.music_note, size: 16),
                label: const Text('Bass Boost'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Extension to convert Color to hex string.
extension ColorToHex on Color {
  String toHex() {
    return '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }
}
