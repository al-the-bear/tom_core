import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Widget _wrapCupertino(Widget child) =>
    CupertinoApp(home: CupertinoPageScaffold(child: Center(child: child)));

/// Installs [tree] as the application's resources, replacing whatever was
/// there — the form widgets read their wording through this provider.
void _installResources(Map<String, dynamic> tree) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(tree),
  );
}

void main() {
  setUp(() => _installResources({}));
  tearDown(() => _installResources({}));

  // -------------------------------------------------------------------------
  // The façade itself
  // -------------------------------------------------------------------------

  group('TomFormLabels resolves scoped, then globally, then to English', () {
    test('an unconfigured application still reads in English', () {
      expect(TomFormLabels.cancel(null), 'Cancel');
      expect(TomFormLabels.done('anything'), 'Done');
      expect(TomFormLabels.choose('anything'), 'Choose…');
      expect(TomFormLabels.nullDisplay(null), '— null —');
    });

    test('a global key covers every field at once', () {
      _installResources({
        'form': {'cancel': 'Abbrechen', 'done': 'Fertig'},
      });
      expect(TomFormLabels.cancel(null), 'Abbrechen');
      expect(TomFormLabels.cancel('order.dueDate'), 'Abbrechen');
      expect(TomFormLabels.done('order.country'), 'Fertig');
    });

    test('a field-scoped key beats the global one', () {
      _installResources({
        'form': {'choose': 'Choose…'},
        'country': {
          'form': {'choose': 'Pick a country'},
        },
      });
      expect(TomFormLabels.choose('city'), 'Choose…');
      expect(TomFormLabels.choose('country'), 'Pick a country');
    });

    test('placeholders are interpolated at whichever level won', () {
      _installResources({
        'form': {'formatHint': 'Erwartet: {pattern}'},
      });
      expect(TomFormLabels.formatHint(null, 'TT.MM.JJJJ'), 'Erwartet: TT.MM.JJJJ');
      // The built-in fallback interpolates too, so an unconfigured
      // application still names the pattern rather than showing the brace.
      _installResources({});
      expect(TomFormLabels.formatHint(null, 'YYYY-MM-DD'), 'Format: YYYY-MM-DD');
    });

    test('the row-error caption has a key per plural form', () {
      _installResources({
        'form': {
          'rowErrorsOne': 'Eine Zeile ist fehlerhaft:',
          'rowErrorsMany': '{count} Fehler in dieser Zeile:',
        },
      });
      expect(TomFormLabels.rowErrors(null, 1), 'Eine Zeile ist fehlerhaft:');
      expect(TomFormLabels.rowErrors(null, 3), '3 Fehler in dieser Zeile:');
    });

    test('resolve() is the same order, for a caption outside the list', () {
      _installResources({
        'form': {'custom': 'global'},
        'here': {
          'form': {'custom': 'scoped'},
        },
      });
      expect(TomFormLabels.resolve('here', 'form.custom', 'fallback'), 'scoped');
      expect(TomFormLabels.resolve('other', 'form.custom', 'fallback'), 'global');
      expect(TomFormLabels.resolve(null, 'form.absent', 'fallback'), 'fallback');
    });
  });

  // -------------------------------------------------------------------------
  // The captions the widgets actually render
  // -------------------------------------------------------------------------

  group('Cupertino modal sheets read their buttons from resources', () {
    testWidgets('an enum picker sheet says Cancel and Done in the app language', (
      tester,
    ) async {
      _installResources({
        'form': {'cancel': 'Abbrechen', 'done': 'Fertig'},
      });
      final field = TomCupertinoFormObjectPicker<String>(
        'country',
        'de',
        source: StaticSelectableSource<String>(const [
          SelectableItem(label: 'Deutschland', value: 'de'),
          SelectableItem(label: 'Frankreich', value: 'fr'),
        ]),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));
      // The source loads asynchronously and a picker with no items refuses to
      // open, so settle before tapping or the sheet never appears.
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('a date picker sheet reads the same two keys', (tester) async {
      _installResources({
        'form': {'cancel': 'Abbrechen', 'done': 'Fertig'},
      });
      final field = TomCupertinoFormDatePicker(
        'due',
        DateTime(2026, 1, 1),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
    });
  });

  group('placeholders resolve from resources', () {
    testWidgets('a Cupertino picker with nothing selected says Choose…', (
      tester,
    ) async {
      _installResources({
        'form': {'choose': 'Bitte wählen…'},
      });
      final field = TomCupertinoFormObjectPicker<String>(
        'country',
        'de',
        // An empty source is what leaves a picker with nothing to show, so
        // this is the state the placeholder exists for.
        source: StaticSelectableSource<String>(const []),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      expect(find.text('Bitte wählen…'), findsOneWidget);
    });

    testWidgets('a Cupertino search input reads form.search', (tester) async {
      _installResources({
        'form': {'search': 'Suchen'},
      });
      final field = TomCupertinoFormStringSearchInput('q', '');
      await tester.pumpWidget(_wrapCupertino(field.widget));

      expect(find.text('Suchen'), findsOneWidget);
    });

    testWidgets('a Material autocomplete reads form.typeToSearch', (
      tester,
    ) async {
      _installResources({
        'form': {'typeToSearch': 'Zum Suchen tippen…'},
      });
      final field = TomFormSearchInput<String>(
        'q',
        '',
        source: StaticSelectableSource<String>(const [
          SelectableItem(label: 'Alpha', value: 'a'),
        ]),
      );
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Zum Suchen tippen…'), findsOneWidget);
    });
  });

  group('the null sentinel is a resource on both families', () {
    testWidgets('the Material nullable input falls through to form.nullDisplay', (
      tester,
    ) async {
      _installResources({
        'form': {'nullDisplay': '— nicht gesetzt —'},
      });
      final field = TomFormNStringInput('note', null);

      expect(field.resolveNullDisplay(), '— nicht gesetzt —');
      await tester.pumpWidget(_wrap(field.widget));
    });

    testWidgets('the Cupertino nullable input reads the same key', (
      tester,
    ) async {
      _installResources({
        'form': {'nullDisplay': '— nicht gesetzt —'},
      });
      final field = TomCupertinoFormNStringInput('note', null);
      await tester.pumpWidget(_wrapCupertino(field.widget));

      expect(find.text('— nicht gesetzt —'), findsOneWidget);
      expect(find.text('— null —'), findsNothing);
    });

    test('a field-scoped nullDisplay still wins over the global key', () {
      _installResources({
        'form': {'nullDisplay': '— nicht gesetzt —'},
        'note': {'nullDisplay': '(leer)'},
      });
      expect(TomFormNStringInput('note', null).resolveNullDisplay(), '(leer)');
      expect(
        TomFormNStringInput('other', null).resolveNullDisplay(),
        '— nicht gesetzt —',
      );
    });
  });

  group('tooltips and error surfaces are resources', () {
    testWidgets('a date field names its picker button from resources', (
      tester,
    ) async {
      _installResources({
        'form': {'openDatePicker': 'Kalender öffnen'},
      });
      final field = TomFormDateTextInput(
        'due',
        DateTime(2026, 1, 1),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpWidget(_wrap(field.widget));

      final button = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(button.tooltip, 'Kalender öffnen');
    });

    testWidgets('a nullable field names its clear button from resources', (
      tester,
    ) async {
      _installResources({
        'form': {'clearToNull': 'Leeren'},
      });
      final field = TomFormNStringInput('note', 'text');
      await tester.pumpWidget(_wrap(field.widget));

      final button = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(button.tooltip, 'Leeren');
    });

    test('the required suffix is a resource', () {
      _installResources({
        'form': {'requiredSuffix': ' (Pflicht)'},
      });
      expect(
        requiredIndicatorSuffixFor(
          RequiredIndicator.text,
          hasRequired: true,
          isEditable: true,
        ),
        ' (Pflicht)',
      );
    });
  });
}
