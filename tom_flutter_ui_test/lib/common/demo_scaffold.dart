/// Demo scaffold and navigation components.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A demo tile that navigates to a demo page when tapped.
class DemoTile extends StatelessWidget {
  final String title;
  final String description;
  final Widget screen;
  final IconData? icon;

  const DemoTile({
    super.key,
    required this.title,
    required this.description,
    required this.screen,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: icon != null
            ? Icon(icon, color: Theme.of(context).primaryColor)
            : null,
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DemoScaffold(title: title, child: screen),
          ),
        ),
      ),
    );
  }
}

/// A scaffold that wraps demo content with appbar and RTL toggle.
class DemoScaffold extends StatefulWidget {
  final String title;
  final Widget child;
  final bool showRtlToggle;

  const DemoScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showRtlToggle = true,
  });

  @override
  State<DemoScaffold> createState() => _DemoScaffoldState();
}

class _DemoScaffoldState extends State<DemoScaffold> {
  AclDirection? _direction;

  @override
  Widget build(BuildContext context) {
    // Seed the toggle from the ambient locale's text direction on first build;
    // the RTL switch then owns it for the rest of the page's lifetime.
    final localeDirection = Directionality.of(context);
    _direction ??= localeDirection == TextDirection.rtl
        ? AclDirection.rtl
        : AclDirection.ltr;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: widget.showRtlToggle
            ? [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('LTR'),
                    Switch(
                      value: _direction == AclDirection.rtl,
                      onChanged: (v) => setState(() {
                        _direction = v ? AclDirection.rtl : AclDirection.ltr;
                      }),
                    ),
                    const Text('RTL'),
                    const SizedBox(width: 8),
                  ],
                ),
              ]
            : null,
      ),
      body: Directionality(
        textDirection: _direction == AclDirection.rtl
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: AclDirectionScope(direction: _direction!, child: widget.child),
      ),
    );
  }
}
