/// Demo 09: Dialog & Modal Gallery
///
/// Comprehensive demonstration of Tom dialog and overlay widgets for
/// alerts, simple dialogs, bottom sheets, snack bars, tooltips, banners,
/// date/time pickers, and Cupertino-style dialogs.
/// Widgets covered: TomAlertDialog, TomSimpleDialog, TomBottomSheet,
/// TomModalBottomSheet, TomSnackBar, TomMaterialBanner, TomTooltip,
/// TomDatePickerDialog, TomCupertinoAlertDialog, TomCupertinoActionSheet.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Dialog & Modal Gallery demo.
class DialogModalGalleryDemo extends StatelessWidget {
  const DialogModalGalleryDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DialogDemoContent();
  }
}

class _DialogDemoContent extends StatefulWidget {
  const _DialogDemoContent();

  @override
  State<_DialogDemoContent> createState() => _DialogDemoContentState();
}

class _DialogDemoContentState extends State<_DialogDemoContent> {
  // ===========================================================================
  // Section 1: Standard Dialogs state
  // ===========================================================================
  String _alertResult = 'No action yet';
  String _simpleDialogResult = 'No selection yet';

  // ===========================================================================
  // Section 2: Bottom Sheets state
  // ===========================================================================
  String _bottomSheetResult = 'No selection yet';
  String _modalSheetResult = 'No selection yet';

  // ===========================================================================
  // Section 3: Feedback Overlays state
  // ===========================================================================
  int _snackBarCount = 0;
  bool _bannerVisible = false;

