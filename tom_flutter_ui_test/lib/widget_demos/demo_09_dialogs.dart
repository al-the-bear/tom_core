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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'AlertDialog',
          subtitle: 'Modal dialogs for alerts and confirmations',
        ),
        _AlertDialogSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'SimpleDialog',
          subtitle: 'Dialogs for simple choices',
        ),
        _SimpleDialogSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'BottomSheet',
          subtitle: 'Sheets sliding up from bottom',
        ),
        _BottomSheetSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'SnackBar',
          subtitle: 'Brief messages at screen bottom',
        ),
        _SnackBarSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Tooltip',
          subtitle: 'Informational tooltips on hover/press',
        ),
        _TooltipSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Banner',
          subtitle: 'Persistent banners at top',
        ),
        _BannerSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Dialog Patterns',
          subtitle: 'Common dialog implementations',
        ),
        _DialogPatternsSection(),
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
// AlertDialog Section
// =============================================================================

class _AlertDialogSection extends StatelessWidget {
  const _AlertDialogSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _showBasicDialog(context),
                  child: const Text('Basic Dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showConfirmDialog(context),
                  child: const Text('Confirm Dialog'),
                ),
                OutlinedButton(
                  onPressed: () => _showIconDialog(context),
                  child: const Text('With Icon'),
                ),
                OutlinedButton(
                  onPressed: () => _showStyledDialog(context),
                  child: const Text('Styled Dialog'),
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
        return AlertDialog(
          title: const Text('Basic Alert'),
          content: const Text(
            'This is a basic alert dialog with a title and content.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
        return AlertDialog(
          title: const Text('Confirm Action'),
          content: const Text(
            'Are you sure you want to proceed with this action?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Action confirmed!')),
                );
              },
              child: const Text('Confirm'),
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
        return AlertDialog(
          icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
          title: const Text('Warning'),
          content: const Text(
            'This action cannot be undone. Please proceed with caution.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('I Understand'),
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
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Styled Dialog'),
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          content: const Text(
            'This dialog has custom styling including background color, '
            'border radius, and text styles.',
          ),
          contentTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _showSimpleDialog(context),
                  child: const Text('Simple Dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showListDialog(context),
                  child: const Text('List Dialog'),
                ),
                OutlinedButton(
                  onPressed: () => _showGridDialog(context),
                  child: const Text('Grid Dialog'),
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
        return SimpleDialog(
          title: const Text('Select Option'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 1'),
              child: const Text('Option 1'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 2'),
              child: const Text('Option 2'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Option 3'),
              child: const Text('Option 3'),
            ),
          ],
        );
      },
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected: $result')));
    }
  }

  void _showListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Account'),
          children: [
            ListTile(
              leading: const CircleAvatar(child: Text('J')),
              title: const Text('John Doe'),
              subtitle: const Text('john@example.com'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const CircleAvatar(child: Text('S')),
              title: const Text('Sarah Smith'),
              subtitle: const Text('sarah@example.com'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.add),
              ),
              title: const Text('Add Account'),
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
        return AlertDialog(
          title: const Text('Choose Color'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  Colors.primaries.map((color) {
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(color),
                      child: Container(
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _showModalBottomSheet(context),
                  child: const Text('Modal Sheet'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showScrollableSheet(context),
                  child: const Text('Scrollable Sheet'),
                ),
                OutlinedButton(
                  onPressed: () => _showDraggableSheet(context),
                  child: const Text('Draggable Sheet'),
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
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Share with',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    [
                      ('Email', Icons.email, Colors.red),
                      ('Message', Icons.message, Colors.green),
                      ('Copy Link', Icons.link, Colors.blue),
                      ('More', Icons.more_horiz, Colors.grey),
                    ].map((item) {
                      return Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: item.$3.withValues(alpha: 0.1),
                            child: Icon(item.$2, color: item.$3),
                          ),
                          const SizedBox(height: 8),
                          Text(item.$1, style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
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
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(15, (index) {
                    return ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text('Notification ${index + 1}'),
                      subtitle: Text('${index + 1} hours ago'),
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
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
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
                            return ListTile(
                              leading: Icon(item.$2),
                              title: Text(item.$1),
                              trailing: const Icon(Icons.chevron_right),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _showBasicSnackBar(context),
                  child: const Text('Basic'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showActionSnackBar(context),
                  child: const Text('With Action'),
                ),
                OutlinedButton(
                  onPressed: () => _showFloatingSnackBar(context),
                  child: const Text('Floating'),
                ),
                OutlinedButton(
                  onPressed: () => _showStyledSnackBar(context),
                  child: const Text('Styled'),
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
      const SnackBar(content: Text('This is a basic snackbar')),
    );
  }

  void _showActionSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Undo successful')),
            );
          },
        ),
      ),
    );
  }

  void _showFloatingSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This is a floating snackbar'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showStyledSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Operation successful!'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hover or long-press the buttons:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                Tooltip(
                  message: 'This is a basic tooltip',
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Basic'),
                  ),
                ),
                Tooltip(
                  message: 'Add new item to the list',
                  waitDuration: const Duration(milliseconds: 500),
                  showDuration: const Duration(seconds: 2),
                  child: IconButton.filled(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                  ),
                ),
                Tooltip(
                  message: 'Custom styled tooltip',
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Styled'),
                  ),
                ),
                Tooltip(
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
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Rich Text'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              onPressed: () {
                setState(() => _showBanner = !_showBanner);
              },
              child: Text(_showBanner ? 'Hide Banner' : 'Show Banner'),
            ),
            const SizedBox(height: 16),
            if (_showBanner)
              MaterialBanner(
                content: const Text(
                  'Your subscription will expire in 3 days. Renew now to '
                  'continue enjoying all features.',
                ),
                leading: const Icon(Icons.warning, color: Colors.orange),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _showBanner = false),
                    child: const Text('Dismiss'),
                  ),
                  FilledButton(
                    onPressed: () => setState(() => _showBanner = false),
                    child: const Text('Renew'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _showFormDialog(context),
                  child: const Text('Form Dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => _showLoadingDialog(context),
                  child: const Text('Loading Dialog'),
                ),
                OutlinedButton(
                  onPressed: () => _showFullscreenDialog(context),
                  child: const Text('Fullscreen'),
                ),
                OutlinedButton(
                  onPressed: () => _showDatePickerDialog(context),
                  child: const Text('Date Picker'),
                ),
                OutlinedButton(
                  onPressed: () => _showTimePickerDialog(context),
                  child: const Text('Time Picker'),
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
        return AlertDialog(
          title: const Text('Contact Form'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Submitted: ${nameController.text}'),
                  ),
                );
              },
              child: const Text('Submit'),
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
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              const Text('Loading, please wait...'),
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
          return Scaffold(
            appBar: AppBar(
              title: const Text('New Item'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Save'),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
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
        SnackBar(
          content: Text('Selected: ${date.toString().split(' ')[0]}'),
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
        SnackBar(content: Text('Selected: ${time.format(context)}')),
      );
    }
  }
}
