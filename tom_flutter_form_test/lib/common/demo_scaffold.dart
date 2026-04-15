import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Shared scaffold for all form demos.
///
/// Provides:
/// - AppBar with demo title
/// - LTR / RTL toggle switch in the AppBar actions
/// - Body wrapped in [Directionality] + [AclDirectionScope] so that
///   ACL layout and Flutter text direction always stay in sync.
class DemoScaffold extends StatefulWidget {
  final String title;
  final Widget child;

  const DemoScaffold({super.key, required this.title, required this.child});

  @override
  State<DemoScaffold> createState() => _DemoScaffoldState();
}

class _DemoScaffoldState extends State<DemoScaffold> {
  AclDirection _direction = AclDirection.ltr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(
              _direction == AclDirection.ltr
                  ? Icons.format_textdirection_l_to_r
                  : Icons.format_textdirection_r_to_l,
            ),
            tooltip: _direction == AclDirection.ltr
                ? 'Switch to RTL'
                : 'Switch to LTR',
            onPressed: () => setState(
              () => _direction = _direction == AclDirection.ltr
                  ? AclDirection.rtl
                  : AclDirection.ltr,
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: _direction == AclDirection.rtl
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: AclDirectionScope(
          direction: _direction,
          child: widget.child,
        ),
      ),
    );
  }
}
