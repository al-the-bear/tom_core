/// Authorization group — the four-state model applied to a form field.
///
/// Every Tom field carries an [authorizer]; the resolved [TomAuthState] decides
/// how it renders, independent of business logic:
///
/// * [TomAuthState.none] — hidden; the field does not exist for the user.
/// * [TomAuthState.disabled] — visible but greyed out and non-interactive.
/// * [TomAuthState.read] — shows its value but cannot be edited.
/// * [TomAuthState.full] — fully interactive and editable.
///
/// Each cell renders one field of a single [AuthShowcaseForm], each pinned to a
/// state with [TomAuthorizer.fixed], so the four renderings of the same field
/// can be compared. In real apps the state is not hard-pinned: resource-level
/// state comes from `TomAuthorization.resolveAuth`, backed by whichever
/// `TomAuthorizationAdapter` the application installs, and an authorizer's
/// `strategy` decides how it combines with that — `authorizerNarrowsOnly` may
/// only restrict it, while `authorizerDecides` overrides it, which is what
/// [TomAuthorizer.fixed] uses. Installing no adapter, as this sample does,
/// resolves every resource to [TomAuthState.full], which is why pinning alone
/// can demonstrate all four states here.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/auth_showcase_form.dart';

ShowcaseCell _stateCell({
  required String title,
  required String note,
  required String scopeId,
  required String stateName,
  required Widget Function(AuthShowcaseForm form) field,
}) {
  return ShowcaseCell(
    title: title,
    note: note,
    code:
        "TomFormStringInput(\n"
        "  '$stateName',\n"
        "  'Analytical Engines Ltd.',\n"
        "  form: this,\n"
        "  labelTextOverride: 'Company name',\n"
        "  authorizer: TomAuthorizer.fixed(TomAuthState.$stateName),\n"
        ")",
    child: FormHost<AuthShowcaseForm>(
      scopeId: scopeId,
      create: AuthShowcaseForm.new,
      bind: (form) => form.bind(CompanyProfile()),
      builder: (context, form) => field(form),
    ),
  );
}

/// Puts [gated] between two labels, so a state that renders nothing shows as
/// the labels closing up rather than as an empty preview.
Widget _betweenLabels(Widget gated) => TomColumn(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TomText(text: 'Above the field'),
    gated,
    TomText(text: 'Below the field'),
  ],
);

/// The Authorization component group.
final ShowcaseGroup authorizationGroup = ShowcaseGroup(
  id: 'authorization',
  title: 'Four-state authorization',
  summary:
      'none, disabled, read and full — the TomAuthState model that drives '
      'how every field renders, shown with TomAuthorizer.fixed.',
  icon: Icons.shield_outlined,
  cells: (context) => [
    _stateCell(
      title: 'TomAuthState.full',
      note: 'Fully interactive and editable — the default.',
      scopeId: 'auth_full',
      stateName: 'full',
      field: (form) => form.full.widget,
    ),
    _stateCell(
      title: 'TomAuthState.read',
      note: 'Shows its value but cannot be edited.',
      scopeId: 'auth_read',
      stateName: 'read',
      field: (form) => form.read.widget,
    ),
    _stateCell(
      title: 'TomAuthState.disabled',
      note: 'Greyed out — present but not accessible here.',
      scopeId: 'auth_disabled',
      stateName: 'disabled',
      field: (form) => form.disabled.widget,
    ),
    _stateCell(
      title: 'TomAuthState.none',
      note:
          'Hidden entirely — the field collapses to nothing, so the labels '
          'above and below it close up.',
      scopeId: 'auth_none',
      stateName: 'none',
      field: (form) => _betweenLabels(form.none.widget),
    ),
  ],
);
