/// Example: TomObservableEnum — enum labels from the resource bundle
///
/// This example demonstrates [TomObservableEnum], an observable enum cell
/// whose *display text* is derived from the application text bundle instead of
/// being hardcoded in Dart:
/// - keys are `<scope>.<enumName>.<value>`, resolved through
///   [TomTextResourceProvider]
/// - the scope segment is implicit — taken from the ambient [TomScope] at
///   construction time — and a scope may override individual labels
/// - a locale switch notifies observers, so bound widgets re-render without
///   the caller rebuilding them
/// - a value with no key degrades to its raw enum name and logs a warning
/// - the value is confined to the `values` the cell was given, so its option
///   list always contains what it holds
///
/// This is what lets an application ship *no* `extension TodoStatusText on
/// TodoStatus { String get text => … }` label tables: the strings the user
/// sees are the ones the server sent.
///
/// NOTE: Run `dart run build_runner build` before executing this example.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

/// The workflow state of a task. Its resource segment is the lower-cased type
/// name, `todostatus`.
enum TodoStatus { open, inReview, done }

/// English labels for [TodoStatus], plus one scoped override.
Map<String, dynamic> _englishBundle() => {
  'global': {
    'todostatus': {'open': 'Open', 'inreview': 'In review', 'done': 'Done'},
  },
  // The checkout screen calls the same state something else.
  'checkout': {
    'todostatus': {'open': 'Not yet ordered'},
  },
};

/// German labels for [TodoStatus] — the same keys, different text.
Map<String, dynamic> _germanBundle() => {
  'global': {
    'todostatus': {
      'open': 'Offen',
      'inreview': 'In Prüfung',
      'done': 'Erledigt',
    },
  },
};

/// Installs [bundle] as the application-wide text resources.
///
/// This is what an application does when the user switches language; it bumps
/// `TomTextResourceProvider.appResourcesRevision`, which is what every
/// [TomObservableEnum] observes.
void _installBundle(Map<String, dynamic> bundle) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(bundle),
  );
}

