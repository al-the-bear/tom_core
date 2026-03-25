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
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Row & Column',
          subtitle: 'Linear arrangement of children',
        ),
        _RowColumnSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'MainAxisAlignment',
          subtitle: 'Alignment along the main axis',
        ),
        _MainAxisAlignmentSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'CrossAxisAlignment',
          subtitle: 'Alignment along the cross axis',
        ),
        _CrossAxisAlignmentSection(),
        TomSizedBox(height: 32),
        _SectionHeader(title: 'Flex & Expanded', subtitle: 'Flexible layouts'),
        _FlexSection(),
        TomSizedBox(height: 32),
        _SectionHeader(title: 'Stack', subtitle: 'Overlapping children'),
        _StackSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Wrap',
          subtitle: 'Wrapping children to next line',
        ),
        _WrapSection(),
        TomSizedBox(height: 32),
        _SectionHeader(title: 'Spacing & Padding', subtitle: 'Layout spacing'),
        _SpacingSection(),
        TomSizedBox(height: 32),
        _SectionHeader(title: 'Constraints', subtitle: 'Size constraints'),
        _ConstraintsSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Practical Layouts',
          subtitle: 'Common layout patterns',
        ),
        _PracticalLayoutsSection(),
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
// Row & Column Section
// =============================================================================

