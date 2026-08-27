/// Which abstract base each concrete field actually extends.
///
/// The field catalogue groups every concrete under its abstract base, and a
/// reader uses that grouping to pick the type to program against — so a wrong
/// base is worse than a missing row. Two concretes are easy to misfile because
/// their *names* suggest a family their declarations do not join, and both had
/// in fact been documented under the wrong one.
///
/// These are not arbitrary facts to be kept in sync with prose: each follows
/// from the value type the field binds, which is what the assertions below
/// spell out. Pinning them here also stops the hierarchy being "corrected" to
/// match a table that was wrong about it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_search_lookup_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_string_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_enum_object_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_nullable_inputs.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_search_lookup_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_string_field.dart';
import 'package:tom_flutter_ui/src/forms/selection/static_selectable_source.dart';
import 'package:tom_flutter_ui/src/forms/selection/tom_selectable_source.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';

TomSelectableSource<String> _cities() =>
    StaticSelectableSource<String>(const [
      SelectableItem(value: 'oslo', label: 'Oslo'),
      SelectableItem(value: 'lima', label: 'Lima'),
    ]);

void main() {
  group('TomFormNEnumDropdown is a nullable input, not an enum field', () {
    test('extends TomField<T?> and is not in the enum family', () {
      final field = TomFormNEnumDropdown<String>(
        'city',
        null,
        source: _cities(),
      );

      expect(field, isA<TomField<String?>>());
      expect(field, isNot(isA<TomFormEnumField<String>>()));
    });

    // The exclusion is forced, not a stylistic choice. The base fixes its
    // value type as the T it is parameterised on, and a TomField<T?> is not a
    // TomField<T> — the substitution fails in the direction that matters, so
    // a nullable field cannot stand where the family is expected. (The
    // reverse does hold: generics are covariant, so the enum field below *is*
    // a TomField<String?>. Covariance is why only this direction proves
    // anything.)
    test('because the enum base binds T where the dropdown binds T?', () {
      final nullable = TomFormNEnumDropdown<String>(
        'city',
        null,
        source: _cities(),
      );
      expect(nullable, isNot(isA<TomField<String>>()));

      final enumField = TomFormEnumDropdown<String>(
        'city',
        'oslo',
        source: _cities(),
      );
      expect(enumField, isA<TomFormEnumField<String>>());
      expect(enumField, isA<TomField<String>>());
    });

    test('the two agree on everything except nullability', () {
      final nullable = TomFormNEnumDropdown<String>(
        'city',
        null,
        source: _cities(),
      );
      nullable.setValue('oslo');
      expect(nullable.get(), 'oslo');

      nullable.setValue(null);
      expect(nullable.get(), isNull);
    });
  });

  group('TomCupertinoFormStringSearchInput is a string field', () {
    // A CupertinoSearchTextField is search *chrome* over a text field; the
    // value it binds is the query string, not a picked item.
    test('extends TomFormStringField and is not in the search family', () {
      final field = TomCupertinoFormStringSearchInput('q', 'osl');

      expect(field, isA<TomFormStringField>());
      expect(field, isA<TomField<String>>());
      expect(field, isNot(isA<TomFormSearchField<String>>()));
    });

    test('the Cupertino search-family member is the other one', () {
      final field = TomCupertinoFormSearchInput<String>(
        'city',
        'oslo',
        source: _cities(),
      );

      expect(field, isA<TomFormSearchField<String>>());
      expect(field, isNot(isA<TomFormStringField>()));
    });
  });
}
