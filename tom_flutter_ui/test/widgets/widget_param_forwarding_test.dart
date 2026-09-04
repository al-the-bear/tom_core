import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// A Tom wrapper that declares a parameter whose `buildContent` then builds the
// underlying Flutter widget WITHOUT passing it leaves that parameter silently
// inert — the omission compiles, and only a render shows it. These render each
// wrapper and read the forwarded property off the underlying widget, pinning
// that the parameter reaches its destination.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('TomMenuItemButton forwards onHover / onFocusChange', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MenuBar(
          children: [
            TomMenuItemButton(
              label: 'item',
              onPressed: () {},
              onHover: () {},
              onFocusChange: () {},
            ),
          ],
        ),
      ),
    );

    final btn = tester.widget<MenuItemButton>(find.byType(MenuItemButton));
    expect(btn.onHover, isNotNull);
    expect(btn.onFocusChange, isNotNull);
  });

  testWidgets('TomSubmenuButton forwards onHover / onFocusChange', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MenuBar(
          children: [
            TomSubmenuButton(
              label: 'menu',
              onHover: () {},
              onFocusChange: () {},
              menuChildren: const [Text('child')],
            ),
          ],
        ),
      ),
    );

    final btn = tester.widget<SubmenuButton>(find.byType(SubmenuButton));
    expect(btn.onHover, isNotNull);
    expect(btn.onFocusChange, isNotNull);
  });

  testWidgets('TomSliverResizingHeader forwards extent prototypes', (
    tester,
  ) async {
    const minProto = SizedBox(key: ValueKey('min'), height: 20);
    const maxProto = SizedBox(key: ValueKey('max'), height: 80);

    await tester.pumpWidget(
      _host(
        CustomScrollView(
          slivers: [
            TomSliverResizingHeader(
              minExtentPrototype: minProto,
              maxExtentPrototype: maxProto,
              child: const Text('header'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 1000)),
          ],
        ),
      ),
    );

    final header = tester.widget<SliverResizingHeader>(
      find.byType(SliverResizingHeader),
    );
    expect(header.minExtentPrototype, same(minProto));
    expect(header.maxExtentPrototype, same(maxProto));
  });

  testWidgets('TomNavigationBar forwards labelTextStyle', (tester) async {
    final labelStyle = WidgetStateProperty.all(const TextStyle(fontSize: 11));

    await tester.pumpWidget(
      _host(
        TomNavigationBar(
          labelTextStyle: labelStyle,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'a'),
            NavigationDestination(icon: Icon(Icons.search), label: 'b'),
          ],
        ),
      ),
    );

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.labelTextStyle, same(labelStyle));
  });

  testWidgets('TomRefreshIndicator forwards a typed triggerMode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TomRefreshIndicator(
          triggerMode: RefreshIndicatorTriggerMode.anywhere,
          onRefresh: () async {},
          child: ListView(children: const [SizedBox(height: 600)]),
        ),
      ),
    );

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(indicator.triggerMode, RefreshIndicatorTriggerMode.anywhere);
  });
}
