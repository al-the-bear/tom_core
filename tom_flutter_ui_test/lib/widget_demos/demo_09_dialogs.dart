/// Comprehensive Dialogs and Overlays Demo
///
/// This demo showcases dialogs, bottom sheets, snackbars, tooltips,
/// and other overlay widgets with their configurations.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main dialogs and overlays demo screen.
class DialogsDemo extends StatelessWidget {
  const DialogsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'AlertDialog',
          subtitle: 'Modal dialogs for alerts and confirmations',
        ),
        _AlertDialogSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'SimpleDialog',
          subtitle: 'Dialogs for simple choices',
        ),
        _SimpleDialogSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'BottomSheet',
          subtitle: 'Sheets sliding up from bottom',
        ),
        _BottomSheetSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'SnackBar',
          subtitle: 'Brief messages at screen bottom',
        ),
        _SnackBarSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Tooltip',
          subtitle: 'Informational tooltips on hover/press',
        ),
        _TooltipSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Banner',
          subtitle: 'Persistent banners at top',
        ),
        _BannerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Dialog Patterns',
          subtitle: 'Common dialog implementations',
        ),
        _DialogPatternsSection(),
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
// AlertDialog Section
// =============================================================================

class _AlertDialogSection extends StatelessWidget {
  const _AlertDialogSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomFilledButton(
                  onPressed: () => _showBasicDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.1'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showConfirmDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.37'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showIconDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.38'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showStyledDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.2'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBasicDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomAlertDialog(
          title: const TomText(null, tomId: 'demo.09.auto.text.3'),
          content: const TomText(null, tomId: 'demo.09.auto.text.32',
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText(null, tomId: 'demo.09.auto.text.4'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomAlertDialog(
          title: const TomText(null, tomId: 'demo.09.auto.text.39'),
          content: const TomText(null, tomId: 'demo.09.auto.text.33',
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText(null, tomId: 'demo.09.auto.text.40'),
            ),
            TomFilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  TomSnackBar(content: TomText(null, tomId: 'demo.09.auto.text.41')),
                );
              },
              child: const TomText(null, tomId: 'demo.09.auto.text.42'),
            ),
          ],
        );
      },
    );
  }

  void _showIconDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomAlertDialog(
          icon: const TomIcon(Icons.warning, color: Colors.orange, size: 48),
          title: const TomText(null, tomId: 'demo.09.auto.text.43'),
          content: const TomText(null, tomId: 'demo.09.auto.text.34',
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText(null, tomId: 'demo.09.auto.text.44'),
            ),
            TomFilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText(null, tomId: 'demo.09.auto.text.45'),
            ),
          ],
        );
      },
    );
  }

  void _showStyledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const TomText(null, tomId: 'demo.09.auto.text.5'),
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          content: const TomText(
            'This dialog has custom styling including background color, '
            'border radius, and text styles.',
          ),
          contentTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText(null, tomId: 'demo.09.auto.text.6'),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SimpleDialog Section
// =============================================================================