void run() {
  print('=== TomObservableEnum Example ===\n');

  _installBundle(_englishBundle());

  // ---------------------------------------------------------------------
  // 1. Display text comes from the bundle, not from Dart
  // ---------------------------------------------------------------------
  print('--- 1. Resolving display text ---');
  final status = TomObservableEnum(TodoStatus.open, values: TodoStatus.values);

  print('value:       ${~status}');
  print('displayText: ${status.displayText}');
  print('displayKey:  ${status.displayKey}');
  print('all labels:  ${status.displayTexts}');

  assert(~status == TodoStatus.open, 'The cell holds the value it was given');
  assert(status.displayText == 'Open', 'Label comes from the bundle');
  assert(
    status.displayKey == 'global.todostatus.open',
    'Key is <scope>.<enumName>.<value>, scope implicit',
  );
  assert(
    status.displayTexts.join('|') == 'Open|In review|Done',
    'displayTexts resolves every permitted value, in order',
  );

  status | TodoStatus.inReview;
  print('after set:   ${status.displayText}\n');

  assert(
    status.displayText == 'In review',
    'The label follows the value without the caller re-reading the bundle',
  );

  // ---------------------------------------------------------------------
  // 2. A scope may override individual labels
  // ---------------------------------------------------------------------
  print('--- 2. Scoped overrides ---');
  TomScope.withScope('checkout', () {
    final scoped = TomObservableEnum(
      TodoStatus.open,
      values: TodoStatus.values,
    );

    // Tries checkout.todostatus.open first, then global.todostatus.open.
    print('candidates:  ${TomObservableEnum.resourceKeysFor(TodoStatus.open)}');
    print('open:        ${scoped.displayText}  (scoped override)');
    print(
      'done:        ${scoped.displayTextOf(TodoStatus.done)}'
      '  (falls back to global)',
    );

    assert(
      TomObservableEnum.resourceKeysFor(TodoStatus.open).join('|') ==
          'checkout.todostatus.open|global.todostatus.open',
      'The scoped key is tried before the global one',
    );
    assert(
      scoped.displayText == 'Not yet ordered',
      'The checkout scope overrides this label',
    );
    assert(
      scoped.displayTextOf(TodoStatus.done) == 'Done',
      'A value the scope does not override falls back to global',
    );
  });
  print('');

  // ---------------------------------------------------------------------
  // 3. A locale switch notifies observers
  // ---------------------------------------------------------------------
  print('--- 3. Switching locale ---');
  // Retain the observer — TomObservable holds its observers weakly.
  var localeNotifications = 0;
  final observer =
      status >>
      (_) {
        localeNotifications++;
        print('  notified: ${status.displayText}');
      };

  print('installing the German bundle…');
  _installBundle(_germanBundle());

  // The value did not change here — the bundle did. Observers are notified
  // anyway, which is the whole point: a bound widget re-renders on a language
  // switch without anyone rebuilding it.
  assert(localeNotifications == 1, 'A locale switch should notify observers');
  assert(
    ~status == TodoStatus.inReview,
    'A locale switch must not disturb the value',
  );
  assert(
    status.displayText == 'In Prüfung',
    'The label should now come from the German bundle',
  );

  print('setting the value…');
  status | TodoStatus.done;

  assert(localeNotifications == 2, 'Setting the value notifies as usual');
  assert(status.displayText == 'Erledigt', 'German label for the new value');

  status.removeObserver(observer);
  print('');

  // ---------------------------------------------------------------------
  // 4. A missing key degrades to the raw enum name
  // ---------------------------------------------------------------------
  print('--- 4. Missing keys ---');
  _installBundle({
    'global': {
      'todostatus': {'open': 'Open'},
    },
  });
  final partial = TomObservableEnum(TodoStatus.done, values: TodoStatus.values);

  // Recognisable, never blank — and a warning names the keys that were tried.
  print('displayText: ${partial.displayText}  (raw enum name)');
  print('displayKey:  ${partial.displayKey}  (the key to add)');
  print('all labels:  ${partial.displayTexts}  (present labels still resolve)');

  assert(
    partial.displayText == 'done',
    'A missing key degrades to the raw enum name, never to blank',
  );
  assert(
    partial.displayKey == 'global.todostatus.done',
    'displayKey still names the key that should be added',
  );
  assert(
    partial.displayTexts.join('|') == 'Open|inReview|done',
    'One missing key does not stop the present ones resolving',
  );
  print('');

  // ---------------------------------------------------------------------
  // 5. The value is confined to the options the cell offers
  // ---------------------------------------------------------------------
  print('--- 5. Permitted values ---');
  _installBundle(_englishBundle());
  // A subset is a legitimate option list: this cell offers two of the three.
  final restricted = TomObservableEnum(
    TodoStatus.open,
    values: const [TodoStatus.open, TodoStatus.inReview],
  );
  print('options:     ${restricted.displayTexts}');
  assert(
    restricted.displayTexts.join('|') == 'Open|In review',
    'The option list is the subset the cell was given, not all values',
  );

  restricted | TodoStatus.inReview;
  print('after set:   ${restricted.displayText}');
  assert(
    restricted.displayText == 'In review',
    'A permitted value is accepted',
  );

  // Tracked so the assertion below can tell "rejected" from "silently
  // accepted": without it, a cell that stopped rejecting would run straight
  // through the try and the example would still print success.
  var rejected = false;
  try {
    restricted | TodoStatus.done;
  } on TomObservableException catch (e) {
    // Without this, the cell would label itself from a list not containing its
    // own value, and a picker bound to it would have nothing to select.
    rejected = true;
    print('rejected:    ${e.key}');
    assert(
      e.key == 'observable.enum_value.not_in_values',
      'Rejection should carry the documented key',
    );
  }
  print('unchanged:   ${restricted.displayText}');

  assert(rejected, 'A value outside `values` must be rejected, not accepted');
  assert(
    ~restricted == TodoStatus.inReview,
    'The rejected assignment must leave the value untouched',
  );
  assert(restricted.displayText == 'In review', '…and the label with it');

  print('\n=== Example Complete ===\n');
}

/// Standalone entry point.
Future<void> main() async {
  requireAsserts();
  run();
}
