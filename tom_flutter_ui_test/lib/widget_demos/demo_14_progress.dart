/// Comprehensive Progress Indicators Demo
///
/// This demo showcases CircularProgressIndicator, LinearProgressIndicator,
/// RefreshIndicator, and custom progress patterns.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'dart:async';

/// Main progress demo screen.
class ProgressDemo extends StatelessWidget {
  const ProgressDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'CircularProgressIndicator',
          subtitle: 'Circular loading indicators',
        ),
        _CircularProgressSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'LinearProgressIndicator',
          subtitle: 'Linear loading bars',
        ),
        _LinearProgressSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Determinate Progress',
          subtitle: 'Progress with known completion',
        ),
        _DeterminateProgressSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Shimmer & Skeleton',
          subtitle: 'Content placeholder loading',
        ),
        _ShimmerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Custom Progress',
          subtitle: 'Custom progress indicators',
        ),
        _CustomProgressSection(),
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
// Circular Progress Section
// =============================================================================

class _CircularProgressSection extends StatelessWidget {
  const _CircularProgressSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Indeterminate',
          'Spinning indicator for unknown duration.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomCircularProgressIndicator(),
              TomCircularProgressIndicator(strokeWidth: 2),
              TomCircularProgressIndicator(strokeWidth: 6),
            ],
          ),
        ),
        _buildDemoCard(
          'Sizes',
          'Different indicator sizes.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomSizedBox(
                width: 20,
                height: 20,
                child: TomCircularProgressIndicator(strokeWidth: 2),
              ),
              TomSizedBox(
                width: 32,
                height: 32,
                child: TomCircularProgressIndicator(strokeWidth: 3),
              ),
              const TomSizedBox(
                width: 48,
                height: 48,
                child: TomCircularProgressIndicator(),
              ),
              const TomSizedBox(
                width: 64,
                height: 64,
                child: TomCircularProgressIndicator(strokeWidth: 6),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Colors',
          'Colored progress indicators.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomCircularProgressIndicator(color: Colors.red),
              TomCircularProgressIndicator(color: Colors.green),
              TomCircularProgressIndicator(color: Colors.blue),
              TomCircularProgressIndicator(color: Colors.orange),
            ],
          ),
        ),
        _buildDemoCard(
          'With Background',
          'Progress with track background.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomCircularProgressIndicator(
                value: 0.7,
                backgroundColor: Colors.grey.shade200,
              ),
              TomCircularProgressIndicator(
                value: 0.4,
                backgroundColor: Colors.blue.shade100,
                color: Colors.blue,
              ),
              TomCircularProgressIndicator(
                value: 0.9,
                backgroundColor: Colors.green.shade100,
                color: Colors.green,
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
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Linear Progress Section
// =============================================================================

class _LinearProgressSection extends StatelessWidget {
  const _LinearProgressSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Indeterminate',
          'Animated bar for unknown duration.',
          const TomColumn(
            children: [
              TomLinearProgressIndicator(),
              TomSizedBox(height: 16),
              TomLinearProgressIndicator(minHeight: 8),
            ],
          ),
        ),
        _buildDemoCard(
          'With Values',
          'Determinate progress bars.',
          TomColumn(
            children: [
              TomLinearProgressIndicator(value: 0.3),
              const TomSizedBox(height: 8),
              TomLinearProgressIndicator(value: 0.6),
              const TomSizedBox(height: 8),
              TomLinearProgressIndicator(value: 1.0),
            ],
          ),
        ),
        _buildDemoCard(
          'Colors',
          'Colored progress bars.',
          TomColumn(
            children: [
              TomLinearProgressIndicator(
                value: 0.7,
                backgroundColor: Colors.red.shade100,
                color: Colors.red,
              ),
              const TomSizedBox(height: 8),
              TomLinearProgressIndicator(
                value: 0.5,
                backgroundColor: Colors.green.shade100,
                color: Colors.green,
              ),
              const TomSizedBox(height: 8),
              TomLinearProgressIndicator(
                value: 0.8,
                backgroundColor: Colors.orange.shade100,
                color: Colors.orange,
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Rounded',
          'Progress bars with border radius.',
          TomColumn(
            children: [
              TomClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TomLinearProgressIndicator(
                  value: 0.6,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const TomSizedBox(height: 12),
              TomClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TomLinearProgressIndicator(
                  value: 0.4,
                  minHeight: 16,
                  backgroundColor: Colors.blue.shade100,
                  color: Colors.blue,
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
            const TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Determinate Progress Section
// =============================================================================

class _DeterminateProgressSection extends StatefulWidget {
  const _DeterminateProgressSection();

  @override
  State<_DeterminateProgressSection> createState() =>
      _DeterminateProgressSectionState();
}

class _DeterminateProgressSectionState
    extends State<_DeterminateProgressSection> {
  double _progress = 0.0;
  bool _isRunning = false;
  Timer? _timer;

  void _startProgress() {
    if (_isRunning) return;
    setState(() {
      _progress = 0;
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.01;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _isRunning = false;
          timer.cancel();
        }
      });
    });
  }

  void _resetProgress() {
    _timer?.cancel();
    setState(() {
      _progress = 0;
      _isRunning = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            const TomText(null, tomId: 'demo.14.auto.text.3',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 16),
            TomRow(
              children: [
                TomExpanded(
                  child: TomColumn(
                    children: [
                      TomStack(
                        alignment: Alignment.center,
                        children: [
                          TomSizedBox(
                            width: 100,
                            height: 100,
                            child: TomCircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                          TomText(
                            '${(_progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TomExpanded(
                  child: TomColumn(
                    children: [
                      TomLinearProgressIndicator(
                        value: _progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const TomSizedBox(height: 8),
                      TomText('${(_progress * 100).toInt()}% complete'),
                    ],
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 16),
            TomRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TomFilledButton(
                  onPressed: _isRunning ? null : _startProgress,
                  child: const TomText(null, tomId: 'demo.14.auto.text.1'),
                ),
                const TomSizedBox(width: 8),
                TomOutlinedButton(
                  onPressed: _resetProgress,
                  child: const TomText(null, tomId: 'demo.14.auto.text.2'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shimmer Section
// =============================================================================

class _ShimmerSection extends StatelessWidget {
  const _ShimmerSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Card Skeleton',
          'Placeholder for loading cards.',
          const _ShimmerCard(),
        ),
        _buildDemoCard(
          'List Skeleton',
          'Placeholder for loading list items.',
          TomColumn(
            children: List.generate(
              3,
              (i) => const TomPadding(
                padding: EdgeInsets.only(bottom: 12),
                child: _ShimmerListItem(),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Text Skeleton',
          'Placeholder for loading text.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(200, 16),
              const TomSizedBox(height: 8),
              _shimmerBox(double.infinity, 12),
              const TomSizedBox(height: 4),
              _shimmerBox(double.infinity, 12),
              const TomSizedBox(height: 4),
              _shimmerBox(150, 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox(double width, double height) {
    return TomContainer(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
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
            child,
          ],
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomAnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return TomContainer(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomContainer(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                    ],
                    stops: [
                      _animation.value - 0.3,
                      _animation.value,
                      _animation.value + 0.3,
                    ].map((s) => s.clamp(0.0, 1.0)).toList(),
                  ),
                ),
              ),
              const TomSizedBox(height: 12),
              _shimmerBox(150, 16),
              const TomSizedBox(height: 8),
              _shimmerBox(double.infinity, 12),
              const TomSizedBox(height: 4),
              _shimmerBox(100, 12),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height) {
    return TomContainer(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
          stops: [
            _animation.value - 0.3,
            _animation.value,
            _animation.value + 0.3,
          ].map((s) => s.clamp(0.0, 1.0)).toList(),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ShimmerListItem extends StatelessWidget {
  const _ShimmerListItem();

  @override
  Widget build(BuildContext context) {
    return TomRow(
      children: [
        TomContainer(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
        ),
        const TomSizedBox(width: 12),
        TomExpanded(
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomContainer(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const TomSizedBox(height: 6),
              TomContainer(
                width: 200,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
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
// Custom Progress Section
// =============================================================================

class _CustomProgressSection extends StatelessWidget {
  const _CustomProgressSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Step Progress',
          'Multi-step progress indicator.',
          const _StepProgressDemo(),
        ),
        _buildDemoCard(
          'Segmented Progress',
          'Progress divided into segments.',
          TomColumn(
            children: [
              _SegmentedProgress(segments: 5, completed: 3),
              const TomSizedBox(height: 12),
              _SegmentedProgress(segments: 4, completed: 4),
              const TomSizedBox(height: 12),
              _SegmentedProgress(segments: 6, completed: 2),
            ],
          ),
        ),
        _buildDemoCard(
          'Progress with Icon',
          'Circular progress with center icon.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _iconProgress(Icons.download, 0.7, Colors.blue),
              _iconProgress(Icons.upload, 0.4, Colors.green),
              _iconProgress(Icons.sync, 0.9, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconProgress(IconData icon, double value, Color color) {
    return TomStack(
      alignment: Alignment.center,
      children: [
        TomSizedBox(
          width: 60,
          height: 60,
          child: TomCircularProgressIndicator(
            value: value,
            strokeWidth: 4,
            backgroundColor: color.withValues(alpha: 0.2),
            color: color,
          ),
        ),
        TomIcon(icon, color: color),
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
            child,
          ],
        ),
      ),
    );
  }
}

class _StepProgressDemo extends StatefulWidget {
  const _StepProgressDemo();

  @override
  State<_StepProgressDemo> createState() => _StepProgressDemoState();
}

class _StepProgressDemoState extends State<_StepProgressDemo> {
  int _currentStep = 1;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        TomRow(
          children: [
            for (int i = 1; i <= 4; i++) ...[
              _stepCircle(i),
              if (i < 4)
                TomExpanded(
                  child: TomContainer(
                    height: 2,
                    color: i < _currentStep ? Colors.blue : Colors.grey.shade300,
                  ),
                ),
            ],
          ],
        ),
        const TomSizedBox(height: 16),
        TomRow(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TomIconButton(
              onPressed: _currentStep > 1
                  ? () => setState(() => _currentStep--)
                  : null,
              icon: const TomIcon(Icons.arrow_back),
            ),
            TomText('Step $_currentStep of 4'),
            TomIconButton(
              onPressed: _currentStep < 4
                  ? () => setState(() => _currentStep++)
                  : null,
              icon: const TomIcon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepCircle(int step) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;
    return TomContainer(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted || isCurrent ? Colors.blue : Colors.grey.shade300,
      ),
      child: TomCenter(
        child: isCompleted
            ? const TomIcon(Icons.check, color: Colors.white, size: 18)
            : TomText(null, tomId: 'demo.14.auto.text.1',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int segments;
  final int completed;

  const _SegmentedProgress({required this.segments, required this.completed});

  @override
  Widget build(BuildContext context) {
    return TomRow(
      children: List.generate(segments, (index) {
        final isCompleted = index < completed;
        return TomExpanded(
          child: TomContainer(
            height: 8,
            margin: EdgeInsets.only(right: index < segments - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.blue : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
