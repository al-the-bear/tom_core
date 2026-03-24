/// Comprehensive Layout Widgets Demo
///
/// This demo showcases layout widgets including Row, Column, Stack,
/// Wrap, Flex, GridView, and various spacing and alignment options.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main layout widgets demo screen.
class LayoutDemo extends StatelessWidget {
  const LayoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Row & Column',
          subtitle: 'Linear arrangement of children',
        ),
        _RowColumnSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'MainAxisAlignment',
          subtitle: 'Alignment along the main axis',
        ),
        _MainAxisAlignmentSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'CrossAxisAlignment',
          subtitle: 'Alignment along the cross axis',
        ),
        _CrossAxisAlignmentSection(),
        SizedBox(height: 32),
        _SectionHeader(title: 'Flex & Expanded', subtitle: 'Flexible layouts'),
        _FlexSection(),
        SizedBox(height: 32),
        _SectionHeader(title: 'Stack', subtitle: 'Overlapping children'),
        _StackSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Wrap',
          subtitle: 'Wrapping children to next line',
        ),
        _WrapSection(),
        SizedBox(height: 32),
        _SectionHeader(title: 'Spacing & Padding', subtitle: 'Layout spacing'),
        _SpacingSection(),
        SizedBox(height: 32),
        _SectionHeader(title: 'Constraints', subtitle: 'Size constraints'),
        _ConstraintsSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Practical Layouts',
          subtitle: 'Common layout patterns',
        ),
        _PracticalLayoutsSection(),
        SizedBox(height: 48),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
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
// Row & Column Section
// =============================================================================

