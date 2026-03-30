/// Demo 05: Slider & Range Controls
///
/// Comprehensive demonstration of all Tom slider widgets.
/// Widgets covered: TomSlider, TomRangeSlider, TomCupertinoSlider.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Slider & Range Controls demo.
class SliderDemo extends StatelessWidget {
  const SliderDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SliderDemoContent();
  }
}

class _SliderDemoContent extends StatefulWidget {
  const _SliderDemoContent();

  @override
  State<_SliderDemoContent> createState() => _SliderDemoContentState();
}

class _SliderDemoContentState extends State<_SliderDemoContent> {
  // ===========================================================================
  // Section 1: Basic Sliders state
  // ===========================================================================
  double _basicValue = 42;
  double _labeledVolume = 60;
  double _discreteValue = 40;
  double _valueLabelSlider = 60;
  double _customTrackValue = 0.65;

  // ===========================================================================
  // Section 2: Range Sliders state
  // ===========================================================================
  RangeValues _priceRange = const RangeValues(150, 580);
  RangeValues _ageRange = const RangeValues(25, 55);
  RangeValues _timeRange = const RangeValues(9, 17);

  // ===========================================================================
  // Section 3: Cupertino Sliders state
  // ===========================================================================
  double _cupertinoBrightness = 0.6;
  double _cupertinoVolume = 0.75;
  double _cupertinoCustom = 0.5;
  double _cupertinoDisplay = 0.72;

  // ===========================================================================
  // Section 4: Slider Applications state
  // ===========================================================================
  // Audio player
  double _audioProgress = 102; // seconds into 260s track
  double _audioVolume = 0.7;

  // Color picker
  double _redValue = 156;
  double _greenValue = 89;
  double _blueValue = 234;

  // Image adjustments
  double _brightness = 20;
  double _contrast = 0;
  double _saturation = -10;
  double _exposure = 5;

  // ===========================================================================
  // Section 5: ACL state
  // ===========================================================================
  double _aclSlider = 50;
  RangeValues _aclRange = const RangeValues(20, 80);
  double _aclCupertino = 0.5;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Basic Sliders
            _SectionHeader(tomId: 'demo05.section.basic'),
            const TomSizedBox(height: 16),
            _buildBasicSliderSection(),
            const TomSizedBox(height: 32),

            // Section 2: Range Sliders
            _SectionHeader(tomId: 'demo05.section.range'),
            const TomSizedBox(height: 16),
            _buildRangeSliderSection(),
            const TomSizedBox(height: 32),

            // Section 3: Cupertino Sliders
            _SectionHeader(tomId: 'demo05.section.cupertino'),
            const TomSizedBox(height: 16),
            _buildCupertinoSliderSection(),
            const TomSizedBox(height: 32),

            // Section 4: Slider Applications
            _SectionHeader(tomId: 'demo05.section.applications'),
            const TomSizedBox(height: 16),
            _buildAudioPlayerSection(),
            const TomSizedBox(height: 24),
            _buildColorPickerSection(),
            const TomSizedBox(height: 24),
            _buildImageAdjustmentsSection(),
            const TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo
            _SectionHeader(tomId: 'demo05.section.acl'),
            const TomSizedBox(height: 16),
            _buildAclSliderSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Basic Sliders
  // ===========================================================================

