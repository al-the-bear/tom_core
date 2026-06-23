/// A single reflected form whose four fields each pin a different
/// [TomAuthState] via [TomAuthorizer.fixed], so the four renderings of the same
/// field can be compared side by side in the authorization group.
///
/// It is a `TomForm` like the others — annotated `@tomReflector` and seeded for
/// reflection — because binding a form reads/writes its fields through kernel
/// reflection. Each field carries the same label and seeded value; only the
/// fixed authorizer differs.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/showcase_entities.dart';

/// Sample value the read/disabled states display (full/none speak for
/// themselves).
const String _sampleCompany = 'Analytical Engines Ltd.';

/// Form backing the four-state authorization cells.
@tomReflector
class AuthShowcaseForm extends TomForm<CompanyProfile> {
  /// Creates the form in the ambient scope.
  AuthShowcaseForm() : super(formId: 'company');

  @override
  void createFormElements() {}

  /// Fully interactive and editable.
  late final full = _field('full', TomAuthState.full);

  /// Shows its value but cannot be edited.
  late final read = _field('read', TomAuthState.read);

  /// Greyed out and non-interactive.
  late final disabled = _field('disabled', TomAuthState.disabled);

  /// Hidden entirely.
  late final none = _field('none', TomAuthState.none);

  TomFormStringInput _field(String id, TomAuthState state) => TomFormStringInput(
        id,
        _sampleCompany,
        form: this,
        labelTextOverride: 'Company name',
        authorizer: TomAuthorizer.fixed(state),
      );
}
