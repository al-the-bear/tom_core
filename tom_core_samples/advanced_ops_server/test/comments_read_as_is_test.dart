/// Every artefact this package ships reads as a statement of what the code
/// does *now*: no work-item pointers (`tcinc262`, `RCK13`, `Todo 9`), which
/// resolve only against quest documents a reader of the package does not have,
/// and no history narration ("used to", "before the fix"), which makes a reader
/// reconstruct the rule instead of reading it. Traceability runs the other way
/// -- a todo names the files it touched.
///
/// A section number (`§12`) names the document it belongs to, for the same
/// reason: a bare one points into whichever document the writer had open.
///
/// The rules, the id vocabulary and the exemptions are stated once, in
/// `tom_ai/core/tool/check_comments_read_as_is.py` and
/// `tom_ai/core/tool/check_section_refs.py`, which `check_gates.py` runs over
/// the whole repository. This suite runs those checkers over this package,
/// so a regression fails here, in the ordinary test run of the package that
/// introduced it. It holds no vocabulary of its own: copies that did drifted
/// apart, and one stayed narrower than the gate long enough to block a third
/// package from adopting it.
library;

import 'package:test/test.dart';

import '../../../tool/package_gate.dart';

void main() {
  test('shipped artefacts read as-is', () {
    final result = runPackageGate('check_comments_read_as_is');
    expect(
      result.faults,
      0,
      reason:
          'State the rule instead of the work item, and the rule that holds '
          'now instead of the change that produced it:\n${result.output}',
    );
  });

  test('every section reference names its document', () {
    final result = runPackageGate('check_section_refs');
    expect(
      result.faults,
      0,
      reason:
          'Name the document a section number belongs to, in the same '
          'comment:\n${result.output}',
    );
  });
}