class _RowColumnSection extends StatelessWidget {
  const _RowColumnSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Basic Row',
          'Horizontal arrangement of children.',
          Row(
            children: [
              _ColorBox(Colors.red, '1'),
              _ColorBox(Colors.green, '2'),
              _ColorBox(Colors.blue, '3'),
            ],
          ),
        ),
        _buildDemoCard(
          'Basic Column',
          'Vertical arrangement of children.',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColorBox(Colors.red, '1'),
              _ColorBox(Colors.green, '2'),
              _ColorBox(Colors.blue, '3'),
            ],
          ),
        ),
        _buildDemoCard(
          'Nested Row & Column',
          'Combining rows and columns.',
          Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorBox(Colors.red, '1'),
                  _ColorBox(Colors.orange, '2'),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorBox(Colors.green, '3'),
                  _ColorBox(Colors.teal, '4'),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorBox(Colors.blue, '5'),
                  _ColorBox(Colors.purple, '6'),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'MainAxisSize',
          'min vs max for available space usage.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MainAxisSize.min:', style: TextStyle(fontSize: 12)),
              Container(
                color: Colors.grey.shade200,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ColorBox(Colors.red, '1'),
                    _ColorBox(Colors.green, '2'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('MainAxisSize.max:', style: TextStyle(fontSize: 12)),
              Container(
                color: Colors.grey.shade200,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _ColorBox(Colors.red, '1'),
                    _ColorBox(Colors.green, '2'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MainAxisAlignment Section
// =============================================================================

class _MainAxisAlignmentSection extends StatelessWidget {
  const _MainAxisAlignmentSection();

  @override
  Widget build(BuildContext context) {
    final alignments = {
      'start': MainAxisAlignment.start,
      'end': MainAxisAlignment.end,
      'center': MainAxisAlignment.center,
      'spaceBetween': MainAxisAlignment.spaceBetween,
      'spaceAround': MainAxisAlignment.spaceAround,
      'spaceEvenly': MainAxisAlignment.spaceEvenly,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              alignments.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MainAxisAlignment.${entry.key}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: entry.value,
                          children: [
                            _SmallBox(Colors.red),
                            _SmallBox(Colors.green),
                            _SmallBox(Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}

// =============================================================================
// CrossAxisAlignment Section
// =============================================================================

class _CrossAxisAlignmentSection extends StatelessWidget {
  const _CrossAxisAlignmentSection();

  @override
  Widget build(BuildContext context) {
    final alignments = {
      'start': CrossAxisAlignment.start,
      'end': CrossAxisAlignment.end,
      'center': CrossAxisAlignment.center,
      'stretch': CrossAxisAlignment.stretch,
      'baseline': CrossAxisAlignment.baseline,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              alignments.entries.map((entry) {
                final isBaseline = entry.key == 'baseline';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CrossAxisAlignment.${entry.key}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: entry.value,
                          textBaseline:
                              isBaseline ? TextBaseline.alphabetic : null,
                          children: [
                            if (isBaseline) ...[
                              const Text(
                                'Abc',
                                style: TextStyle(fontSize: 24),
                              ),
                              const Text(
                                'Xyz',
                                style: TextStyle(fontSize: 16),
                              ),
                              const Text(
                                '123',
                                style: TextStyle(fontSize: 12),
                              ),
                            ] else ...[
                              _SmallBox(Colors.red, height: 30),
                              _SmallBox(Colors.green, height: 50),
                              _SmallBox(Colors.blue, height: 40),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}

// =============================================================================
// Flex Section
// =============================================================================

class _FlexSection extends StatelessWidget {
  const _FlexSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Expanded',
          'Child fills available space.',
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                _ColorBox(Colors.red, 'Fixed'),
                Expanded(child: _ColorBox(Colors.green, 'Expanded')),
                _ColorBox(Colors.blue, 'Fixed'),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Flexible',
          'Child can shrink but tries to fill space.',
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: _ColorBox(Colors.red, 'Tight'),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: _ColorBox(Colors.green, 'Loose'),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Flex (flex factor)',
          'Weighted distribution of space.',
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(flex: 1, child: _ColorBox(Colors.red, '1')),
                Expanded(flex: 2, child: _ColorBox(Colors.green, '2')),
                Expanded(flex: 3, child: _ColorBox(Colors.blue, '3')),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'FractionallySizedBox',
          'Child as fraction of available space.',
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      '60% width',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Spacer',
          'Empty space between children.',
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                _ColorBox(Colors.red, 'Left'),
                const Spacer(),
                _ColorBox(Colors.green, 'Center'),
                const Spacer(flex: 2),
                _ColorBox(Colors.blue, 'Right'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Stack Section
// =============================================================================

class _StackSection extends StatelessWidget {
  const _StackSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Basic Stack',
          'Overlapping widgets.',
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Container(
                  width: 150,
                  height: 150,
                  color: Colors.red.shade200,
                  child: const Center(child: Text('Bottom')),
                ),
                Positioned(
                  left: 50,
                  top: 50,
                  child: Container(
                    width: 100,
                    height: 100,
                    color: Colors.green.shade300,
                    child: const Center(child: Text('Middle')),
                  ),
                ),
                Positioned(
                  left: 100,
                  top: 30,
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.blue.shade400,
                    child: const Center(
                      child: Text('Top', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Stack Alignment',
          'Different alignment options.',
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        color: Colors.red.shade100,
                      ),
                      Container(width: 40, height: 40, color: Colors.red),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        color: Colors.green.shade100,
                      ),
                      Container(width: 40, height: 40, color: Colors.green),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        color: Colors.blue.shade100,
                      ),
                      Container(width: 40, height: 40, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Positioned',
          'Precise positioning within stack.',
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Container(color: Colors.grey.shade100),
                const Positioned(
                  top: 10,
                  left: 10,
                  child: Icon(Icons.add_circle, color: Colors.red),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(Icons.remove_circle, color: Colors.blue),
                ),
                const Positioned(
                  bottom: 10,
                  left: 10,
                  child: Icon(Icons.check_circle, color: Colors.green),
                ),
                const Positioned(
                  bottom: 10,
                  right: 10,
                  child: Icon(Icons.cancel, color: Colors.orange),
                ),
                const Center(child: Icon(Icons.star, size: 48, color: Colors.amber)),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Positioned.fill',
          'Child fills entire stack area.',
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Filled Background',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Stack with Fit',
          'StackFit options for non-positioned children.',
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('loose', style: TextStyle(fontSize: 10)),
                    SizedBox(
                      height: 80,
                      child: Stack(
                        fit: StackFit.loose,
                        children: [
                          Container(color: Colors.grey.shade200),
                          Container(width: 40, height: 40, color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    const Text('expand', style: TextStyle(fontSize: 10)),
                    SizedBox(
                      height: 80,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey.shade200),
                          Container(color: Colors.green.withValues(alpha: 0.7)),
                        ],
                      ),
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

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Wrap Section
// =============================================================================

class _WrapSection extends StatelessWidget {
  const _WrapSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Basic Wrap',
          'Children wrap to next line automatically.',
          Wrap(
            children: List.generate(
              10,
              (i) => Padding(
                padding: const EdgeInsets.all(4),
                child: Chip(label: Text('Item ${i + 1}')),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Wrap with Spacing',
          'Control horizontal and vertical spacing.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              8,
              (i) => Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.primaries[i % Colors.primaries.length],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Wrap Direction',
          'Vertical wrapping direction.',
          SizedBox(
            height: 150,
            child: Wrap(
              direction: Axis.vertical,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                8,
                (i) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.primaries[i % Colors.primaries.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Wrap Alignment',
          'Different alignment options.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WrapAlignment.start', style: TextStyle(fontSize: 10)),
              Container(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('WrapAlignment.center', style: TextStyle(fontSize: 10)),
              Container(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('WrapAlignment.end', style: TextStyle(fontSize: 10)),
              Container(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'WrapAlignment.spaceBetween',
                style: TextStyle(fontSize: 10),
              ),
              Container(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Spacing Section
// =============================================================================

class _SpacingSection extends StatelessWidget {
  const _SpacingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Padding',
          'Insets around a child widget.',
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'EdgeInsets.all(16)',
                          style: TextStyle(fontSize: 10),
                        ),
                        Container(
                          color: Colors.blue.shade100,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              height: 30,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'EdgeInsets.symmetric',
                          style: TextStyle(fontSize: 10),
                        ),
                        Container(
                          color: Colors.green.shade100,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Container(
                              height: 30,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'EdgeInsets.only(left)',
                          style: TextStyle(fontSize: 10),
                        ),
                        Container(
                          color: Colors.orange.shade100,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Container(
                              height: 30,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'EdgeInsets.fromLTRB',
                          style: TextStyle(fontSize: 10),
                        ),
                        Container(
                          color: Colors.purple.shade100,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 24, 4),
                            child: Container(
                              height: 30,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'SizedBox as Spacer',
          'Using SizedBox to add spacing.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SizedBox(height: 16)', style: TextStyle(fontSize: 10)),
              Container(
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    Container(height: 30, color: Colors.blue),
                    const SizedBox(height: 16),
                    Container(height: 30, color: Colors.green),
                    const SizedBox(height: 16),
                    Container(height: 30, color: Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Gap (with Wrap)',
          'Uniform spacing in layouts.',
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                6,
                (i) => Container(
                  width: 50,
                  height: 30,
                  color: Colors.primaries[i],
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Margin vs Padding',
          'Understanding the difference.',
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Margin', style: TextStyle(fontSize: 10)),
                    Container(
                      color: Colors.grey.shade200,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        height: 40,
                        color: Colors.blue,
                        child: const Center(
                          child: Text(
                            'Container',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    const Text('Padding', style: TextStyle(fontSize: 10)),
                    Container(
                      color: Colors.grey.shade200,
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        height: 40,
                        color: Colors.green,
                        child: const Center(
                          child: Text(
                            'Container',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
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

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Constraints Section
// =============================================================================

class _ConstraintsSection extends StatelessWidget {
  const _ConstraintsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'SizedBox',
          'Fixed width and/or height.',
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 60,
                child: Container(
                  color: Colors.blue,
                  child: const Center(
                    child: Text(
                      '80x60',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                height: 40,
                child: Container(
                  color: Colors.green,
                  child: const Center(
                    child: Text(
                      '100x40',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'ConstrainedBox',
          'Min/max width and height constraints.',
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 100,
              maxWidth: 200,
              minHeight: 50,
              maxHeight: 80,
            ),
            child: Container(
              color: Colors.purple,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'min 100x50\nmax 200x80',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'UnconstrainedBox',
          'Allows child to size without constraints.',
          Container(
            height: 80,
            color: Colors.grey.shade200,
            child: UnconstrainedBox(
              child: Container(
                width: 150,
                height: 50,
                color: Colors.orange,
                child: const Center(
                  child: Text(
                    'Unconstrained',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'LimitedBox',
          'Maximum size when unbounded.',
          Container(
            height: 100,
            color: Colors.grey.shade100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                LimitedBox(
                  maxWidth: 100,
                  child: Container(
                    color: Colors.red,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Max 100',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LimitedBox(
                  maxWidth: 150,
                  child: Container(
                    color: Colors.blue,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Max 150',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'AspectRatio',
          'Maintain width-to-height ratio.',
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('1:1', style: TextStyle(fontSize: 10)),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        color: Colors.red,
                        child: const Center(
                          child: Text(
                            '1:1',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    const Text('16:9', style: TextStyle(fontSize: 10)),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.blue,
                        child: const Center(
                          child: Text(
                            '16:9',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    const Text('4:3', style: TextStyle(fontSize: 10)),
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: Colors.green,
                        child: const Center(
                          child: Text(
                            '4:3',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'IntrinsicWidth/Height',
          'Size based on largest child.',
          IntrinsicWidth(
            child: Column(
              children: [
                Container(
                  color: Colors.red.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const Text('Short'),
                ),
                Container(
                  color: Colors.green.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const Text('Medium length'),
                ),
                Container(
                  color: Colors.blue.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const Text('Longest text here'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Practical Layouts Section
// =============================================================================

class _PracticalLayoutsSection extends StatelessWidget {
  const _PracticalLayoutsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Header Layout',
          'Common header pattern with title and actions.',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.menu),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'App Title',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'List Item Layout',
          'Common list item pattern.',
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John Doe',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'john.doe@example.com',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Form Layout',
          'Labeled form fields.',
          Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Name:', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Email:', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Media Card Layout',
          'Card with image and content.',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video Title',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Channel Name • 125K views • 2 days ago',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        const Chip(
                          label: Text('Flutter'),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Chip(
                          label: Text('Tutorial'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Bottom Bar Layout',
          'Action bar at bottom.',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                const Spacer(),
                FilledButton.tonal(onPressed: () {}, child: const Text('Save Draft')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () {}, child: const Text('Submit')),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Centered Content',
          'Vertically and horizontally centered.',
          Container(
            height: 150,
            color: Colors.grey.shade100,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No items yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Add First Item'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _ColorBox extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorBox(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 40,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SmallBox extends StatelessWidget {
  final Color color;
  final double? height;

  const _SmallBox(this.color, {this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: height ?? 30,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
