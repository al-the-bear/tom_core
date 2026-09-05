/// Demonstrates `appResourcesRevision`, the observable counter that makes a
/// bundle change visible to everything derived from the bundle.
///
/// This example covers:
/// - Observing `TomTextResourceProvider.appResourcesRevision` with `>>`
/// - Installing a bundle (`setAppResourceProvider`) as a locale switch
/// - Assigning a new map to the **installed** provider's `resources`
/// - Assigning `resources` on a provider that is *not* installed — silent
/// - Mutating the installed map **in place** — also silent, and why
/// - Announcing that mutation with `notifyAppResourcesChanged()`
///
/// Text read out of the bundle is a copy: a label rendered into a widget, a
/// caption cached in a field. Swap the bundle and every such copy is stale,
/// with nothing in the value itself to say so. The revision is the signal that
/// says so — observe it, re-read the bundle when it fires. It is what
/// `TomObservableEnum` uses to keep its display strings current, so a language
/// switch re-renders bound widgets without the caller rebuilding them.
///
/// Three rules decide whether the counter moves, and only the third is
/// surprising:
///
/// 1. **Installing a provider notifies.** Installation is the one way a bundle
///    becomes application-wide, and it always announces itself.
/// 2. **Assigning `resources` on the installed provider notifies** — but only
///    on *that* provider. A provider nobody reads from has not changed
///    anything application-visible, so its setter is silent.
/// 3. **Mutating the installed map in place does not notify.** `resources['k']
///    = v` never runs the setter; nothing in the module can see it. Call
///    `notifyAppResourcesChanged()` yourself after such an edit.
///
/// The counter is a process-wide `static final TomInt` that nothing resets, so
/// this example reads it with `~` up front and compares deltas rather than
/// absolute values.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// English labels — the bundle the application starts with.
Map<String, dynamic> _englishBundle() => {
  'app': {'title': 'Task Board', 'newTask': 'New task'},
};

/// German labels — the same keys, what a locale switch installs.
Map<String, dynamic> _germanBundle() => {
  'app': {'title': 'Aufgabenbrett', 'newTask': 'Neue Aufgabe'},
};

/// French labels — installed by *assigning* rather than by replacing the
/// provider, to show that both routes notify.
Map<String, dynamic> _frenchBundle() => {
  'app': {'title': 'Tableau des tâches', 'newTask': 'Nouvelle tâche'},
};

