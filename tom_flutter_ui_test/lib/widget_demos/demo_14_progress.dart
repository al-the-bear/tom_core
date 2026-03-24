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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'CircularProgressIndicator',
          subtitle: 'Circular loading indicators',
        ),
        _CircularProgressSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'LinearProgressIndicator',
          subtitle: 'Linear loading bars',
        ),
        _LinearProgressSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Determinate Progress',
          subtitle: 'Progress with known completion',
        ),
        _DeterminateProgressSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Shimmer & Skeleton',
          subtitle: 'Content placeholder loading',
        ),
        _ShimmerSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Custom Progress',
          subtitle: 'Custom progress indicators',
        ),
        _CustomProgressSection(),
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
// Circular Progress Section
// =============================================================================

class _CircularProgressSection extends StatelessWidget {
  const _CircularProgressSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Indeterminate',
          'Spinning indicator for unknown duration.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularProgressIndicator(),
              CircularProgressIndicator(strokeWidth: 2),
              CircularProgressIndicator(strokeWidth: 6),
            ],
          ),
        ),
        _buildDemoCard(
          'Sizes',
          'Different indicator sizes.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(strokeWidth: 6),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Colors',
          'Colored progress indicators.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularProgressIndicator(color: Colors.red),
              CircularProgressIndicator(color: Colors.green),
              CircularProgressIndicator(color: Colors.blue),
              CircularProgressIndicator(color: Colors.orange),
            ],
          ),
        ),
        _buildDemoCard(
          'With Background',
          'Progress with track background.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularProgressIndicator(
                value: 0.7,
                backgroundColor: Colors.grey.shade200,
              ),
              CircularProgressIndicator(
                value: 0.4,
                backgroundColor: Colors.blue.shade100,
                color: Colors.blue,
              ),
              CircularProgressIndicator(
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
            const SizedBox(height: 16),
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
    return Column(
      children: [
        _buildDemoCard(
          'Indeterminate',
          'Animated bar for unknown duration.',
          const Column(
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 16),
              LinearProgressIndicator(minHeight: 8),
            ],
          ),
        ),
        _buildDemoCard(
          'With Values',
          'Determinate progress bars.',
          Column(
            children: [
              LinearProgressIndicator(value: 0.3),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: 0.6),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: 1.0),
            ],
          ),
        ),
        _buildDemoCard(
          'Colors',
          'Colored progress bars.',
          Column(
            children: [
              LinearProgressIndicator(
                value: 0.7,
                backgroundColor: Colors.red.shade100,
                color: Colors.red,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.5,
                backgroundColor: Colors.green.shade100,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
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
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.6,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
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
            const SizedBox(height: 16),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Animated Progress',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                          Text(
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
                Expanded(
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toInt()}% complete'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: _isRunning ? null : _startProgress,
                  child: const Text('Start'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _resetProgress,
                  child: const Text('Reset'),
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
    return Column(
      children: [
        _buildDemoCard(
          'Card Skeleton',
          'Placeholder for loading cards.',
          const _ShimmerCard(),
        ),
        _buildDemoCard(
          'List Skeleton',
          'Placeholder for loading list items.',
          Column(
            children: List.generate(
              3,
              (i) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _ShimmerListItem(),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Text Skeleton',
          'Placeholder for loading text.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(200, 16),
              const SizedBox(height: 8),
              _shimmerBox(double.infinity, 12),
              const SizedBox(height: 4),
              _shimmerBox(double.infinity, 12),
              const SizedBox(height: 4),
              _shimmerBox(150, 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
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
            const SizedBox(height: 16),
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
              const SizedBox(height: 12),
              _shimmerBox(150, 16),
              const SizedBox(height: 8),
              _shimmerBox(double.infinity, 12),
              const SizedBox(height: 4),
              _shimmerBox(100, 12),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height) {
    return Container(
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
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
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
    return Column(
      children: [
        _buildDemoCard(
          'Step Progress',
          'Multi-step progress indicator.',
          const _StepProgressDemo(),
        ),
        _buildDemoCard(
          'Segmented Progress',
          'Progress divided into segments.',
          Column(
            children: [
              _SegmentedProgress(segments: 5, completed: 3),
              const SizedBox(height: 12),
              _SegmentedProgress(segments: 4, completed: 4),
              const SizedBox(height: 12),
              _SegmentedProgress(segments: 6, completed: 2),
            ],
          ),
        ),
        _buildDemoCard(
          'Progress with Icon',
          'Circular progress with center icon.',
          Row(
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
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 4,
            backgroundColor: color.withValues(alpha: 0.2),
            color: color,
          ),
        ),
        Icon(icon, color: color),
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
            const SizedBox(height: 16),
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
    return Column(
      children: [
        Row(
          children: [
            for (int i = 1; i <= 4; i++) ...[
              _stepCircle(i),
              if (i < 4)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < _currentStep ? Colors.blue : Colors.grey.shade300,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentStep > 1
                  ? () => setState(() => _currentStep--)
                  : null,
              icon: const Icon(Icons.arrow_back),
            ),
            Text('Step $_currentStep of 4'),
            IconButton(
              onPressed: _currentStep < 4
                  ? () => setState(() => _currentStep++)
                  : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepCircle(int step) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted || isCurrent ? Colors.blue : Colors.grey.shade300,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$step',
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
    return Row(
      children: List.generate(segments, (index) {
        final isCompleted = index < completed;
        return Expanded(
          child: Container(
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
