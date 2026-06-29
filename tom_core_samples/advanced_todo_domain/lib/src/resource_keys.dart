/// Stable resource keys for the gradable `TodoItem` fields.
///
/// The four-state field authorization model keys per-field `TomAuthState`
/// grades on these strings: the auth server's grant matrix stores
/// `(ProjectRole, resourceKey) → TomAuthState` rows, the app server projects the
/// resolved states to the client, and each form field is rendered through the
/// grade for its key. The set is **named and stable** so the same key means the
/// same field on the server, over the wire, and in the client — the same way
/// `core_server_sample` defines its keys.
///
/// ## The scope↔key convention (pinned here)
///
/// Every gradable key is exactly `<scope>.<formId>.<field>` = `todo.item.<field>`.
/// This is not incidental: the Tom Flutter UI form layer derives each field's
/// `basePath` as `<scopePath>.<formId>.<tomId>`, and uses that single path two
/// ways — as the **authorization** key (no suffix) consulted via
/// `TomAuthorization.resolveAuth(basePath)`, and as the base for the field's
/// **resource** keys (`<basePath>.label`, `<basePath>.hint`,
/// `<basePath>.<errorKey>`, …). So for a field to self-address as the key the
/// server graded, the form **must** run under [TodoItemResourceKeys.scope]
/// (`'todo'`) with `formId` = [TodoItemResourceKeys.formId] (`'item'`), and each
/// field's `tomId` must equal the matching last segment.
///
/// The keys below are therefore *derived* from `scope`/`formId`/the field
/// tokens rather than written as free strings, so a client cannot silently
/// drift from the convention. Use [TodoItemResourceKeys.keyFor] to build a key
/// at runtime, and the `*Field` token constants as the `tomId` each form field
/// must carry.
library;

/// Stable resource keys for the gradable [TodoItem] fields.
///
/// The key for the effort estimate is `todo.item.estimate` even though the
/// entity field is `estimateHours` — the resource key names the *concept*, not
/// the storage field. Accordingly the gradable estimate field's `tomId` must be
/// [estimateField] (`'estimate'`), while its reflected member stays
/// `estimateHours`.
class TodoItemResourceKeys {
  const TodoItemResourceKeys._();

  /// The scope segment of every gradable key. The item form must run under
  /// `TomScope.withScope(scope, …)` for field `basePath`s to equal these keys.
  static const String scope = 'todo';

  /// The form segment of every gradable key. The item form must be constructed
  /// with `formId` = this value.
  static const String formId = 'item';

  /// Builds the gradable resource/authorization base key for [field].
  ///
  /// `keyFor('title')` == [title] == `'todo.item.title'`. The result is the
  /// authorization key as-is, and the base for the field's resource keys
  /// (`'${keyFor(field)}.label'`, `'.hint'`, `'.<errorKey>'`, …).
  static String keyFor(String field) => '$scope.$formId.$field';

  /// Field token (the `tomId`) for the item title field.
  static const String titleField = 'title';

  /// Field token (the `tomId`) for the workflow status field.
  static const String statusField = 'status';

  /// Field token (the `tomId`) for the priority field.
  static const String priorityField = 'priority';

  /// Field token (the `tomId`) for the assignee field.
  static const String assigneeIdField = 'assigneeId';

  /// Field token (the `tomId`) for the due-date field.
  static const String dueDateField = 'dueDate';

  /// Field token (the `tomId`) for the effort-estimate field. Note this is
  /// `estimate`, **not** the entity member name `estimateHours` — the key names
  /// the concept, so the form field carries `tomId: estimateField`.
  static const String estimateField = 'estimate';

  /// Field token (the `tomId`) for the description field.
  static const String descriptionField = 'description';

  /// Resource key for the item title field.
  static const String title = '$scope.$formId.$titleField';

  /// Resource key for the workflow status field.
  static const String status = '$scope.$formId.$statusField';

  /// Resource key for the priority field.
  static const String priority = '$scope.$formId.$priorityField';

  /// Resource key for the assignee field.
  static const String assigneeId = '$scope.$formId.$assigneeIdField';

  /// Resource key for the due-date field.
  static const String dueDate = '$scope.$formId.$dueDateField';

  /// Resource key for the effort-estimate field (the `estimateHours` entity
  /// field).
  static const String estimate = '$scope.$formId.$estimateField';

  /// Resource key for the description field.
  static const String description = '$scope.$formId.$descriptionField';

  /// Every gradable key, in display order.
  static const List<String> all = [
    title,
    status,
    priority,
    assigneeId,
    dueDate,
    estimate,
    description,
  ];

  /// Every gradable field token (the `tomId`s the item form must carry), in the
  /// same display order as [all].
  static const List<String> allFields = [
    titleField,
    statusField,
    priorityField,
    assigneeIdField,
    dueDateField,
    estimateField,
    descriptionField,
  ];
}
