import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// `TomTextFormFieldBase` reads its label, hint and helper under its own path
/// with the same suffixes as every other field: `label`, `hint`, `helper`.
void main() {
  tearDown(
    () => TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    ),
  );

  testWidgets('TTFR-1: a field outside any scope shows its label, hint and '
      'helper from <tomId>.label, .hint and .helper', (tester) async {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({
        'notes': {'label': 'Notes', 'hint': 'Type here', 'helper': 'Free text'},
      }),
    );
    final field = TomTextFormFieldBase<String>('notes', '');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field.widget)));
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Type here'), findsOneWidget);
    expect(find.text('Free text'), findsOneWidget);
  });

  testWidgets('TTFR-2: the parameter names are not read as keys', (
    tester,
  ) async {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({
        'notes': {'hintText': 'old hint', 'helperText': 'old helper'},
      }),
    );
    final field = TomTextFormFieldBase<String>('notes', '');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field.widget)));
    expect(find.text('old hint'), findsNothing);
    expect(find.text('old helper'), findsNothing);
  });
}
