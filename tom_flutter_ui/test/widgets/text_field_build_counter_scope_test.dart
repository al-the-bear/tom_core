import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// `TextField` calls `buildCounter` from its own build, long after the zone the
// `TomTextField` was constructed in has been left — so a counter that builds
// Tom widgets would resolve their resources under the default scope unless the
// callback re-enters the scope captured at construction.
//
// `InputCounterWidgetBuilder` has named parameters, which the positional
// `ScopeCapture.wrapN` family cannot express; the text field wraps it by hand
// around `ScopeCapture.run`. This pins that the hand-written wrapper both
// re-enters the scope and forwards every named argument.

void main() {
  testWidgets('buildCounter runs in the scope the field was built in', (
    tester,
  ) async {
    String? observedScope;
    int? observedLength;
    int? observedMax;
    bool? observedFocus;

    final field = TomScope.withScope(
      'signup',
      () => TomTextField(
        decoration: const InputDecoration(labelText: 'Name'),
        maxLength: 12,
        buildCounter:
            (
              context, {
              required currentLength,
              required maxLength,
              required isFocused,
            }) {
              observedScope = TomScope.current.getScopePath();
              observedLength = currentLength;
              observedMax = maxLength;
              observedFocus = isFocused;
              return Text('$currentLength/$maxLength');
            },
      ),
    );

    // Pumped outside the constructing zone: the current scope here is the
    // default one, so only the captured scope can produce 'signup'.
    expect(TomScope.current, same(TomScope.defaultScope));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field)));
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();

    expect(observedScope, 'signup');
    expect(observedLength, 3);
    expect(observedMax, 12);
    expect(observedFocus, isTrue);
    expect(find.text('3/12'), findsOneWidget);
  });
}
