/// Widget families categorize Tom widgets by their behavioral role.
///
/// A widget reports its primary family through `TomFamilyBase.family`, which
/// each of the 20 branch bases (`TomButtonBase`, `TomInputBase`, …) fixes to
/// one of the Flutter-derived values below. `TomFamilyBase.families` allows a
/// widget to report more than one, but nothing overrides it today: every Tom
/// widget reports exactly the one family its branch base gives it.
///
/// The six form values are **reserved and unclaimed** — see the doc comment on
/// that group below.
enum TomWidgetFamily {
  // Families derived from Flutter widgets
  // Each of these is fixed by a branch base in `tom_family_base.dart` and
  // reported by concrete widgets in `widgets/`.
  button,
  input,
  select,
  toggle,
  slider,
  container,
  dialog,
  table,
  label,
  image,
  navigation,
  progress,
  chip,
  list,
  tree,
  sliver,
  animated,
  effect,
  interaction,
  builder,

  // Tom form families — RESERVED, and currently claimed by nothing.
  //
  // These six have no branch base in `tom_family_base.dart` and no widget
  // reports them: a grep for `TomWidgetFamily.formField` (and its five
  // siblings) across `lib/` returns no hits. The forms module does not
  // participate in this taxonomy at all — it does not import this enum. Its
  // fields descend from `TomField<T> extends TomObject<T>`, a kernel
  // observable rendered through `TomFieldWidgetAdapter`, not from
  // `TomFamilyBase`; so a form field carries no family rather than one of
  // these. (`TomTextFormFieldBase` is on that side too, despite the name.)
  //
  // They are kept because the ACL/layout design in
  // `doc/container_widget_resources_authorization.md` §12.2 specifies them as
  // the intended classification once form fields become family-reporting
  // widgets. Treat them as a declared intent, not as a description of what
  // exists. `test/widget_base/tom_widget_family_coverage_test.dart` pins the
  // 20-covered / 6-unclaimed split so this comment cannot quietly go stale.
  formField,
  dateTimePicker,
  listEditor,
  masterDetail,
  searchField,
  fileUpload,
}
