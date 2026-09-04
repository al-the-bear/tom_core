/// `TomTextFormFieldBase<T>` bridges a `String` controller to a `T` value, and
/// the two directions of that bridge are not equally available.
///
/// `T` → text always works: `toString()` is defined for everything, so
/// `valueToTextConverter` is genuinely optional. Text → `T` only works for
/// `T == String`, where it is the identity — nothing can parse an arbitrary
/// `T` out of a string. So `valueConverter` is optional in the type signature
/// but mandatory in fact for every `T` except `String`.
///
/// That gap used to be discovered at the first keystroke: the field
/// constructed, rendered, and threw `UnimplementedError` the moment the user
/// typed a character. It is now refused at construction, since whether a
/// converter was supplied is known the instant the field is built.
///
/// The tests below pin both halves — the refusal, and that the supported
/// combinations still work — because the constructor guard is exactly the kind
/// of check that is easy to make too strict, and the caller it would break is
/// a consumer's subclass rather than anything in this package.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // -------------------------------------------------------------------------
  // The refusal
  // -------------------------------------------------------------------------

  group('a non-String field built without a converter', () {
    test('is refused at construction, not at the first keystroke', () {
      expect(
        () => TomTextFormFieldBase<int>('age', 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('names the public constructor argument, not the private field', () {
      // The old message said "Override _valueConverter", naming a member no
      // subclass outside this library can see. The caller's remedy is the
      // constructor argument.
      expect(
        () => TomTextFormFieldBase<int>('age', 0),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'valueConverter')
              .having(
                (e) => e.message.toString(),
                'message',
                allOf(contains('valueConverter'), isNot(contains('_value'))),
              ),
        ),
      );
    });

    test('says which T it could not convert to', () {
      expect(
        () => TomTextFormFieldBase<double>('rating', 0.0),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('double'),
          ),
        ),
      );
    });

    test('is refused even when only the outbound converter was supplied', () {
      // valueToTextConverter covers T -> text. It says nothing about how to
      // get back, so supplying it does not satisfy the requirement.
      expect(
        () => TomTextFormFieldBase<int>(
          'age',
          0,
          valueToTextConverter: (v) => v.toString(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // What is still allowed
  // -------------------------------------------------------------------------

  group('the supported combinations', () {
    test('String needs no converter — its default is the identity', () {
      final field = TomTextFormFieldBase<String>('name', 'Bolt');
      addTearDown(field.dispose);

      expect(field.get(), 'Bolt');
    });

    test('a non-String field with a converter builds', () {
      final field = TomTextFormFieldBase<int>(
        'age',
        7,
        valueConverter: (s) => int.tryParse(s) ?? 0,
      );
      addTearDown(field.dispose);

      expect(field.get(), 7);
    });

    testWidgets('the outbound converter stays optional, because toString() '
        'always exists', (tester) async {
      // Only valueConverter was passed, yet the controller comes up showing
      // the int rendered as text — that is the outbound default doing its job
      // for a T it was never told about, which is why only one of the two
      // converters is mandatory.
      final field = TomTextFormFieldBase<int>(
        'age',
        42,
        valueConverter: (s) => int.tryParse(s) ?? 0,
      );
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '42',
      );
    });
  });

  // -------------------------------------------------------------------------
  // The converter actually running
  // -------------------------------------------------------------------------

  group('typing into a converted field', () {
    testWidgets('parses the text through valueConverter', (tester) async {
      final field = TomTextFormFieldBase<int>(
        'age',
        0,
        valueConverter: (s) => int.tryParse(s) ?? 0,
      );
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      await tester.enterText(find.byType(TextField), '37');
      await tester.pump();

      expect(field.get(), 37);
    });

    testWidgets('a subclass may supply the converter from its super call', (
      tester,
    ) async {
      // Passing valueConverter through `super` is a different arrival path
      // from passing it directly, and it is the one a subclass uses. A
      // constructor guard that read the argument wrongly would reject every
      // such subclass while the direct-construction cases above stayed green,
      // so the path is covered here rather than left to a consumer to find.
      final field = _Celsius('temperature', 0);
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      await tester.enterText(find.byType(TextField), '21');
      await tester.pump();

      expect(field.get(), 21);
    });
  });
}

/// A minimal non-`String` subclass, standing in for the shape a consumer
/// writes: the type argument and the converter are fixed by the subclass, and
/// the caller supplies neither.
class _Celsius extends TomTextFormFieldBase<int> {
  _Celsius(super.tomId, super.initialValue)
    : super(valueConverter: (s) => int.tryParse(s) ?? 0);
}
