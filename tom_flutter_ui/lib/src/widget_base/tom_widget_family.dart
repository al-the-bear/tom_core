/// Widget families categorize Tom widgets by their behavioral role.
///
/// Every Tom widget declares its primary family and optionally additional
/// families (e.g., a date picker is both [formField] and [dateTimePicker]).
enum TomWidgetFamily {
  // Families derived from Flutter widgets
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

  // Tom Form Component families (custom, richer than Flutter equivalents)
  formField,
  dateTimePicker,
  listEditor,
  masterDetail,
  searchField,
  fileUpload,
}
