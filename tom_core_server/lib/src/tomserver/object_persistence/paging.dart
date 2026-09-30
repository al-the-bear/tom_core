import 'operators_expressions.dart';

/// The direction one sort term orders in.
enum TomSortDirection {
  /// Smallest value first (`ASC`).
  ascending,

  /// Largest value first (`DESC`).
  descending;

  /// The SQL keyword for this direction.
  String get sqlKeyword => this == TomSortDirection.ascending ? 'ASC' : 'DESC';
}

/// One term of a sort: a [field] and the [direction] it orders in.
///
/// A sort is an *ordered list* of these rather than a field list plus a single
/// direction, because `ORDER BY priority DESC, due_date ASC` — a perfectly
/// ordinary request — cannot be expressed by one flag shared across every
/// column.
///
/// [field] is a declared entity field name where the caller builds the sort, and
/// the rendered column expression by the time the SQL is generated; the query
/// resolves the one into the other with [withField] so an unknown name fails at
/// resolution instead of reaching the statement text.
class TomSortField {
  /// The field (or, once resolved, the column expression) to sort on.
  final String field;

  /// The direction [field] orders in.
  final TomSortDirection direction;

  /// Sorts on [field], ascending unless [direction] says otherwise.
  const TomSortField(this.field, {this.direction = TomSortDirection.ascending});

  /// Sorts on [field] ascending.
  const TomSortField.asc(this.field) : direction = TomSortDirection.ascending;

  /// Sorts on [field] descending.
  const TomSortField.desc(this.field) : direction = TomSortDirection.descending;

  /// Whether this term orders ascending.
  bool get isAscending => direction == TomSortDirection.ascending;

  /// This term with [field] replaced by [resolved], keeping the direction — how
  /// a declared field name becomes a qualified column expression.
  TomSortField withField(String resolved) =>
      TomSortField(resolved, direction: direction);

  /// This term ordering in [direction] instead.
  TomSortField withDirection(TomSortDirection direction) =>
      TomSortField(field, direction: direction);

  /// Maps [fields] onto sort terms all ordering in [direction] — the shape a
  /// caller that only ever wanted one direction still writes.
  static List<TomSortField> allOf(
    List<String> fields, {
    TomSortDirection direction = TomSortDirection.ascending,
  }) => [for (final field in fields) TomSortField(field, direction: direction)];

  @override
  String toString() => '$field ${direction.sqlKeyword}';

  @override
  bool operator ==(Object other) =>
      other is TomSortField &&
      other.field == field &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(field, direction);
}

/// A caller's request for one window of a result set: [offset] rows in, at most
/// [limit] rows wide, ordered by [sort].
///
/// This is the only paging vocabulary the repository speaks. It is passed to the
/// finders as an optional argument rather than duplicating them into a paged
/// family, so a caller that does not page writes exactly what it wrote before.
///
/// **The result is the page, not a page object.** A finder given a request
/// returns the rows of that window as a plain `List<T>`; the *total* comes from
/// the matching `count` method, which applies the same row scope. Two calls,
/// both scoped, and a caller that does not need the total does not pay for it.
///
/// **A window is ordered.** Rows come back in whatever order the database found
/// convenient unless something says otherwise, so "page 2" of an unordered query
/// is not the complement of "page 1" — it may repeat rows or skip them. The
/// repository therefore appends the entity's primary key as a final sort term
/// whenever a window is requested and the caller's [sort] does not already
/// settle it (see [needsStableSort]).
class TomPageRequest {
  /// Rows to skip before the first returned row.
  final int offset;

  /// The maximum number of rows to return; `0` means unbounded.
  final int limit;

  /// The ordering the window is cut from, outermost term first.
  final List<TomSortField> sort;

  /// Requests [limit] rows starting at [offset], ordered by [sort].
  ///
  /// Throws [TomQuerySyntaxException] for a negative bound, or for an [offset]
  /// without a [limit] — see [assertWindow].
  TomPageRequest({this.offset = 0, this.limit = 0, this.sort = const []}) {
    assertWindow(limit: limit, offset: offset);
  }

  /// Requests the zero-based page [pageNumber] of [pageSize] rows.
  TomPageRequest.page(
    int pageNumber,
    int pageSize, {
    List<TomSortField> sort = const [],
  }) : this(offset: pageNumber * pageSize, limit: pageSize, sort: sort);

  /// Requests only an ordering, over the whole result set.
  TomPageRequest.sorted(List<TomSortField> sort) : this(sort: sort);

  /// Whether this request shapes nothing at all — no window, no ordering.
  bool get isUnpaged => offset == 0 && limit <= 0 && sort.isEmpty;

  /// Whether this request cuts a window out of the result set, and so needs a
  /// total ordering to be reproducible across pages.
  bool get needsStableSort => offset > 0 || limit > 0;

  /// This request with a *total* ordering, made so by [key] — the entity's
  /// primary key, which no two rows share.
  ///
  /// A request that cuts a window gets [key] appended as its final sort term
  /// unless it already sorts on it. Without that, "page 2" is not the
  /// complement of "page 1": rows tied under the caller's ordering (or under no
  /// ordering at all) may appear on both pages or on neither, because nothing
  /// obliges the database to visit them in the same order twice. A request
  /// that cuts no window is returned unchanged, since the whole result set
  /// arrives either way.
  TomPageRequest stableUnder(String key) {
    if (!needsStableSort) return this;
    if (sort.any((term) => term.field == key)) return this;
    return withSort([...sort, TomSortField.asc(key)]);
  }

  /// This request with [sort] replaced.
  TomPageRequest withSort(List<TomSortField> sort) =>
      TomPageRequest(offset: offset, limit: limit, sort: sort);

  /// Rejects a row window that is not renderable.
  ///
  /// Two cases, both programming errors rather than user input:
  ///
  ///  * a negative bound has no meaning; and
  ///  * an [offset] without a [limit] is *unrepresentable* in MariaDB/MySQL —
  ///    the grammar is `LIMIT n [OFFSET m]`, so there is no bare `OFFSET`.
  ///    Rejecting it says so at the call site instead of emitting a statement
  ///    that silently ignores the skip.
  static void assertWindow({required int limit, required int offset}) {
    if (offset < 0) {
      throw TomQuerySyntaxException(
        'paging.window.negative_offset',
        'A page offset may not be negative, but was $offset.',
        parameters: {'offset': offset},
      );
    }
    if (limit < 0) {
      throw TomQuerySyntaxException(
        'paging.window.negative_limit',
        'A page limit may not be negative, but was $limit.',
        parameters: {'limit': limit},
      );
    }
    if (offset > 0 && limit <= 0) {
      throw TomQuerySyntaxException(
        'paging.window.offset_without_limit',
        'A page offset needs a row limit: SQL skips rows with '
            'LIMIT <n> OFFSET <m>, which has no form that skips without also '
            'capping. Give the request a limit, or drop the offset.',
        parameters: {'offset': offset},
      );
    }
  }

  @override
  String toString() =>
      'TomPageRequest(offset: $offset, limit: $limit, sort: $sort)';
}
