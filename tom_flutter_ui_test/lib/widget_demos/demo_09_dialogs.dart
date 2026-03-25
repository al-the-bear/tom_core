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
                  child: const TomText('Basic Dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showConfirmDialog(context),
                  child: const TomText('Confirm Dialog'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showIconDialog(context),
                  child: const TomText('With Icon'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showStyledDialog(context),
                  child: const TomText('Styled Dialog'),
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
          title: const TomText('Basic Alert'),
          content: const TomText(
            'This is a basic alert dialog with a title and content.',
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText('OK'),
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
          title: const TomText('Confirm Action'),
          content: const TomText(
            'Are you sure you want to proceed with this action?',
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText('Cancel'),
            ),
            TomFilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  TomSnackBar(content: TomText('Action confirmed!')),
                );
              },
              child: const TomText('Confirm'),
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
          title: const TomText('Warning'),
          content: const TomText(
            'This action cannot be undone. Please proceed with caution.',
          ),
          actions: [
            TomTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText('Cancel'),
            ),
            TomFilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TomText('I Understand'),
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
          title: const TomText('Styled Dialog'),
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
              child: const TomText('Close'),
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
                  child: const TomText('Simple Dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showListDialog(context),
                  child: const TomText('List Dialog'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showGridDialog(context),
                  child: const TomText('Grid Dialog'),
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
          title: const TomText('Select Option'),
          children: [
            TomSimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 1'),
              child: const TomText('Option 1'),
            ),
            TomSimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 2'),
              child: const TomText('Option 2'),
            ),
            TomSimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 3'),
              child: const TomText('Option 3'),
            ),
          ],
        );
      },
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(TomSnackBar(content: TomText('Selected: $result')));
    }
  }

  void _showListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return TomSimpleDialog(
          title: const TomText('Select Account'),
          children: [
            TomListTile(
              leading: const TomCircleAvatar(child: TomText('J')),
              title: const TomText('John Doe'),
              subtitle: const TomText('john@example.com'),
              onTap: () => Navigator.of(context).pop(),
            ),
            TomListTile(
              leading: const TomCircleAvatar(child: TomText('S')),
              title: const TomText('Sarah Smith'),
              subtitle: const TomText('sarah@example.com'),
              onTap: () => Navigator.of(context).pop(),
            ),
            TomListTile(
              leading: TomCircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: const TomIcon(Icons.add),
              ),
              title: const TomText('Add Account'),
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
          title: const TomText('Choose Color'),
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
                  child: const TomText('Modal Sheet'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showScrollableSheet(context),
                  child: const TomText('Scrollable Sheet'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showDraggableSheet(context),
                  child: const TomText('Draggable Sheet'),
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
              const TomText(
                'Share with',
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
                  const TomText(
                    'Notifications',
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
                  child: const TomText('Basic'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showActionSnackBar(context),
                  child: const TomText('With Action'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showFloatingSnackBar(context),
                  child: const TomText('Floating'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showStyledSnackBar(context),
                  child: const TomText('Styled'),
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
      TomSnackBar(content: TomText('This is a basic snackbar')),
    );
  }

  void _showActionSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText('Item deleted'),
        action: TomSnackBarAction(
          label: 'Undo',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              TomSnackBar(content: TomText('Undo successful')),
            );
          },
        ),
      ),
    );
  }

  void _showFloatingSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText('This is a floating snackbar'),
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
            const TomText('Operation successful!'),
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
            const TomText(
              'Hover or long-press the buttons:',
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
                    child: const TomText('Basic'),
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
                    child: const TomText('Styled'),
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
                    child: const TomText('Rich Text'),
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
                    child: const TomText('Dismiss'),
                  ),
                  TomFilledButton(
                    onPressed: () => setState(() => _showBanner = false),
                    child: const TomText('Renew'),
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
                  child: const TomText('Form Dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showLoadingDialog(context),
                  child: const TomText('Loading Dialog'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showFullscreenDialog(context),
                  child: const TomText('Fullscreen'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showDatePickerDialog(context),
                  child: const TomText('Date Picker'),
                ),
                TomOutlinedButton(
                  onPressed: () => _showTimePickerDialog(context),
                  child: const TomText('Time Picker'),
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
          title: const TomText('Contact Form'),
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
              child: const TomText('Cancel'),
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
              child: const TomText('Submit'),
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
              const TomText('Loading, please wait...'),
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
              title: const TomText('New Item'),
              actions: [
                TomTextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const TomText('Save'),
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
