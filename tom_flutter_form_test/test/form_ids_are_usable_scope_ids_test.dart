/// Every `formId` and `listId` in this package must be a legal scope id.
///
/// A form id is not merely a label: `TomForm.prepareForSelfObservation` passes
/// it to `TomScope.withScope` and joins it into `basePath`, so it *is* a scope
/// id, and the kernel refuses one containing the '.' that scope paths are
/// joined with. An id like `example.customer` would render identically to the
/// unrelated chain `example` → `customer`, which is how a form named from data
/// could reach another scope's resources.
///
/// The rule was added to the kernel without the call sites being brought with
/// it, and nine ids in `lib/examples/forms/` kept the dotted spelling. Twenty-
/// one tests failed, every one of them at construction — but only in the suites
/// that happened to mount those particular forms. A form added tomorrow with a
/// dotted id fails the same way and just as far from the cause.
///
/// **Why this asserts through the kernel rather than about it.** The test does
/// not check for a '.'; it hands each id to `TomScope.withScope` and requires
/// that not to throw. Restating the rule here would create a second copy of it
/// that can drift from the first — and this file exists because a rule and its
/// call sites drifted apart. Whatever the kernel comes to refuse, this fails
/// on, without being edited.
///
/// The ids are read out of the source rather than from constructed forms
/// because constructing every form in the package means binding every state
/// class it needs; the literal in the constructor is the thing under test and
/// it is right there. The scan itself lives in `support/form_id_sites.dart`,
/// shared with `example_key_maps_follow_form_ids_test.dart`.
///
/// **Interpolated ids.** One id is built at construction time
/// (`'phase5cFamily-${family.kind.name}'`). Its runtime value is not knowable
/// from the source, so each interpolation is replaced by a known-legal
/// placeholder and the surrounding *constant* text is what gets tested — that
/// catches `'a.${x}'`, which is the mistake a reader can actually make while
/// typing. It does not catch a separator arriving from inside the
/// interpolation; nothing static can. The kernel still refuses that one, just
/// at construction rather than here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'support/form_id_sites.dart';

void main() {
  final sites = idSites();

  test('the package declares form and list ids at all', () {
    expect(
      sites,
      isNotEmpty,
      reason:
          'no formId/listId literal was found under lib/. Either the '
          'forms moved or the pattern this test scans with no longer matches '
          'how they are written; an empty list must not read as "every id is '
          'fine".',
    );
  });

  group('every form and list id is one the kernel accepts as a scope id', () {
    for (final site in sites) {
      test('${site.file}:${site.line} ${site.kind}: ${site.id}', () {
        expect(
          () => TomScope.withScope(site.testable, () {}),
          returnsNormally,
          reason:
              'a ${site.kind} is used directly as a scope id and joined '
              'into the form\'s basePath, so it has to be one the kernel will '
              'accept. Rename it to a single segment — the examples spell the '
              'prefix inside the id (`exampleCustomer`, not '
              '`example.customer`) and their resource and authorization keys '
              'follow.',
        );
      });
    }
  });
}