void run() {
  print('=== 05: Resource Revision Example ===\n');

  // ===========================================================================
  // Example 1: a derived caption, and an observer that keeps it current
  // ===========================================================================

  print('1. Observe the revision and re-derive on every bump:');

  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(_englishBundle()),
  );

  // Stands in for a rendered widget label: read once, then stale until
  // something re-reads it.
  var caption = TomTextResourceProvider.getAppResources().getText('app.title');
  var notifications = 0;

  // Retain the returned observer — TomObservable holds its observers weakly,
  // and a discarded wrapper silently stops firing at some later point.
  final observer =
      TomTextResourceProvider.appResourcesRevision >>
      (_) {
        notifications++;
        caption = TomTextResourceProvider.getAppResources().getText(
          'app.title',
        );
      };

  final revisionAtStart = ~TomTextResourceProvider.appResourcesRevision;

  print('   caption: $caption');
  print('   revision: $revisionAtStart, notifications: $notifications');
  print('');

  // ===========================================================================
  // Example 2: a locale switch — installing a provider notifies
  // ===========================================================================

  print('2. Installing the German bundle (the locale switch):');

  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(_germanBundle()),
  );

  final afterInstall = ~TomTextResourceProvider.appResourcesRevision;
  final captionAfterInstall = caption;
  final notificationsAfterInstall = notifications;

  // Nothing re-read the bundle by hand: the observer did it, because the
  // counter moved.
  print('   caption: $captionAfterInstall');
  print(
    '   revision: $afterInstall, notifications: $notificationsAfterInstall',
  );
  print('');

  // ===========================================================================
  // Example 3: assigning resources on the installed provider notifies too
  // ===========================================================================

  print('3. Assigning a new map to the installed provider:');

  // The other route to a new bundle: keep the provider, replace its map. The
  // setter sees the assignment and announces it.
  TomTextResourceProvider.getAppResources().resources = _frenchBundle();

  final afterAssign = ~TomTextResourceProvider.appResourcesRevision;
  final captionAfterAssign = caption;

  print('   caption: $captionAfterAssign');
  print('   revision: $afterAssign, notifications: $notifications');
  print('');

  // ===========================================================================
  // Example 4: assigning on a provider that is not installed is silent
  // ===========================================================================

  print('4. Assigning on a provider that is NOT installed:');

  // Building and populating a provider off to one side is not an
  // application-wide event; nobody reads from it, so nobody is told.
  final scratch = TomTextResourceProvider.from({});
  scratch.resources = _englishBundle();

  final afterScratch = ~TomTextResourceProvider.appResourcesRevision;
  final captionAfterScratch = caption;

  print('   scratch.getText("app.title"): ${scratch.getText('app.title')}');
  print('   app-wide caption is untouched: $captionAfterScratch');
  print('   revision: $afterScratch (unchanged)');
  print('');

  // ===========================================================================
  // Example 5: in-place mutation is silent — and how to announce it
  // ===========================================================================

  print('5. Mutating the installed bundle in place:');

  // `[]=` on the map the provider already holds. The setter never runs, so the
  // module cannot see this: the bundle now says one thing and every derived
  // copy still says another.
  final installedBundle = TomTextResourceProvider.getAppResources().resources;
  (installedBundle['app'] as Map)['title'] = 'Tableau révisé';

  final afterMutation = ~TomTextResourceProvider.appResourcesRevision;
  final captionAfterMutation = caption;
  final bundleAfterMutation = TomTextResourceProvider.getAppResources().getText(
    'app.title',
  );

  print('   bundle now says:  $bundleAfterMutation');
  print('   caption still says: $captionAfterMutation  ← stale');
  print('   revision: $afterMutation (unchanged)');

  // Which is what the manual announcement is for.
  TomTextResourceProvider.notifyAppResourcesChanged();

  final afterNotify = ~TomTextResourceProvider.appResourcesRevision;
  final captionAfterNotify = caption;

  print('   after notifyAppResourcesChanged():');
  print('   caption: $captionAfterNotify');
  print('   revision: $afterNotify, notifications: $notifications');
  print('');

  // Stop observing. Nothing later in this process needs the caption, and an
  // observer left registered would keep re-deriving from bundles installed by
  // unrelated examples.
  TomTextResourceProvider.appResourcesRevision.removeObserver(observer);

  final notificationsAtEnd = notifications;
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(_englishBundle()),
  );

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 2: installing notifies, and the observer re-derived the caption.
  assert(
    afterInstall == revisionAtStart + 1,
    'Installing a provider bumps the revision exactly once',
  );
  assert(notificationsAfterInstall == 1, 'The observer fired on the install');
  assert(
    captionAfterInstall == 'Aufgabenbrett',
    'The caption followed the bundle without anyone re-reading it by hand',
  );

  // Example 3: assigning to the installed provider notifies as well.
  assert(
    afterAssign == revisionAtStart + 2,
    'Assigning resources on the installed provider bumps too',
  );
  assert(captionAfterAssign == 'Tableau des tâches');

  // Example 4: the same assignment on any other provider is silent.
  assert(
    afterScratch == afterAssign,
    'A provider nobody reads from announces nothing',
  );
  assert(
    captionAfterScratch == 'Tableau des tâches',
    'The app-wide bundle is unaffected by an unrelated provider',
  );
  assert(
    scratch.getText('app.title') == 'Task Board',
    'The scratch provider does hold its own new map',
  );

  // Example 5: in-place mutation is invisible until announced.
  assert(
    afterMutation == afterAssign,
    'In-place mutation cannot be detected — the setter never runs',
  );
  assert(
    bundleAfterMutation == 'Tableau révisé',
    'The value in the bundle really did change',
  );
  assert(
    captionAfterMutation == 'Tableau des tâches',
    '…and every derived copy is now stale, with no signal that it is',
  );
  assert(
    afterNotify == afterMutation + 1,
    'notifyAppResourcesChanged() supplies the missing signal',
  );
  assert(
    captionAfterNotify == 'Tableau révisé',
    'The observer re-derived, and the caption caught up',
  );

  // Five bundle changes happened in this example; three announced themselves.
  // The observer counted exactly those three — the two silent ones (the
  // uninstalled provider's setter, the in-place edit) never reached it.
  assert(
    notificationsAtEnd == 3,
    'Three announced changes, three notifications',
  );
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
