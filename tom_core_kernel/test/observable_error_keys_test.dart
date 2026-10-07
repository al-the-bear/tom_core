/// Pins the error key of the `TomClass` refusals that no other test names.
///
/// [TomObservableException] carries a key so a caller can tell a malformed
/// payload from a class that cannot be observed at all. A test that only checks
/// the exception type passes just as well when the key is misspelled or raised
/// from the wrong branch, so a key no test names is a failure mode nobody
/// checks. The rest of the module's vocabulary is pinned in
/// `observable_test.dart`'s error-key group.
///
/// Both cases need reflected classes, so they use the fixtures declared in
/// `observable_test.dart` and that suite's reflection build.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'observable_test.dart' show TestDirectory, TestLateChild;
import 'observable_test.reflection.dart';

/// Matches a [TomObservableException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomObservableException>().having((e) => e.key, 'key', key));

void main() {
  setUpAll(initializeReflection);

  test(
    'a superclass member that cannot be read during self-observation is '
    'reported under '
    'observable.class_initialization.could_not_register_superclass_members',
    () {
      // The subclass assigns the superclass's `late` member in its constructor
      // body, which runs only after the TomClass constructor has already tried
      // to register it.
      expect(
        TestLateChild.new,
        _throwsKey(
          'observable.class_initialization.could_not_register_superclass_members',
        ),
      );
    },
  );

  test('a TomClass map value given a non-map is refused under '
      'observable.class_set_map_member.invalid_element_type', () {
    expect(
      () => TestDirectory().setValues({
        'profiles': {'alice': 'not a map'},
      }),
      _throwsKey('observable.class_set_map_member.invalid_element_type'),
    );
  });
}