  Widget _buildBasicSliderSection() {
    return _DemoCard(
      tomId: 'demo05.basicSlider',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic continuous slider
          TomText(tomId: 'demo05.basicSlider.basicLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomText(
                text: '0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TomExpanded(
                child: TomSlider(
                  value: _basicValue,
                  min: 0,
                  max: 100,
                  onChanged: (v) => setState(() => _basicValue = v),
                ),
              ),
              TomText(
                text: '100',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          TomCenter(
            child: TomText(
              text: _basicValue.round().toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          const TomSizedBox(height: 24),

          // With label
          TomText(tomId: 'demo05.basicSlider.volumeLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomText(tomId: 'demo05.basicSlider.volumeName'),
              const TomSizedBox(width: 16),
              TomExpanded(
                child: TomSlider(
                  value: _labeledVolume,
                  min: 0,
                  max: 100,
                  label: _labeledVolume.round().toString(),
                  onChanged: (v) => setState(() => _labeledVolume = v),
                ),
              ),
              TomSizedBox(
                width: 40,
                child: TomText(
                  text: '[${_labeledVolume.round()}]',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Discrete with divisions
          TomText(tomId: 'demo05.basicSlider.discreteLabel'),
          const TomSizedBox(height: 8),
          TomSlider(
            value: _discreteValue,
            min: 0,
            max: 100,
            divisions: 5,
            label: _discreteValue.round().toString(),
            onChanged: (v) => setState(() => _discreteValue = v),
          ),
          TomPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final v in [0, 20, 40, 60, 80, 100])
                  TomText(
                    text: '$v',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          const TomSizedBox(height: 24),

          // With value label overlay
          TomText(tomId: 'demo05.basicSlider.valueLabelTitle'),
          const TomSizedBox(height: 8),
          TomSlider(
            value: _valueLabelSlider,
            min: 0,
            max: 100,
            divisions: 100,
            label: _valueLabelSlider.round().toString(),
            onChanged: (v) => setState(() => _valueLabelSlider = v),
          ),
          const TomSizedBox(height: 24),

          // Custom track/thumb styling
          TomText(tomId: 'demo05.basicSlider.customLabel'),
          const TomSizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.teal,
              inactiveTrackColor: Colors.teal.shade100,
              thumbColor: Colors.teal.shade700,
              overlayColor: Colors.teal.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
            ),
            child: TomSlider(
              value: _customTrackValue,
              onChanged: (v) => setState(() => _customTrackValue = v),
            ),
          ),
          TomCenter(
            child: TomText(
              text: '${(_customTrackValue * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.teal,
                  ),
            ),
          ),

          const TomSizedBox(height: 16),

          // Disabled slider
          TomText(tomId: 'demo05.basicSlider.disabledLabel'),
          const TomSizedBox(height: 8),
          TomSlider(
            value: 0.5,
            onChanged: null,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Range Sliders
  // ===========================================================================

  Widget _buildRangeSliderSection() {
    return _DemoCard(
      tomId: 'demo05.rangeSlider',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price range
          TomText(tomId: 'demo05.rangeSlider.priceLabel'),
          const TomSizedBox(height: 8),
          TomRangeSlider(
            values: _priceRange,
            min: 0,
            max: 800,
            divisions: 16,
            labels: RangeLabels(
              '\$${_priceRange.start.round()}',
              '\$${_priceRange.end.round()}',
            ),
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          TomPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TomText(
                  text: '\$${_priceRange.start.round()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                TomText(tomId: 'demo05.rangeSlider.priceRangeLabel'),
                TomText(
                  text: '\$${_priceRange.end.round()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 24),

          // Age range (discrete)
          TomText(tomId: 'demo05.rangeSlider.ageLabel'),
          const TomSizedBox(height: 8),
          TomRangeSlider(
            values: _ageRange,
            min: 18,
            max: 75,
            divisions: 57,
            labels: RangeLabels(
              '${_ageRange.start.round()}',
              '${_ageRange.end.round()}',
            ),
            onChanged: (v) => setState(() => _ageRange = v),
          ),
          TomCenter(
            child: TomText(
              text: 'Age ${_ageRange.start.round()} – ${_ageRange.end.round()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const TomSizedBox(height: 24),

          // Time range
          TomText(tomId: 'demo05.rangeSlider.timeLabel'),
          const TomSizedBox(height: 8),
          TomRangeSlider(
            values: _timeRange,
            min: 0,
            max: 24,
            divisions: 24,
            labels: RangeLabels(
              '${_timeRange.start.round().toString().padLeft(2, '0')}:00',
              '${_timeRange.end.round().toString().padLeft(2, '0')}:00',
            ),
            onChanged: (v) => setState(() => _timeRange = v),
          ),
          TomCenter(
            child: TomText(
              text:
                  '${_timeRange.start.round().toString().padLeft(2, '0')}:00 – '
                  '${_timeRange.end.round().toString().padLeft(2, '0')}:00 '
                  '(Work hours)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const TomSizedBox(height: 16),

          // Disabled range slider
          TomText(tomId: 'demo05.rangeSlider.disabledLabel'),
          const TomSizedBox(height: 8),
          TomRangeSlider(
            values: const RangeValues(30, 70),
            min: 0,
            max: 100,
            onChanged: null,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Cupertino Sliders
  // ===========================================================================

  Widget _buildCupertinoSliderSection() {
    return _DemoCard(
      tomId: 'demo05.cupertinoSlider',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brightness
          TomText(tomId: 'demo05.cupertinoSlider.brightnessLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              const Icon(CupertinoIcons.sun_min, size: 20),
              TomExpanded(
                child: TomCupertinoSlider(
                  value: _cupertinoBrightness,
                  onChanged: (v) =>
                      setState(() => _cupertinoBrightness = v),
                ),
              ),
              const Icon(CupertinoIcons.sun_max_fill, size: 20),
            ],
          ),
          const TomSizedBox(height: 20),

          // Volume
          TomText(tomId: 'demo05.cupertinoSlider.volumeLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              const Icon(CupertinoIcons.volume_down, size: 20),
              TomExpanded(
                child: TomCupertinoSlider(
                  value: _cupertinoVolume,
                  onChanged: (v) =>
                      setState(() => _cupertinoVolume = v),
                ),
              ),
              const Icon(CupertinoIcons.volume_up, size: 20),
            ],
          ),
          const TomSizedBox(height: 20),

          // Custom colors
          TomText(tomId: 'demo05.cupertinoSlider.customLabel'),
          const TomSizedBox(height: 8),
          TomCupertinoSlider(
            value: _cupertinoCustom,
            activeColor: CupertinoColors.activeBlue,
            onChanged: (v) => setState(() => _cupertinoCustom = v),
          ),
          TomCenter(
            child: TomText(
              text: '${(_cupertinoCustom * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CupertinoColors.activeBlue,
                  ),
            ),
          ),
          const TomSizedBox(height: 20),

          // With value display
          TomText(tomId: 'demo05.cupertinoSlider.displayLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomExpanded(
                child: TomCupertinoSlider(
                  value: _cupertinoDisplay,
                  onChanged: (v) =>
                      setState(() => _cupertinoDisplay = v),
                ),
              ),
              const TomSizedBox(width: 16),
              TomSizedBox(
                width: 50,
                child: TomText(
                  text: '${(_cupertinoDisplay * 100).round()}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Slider Applications
  // ===========================================================================

  Widget _buildAudioPlayerSection() {
    final totalSeconds = 260;
    final currentMin = (_audioProgress ~/ 60);
    final currentSec = (_audioProgress % 60).round();
    final totalMin = totalSeconds ~/ 60;
    final totalSec = totalSeconds % 60;

    return _DemoCard(
      tomId: 'demo05.audioPlayer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Now playing info
          TomText(
            tomId: 'demo05.audioPlayer.nowPlaying',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const TomSizedBox(height: 4),
          TomText(
            tomId: 'demo05.audioPlayer.trackInfo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const TomSizedBox(height: 16),

          // Progress slider
          TomSlider(
            value: _audioProgress,
            min: 0,
            max: totalSeconds.toDouble(),
            onChanged: (v) => setState(() => _audioProgress = v),
          ),
          TomPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TomText(
                  text:
                      '$currentMin:${currentSec.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TomText(
                  text: '$totalMin:${totalSec.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          // Volume
          TomRow(
            children: [
              TomText(tomId: 'demo05.audioPlayer.volumeName'),
              const TomSizedBox(width: 8),
              const Icon(Icons.volume_down, size: 20),
              TomExpanded(
                child: TomSlider(
                  value: _audioVolume,
                  onChanged: (v) => setState(() => _audioVolume = v),
                ),
              ),
              const Icon(Icons.volume_up, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerSection() {
    final previewColor = Color.fromARGB(
      255,
      _redValue.round(),
      _greenValue.round(),
      _blueValue.round(),
    );

    return _DemoCard(
      tomId: 'demo05.colorPicker',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red channel
          _buildColorChannel(
            label: 'R',
            value: _redValue,
            color: Colors.red,
            onChanged: (v) => setState(() => _redValue = v),
          ),
          const TomSizedBox(height: 8),

          // Green channel
          _buildColorChannel(
            label: 'G',
            value: _greenValue,
            color: Colors.green,
            onChanged: (v) => setState(() => _greenValue = v),
          ),
          const TomSizedBox(height: 8),

          // Blue channel
          _buildColorChannel(
            label: 'B',
            value: _blueValue,
            color: Colors.blue,
            onChanged: (v) => setState(() => _blueValue = v),
          ),
          const TomSizedBox(height: 16),

          // Preview
          TomRow(
            children: [
              TomText(
                tomId: 'demo05.colorPicker.previewLabel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const TomSizedBox(width: 12),
              TomExpanded(
                child: TomContainer(
                  height: 48,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 12),
              TomText(
                text:
                    '#${(previewColor.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
                    '${(previewColor.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
                    '${(previewColor.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
                        .toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorChannel({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return TomRow(
      children: [
        TomSizedBox(
          width: 20,
          child: TomText(
            text: label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ),
        TomText(
          text: '0',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TomExpanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
            ),
            child: TomSlider(
              value: value,
              min: 0,
              max: 255,
              divisions: 255,
              label: value.round().toString(),
              onChanged: onChanged,
            ),
          ),
        ),
        TomText(
          text: '255',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TomSizedBox(
          width: 50,
          child: TomCenter(
            child: TomContainer(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TomText(
                text: '${value.round()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageAdjustmentsSection() {
    return _DemoCard(
      tomId: 'demo05.imageAdjust',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdjustmentSlider(
            tomId: 'demo05.imageAdjust.brightness',
            value: _brightness,
            min: -100,
            max: 100,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          const TomSizedBox(height: 12),
          _buildAdjustmentSlider(
            tomId: 'demo05.imageAdjust.contrast',
            value: _contrast,
            min: -100,
            max: 100,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          const TomSizedBox(height: 12),
          _buildAdjustmentSlider(
            tomId: 'demo05.imageAdjust.saturation',
            value: _saturation,
            min: -100,
            max: 100,
            onChanged: (v) => setState(() => _saturation = v),
          ),
          const TomSizedBox(height: 12),
          _buildAdjustmentSlider(
            tomId: 'demo05.imageAdjust.exposure',
            value: _exposure,
            min: -100,
            max: 100,
            onChanged: (v) => setState(() => _exposure = v),
          ),
          const TomSizedBox(height: 16),
          TomCenter(
            child: TomFilledButton(
              tonal: true,
              tomId: 'demo05.imageAdjust.reset',
              onPressed: () {
                setState(() {
                  _brightness = 0;
                  _contrast = 0;
                  _saturation = 0;
                  _exposure = 0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSlider({
    required String tomId,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return TomRow(
      children: [
        TomSizedBox(
          width: 100,
          child: TomText(
            tomId: tomId,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TomExpanded(
          child: TomSlider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) ~/ 1),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        TomSizedBox(
          width: 50,
          child: TomText(
            text: value >= 0
                ? '+${value.round()}'
                : '${value.round()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo
  // ===========================================================================

  Widget _buildAclSliderSection() {
    return _DemoCard(
      tomId: 'demo05.aclSlider',
      child: AclBuilder()
          // Row 1: Label + Slider
          .append(TomText(tomId: 'demo05.aclSlider.sliderLabel'))
          .append(
            TomSlider(
              value: _aclSlider,
              min: 0,
              max: 100,
              divisions: 100,
              label: _aclSlider.round().toString(),
              onChanged: (v) => setState(() => _aclSlider = v),
            ),
            dist: 16,
          )
          .expandX()
          .append(
            TomText(
              text: '${_aclSlider.round()}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            dist: 8,
          )
          .newRow(dist: 16)
          // Row 2: Label + Range slider
          .append(TomText(tomId: 'demo05.aclSlider.rangeLabel'))
          .append(
            TomRangeSlider(
              values: _aclRange,
              min: 0,
              max: 100,
              divisions: 20,
              labels: RangeLabels(
                '${_aclRange.start.round()}',
                '${_aclRange.end.round()}',
              ),
              onChanged: (v) => setState(() => _aclRange = v),
            ),
            dist: 16,
          )
          .expandX()
          .newRow(dist: 16)
          // Row 3: Label + Cupertino slider
          .append(TomText(tomId: 'demo05.aclSlider.cupertinoLabel'))
          .append(
            TomCupertinoSlider(
              value: _aclCupertino,
              onChanged: (v) => setState(() => _aclCupertino = v),
            ),
            dist: 16,
          )
          .expandX()
          .append(
            TomText(
              text: '${(_aclCupertino * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            dist: 8,
          )
          .newRow(dist: 16)
          // Row 4: Action buttons
          .append(
            TomTextButton(
              tomId: 'demo05.aclSlider.reset',
              onPressed: () {
                setState(() {
                  _aclSlider = 50;
                  _aclRange = const RangeValues(20, 80);
                  _aclCupertino = 0.5;
                });
              },
            ),
          )
          .gap()
          .append(
            TomFilledButton(
              tomId: 'demo05.aclSlider.apply',
              onPressed: () {},
            ),
            dist: 8,
          )
          .build(),
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
