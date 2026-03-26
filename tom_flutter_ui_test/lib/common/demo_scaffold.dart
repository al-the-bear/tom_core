/// Demo scaffold and navigation components.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A demo tile that navigates to a demo page when tapped.
class DemoTile extends StatelessWidget {
  final String title;
  final String description;
  final Widget screen;
  final bool fullScreen;
  final IconData? icon;

  const DemoTile({
    super.key,
    required this.title,
    required this.description,
    required this.screen,
    this.fullScreen = false,
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
            builder: (context) => DemoScaffold(
              title: title,
              fullScreen: fullScreen,
              child: screen,
            ),
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
  final bool fullScreen;
  final bool showRtlToggle;

  const DemoScaffold({
    super.key,
    required this.title,
    required this.child,
    this.fullScreen = false,
    this.showRtlToggle = true,
  });

  @override
  State<DemoScaffold> createState() => _DemoScaffoldState();
}

class _DemoScaffoldState extends State<DemoScaffold> {
  AclDirection? _direction;

  @override
  Widget build(BuildContext context) {
    // Initialize direction from locale's text direction if not yet set
    final localeDirection = Directionality.of(context);
    _direction ??= localeDirection == TextDirection.rtl
        ? AclDirection.rtl
        : AclDirection.ltr;

    // Demos that use ListView manage their own scrolling and padding.
    // fullScreen: true is for demos that need the entire screen (no padding).
    final body = widget.child;

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
      body: AclDirectionScope(
        direction: _direction!,
        child: body,
      ),
    );
  }
}

/// A grid of demo tiles for the main demo listing.
class DemoGrid extends StatelessWidget {
  final List<DemoTile> demos;

  const DemoGrid({super.key, required this.demos});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: demos.length,
      itemBuilder: (context, index) => demos[index],
    );
  }
}

/// An expanding box for demos that need to show expansion behavior.
class ExpandingBox extends StatelessWidget {
  final String label;
  final Color color;
  final bool expandX;
  final bool expandY;

  const ExpandingBox({
    super.key,
    required this.label,
    required this.color,
    this.expandX = false,
    this.expandY = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (expandX || expandY) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (expandX) 'expandX',
                  if (expandY) 'expandY',
                ].join(' + '),
                style: TextStyle(
                  color: color.withAlpha(150),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