class _SimpleDialogSection extends StatelessWidget {
  const _SimpleDialogSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomFilledButton(
                  onPressed: () => _showSimpleDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.7'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showListDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.8'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showGridDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.9'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSimpleDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return TomSimpleDialog(
          title: const TomText(null, tomId: 'demo.09.auto.text.46'),
          children: [
            TomSimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 1'),
              child: const TomText(null, tomId: 'demo.09.auto.text.47'),
            ),
            TomSimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 2'),
              child: const TomText(null, tomId: 'demo.09.auto.text.48'),
            ),
            TomSimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 3'),
              child: const TomText(null, tomId: 'demo.09.auto.text.49'),
            ),
          ],
        );
      },
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(TomSnackBar(content: TomText(null, tomId: 'demo.09.auto.text.10')));
    }
  }

  void _showListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomSimpleDialog(
          title: const TomText(null, tomId: 'demo.09.auto.text.50'),
          children: [
            TomListTile(
              leading: const TomCircleAvatar(child: TomText(null, tomId: 'demo.09.auto.text.11')),
              title: const TomText(null, tomId: 'demo.09.auto.text.51'),
              subtitle: const TomText(null, tomId: 'demo.09.auto.text.52'),
              onTap: () => Navigator.of(context).pop(),
            ),
            TomListTile(
              leading: const TomCircleAvatar(child: TomText(null, tomId: 'demo.09.auto.text.12')),
              title: const TomText(null, tomId: 'demo.09.auto.text.13'),
              subtitle: const TomText(null, tomId: 'demo.09.auto.text.14'),
              onTap: () => Navigator.of(context).pop(),
            ),
            TomListTile(
              leading: TomCircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: const TomIcon(Icons.add),
              ),
              title: const TomText(null, tomId: 'demo.09.auto.text.53'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showGridDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomAlertDialog(
          title: const TomText(null, tomId: 'demo.09.auto.text.15'),
          content: TomSizedBox(
            width: 280,
            child: TomWrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  Colors.primaries.map((color) {
                    return TomInkWell(
                      onTap: () => Navigator.of(context).pop(color),
                      child: TomContainer(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// BottomSheet Section
// =============================================================================

class _BottomSheetSection extends StatelessWidget {
  const _BottomSheetSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomFilledButton(
                  onPressed: () => _showModalBottomSheet(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.16'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showScrollableSheet(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.17'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showDraggableSheet(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.18'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return TomContainer(
          padding: const EdgeInsets.all(24),
          child: TomColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              TomContainer(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const TomSizedBox(height: 24),
              const TomText(null, tomId: 'demo.09.auto.text.1',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const TomSizedBox(height: 24),
              TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    [
                      ('Email', Icons.email, Colors.red),
                      ('Message', Icons.message, Colors.green),
                      ('Copy Link', Icons.link, Colors.blue),
                      ('More', Icons.more_horiz, Colors.grey),
                    ].map((item) {
                      return TomColumn(
                        children: [
                          TomCircleAvatar(
                            backgroundColor: item.$3.withValues(alpha: 0.1),
                            child: TomIcon(item.$2, color: item.$3),
                          ),
                          const TomSizedBox(height: 8),
                          TomText(item.$1, style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
              ),
              const TomSizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showScrollableSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return TomDraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return TomContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TomListView(
                controller: scrollController,
                children: [
                  TomCenter(
                    child: TomContainer(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const TomText(null, tomId: 'demo.09.auto.text.35',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const TomSizedBox(height: 16),
                  ...List.generate(15, (index) {
                    return TomListTile(
                      leading: TomCircleAvatar(child: TomText('${index + 1}')),
                      title: TomText('Notification ${index + 1}'),
                      subtitle: TomText('${index + 1} hours ago'),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDraggableSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TomDraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return TomContainer(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: TomColumn(
                children: [
                  TomContainer(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  TomExpanded(
                    child: TomListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children:
                          [
                            ('Settings', Icons.settings),
                            ('Profile', Icons.person),
                            ('Security', Icons.security),
                            ('Notifications', Icons.notifications),
                            ('Privacy', Icons.lock),
                            ('Help', Icons.help),
                            ('About', Icons.info),
                            ('Logout', Icons.logout),
                          ].map((item) {
                            return TomListTile(
                              leading: TomIcon(item.$2),
                              title: TomText(item.$1),
                              trailing: const TomIcon(Icons.chevron_right),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// SnackBar Section
// =============================================================================

class _SnackBarSection extends StatelessWidget {
  const _SnackBarSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomFilledButton(
                  onPressed: () => _showBasicSnackBar(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.19'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showActionSnackBar(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.54'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showFloatingSnackBar(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.55'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showStyledSnackBar(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.20'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBasicSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(content: TomText(null, tomId: 'demo.09.auto.text.56')),
    );
  }

  void _showActionSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText(null, tomId: 'demo.09.auto.text.21'),
        action: TomSnackBarAction(
          label: 'Undo',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              TomSnackBar(content: TomText(null, tomId: 'demo.09.auto.text.57')),
            );
          },
        ),
      ),
    );
  }

  void _showFloatingSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText(null, tomId: 'demo.09.auto.text.58'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showStyledSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: TomRow(
          children: [
            const TomIcon(Icons.check_circle, color: Colors.white),
            const TomSizedBox(width: 12),
            const TomText(null, tomId: 'demo.09.auto.text.59'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// =============================================================================
// Tooltip Section
// =============================================================================

class _TooltipSection extends StatelessWidget {
  const _TooltipSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(null, tomId: 'demo.09.auto.text.36',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const TomSizedBox(height: 16),
            TomWrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TomTooltip(
                  message: 'This is a basic tooltip',
                  child: TomFilledButton(
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.09.auto.text.22'),
                  ),
                ),
                TomTooltip(
                  message: 'Add new item to the list',
                  waitDuration: const Duration(milliseconds: 500),
                  showDuration: const Duration(seconds: 2),
                  child: IconButton.filled(
                    onPressed: () {},
                    icon: const TomIcon(Icons.add),
                  ),
                ),
                TomTooltip(
                  message: 'Custom styled tooltip',
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  child: TomOutlinedButton(
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.09.auto.text.23'),
                  ),
                ),
                TomTooltip(
                  richMessage: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Rich text ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: 'with '),
                      TextSpan(
                        text: 'multiple ',
                        style: TextStyle(color: Colors.amber.shade200),
                      ),
                      const TextSpan(text: 'styles'),
                    ],
                  ),
                  child: TomOutlinedButton(
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.09.auto.text.24'),
                  ),
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
// Banner Section
// =============================================================================

class _BannerSection extends StatefulWidget {
  const _BannerSection();

  @override
  State<_BannerSection> createState() => _BannerSectionState();
}

class _BannerSectionState extends State<_BannerSection> {
  bool _showBanner = false;

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomFilledButton(
              onPressed: () {
                setState(() => _showBanner = !_showBanner);
              },
              child: TomText(_showBanner ? 'Hide Banner' : 'Show Banner'),
            ),
            const TomSizedBox(height: 16),
            if (_showBanner)
              MaterialBanner(
                content: const TomText(
                  'Your subscription will expire in 3 days. Renew now to '
                  'continue enjoying all features.',
                ),
                leading: const TomIcon(Icons.warning, color: Colors.orange),
                actions: [
                  TomTextButton(
                    onPressed: () => setState(() => _showBanner = false),
                    child: const TomText(null, tomId: 'demo.09.auto.text.25'),
                  ),
                  TomFilledButton(
                    onPressed: () => setState(() => _showBanner = false),
                    child: const TomText(null, tomId: 'demo.09.auto.text.60'),
                  ),
                ],
              ),
            const TomSizedBox(height: 16),
            const TomText(
              'Note: MaterialBanner is typically shown using '
              'ScaffoldMessenger.showMaterialBanner()',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Dialog Patterns Section
// =============================================================================

class _DialogPatternsSection extends StatelessWidget {
  const _DialogPatternsSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomFilledButton(
                  onPressed: () => _showFormDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.26'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showLoadingDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.61'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showFullscreenDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.62'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showDatePickerDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.27'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showTimePickerDialog(context),
                  child: const TomText(null, tomId: 'demo.09.auto.text.28'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFormDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return TomAlertDialog(
          title: const TomText(null, tomId: 'demo.09.auto.text.63'),
          content: TomColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              TomTextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText(null, tomId: 'demo.09.auto.text.64'),
            ),
            TomFilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  TomSnackBar(
                    content: TomText('Submitted: ${nameController.text}'),
                  ),
                );
              },
              child: const TomText(null, tomId: 'demo.09.auto.text.29'),
            ),
          ],
        );
      },
    );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) Navigator.of(context).pop();
        });
        return TomAlertDialog(
          content: TomRow(
            children: [
              const TomCircularProgressIndicator(),
              const TomSizedBox(width: 24),
              const TomText(null, tomId: 'demo.09.auto.text.65'),
            ],
          ),
        );
      },
    );
  }

  void _showFullscreenDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return TomScaffold(
            appBar: TomAppBar(
              title: const TomText(null, tomId: 'demo.09.auto.text.30'),
              actions: [
                TomTextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const TomText(null, tomId: 'demo.09.auto.text.31'),
                ),
              ],
            ),
            body: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomColumn(
                children: [
                  const TomTextField(
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const TomSizedBox(height: 16),
                  const TomTextField(
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDatePickerDialog(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        TomSnackBar(
          content: TomText('Selected: ${date.toString().split(' ')[0]}'),
        ),
      );
    }
  }

  void _showTimePickerDialog(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        TomSnackBar(content: TomText('Selected: ${time.format(context)}')),
      );
    }
  }
}
