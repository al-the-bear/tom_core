/// Demo 14: Progress Indicators
///
/// Comprehensive demonstration of all Tom progress indicator widgets.
/// Widgets covered: TomCircularProgressIndicator, TomLinearProgressIndicator,
/// TomRefreshIndicator, TomCupertinoActivityIndicator,
/// TomCupertinoLinearActivityIndicator, TomCupertinoSliverRefreshControl.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Progress Indicators demo.
class ProgressDemo extends TomStatelessWidget {
  ProgressDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ProgressDemoContent();
  }
}

class _ProgressDemoContent extends TomStatefulWidget {
  _ProgressDemoContent();

  @override
  State<_ProgressDemoContent> createState() => _ProgressDemoContentState();
}

class _ProgressDemoContentState extends TomState<_ProgressDemoContent>
    with TickerProviderStateMixin {
  // Animation controllers for determinate progress
  late AnimationController _circularController;
  late AnimationController _linearController;

  // State for interactive demos
  double _circularProgress = 0.0;
  double _linearProgress = 0.0;
  bool _cupertinoAnimating = true;

  // Refresh state
  final List<String> _refreshItems = List.generate(5, (i) => 'Item ${i + 1}');

  @override
  void initState() {
    super.initState();
    _circularController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addListener(() {
            setState(() {
              _circularProgress = _circularController.value;
            });
          });

    _linearController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(() {
            setState(() {
              _linearProgress = _linearController.value;
            });
          });
  }

  @override
  void dispose() {
    _circularController.dispose();
    _linearController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Circular Progress
            _SectionHeader(tomId: 'section.circular'),
            TomSizedBox(height: 16),
            _buildCircularProgressSection(),
            TomSizedBox(height: 32),

            // Section 2: Linear Progress
            _SectionHeader(tomId: 'section.linear'),
            TomSizedBox(height: 16),
            _buildLinearProgressSection(),
            TomSizedBox(height: 32),

            // Section 3: Refresh Indicators
            _SectionHeader(tomId: 'section.refresh'),
            TomSizedBox(height: 16),
            _buildRefreshIndicatorSection(),
            TomSizedBox(height: 32),

            // Section 4: Cupertino Indicators
            _SectionHeader(tomId: 'section.cupertino'),
            TomSizedBox(height: 16),
            _buildCupertinoActivitySection(),
            TomSizedBox(height: 24),
            _buildCupertinoLinearSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Circular Progress
  // ===========================================================================

  Widget _buildCircularProgressSection() {
    return _DemoCard(
      tomId: 'circular',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indeterminate circular indicators
          TomText(
            tomId: 'circular.indeterminateLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              // Default indeterminate
              TomColumn(
                children: [
                  TomCircularProgressIndicator(),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.default',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Custom color
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.colored',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Thick stroke
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    strokeWidth: 8,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.thick',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Thin stroke
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.thin',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Determinate circular indicators
          TomText(
            tomId: 'circular.determinateLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              // Animated determinate
              TomColumn(
                children: [
                  TomCircularProgressIndicator(value: _circularProgress),
                  TomSizedBox(height: 8),
                  TomText(
                    text: '${(_circularProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Fixed 25%
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 0.25,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    text: '25%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Fixed 50%
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 0.5,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    text: '50%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Fixed 75%
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 0.75,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    text: '75%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Complete
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 1.0,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: Colors.green,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    text: '100%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          TomSizedBox(height: 16),

          // Control buttons
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomElevatedButton(
                tomId: 'circular.start',
                onPressed: () {
                  _circularController.forward(from: 0);
                },
              ),
              TomSizedBox(width: 12),
              TomOutlinedButton(
                tomId: 'circular.reset',
                onPressed: () {
                  _circularController.reset();
                },
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Stroke caps
          TomText(
            tomId: 'circular.strokeCapLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 0.7,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.butt,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.capButt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 0.7,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.capRound',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              TomColumn(
                children: [
                  TomCircularProgressIndicator(
                    value: 0.7,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.square,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'circular.capSquare',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Linear Progress
  // ===========================================================================

  Widget _buildLinearProgressSection() {
    return _DemoCard(
      tomId: 'linear',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indeterminate linear indicators
          TomText(
            tomId: 'linear.indeterminateLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          // Default indeterminate
          TomText(
            tomId: 'linear.default',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TomSizedBox(height: 8),
          TomLinearProgressIndicator(),
          TomSizedBox(height: 16),

          // Colored
          TomText(
            tomId: 'linear.colored',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TomSizedBox(height: 8),
          TomLinearProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.2),
          ),
          TomSizedBox(height: 16),

          // Thick
          TomText(
            tomId: 'linear.thick',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TomSizedBox(height: 8),
          TomLinearProgressIndicator(
            minHeight: 12,
            color: Theme.of(context).colorScheme.tertiary,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.2),
          ),
          TomSizedBox(height: 24),

          // Determinate linear indicators
          TomText(
            tomId: 'linear.determinateLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          // Animated determinate
          TomRow(
            children: [
              TomExpanded(
                child: TomLinearProgressIndicator(
                  value: _linearProgress,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              TomSizedBox(width: 12),
              TomText(
                text: '${(_linearProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          TomSizedBox(height: 16),

          // Fixed percentages
          TomColumn(
            children: [
              _buildLinearProgressRow('25%', 0.25),
              TomSizedBox(height: 8),
              _buildLinearProgressRow('50%', 0.5),
              TomSizedBox(height: 8),
              _buildLinearProgressRow('75%', 0.75),
              TomSizedBox(height: 8),
              _buildLinearProgressRow('100%', 1.0),
            ],
          ),
          TomSizedBox(height: 16),

          // Control buttons
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomElevatedButton(
                tomId: 'linear.start',
                onPressed: () {
                  _linearController.forward(from: 0);
                },
              ),
              TomSizedBox(width: 12),
              TomOutlinedButton(
                tomId: 'linear.reset',
                onPressed: () {
                  _linearController.reset();
                },
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Rounded corners
          TomText(
            tomId: 'linear.roundedLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          TomText(
            tomId: 'linear.roundedSmall',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TomSizedBox(height: 8),
          TomLinearProgressIndicator(
            value: 0.6,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
          TomSizedBox(height: 12),

          TomText(
            tomId: 'linear.roundedLarge',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TomSizedBox(height: 8),
          TomLinearProgressIndicator(
            value: 0.6,
            minHeight: 16,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.secondary,
          ),
          TomSizedBox(height: 12),

          TomText(
            tomId: 'linear.pill',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TomSizedBox(height: 8),
          TomLinearProgressIndicator(
            value: 0.6,
            minHeight: 24,
            borderRadius: BorderRadius.circular(12),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildLinearProgressRow(String label, double value) {
    return TomRow(
      children: [
        TomSizedBox(
          width: 40,
          child: TomText(
            text: label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TomExpanded(
          child: TomLinearProgressIndicator(
            value: value,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 3: Refresh Indicators
  // ===========================================================================

  Widget _buildRefreshIndicatorSection() {
    return _DemoCard(
      tomId: 'refresh',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'refresh.pullLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          // Material Refresh Indicator
          TomContainer(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomRefreshIndicator(
              onRefresh: () async {
                await Future<void>.delayed(const Duration(seconds: 1));
                if (mounted) {
                  setState(() {
                    _refreshItems.insert(
                      0,
                      'New Item ${DateTime.now().second}',
                    );
                  });
                }
              },
              child: TomListView.builder(
                itemCount: _refreshItems.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(_refreshItems[index]),
                    subtitle: const Text('Pull down to refresh'),
                  );
                },
              ),
            ),
          ),
          TomSizedBox(height: 8),
          Center(
            child: TomText(
              tomId: 'refresh.hint',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TomSizedBox(height: 24),

          // Colored refresh indicator
          TomText(
            tomId: 'refresh.customLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          TomContainer(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomRefreshIndicator(
              color: Theme.of(context).colorScheme.secondary,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              displacement: 60,
              strokeWidth: 3,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(seconds: 1));
              },
              child: TomListView(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.color_lens,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: const Text('Custom Colors'),
                    subtitle: const Text('Secondary color theme'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.straighten,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: const Text('Custom Displacement'),
                    subtitle: const Text('60px from top'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Cupertino Indicators
  // ===========================================================================

  Widget _buildCupertinoActivitySection() {
    return _DemoCard(
      tomId: 'cupertinoActivity',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'cupertinoActivity.spinnerLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          TomWrap(
            spacing: 32,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              // Default
              TomColumn(
                children: [
                  TomCupertinoActivityIndicator(),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'cupertinoActivity.default',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Large
              TomColumn(
                children: [
                  TomCupertinoActivityIndicator(radius: 20),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'cupertinoActivity.large',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Small
              TomColumn(
                children: [
                  TomCupertinoActivityIndicator(radius: 8),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'cupertinoActivity.small',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              // Custom color
              TomColumn(
                children: [
                  TomCupertinoActivityIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'cupertinoActivity.colored',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Toggle animation
          TomText(
            tomId: 'cupertinoActivity.animationLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          TomRow(
            children: [
              TomCupertinoActivityIndicator(
                animating: _cupertinoAnimating,
                radius: 15,
              ),
              TomSizedBox(width: 16),
              TomText(
                text: _cupertinoAnimating ? 'Animating' : 'Paused',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              TomSwitch(
                value: _cupertinoAnimating,
                onChanged: (value) {
                  setState(() => _cupertinoAnimating = value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoLinearSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'cupertinoLinear',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              tomId: 'cupertinoLinear.barLabel',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            TomSizedBox(height: 12),

            // Indeterminate
            TomText(
              tomId: 'cupertinoLinear.indeterminate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TomSizedBox(height: 8),
            TomCupertinoLinearActivityIndicator(),
            TomSizedBox(height: 16),

            // Determinate values
            TomText(
              tomId: 'cupertinoLinear.determinate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TomSizedBox(height: 8),
            TomColumn(
              children: [
                TomRow(
                  children: [
                    TomSizedBox(width: 40, child: TomText(text: '25%')),
                    TomExpanded(
                      child: TomCupertinoLinearActivityIndicator(value: 0.25),
                    ),
                  ],
                ),
                TomSizedBox(height: 8),
                TomRow(
                  children: [
                    TomSizedBox(width: 40, child: TomText(text: '50%')),
                    TomExpanded(
                      child: TomCupertinoLinearActivityIndicator(value: 0.5),
                    ),
                  ],
                ),
                TomSizedBox(height: 8),
                TomRow(
                  children: [
                    TomSizedBox(width: 40, child: TomText(text: '75%')),
                    TomExpanded(
                      child: TomCupertinoLinearActivityIndicator(value: 0.75),
                    ),
                  ],
                ),
                TomSizedBox(height: 8),
                TomRow(
                  children: [
                    TomSizedBox(width: 40, child: TomText(text: '100%')),
                    TomExpanded(
                      child: TomCupertinoLinearActivityIndicator(value: 1.0),
                    ),
                  ],
                ),
              ],
            ),
            TomSizedBox(height: 16),

            // Customized
            TomText(
              tomId: 'cupertinoLinear.custom',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TomSizedBox(height: 8),
            TomCupertinoLinearActivityIndicator(
              value: 0.6,
              trackHeight: 10,
              color: CupertinoColors.activeGreen,
            ),
            TomSizedBox(height: 12),
            TomCupertinoLinearActivityIndicator(
              value: 0.4,
              trackHeight: 10,
              color: CupertinoColors.systemOrange,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header widget with gradient underline.
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

/// Demo card widget for individual widget showcases.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
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
                TomIcon(tomId: tomId),
                TomSizedBox(width: 12),
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
            TomSizedBox(height: 8),
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