  // ===========================================================================
  // Section 4: Pickers state
  // ===========================================================================
  DateTime _selectedDate = DateTime(2025, 6, 15);
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 30);

  // ===========================================================================
  // Section 5: ACL state
  // ===========================================================================
  String _aclDialogType = 'alert';
  bool _aclBarrierDismissible = true;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Standard Dialogs
            _SectionHeader(tomId: 'demo09.section.standard'),
            const TomSizedBox(height: 16),
            _buildAlertDialogSection(),
            const TomSizedBox(height: 24),
            _buildSimpleDialogSection(),
            const TomSizedBox(height: 32),

            // Section 2: Bottom Sheets
            _SectionHeader(tomId: 'demo09.section.sheets'),
            const TomSizedBox(height: 16),
            _buildBottomSheetSection(),
            const TomSizedBox(height: 24),
            _buildModalBottomSheetSection(),
            const TomSizedBox(height: 32),

            // Section 3: Feedback Overlays
            _SectionHeader(tomId: 'demo09.section.feedback'),
            const TomSizedBox(height: 16),
            _buildSnackBarSection(),
            const TomSizedBox(height: 24),
            _buildMaterialBannerSection(),
            const TomSizedBox(height: 24),
            _buildTooltipSection(),
            const TomSizedBox(height: 32),

            // Section 4: Pickers & Cupertino
            _SectionHeader(tomId: 'demo09.section.pickers'),
            const TomSizedBox(height: 16),
            _buildDatePickerSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoAlertSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoActionSheetSection(),
            const TomSizedBox(height: 32),

            // Section 5: ACL Dialog Demo
            _SectionHeader(tomId: 'demo09.section.acl'),
            const TomSizedBox(height: 16),
            _buildAclDialogSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Standard Dialogs
  // ===========================================================================

  Widget _buildAlertDialogSection() {
    return _DemoCard(
      tomId: 'demo09.alertDialog',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.alertDialog.resultLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 4),
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomText(
              text: _alertResult,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomFilledButton(
                tomId: 'demo09.alertDialog.basic',
                onPressed: () => _showBasicAlert(context),
              ),
              const TomSizedBox(width: 8),
              TomFilledButton(
                tonal: true,
                tomId: 'demo09.alertDialog.withIcon',
                onPressed: () => _showIconAlert(context),
              ),
              const TomSizedBox(width: 8),
              TomOutlinedButton(
                tomId: 'demo09.alertDialog.scrollable',
                onPressed: () => _showScrollableAlert(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBasicAlert(BuildContext context) {
    TomDialogs.showDialog(
      context: context,
      builder: (ctx) => TomAlertDialog(
        tomId: 'demo09.alertDialog.dlg',
        titleText: 'Confirm Action',
        content: const TomPadding(
          padding: EdgeInsets.only(top: 8),
          child: TomText(text: 'Are you sure you want to proceed?'),
        ),
        actions: [
          TomTextButton(
            tomId: 'demo09.alertDialog.cancel',
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _alertResult = 'Cancelled');
            },
          ),
          TomFilledButton(
            tomId: 'demo09.alertDialog.confirm',
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _alertResult = 'Confirmed');
            },
          ),
        ],
      ),
    );
  }

  void _showIconAlert(BuildContext context) {
    TomDialogs.showDialog(
      context: context,
      builder: (ctx) => TomAlertDialog(
        tomId: 'demo09.alertDialog.iconDlg',
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 48,
        ),
        titleText: 'Warning',
        content: const TomPadding(
          padding: EdgeInsets.only(top: 8),
          child: TomText(text: 'This action cannot be undone.'),
        ),
        actions: [
          TomTextButton(
            tomId: 'demo09.alertDialog.dismiss',
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _alertResult = 'Dismissed warning');
            },
          ),
          TomFilledButton(
            tomId: 'demo09.alertDialog.proceed',
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _alertResult = 'Proceeded despite warning');
            },
          ),
        ],
      ),
    );
  }

  void _showScrollableAlert(BuildContext context) {
    TomDialogs.showDialog(
      context: context,
      builder: (ctx) => TomAlertDialog(
        tomId: 'demo09.alertDialog.scrollDlg',
        titleText: 'Terms of Service',
        scrollable: true,
        content: TomPadding(
          padding: const EdgeInsets.only(top: 8),
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              10,
              (i) => TomPadding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TomText(
                  text: 'Section ${i + 1}: Lorem ipsum dolor sit amet, '
                      'consectetur adipiscing elit. Sed do eiusmod tempor '
                      'incididunt ut labore et dolore magna aliqua.',
                ),
              ),
            ),
          ),
        ),
        actions: [
          TomTextButton(
            tomId: 'demo09.alertDialog.decline',
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _alertResult = 'Declined terms');
            },
          ),
          TomFilledButton(
            tomId: 'demo09.alertDialog.accept',
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _alertResult = 'Accepted terms');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDialogSection() {
    return _DemoCard(
      tomId: 'demo09.simpleDialog',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.simpleDialog.resultLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 4),
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomText(
              text: _simpleDialogResult,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const TomSizedBox(height: 16),
          TomFilledButton(
            tomId: 'demo09.simpleDialog.show',
            onPressed: () => _showSimpleDialog(context),
          ),
        ],
      ),
    );
  }

  void _showSimpleDialog(BuildContext context) {
    TomDialogs.showDialog<String>(
      context: context,
      builder: (ctx) => TomSimpleDialog(
        tomId: 'demo09.simpleDialog.dlg',
        titleText: 'Select a language',
        children: [
          for (final lang in ['Dart', 'TypeScript', 'Rust', 'Go', 'Python'])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(lang),
              child: TomRow(
                children: [
                  const Icon(Icons.code, size: 20),
                  const TomSizedBox(width: 12),
                  TomText(text: lang),
                ],
              ),
            ),
        ],
      ),
    ).then((value) {
      if (value != null) {
        setState(() => _simpleDialogResult = 'Selected: $value');
      }
    });
  }

  // ===========================================================================
  // Section 2: Bottom Sheets
  // ===========================================================================

  Widget _buildBottomSheetSection() {
    return _DemoCard(
      tomId: 'demo09.bottomSheet',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.bottomSheet.resultLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 4),
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomText(
              text: _bottomSheetResult,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const TomSizedBox(height: 16),
          TomFilledButton(
            tomId: 'demo09.bottomSheet.show',
            onPressed: () => _showPersistentBottomSheet(context),
          ),
        ],
      ),
    );
  }

  void _showPersistentBottomSheet(BuildContext context) {
    Scaffold.of(context).showBottomSheet(
      (ctx) => TomContainer(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: TomColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            TomContainer(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const TomSizedBox(height: 16),
            TomText(
              text: 'Persistent Bottom Sheet',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const TomSizedBox(height: 8),
            const TomText(
              text: 'This sheet stays visible until explicitly closed.',
            ),
            const TomSizedBox(height: 16),
            TomRow(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final option in ['Option A', 'Option B', 'Option C'])
                  TomFilledButton(
                    tonal: true,
                    label: option,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(
                        () => _bottomSheetResult = 'Selected: $option',
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalBottomSheetSection() {
    return _DemoCard(
      tomId: 'demo09.modalSheet',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.modalSheet.resultLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 4),
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomText(
              text: _modalSheetResult,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomFilledButton(
                tomId: 'demo09.modalSheet.basic',
                onPressed: () => _showBasicModalSheet(context),
              ),
              const TomSizedBox(width: 8),
              TomFilledButton(
                tonal: true,
                tomId: 'demo09.modalSheet.scrollable',
                onPressed: () => _showScrollableModalSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBasicModalSheet(BuildContext context) {
    TomDialogs.showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => TomPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: TomColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            TomText(
              text: 'Choose an Action',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const TomSizedBox(height: 16),
            for (final item in [
              ('Share', Icons.share),
              ('Download', Icons.download),
              ('Delete', Icons.delete_outline),
            ]) ...[
              ListTile(
                leading: Icon(item.$2),
                title: TomText(text: item.$1),
                onTap: () => Navigator.of(ctx).pop(item.$1),
              ),
            ],
          ],
        ),
      ),
    ).then((value) {
      if (value != null) {
        setState(() => _modalSheetResult = 'Action: $value');
      }
    });
  }

  void _showScrollableModalSheet(BuildContext context) {
    TomDialogs.showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: 30,
          itemBuilder: (_, i) => ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: TomText(text: 'Scrollable item ${i + 1}'),
            subtitle: const TomText(text: 'Drag to expand or collapse'),
            onTap: () {
              Navigator.of(ctx).pop();
              setState(
                () => _modalSheetResult = 'Picked item ${i + 1}',
              );
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 3: Feedback Overlays
  // ===========================================================================

  Widget _buildSnackBarSection() {
    return _DemoCard(
      tomId: 'demo09.snackBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.snackBar.countLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 4),
          TomText(
            text: 'Shown: $_snackBarCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomFilledButton(
                tomId: 'demo09.snackBar.basic',
                onPressed: () => _showBasicSnackBar(context),
              ),
              const TomSizedBox(width: 8),
              TomFilledButton(
                tonal: true,
                tomId: 'demo09.snackBar.action',
                onPressed: () => _showActionSnackBar(context),
              ),
              const TomSizedBox(width: 8),
              TomOutlinedButton(
                tomId: 'demo09.snackBar.floating',
                onPressed: () => _showFloatingSnackBar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBasicSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText(text: 'This is a basic snack bar'),
      ),
    );
    setState(() => _snackBarCount++);
  }

  void _showActionSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText(text: 'File deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {},
        ),
        showCloseIcon: true,
      ),
    );
    setState(() => _snackBarCount++);
  }

  void _showFloatingSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      TomSnackBar(
        content: const TomText(text: 'Floating snack bar with action'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'RETRY',
          onPressed: () {},
        ),
      ),
    );
    setState(() => _snackBarCount++);
  }

  Widget _buildMaterialBannerSection() {
    return _DemoCard(
      tomId: 'demo09.banner',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.banner.statusLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 4),
          TomText(
            text: _bannerVisible ? 'Banner visible' : 'Banner hidden',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomFilledButton(
                tomId: 'demo09.banner.show',
                onPressed: _bannerVisible
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showMaterialBanner(
                          MaterialBanner(
                            content: const TomText(
                              text: 'A new software update is available.',
                            ),
                            leading: const Icon(Icons.system_update),
                            actions: [
                              TomTextButton(
                                label: 'DISMISS',
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentMaterialBanner();
                                  setState(() => _bannerVisible = false);
                                },
                              ),
                              TomTextButton(
                                label: 'UPDATE',
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentMaterialBanner();
                                  setState(() => _bannerVisible = false);
                                },
                              ),
                            ],
                          ),
                        );
                        setState(() => _bannerVisible = true);
                      },
              ),
              const TomSizedBox(width: 8),
              TomOutlinedButton(
                tomId: 'demo09.banner.hide',
                onPressed: _bannerVisible
                    ? () {
                        ScaffoldMessenger.of(context)
                            .hideCurrentMaterialBanner();
                        setState(() => _bannerVisible = false);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'demo09.tooltip',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.tooltip.hintLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const TomSizedBox(height: 16),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomTooltip(
                message: 'Save your work',
                child: TomIconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () {},
                ),
              ),
              TomTooltip(
                message: 'Share with others',
                waitDuration: const Duration(milliseconds: 500),
                child: TomIconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {},
                ),
              ),
              TomTooltip(
                message: 'Delete permanently',
                preferBelow: false,
                child: TomIconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () {},
                ),
              ),
              TomTooltip(
                richMessage: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Rich tooltip ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'with styled text',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                child: TomIconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Pickers & Cupertino
  // ===========================================================================

  Widget _buildDatePickerSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'demo09.datePicker',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              Icon(Icons.calendar_today, color: theme.colorScheme.primary),
              const TomSizedBox(width: 8),
              TomText(
                text:
                    'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              Icon(Icons.access_time, color: theme.colorScheme.primary),
              const TomSizedBox(width: 8),
              TomText(
                text: 'Time: ${_selectedTime.format(context)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomFilledButton(
                tomId: 'demo09.datePicker.pickDate',
                onPressed: () => _pickDate(context),
              ),
              const TomSizedBox(width: 8),
              TomFilledButton(
                tonal: true,
                tomId: 'demo09.datePicker.pickTime',
                onPressed: () => _pickTime(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final result = await TomDialogs.showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select a date',
    );
    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final result = await TomDialogs.showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Select a time',
    );
    if (result != null) {
      setState(() => _selectedTime = result);
    }
  }

  Widget _buildCupertinoAlertSection() {
    return _DemoCard(
      tomId: 'demo09.cupertinoAlert',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.cupertinoAlert.infoLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const TomSizedBox(height: 16),
          TomRow(
            children: [
              TomFilledButton(
                tomId: 'demo09.cupertinoAlert.show',
                onPressed: () => _showCupertinoAlert(context),
              ),
              const TomSizedBox(width: 8),
              TomFilledButton(
                tonal: true,
                tomId: 'demo09.cupertinoAlert.showDestructive',
                onPressed: () => _showDestructiveCupertinoAlert(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCupertinoAlert(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => TomCupertinoAlertDialog(
        tomId: 'demo09.cupertinoAlert.dlg',
        titleText: 'Allow Notifications?',
        content: const TomPadding(
          padding: EdgeInsets.only(top: 8),
          child: TomText(text: 'We would like to send you push notifications.'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Don't Allow"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Allow'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showDestructiveCupertinoAlert(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => TomCupertinoAlertDialog(
        tomId: 'demo09.cupertinoAlert.destructiveDlg',
        titleText: 'Delete Account?',
        content: const TomPadding(
          padding: EdgeInsets.only(top: 8),
          child: TomText(
            text: 'This will permanently delete your account and all data.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoActionSheetSection() {
    return _DemoCard(
      tomId: 'demo09.cupertinoSheet',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo09.cupertinoSheet.infoLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const TomSizedBox(height: 16),
          TomFilledButton(
            tomId: 'demo09.cupertinoSheet.show',
            onPressed: () => _showCupertinoActionSheet(context),
          ),
        ],
      ),
    );
  }

  void _showCupertinoActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => TomCupertinoActionSheet(
        tomId: 'demo09.cupertinoSheet.sheet',
        titleText: 'Photo Options',
        message: const TomText(text: 'Choose how to add a photo'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Take Photo'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoActionSheetAction(
            child: const Text('Choose from Library'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete Photo'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Dialog Demo
  // ===========================================================================

  Widget _buildAclDialogSection() {
    return _DemoCard(
      tomId: 'demo09.aclDialog',
      child: AclBuilder()
          // Row 1: Dialog type selector
          .append(TomText(tomId: 'demo09.aclDialog.typeLabel'))
          .append(
            TomExpanded(
              child: TomSegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'alert', label: Text('Alert')),
                  ButtonSegment(value: 'simple', label: Text('Simple')),
                  ButtonSegment(value: 'sheet', label: Text('Sheet')),
                ],
                selected: {_aclDialogType},
                onSelectionChanged: (v) =>
                    setState(() => _aclDialogType = v.first),
              ),
            ),
            dist: 8,
          )
          .newRow(dist: 12)
          // Row 2: Barrier dismissible toggle
          .append(TomText(tomId: 'demo09.aclDialog.barrierLabel'))
          .append(
            TomSwitch(
              value: _aclBarrierDismissible,
              onChanged: (v) => setState(() => _aclBarrierDismissible = v),
            ),
            dist: 8,
          )
          .newRow(dist: 12)
          // Row 3: Preview of current settings
          .append(
            TomExpanded(
              child: TomContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomText(
                  text: 'Type: $_aclDialogType | '
                      'Dismissible: $_aclBarrierDismissible',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ),
          )
          .newRow(dist: 12)
          // Row 4: Launch button
          .append(
            TomFilledButton(
              tomId: 'demo09.aclDialog.launch',
              onPressed: () => _launchAclDialog(context),
            ),
          )
          .gap()
          .append(
            TomTextButton(
              tomId: 'demo09.aclDialog.reset',
              onPressed: () {
                setState(() {
                  _aclDialogType = 'alert';
                  _aclBarrierDismissible = true;
                });
              },
            ),
            dist: 8,
          )
          .build(),
    );
  }

  void _launchAclDialog(BuildContext context) {
    switch (_aclDialogType) {
      case 'alert':
        TomDialogs.showDialog(
          context: context,
          barrierDismissible: _aclBarrierDismissible,
          builder: (ctx) => TomAlertDialog(
            titleText: 'ACL Alert',
            content: const TomPadding(
              padding: EdgeInsets.only(top: 8),
              child: TomText(text: 'Dialog launched from ACL builder.'),
            ),
            actions: [
              TomFilledButton(
                label: 'OK',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      case 'simple':
        TomDialogs.showDialog(
          context: context,
          barrierDismissible: _aclBarrierDismissible,
          builder: (ctx) => TomSimpleDialog(
            titleText: 'ACL Simple Dialog',
            children: [
              for (final opt in ['Alpha', 'Beta', 'Gamma'])
                SimpleDialogOption(
                  child: TomText(text: opt),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
            ],
          ),
        );
      case 'sheet':
        TomDialogs.showModalBottomSheet(
          context: context,
          isDismissible: _aclBarrierDismissible,
          showDragHandle: true,
          builder: (ctx) => TomPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: TomColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                TomText(
                  text: 'ACL Bottom Sheet',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const TomSizedBox(height: 8),
                const TomText(text: 'Launched from ACL builder controls.'),
                const TomSizedBox(height: 16),
                TomFilledButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
    }
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