class _RowColumnSection extends StatelessWidget {
  const _RowColumnSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Row',
          'Horizontal arrangement of children.',
          TomRow(
            tomId: 'demo.layout.row.basic',
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
          TomColumn(
            tomId: 'demo.layout.column.basic',
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
          TomRow(
            tomId: 'demo.layout.row.nested',
            children: [
              TomColumn(
                tomId: 'demo.layout.column.nested1',
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorBox(Colors.red, '1'),
                  _ColorBox(Colors.orange, '2'),
                ],
              ),
              TomColumn(
                tomId: 'demo.layout.column.nested2',
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorBox(Colors.green, '3'),
                  _ColorBox(Colors.teal, '4'),
                ],
              ),
              TomColumn(
                tomId: 'demo.layout.column.nested3',
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
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText('MainAxisSize.min:', style: TextStyle(fontSize: 12)),
              TomContainer(
                color: Colors.grey.shade200,
                child: TomRow(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ColorBox(Colors.red, '1'),
                    _ColorBox(Colors.green, '2'),
                  ],
                ),
              ),
              const TomSizedBox(height: 8),
              const TomText('MainAxisSize.max:', style: TextStyle(fontSize: 12)),
              TomContainer(
                color: Colors.grey.shade200,
                child: TomRow(
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
            const TomSizedBox(height: 12),
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

    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              alignments.entries.map((entry) {
                return TomPadding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        'MainAxisAlignment.${entry.key}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TomSizedBox(height: 4),
                      TomContainer(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TomRow(
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

    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              alignments.entries.map((entry) {
                final isBaseline = entry.key == 'baseline';
                return TomPadding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        'CrossAxisAlignment.${entry.key}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TomSizedBox(height: 4),
                      TomContainer(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TomRow(
                          crossAxisAlignment: entry.value,
                          textBaseline:
                              isBaseline ? TextBaseline.alphabetic : null,
                          children: [
                            if (isBaseline) ...[
                              const TomText(
                                'Abc',
                                style: TextStyle(fontSize: 24),
                              ),
                              const TomText(
                                'Xyz',
                                style: TextStyle(fontSize: 16),
                              ),
                              const TomText(
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Expanded',
          'Child fills available space.',
          TomContainer(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TomRow(
              children: [
                _ColorBox(Colors.red, 'Fixed'),
                TomExpanded(child: _ColorBox(Colors.green, 'Expanded')),
                _ColorBox(Colors.blue, 'Fixed'),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Flexible',
          'Child can shrink but tries to fill space.',
          TomContainer(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TomRow(
              children: [
                TomFlexible(
                  fit: FlexFit.tight,
                  child: _ColorBox(Colors.red, 'Tight'),
                ),
                TomFlexible(
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
          TomContainer(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TomRow(
              children: [
                TomExpanded(flex: 1, child: _ColorBox(Colors.red, '1')),
                TomExpanded(flex: 2, child: _ColorBox(Colors.green, '2')),
                TomExpanded(flex: 3, child: _ColorBox(Colors.blue, '3')),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'FractionallySizedBox',
          'Child as fraction of available space.',
          TomContainer(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TomAlign(
              alignment: Alignment.centerLeft,
              child: TomFractionallySizedBox(
                widthFactor: 0.6,
                child: TomContainer(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const TomCenter(
                    child: TomText(
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
          TomContainer(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TomRow(
              children: [
                _ColorBox(Colors.red, 'Left'),
                const TomSpacer(),
                _ColorBox(Colors.green, 'Center'),
                const TomSpacer(flex: 2),
                _ColorBox(Colors.blue, 'Right'),
              ],
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
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Stack',
          'Overlapping widgets.',
          TomSizedBox(
            height: 150,
            child: TomStack(
              tomId: 'demo.layout.stack.basic',
              children: [
                TomContainer(
                  width: 150,
                  height: 150,
                  color: Colors.red.shade200,
                  child: const TomCenter(child: TomText('Bottom')),
                ),
                TomPositioned(
                  left: 50,
                  top: 50,
                  child: TomContainer(
                    width: 100,
                    height: 100,
                    color: Colors.green.shade300,
                    child: const TomCenter(child: TomText('Middle')),
                  ),
                ),
                TomPositioned(
                  left: 100,
                  top: 30,
                  child: TomContainer(
                    width: 80,
                    height: 80,
                    color: Colors.blue.shade400,
                    child: const TomCenter(
                      child: TomText('Top', style: TextStyle(color: Colors.white)),
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
          TomSizedBox(
            height: 120,
            child: TomRow(
              children: [
                TomExpanded(
                  child: TomStack(
                    alignment: Alignment.topLeft,
                    children: [
                      TomContainer(
                        width: 80,
                        height: 80,
                        color: Colors.red.shade100,
                      ),
                      TomContainer(width: 40, height: 40, color: Colors.red),
                    ],
                  ),
                ),
                TomExpanded(
                  child: TomStack(
                    alignment: Alignment.center,
                    children: [
                      TomContainer(
                        width: 80,
                        height: 80,
                        color: Colors.green.shade100,
                      ),
                      TomContainer(width: 40, height: 40, color: Colors.green),
                    ],
                  ),
                ),
                TomExpanded(
                  child: TomStack(
                    alignment: Alignment.bottomRight,
                    children: [
                      TomContainer(
                        width: 80,
                        height: 80,
                        color: Colors.blue.shade100,
                      ),
                      TomContainer(width: 40, height: 40, color: Colors.blue),
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
          TomSizedBox(
            height: 150,
            child: TomStack(
              children: [
                TomContainer(color: Colors.grey.shade100),
                const TomPositioned(
                  top: 10,
                  left: 10,
                  child: TomIcon(Icons.add_circle, color: Colors.red),
                ),
                const TomPositioned(
                  top: 10,
                  right: 10,
                  child: TomIcon(Icons.remove_circle, color: Colors.blue),
                ),
                const TomPositioned(
                  bottom: 10,
                  left: 10,
                  child: TomIcon(Icons.check_circle, color: Colors.green),
                ),
                const TomPositioned(
                  bottom: 10,
                  right: 10,
                  child: TomIcon(Icons.cancel, color: Colors.orange),
                ),
                const TomCenter(child: TomIcon(Icons.star, size: 48, color: Colors.amber)),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Positioned.fill',
          'Child fills entire stack area.',
          TomSizedBox(
            height: 120,
            child: TomStack(
              children: [
                Positioned.fill(
                  child: TomContainer(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                TomCenter(
                  child: TomText(
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
          TomRow(
            children: [
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('loose', style: TextStyle(fontSize: 10)),
                    TomSizedBox(
                      height: 80,
                      child: TomStack(
                        fit: StackFit.loose,
                        children: [
                          TomContainer(color: Colors.grey.shade200),
                          TomContainer(width: 40, height: 40, color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('expand', style: TextStyle(fontSize: 10)),
                    TomSizedBox(
                      height: 80,
                      child: TomStack(
                        fit: StackFit.expand,
                        children: [
                          TomContainer(color: Colors.grey.shade200),
                          TomContainer(color: Colors.green.withValues(alpha: 0.7)),
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
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Wrap',
          'Children wrap to next line automatically.',
          TomWrap(
            tomId: 'demo.layout.wrap.basic',
            children: List.generate(
              10,
              (i) => TomPadding(
                padding: const EdgeInsets.all(4),
                child: TomChip(label: TomText('Item \${i + 1}')),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Wrap with Spacing',
          'Control horizontal and vertical spacing.',
          TomWrap(
            tomId: 'demo.layout.wrap.spacing',
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              8,
              (i) => TomContainer(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.primaries[i % Colors.primaries.length],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TomCenter(
                  child: TomText(
                    '\${i + 1}',
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
          TomSizedBox(
            height: 150,
            child: TomWrap(
              tomId: 'demo.layout.wrap.vertical',
              direction: Axis.vertical,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                8,
                (i) => TomContainer(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.primaries[i % Colors.primaries.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TomCenter(
                    child: TomText(
                      '\${i + 1}',
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
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText('WrapAlignment.start', style: TextStyle(fontSize: 10)),
              TomContainer(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: TomWrap(
                  alignment: WrapAlignment.start,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
              const TomSizedBox(height: 8),
              const TomText('WrapAlignment.center', style: TextStyle(fontSize: 10)),
              TomContainer(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: TomWrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
              const TomSizedBox(height: 8),
              const TomText('WrapAlignment.end', style: TextStyle(fontSize: 10)),
              TomContainer(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: TomWrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: List.generate(
                    3,
                    (i) => _SmallBox(Colors.primaries[i]),
                  ),
                ),
              ),
              const TomSizedBox(height: 8),
              const TomText(
                'WrapAlignment.spaceBetween',
                style: TextStyle(fontSize: 10),
              ),
              TomContainer(
                color: Colors.grey.shade100,
                width: double.infinity,
                child: TomWrap(
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
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Padding',
          'Insets around a child widget.',
          TomColumn(
            children: [
              TomRow(
                children: [
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        const TomText(
                          'EdgeInsets.all(16)',
                          style: TextStyle(fontSize: 10),
                        ),
                        TomContainer(
                          color: Colors.blue.shade100,
                          child: TomPadding(
                            padding: const EdgeInsets.all(16),
                            child: TomContainer(
                              height: 30,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TomSizedBox(width: 8),
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        const TomText(
                          'EdgeInsets.symmetric',
                          style: TextStyle(fontSize: 10),
                        ),
                        TomContainer(
                          color: Colors.green.shade100,
                          child: TomPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: TomContainer(
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
              const TomSizedBox(height: 8),
              TomRow(
                children: [
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        const TomText(
                          'EdgeInsets.only(left)',
                          style: TextStyle(fontSize: 10),
                        ),
                        TomContainer(
                          color: Colors.orange.shade100,
                          child: TomPadding(
                            padding: const EdgeInsets.only(left: 32),
                            child: TomContainer(
                              height: 30,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TomSizedBox(width: 8),
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        const TomText(
                          'EdgeInsets.fromLTRB',
                          style: TextStyle(fontSize: 10),
                        ),
                        TomContainer(
                          color: Colors.purple.shade100,
                          child: TomPadding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 24, 4),
                            child: TomContainer(
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
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText('TomSizedBox(height: 16)', style: TextStyle(fontSize: 10)),
              TomContainer(
                color: Colors.grey.shade100,
                child: TomColumn(
                  children: [
                    TomContainer(height: 30, color: Colors.blue),
                    const TomSizedBox(height: 16),
                    TomContainer(height: 30, color: Colors.green),
                    const TomSizedBox(height: 16),
                    TomContainer(height: 30, color: Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Gap (with Wrap)',
          'Uniform spacing in layouts.',
          TomContainer(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                6,
                (i) => TomContainer(
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
          TomRow(
            children: [
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('Margin', style: TextStyle(fontSize: 10)),
                    TomContainer(
                      color: Colors.grey.shade200,
                      child: TomContainer(
                        margin: const EdgeInsets.all(16),
                        height: 40,
                        color: Colors.blue,
                        child: const TomCenter(
                          child: TomText(
                            'Container',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('Padding', style: TextStyle(fontSize: 10)),
                    TomContainer(
                      color: Colors.grey.shade200,
                      padding: const EdgeInsets.all(16),
                      child: TomContainer(
                        height: 40,
                        color: Colors.green,
                        child: const TomCenter(
                          child: TomText(
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
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'SizedBox',
          'Fixed width and/or height.',
          TomRow(
            children: [
              TomSizedBox(
                width: 80,
                height: 60,
                child: TomContainer(
                  color: Colors.blue,
                  child: const TomCenter(
                    child: TomText(
                      '80x60',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 8),
              TomSizedBox(
                width: 100,
                height: 40,
                child: TomContainer(
                  color: Colors.green,
                  child: const TomCenter(
                    child: TomText(
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
          TomConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 100,
              maxWidth: 200,
              minHeight: 50,
              maxHeight: 80,
            ),
            child: TomContainer(
              color: Colors.purple,
              child: const TomCenter(
                child: TomPadding(
                  padding: EdgeInsets.all(8),
                  child: TomText(
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
          TomContainer(
            height: 80,
            color: Colors.grey.shade200,
            child: UnconstrainedBox(
              child: TomContainer(
                width: 150,
                height: 50,
                color: Colors.orange,
                child: const TomCenter(
                  child: TomText(
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
          TomContainer(
            height: 100,
            color: Colors.grey.shade100,
            child: TomListView(
              scrollDirection: Axis.horizontal,
              children: [
                TomLimitedBox(
                  maxWidth: 100,
                  child: TomContainer(
                    color: Colors.red,
                    child: const TomPadding(
                      padding: EdgeInsets.all(8),
                      child: TomText(
                        'Max 100',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const TomSizedBox(width: 8),
                TomLimitedBox(
                  maxWidth: 150,
                  child: TomContainer(
                    color: Colors.blue,
                    child: const TomPadding(
                      padding: EdgeInsets.all(8),
                      child: TomText(
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
          TomRow(
            children: [
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('1:1', style: TextStyle(fontSize: 10)),
                    TomAspectRatio(
                      aspectRatio: 1,
                      child: TomContainer(
                        color: Colors.red,
                        child: const TomCenter(
                          child: TomText(
                            '1:1',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('16:9', style: TextStyle(fontSize: 10)),
                    TomAspectRatio(
                      aspectRatio: 16 / 9,
                      child: TomContainer(
                        color: Colors.blue,
                        child: const TomCenter(
                          child: TomText(
                            '16:9',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomColumn(
                  children: [
                    const TomText('4:3', style: TextStyle(fontSize: 10)),
                    TomAspectRatio(
                      aspectRatio: 4 / 3,
                      child: TomContainer(
                        color: Colors.green,
                        child: const TomCenter(
                          child: TomText(
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
            child: TomColumn(
              children: [
                TomContainer(
                  color: Colors.red.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const TomText('Short'),
                ),
                TomContainer(
                  color: Colors.green.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const TomText('Medium length'),
                ),
                TomContainer(
                  color: Colors.blue.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const TomText('Longest text here'),
                ),
              ],
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
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Header Layout',
          'Common header pattern with title and actions.',
          TomContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: TomRow(
              children: [
                const TomIcon(Icons.menu),
                const TomSizedBox(width: 16),
                const TomExpanded(
                  child: TomText(
                    'App Title',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TomIconButton(
                  icon: const TomIcon(Icons.search),
                  onPressed: () {},
                ),
                TomIconButton(
                  icon: const TomIcon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'List Item Layout',
          'Common list item pattern.',
          TomContainer(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              children: [
                const TomCircleAvatar(child: TomIcon(Icons.person)),
                const TomSizedBox(width: 12),
                const TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        'John Doe',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TomText(
                        'john.doe@example.com',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const TomIcon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Form Layout',
          'Labeled form fields.',
          TomColumn(
            children: [
              TomRow(
                children: [
                  const TomSizedBox(
                    width: 80,
                    child: TomText('Name:', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  TomExpanded(
                    child: TomTextField(
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
              const TomSizedBox(height: 12),
              TomRow(
                children: [
                  const TomSizedBox(
                    width: 80,
                    child: TomText('Email:', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  TomExpanded(
                    child: TomTextField(
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
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomContainer(
                width: 100,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TomIcon(
                  Icons.play_circle_outline,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const TomSizedBox(width: 12),
              TomExpanded(
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TomText(
                      'Video Title',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TomSizedBox(height: 4),
                    const TomText(
                      'Channel Name • 125K views • 2 days ago',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const TomSizedBox(height: 8),
                    TomWrap(
                      spacing: 4,
                      children: [
                        const TomChip(
                          label: TomText('Flutter'),
                          visualDensity: VisualDensity.compact,
                        ),
                        const TomChip(
                          label: TomText('Tutorial'),
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
          TomContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              children: [
                TomOutlinedButton(onPressed: () {}, child: const TomText('Cancel')),
                const TomSpacer(),
                FilledButton.tonal(onPressed: () {}, child: const TomText('Save Draft')),
                const TomSizedBox(width: 8),
                TomFilledButton(onPressed: () {}, child: const TomText('Submit')),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Centered Content',
          'Vertically and horizontally centered.',
          TomContainer(
            height: 150,
            color: Colors.grey.shade100,
            child: TomCenter(
              child: TomColumn(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TomIcon(Icons.inbox, size: 48, color: Colors.grey),
                  const TomSizedBox(height: 8),
                  TomText(
                    'No items yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const TomSizedBox(height: 16),
                  TomFilledButton(
                    onPressed: () {},
                    child: const TomText('Add First Item'),
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
            const TomSizedBox(height: 12),
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
    return TomContainer(
      width: 50,
      height: 40,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: TomCenter(
        child: TomText(
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
    return TomContainer(
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
