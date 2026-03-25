/// Comprehensive Labels and Text Demo
///
/// This demo showcases Text, RichText, SelectableText, Badge,
/// and various text styling options.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main labels and text demo screen.
class LabelsDemo extends StatelessWidget {
  const LabelsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Text Widget',
          subtitle: 'Basic text display',
        ),
        _TextSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Text Styles',
          subtitle: 'Typography and styling options',
        ),
        _TextStylesSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'RichText',
          subtitle: 'Text with multiple styles',
        ),
        _RichTextSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'SelectableText',
          subtitle: 'Text that can be selected',
        ),
        _SelectableTextSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Badge',
          subtitle: 'Notification badges',
        ),
        _BadgeSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Text Effects',
          subtitle: 'Decorations and effects',
        ),
        _TextEffectsSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Practical Examples',
          subtitle: 'Common text patterns',
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
// Text Section
// =============================================================================

class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Text',
          'Simple text display.',
          const TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This is basic text'),
              TomSizedBox(height: 8),
              Text(
                'This is text with maxLines and overflow.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Text Overflow',
          'Different overflow behaviors.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TextOverflow.clip:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TomContainer(
                width: 200,
                color: Colors.grey.shade100,
                child: const Text(
                  'This is a long text that will be clipped',
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ),
              const TomSizedBox(height: 12),
              const Text(
                'TextOverflow.fade:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TomContainer(
                width: 200,
                color: Colors.grey.shade100,
                child: const Text(
                  'This is a long text that will fade out',
                  overflow: TextOverflow.fade,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              const TomSizedBox(height: 12),
              const Text(
                'TextOverflow.ellipsis:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TomContainer(
                width: 200,
                color: Colors.grey.shade100,
                child: const Text(
                  'This is a long text that will show ellipsis',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const TomSizedBox(height: 12),
              const Text(
                'TextOverflow.visible:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TomContainer(
                width: 200,
                height: 30,
                color: Colors.grey.shade100,
                child: const Text(
                  'This text overflows visibly',
                  overflow: TextOverflow.visible,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Text Alignment',
          'Different text alignments.',
          TomColumn(
            children:
                [
                  ('left', TextAlign.left),
                  ('center', TextAlign.center),
                  ('right', TextAlign.right),
                  ('justify', TextAlign.justify),
                ].map((align) {
                  return TomContainer(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade100,
                    child: Text(
                      'TextAlign.${align.$1}: The quick brown fox jumps over the lazy dog.',
                      textAlign: align.$2,
                    ),
                  );
                }).toList(),
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// Text Styles Section
// =============================================================================

class _TextStylesSection extends StatelessWidget {
  const _TextStylesSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Typography Scale',
          'Material 3 typography styles.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Display Large',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Text(
                'Display Medium',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              Text(
                'Display Small',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const TomDivider(),
              Text(
                'Headline Large',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                'Headline Medium',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Headline Small',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const TomDivider(),
              Text('Title Large', style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Title Medium',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('Title Small', style: Theme.of(context).textTheme.titleSmall),
              const TomDivider(),
              Text('Body Large', style: Theme.of(context).textTheme.bodyLarge),
              Text('Body Medium', style: Theme.of(context).textTheme.bodyMedium),
              Text('Body Small', style: Theme.of(context).textTheme.bodySmall),
              const TomDivider(),
              Text('Label Large', style: Theme.of(context).textTheme.labelLarge),
              Text(
                'Label Medium',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text('Label Small', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        _buildDemoCard(
          'Font Weight',
          'Different font weights.',
          TomWrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              const Text('w100', style: TextStyle(fontWeight: FontWeight.w100)),
              const Text('w200', style: TextStyle(fontWeight: FontWeight.w200)),
              const Text('w300', style: TextStyle(fontWeight: FontWeight.w300)),
              const Text('w400', style: TextStyle(fontWeight: FontWeight.w400)),
              const Text('w500', style: TextStyle(fontWeight: FontWeight.w500)),
              const Text('w600', style: TextStyle(fontWeight: FontWeight.w600)),
              const Text('w700', style: TextStyle(fontWeight: FontWeight.w700)),
              const Text('w800', style: TextStyle(fontWeight: FontWeight.w800)),
              const Text('w900', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        _buildDemoCard(
          'Font Style & Colors',
          'Italic and colored text.',
          const TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Normal Style',
                style: TextStyle(fontStyle: FontStyle.normal),
              ),
              Text(
                'Italic Style',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              TomSizedBox(height: 8),
              Text(
                'Primary Color',
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
              Text(
                'Secondary Color',
                style: TextStyle(color: Colors.purple, fontSize: 16),
              ),
              Text(
                'Error Color',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              Text(
                'Success Color',
                style: TextStyle(color: Colors.green, fontSize: 16),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Letter & Word Spacing',
          'Custom spacing between letters and words.',
          const TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Normal spacing'),
              Text(
                'Letter spacing 2.0',
                style: TextStyle(letterSpacing: 2.0),
              ),
              Text(
                'Letter spacing 4.0',
                style: TextStyle(letterSpacing: 4.0),
              ),
              TomSizedBox(height: 8),
              Text('Word spacing normal'),
              Text(
                'Word spacing 10.0',
                style: TextStyle(wordSpacing: 10.0),
              ),
              Text(
                'Word spacing 20.0',
                style: TextStyle(wordSpacing: 20.0),
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// RichText Section
// =============================================================================

class _RichTextSection extends StatelessWidget {
  const _RichTextSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic RichText',
          'Text with multiple styles.',
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: [
                TextSpan(text: 'This is '),
                TextSpan(
                  text: 'bold',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ', '),
                TextSpan(
                  text: 'italic',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ', and '),
                TextSpan(
                  text: 'colored',
                  style: TextStyle(color: Colors.blue),
                ),
                TextSpan(text: ' text.'),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Text.rich',
          'Alternative syntax using Text.rich.',
          const Text.rich(
            TextSpan(
              text: 'Welcome to ',
              children: [
                TextSpan(
                  text: 'Flutter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                TextSpan(text: '! Build '),
                TextSpan(
                  text: 'beautiful',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.purple,
                  ),
                ),
                TextSpan(text: ' apps.'),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Interactive Text',
          'Tappable text spans with gestures.',
          Builder(
            builder: (context) {
              return RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: [
                    const TextSpan(text: 'Read our '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                TomSnackBar(
                                  content: Text('Terms of Service tapped'),
                                ),
                              );
                            },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                TomSnackBar(
                                  content: Text('Privacy Policy tapped'),
                                ),
                              );
                            },
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              );
            },
          ),
        ),
        _buildDemoCard(
          'Text with Icons',
          'Inline icons using WidgetSpan.',
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Rating: '),
                WidgetSpan(
                  child: TomIcon(Icons.star, color: Colors.amber, size: 18),
                ),
                WidgetSpan(
                  child: TomIcon(Icons.star, color: Colors.amber, size: 18),
                ),
                WidgetSpan(
                  child: TomIcon(Icons.star, color: Colors.amber, size: 18),
                ),
                WidgetSpan(
                  child: TomIcon(Icons.star, color: Colors.amber, size: 18),
                ),
                WidgetSpan(
                  child: TomIcon(Icons.star_half, color: Colors.amber, size: 18),
                ),
                TextSpan(text: ' (4.5)'),
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// SelectableText Section
// =============================================================================

class _SelectableTextSection extends StatelessWidget {
  const _SelectableTextSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic SelectableText',
          'Text that can be selected and copied.',
          const SelectableText(
            'This text can be selected. Try selecting it and copying!',
            style: TextStyle(fontSize: 16),
          ),
        ),
        _buildDemoCard(
          'SelectableText.rich',
          'Selectable text with multiple styles.',
          const SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(text: 'You can select '),
                TextSpan(
                  text: 'rich text',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' with '),
                TextSpan(
                  text: 'multiple',
                  style: TextStyle(color: Colors.blue),
                ),
                TextSpan(text: ' '),
                TextSpan(
                  text: 'styles',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ' too!'),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'With Context Menu',
          'Custom context menu actions.',
          SelectableText(
            'Right-click or long-press to see context menu options.',
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: [
                  ...editableTextState.contextMenuButtonItems,
                  ContextMenuButtonItem(
                    label: 'Custom Action',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        TomSnackBar(content: Text('Custom action!')),
                      );
                    },
                  ),
                ],
              );
            },
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// Badge Section
// =============================================================================

class _BadgeSection extends StatelessWidget {
  const _BadgeSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Badge',
          'Simple notification badges.',
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              TomBadge(
                label: const Text('3'),
                child: IconButton(
                  icon: const TomIcon(Icons.mail),
                  onPressed: () {},
                ),
              ),
              TomBadge(
                label: const Text('99+'),
                child: IconButton(
                  icon: const TomIcon(Icons.notifications),
                  onPressed: () {},
                ),
              ),
              const TomBadge(
                label: Text('New'),
                child: TomIcon(Icons.star, size: 32),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Badge Without Label',
          'Small dot badge indicator.',
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              TomBadge(
                smallSize: 8,
                child: IconButton(
                  icon: const TomIcon(Icons.chat),
                  onPressed: () {},
                ),
              ),
              const TomBadge(
                smallSize: 10,
                child: CircleAvatar(
                  child: Text('JD'),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Colored Badges',
          'Badges with different colors.',
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              TomBadge(
                label: const Text('5'),
                backgroundColor: Colors.red,
                child: const TomIcon(Icons.inbox, size: 32),
              ),
              TomBadge(
                label: const Text('12'),
                backgroundColor: Colors.green,
                child: const TomIcon(Icons.check_circle, size: 32),
              ),
              TomBadge(
                label: const Text('!'),
                backgroundColor: Colors.orange,
                child: const TomIcon(Icons.warning, size: 32),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Badge Alignment',
          'Different badge positions.',
          TomWrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              TomBadge(
                alignment: Alignment.topRight,
                label: const Text('TR'),
                child: TomContainer(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                ),
              ),
              TomBadge(
                alignment: Alignment.topLeft,
                label: const Text('TL'),
                child: TomContainer(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                ),
              ),
              TomBadge(
                alignment: Alignment.bottomRight,
                label: const Text('BR'),
                child: TomContainer(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                ),
              ),
              TomBadge(
                alignment: Alignment.bottomLeft,
                label: const Text('BL'),
                child: TomContainer(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// Text Effects Section
// =============================================================================

class _TextEffectsSection extends StatelessWidget {
  const _TextEffectsSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Text Decoration',
          'Underline, overline, and strikethrough.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Underline text',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 16,
                ),
              ),
              const TomSizedBox(height: 8),
              const Text(
                'Overline text',
                style: TextStyle(
                  decoration: TextDecoration.overline,
                  fontSize: 16,
                ),
              ),
              const TomSizedBox(height: 8),
              const Text(
                'Line-through text',
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  fontSize: 16,
                ),
              ),
              const TomSizedBox(height: 8),
              Text(
                'Combined decorations',
                style: TextStyle(
                  decoration: TextDecoration.combine([
                    TextDecoration.underline,
                    TextDecoration.overline,
                  ]),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Decoration Styles',
          'Different line styles.',
          const TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solid underline',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.solid,
                  fontSize: 16,
                ),
              ),
              TomSizedBox(height: 8),
              Text(
                'Double underline',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.double,
                  fontSize: 16,
                ),
              ),
              TomSizedBox(height: 8),
              Text(
                'Dotted underline',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                  fontSize: 16,
                ),
              ),
              TomSizedBox(height: 8),
              Text(
                'Dashed underline',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dashed,
                  fontSize: 16,
                ),
              ),
              TomSizedBox(height: 8),
              Text(
                'Wavy underline',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.wavy,
                  decorationColor: Colors.red,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Text Shadow',
          'Adding shadows to text.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text with shadow',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const TomSizedBox(height: 12),
              Text(
                'Multiple shadows',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      offset: const Offset(-2, -2),
                      blurRadius: 2,
                    ),
                    Shadow(
                      color: Colors.blue.withValues(alpha: 0.5),
                      offset: const Offset(2, 2),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const TomSizedBox(height: 12),
              Text(
                'Glow effect',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.blue,
                      blurRadius: 10,
                    ),
                    Shadow(
                      color: Colors.blue,
                      blurRadius: 20,
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// Practical Examples Section
// =============================================================================

class _PracticalExamplesSection extends StatelessWidget {
  const _PracticalExamplesSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Price Display',
          'Formatted price with sale indicator.',
          TomRow(
            children: [
              const Text(
                '\$29.99',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                ),
              ),
              const TomSizedBox(width: 8),
              const Text(
                '\$19.99',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const TomSizedBox(width: 8),
              TomContainer(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '-33%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Username with Badge',
          'User display with status indicator.',
          const TomRow(
            children: [
              CircleAvatar(child: Text('JD')),
              TomSizedBox(width: 12),
              TomColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TomRow(
                    children: [
                      Text(
                        'John Doe',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TomSizedBox(width: 8),
                      TomIcon(Icons.verified, size: 16, color: Colors.blue),
                    ],
                  ),
                  Text(
                    '@johndoe',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Formatted Text',
          'Code, hashtags, and mentions.',
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Use '),
                TextSpan(
                  text: 'const',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.purple,
                  ),
                ),
                const TextSpan(text: ' keyword in '),
                const TextSpan(
                  text: '#Flutter',
                  style: TextStyle(color: Colors.blue),
                ),
                const TextSpan(text: ' - cc '),
                const TextSpan(
                  text: '@flutter_dev',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Time Ago',
          'Relative time display patterns.',
          const TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomRow(
                children: [
                  TomIcon(Icons.schedule, size: 14, color: Colors.grey),
                  TomSizedBox(width: 4),
                  Text('2 minutes ago', style: TextStyle(color: Colors.grey)),
                ],
              ),
              TomSizedBox(height: 8),
              TomRow(
                children: [
                  TomIcon(Icons.schedule, size: 14, color: Colors.grey),
                  TomSizedBox(width: 4),
                  Text('Yesterday at 3:45 PM', style: TextStyle(color: Colors.grey)),
                ],
              ),
              TomSizedBox(height: 8),
              TomRow(
                children: [
                  TomIcon(Icons.schedule, size: 14, color: Colors.grey),
                  TomSizedBox(width: 4),
                  Text('Dec 25, 2024', style: TextStyle(color: Colors.grey)),
                ],
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
