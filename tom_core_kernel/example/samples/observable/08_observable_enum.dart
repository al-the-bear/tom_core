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
///
/// This is what lets an application ship *no* `extension TodoStatusText on
/// TodoStatus { String get text => … }` label tables: the strings the user
/// sees are the ones the server sent.
///
/// NOTE: Run `dart run build_runner build` before executing this example.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The workflow state of a task. Its resource segment is the lower-cased type
/// name, `todostatus`.
enum TodoStatus { open, inReview, done }

/// English labels for [TodoStatus], plus one scoped override.
Map<String, dynamic> _englishBundle() => {
      'global': {
        'todostatus': {
          'open': 'Open',
          'inreview': 'In review',
          'done': 'Done',
        },
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
      TomTextResourceProvider.from(bundle));
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

  status | TodoStatus.inReview;
  print('after set:   ${status.displayText}\n');

  // ---------------------------------------------------------------------
  // 2. A scope may override individual labels
  // ---------------------------------------------------------------------
  print('--- 2. Scoped overrides ---');
  TomScope.withScope('checkout', () {
    final scoped = TomObservableEnum(TodoStatus.open,
        values: TodoStatus.values);

    // Tries checkout.todostatus.open first, then global.todostatus.open.
    print('candidates:  ${TomObservableEnum.resourceKeysFor(TodoStatus.open)}');
    print('open:        ${scoped.displayText}  (scoped override)');
    print('done:        ${scoped.displayTextOf(TodoStatus.done)}'
        '  (falls back to global)');
  });
  print('');

  // ---------------------------------------------------------------------
  // 3. A locale switch notifies observers
  // ---------------------------------------------------------------------
  print('--- 3. Switching locale ---');
  // Retain the observer — TomObservable holds its observers weakly.
  final observer = status >> (_) => print('  notified: ${status.displayText}');

  print('installing the German bundle…');
  _installBundle(_germanBundle());

  print('setting the value…');
  status | TodoStatus.done;

  status.removeObserver(observer);
  print('');

  // ---------------------------------------------------------------------
  // 4. A missing key degrades to the raw enum name
  // ---------------------------------------------------------------------
  print('--- 4. Missing keys ---');
  _installBundle({
    'global': {
      'todostatus': {'open': 'Open'}
    }
  });
  final partial =
      TomObservableEnum(TodoStatus.done, values: TodoStatus.values);

  // Recognisable, never blank — and a warning names the keys that were tried.
  print('displayText: ${partial.displayText}  (raw enum name)');
  print('displayKey:  ${partial.displayKey}  (the key to add)');
  print('all labels:  ${partial.displayTexts}  (present labels still resolve)');

  print('\n=== Example Complete ===\n');
}

/// Standalone entry point.
Future<void> main() async {
  run();
}
