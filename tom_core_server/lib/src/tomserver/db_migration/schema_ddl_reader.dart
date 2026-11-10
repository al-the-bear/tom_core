import '../datasources/sql_dialects.dart';
import 'schema_model.dart';
import '../datasources/sql_lexer.dart';

/// One migration artifact as the reader consumes it: the basename the chain
/// orders it by, and the SQL it contains.
///
/// Deliberately not a `File` — the reader replays a chain that has been *read*,
/// so it works the same over a directory, over strings in a test, and over a
/// generator's in-memory output.
class TomMigrationArtifact {
  /// The artifact basename (`[004]-auth_two_factor_columns`), used as the
  /// locality every schema element is attributed to.
  final String basename;

  /// The artifact's SQL body.
  final String sql;

  /// Pairs a [basename] with its [sql].
  const TomMigrationArtifact(this.basename, this.sql);

  @override
  String toString() => basename;
}

/// Something in the chain that could not be replayed — a statement that
/// contradicts the schema built so far, or one the reader cannot parse.
///
/// A chain problem is *reported*, never thrown: the point of the convergence
/// check is to hand back a complete picture of what is wrong, and a throw would
/// stop at the first artifact and hide everything after it.
class TomDdlReplayError {
  /// The artifact whose statement failed.
  final String artifact;

  /// What went wrong, phrased for the person who has to fix the artifact.
  final String message;

  /// The offending statement, truncated for reporting.
  final String statement;

  /// Records a replay failure.
  const TomDdlReplayError({
    required this.artifact,
    required this.message,
    required this.statement,
  });

  @override
  String toString() => '$artifact: $message — $statement';
}

/// The outcome of replaying a migration chain.
class TomDdlReplayResult {
  /// The schema the chain cumulatively produces.
  final TomSchemaModel schema;

  /// Statements that could not be replayed, in chain order.
  final List<TomDdlReplayError> errors;

  /// Pairs the produced [schema] with any replay [errors].
  const TomDdlReplayResult(this.schema, this.errors);
}

/// Builds the schema a migration chain cumulatively produces, without touching
/// a database.
///
/// This is the *actual* side of the CE-DB ↔ CE-MG convergence check: it applies
/// each artifact's DDL to an in-memory [TomSchemaBuilder] in the order the
/// migration engine would, so the result is the shape a fresh database would
/// have after `TomDbMigrations.migrateAll`. It reads the same artifacts
/// the engine reads and changes nothing about how the engine behaves.
///
/// **What it understands.** `CREATE TABLE <name> (<column list>)` — the one
/// `CREATE TABLE` form that spells its columns out, which is the whole of what
/// the reader is for — plus `DROP TABLE`, `ALTER TABLE`
/// (`ADD`/`DROP`/`MODIFY`/`CHANGE`/`RENAME` of columns, `ADD PRIMARY KEY`,
/// `RENAME TO`), and the `IF [NOT] EXISTS` guards that make an artifact
/// idempotent. Statements that do not shape the schema — `INSERT`, `UPDATE`,
/// `DELETE`, `SET`, `CREATE INDEX`, `DROP INDEX`, `CREATE VIEW` — are
/// recognised and skipped rather than reported, because seed data and secondary
/// indexes are legitimate migration content that the check has no opinion on.
///
/// **What the guards mean.** A statement that would fail against a live server
/// is a chain defect and is reported; the `IF [NOT] EXISTS` guard is what says
/// the author meant it conditionally. So an unguarded `CREATE TABLE` of a table
/// the chain already has, an unguarded `ALTER TABLE` on a table it does not, and
/// an unguarded `DROP TABLE` of a table it does not are each reported, while
/// their `IF NOT EXISTS` / `IF EXISTS` forms are silent no-ops. One rule,
/// applied the same way in every direction — a `DROP` that stayed quiet would
/// let a mistyped table name replay clean here and then reappear far downstream
/// as a table the entity model has no entity for.
///
/// **What it does not.** Stored routines and anything using a `DELIMITER`
/// override; the `CREATE TABLE` forms that derive their columns from somewhere
/// else — `AS SELECT …`, `AS (SELECT …)`, `LIKE other` — since the reader has
/// no way to know what those columns are; and vendor extensions beyond the
/// above. Those surface as [TomDdlReplayError]s rather than being silently
/// mis-parsed — an unreadable chain must be visible, since the check's whole
/// value is that it noticed.
///
/// **Rejection is atomic, at the level of the statement form.** A `CREATE
/// TABLE` whose header carries anything at all between the table name and the
/// column list is rejected before the builder is touched, so an unmodelled form
/// leaves no trace in the schema. That distinction matters downstream: a table
/// committed with a fabricated column list, or with none, turns every column
/// its entity declares into a `missingColumn` divergence — a second wave of
/// findings caused by the parse failure rather than by any real disagreement.
/// *Within* a genuine column list the opposite applies deliberately: an entry
/// the reader cannot read is reported on its own and the rest of the table
/// survives, because discarding the table there would manufacture exactly the
/// same derived noise.
class TomSchemaDdlReader {
  /// The dialect that classifies column types (see
  /// [TomStandardSqlDialect.typeFamily]).
  final TomStandardSqlDialect dialect;

  /// Reads DDL through [dialect].
  TomSchemaDdlReader(this.dialect);

  /// Statement leaders that change data or declare objects the schema model
  /// does not carry. Recognised so they are skipped in silence.
  static const Set<String> _ignoredLeaders = {
    'INSERT',
    'REPLACE',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'SET',
    'START',
    'COMMIT',
    'ROLLBACK',
    'USE',
    'LOCK',
    'UNLOCK',
    'ANALYZE',
    'OPTIMIZE',
    'FLUSH',
    'GRANT',
    'REVOKE',
  };

  /// Body entries of a `CREATE TABLE` that declare a constraint rather than a
  /// column.
  static const Set<String> _constraintLeaders = {
    'PRIMARY',
    'UNIQUE',
    'KEY',
    'INDEX',
    'FULLTEXT',
    'SPATIAL',
    'CONSTRAINT',
    'FOREIGN',
    'CHECK',
    'PERIOD',
  };

  /// Column-definition words that end the type and begin the modifiers.
  static const Set<String> _columnModifierLeaders = {
    'NOT',
    'NULL',
    'DEFAULT',
    'AUTO_INCREMENT',
    'PRIMARY',
    'UNIQUE',
    'KEY',
    'COMMENT',
    'COLLATE',
    'CHARACTER',
    'CHARSET',
    'GENERATED',
    'AS',
    'STORED',
    'VIRTUAL',
    'INVISIBLE',
    'CHECK',
    'REFERENCES',
    'ON',
    'FIRST',
    'AFTER',
    'WITH',
    'WITHOUT',
    'COMPRESSED',
  };

  /// Replays [chain] in the given order and returns the resulting schema.
  ///
  /// The caller supplies the order — the migration engine's ascending numeric
  /// version, already filtered to the artifacts that apply in the active
  /// environment. Replaying an unfiltered chain would model a schema no
  /// deployment actually has.
  TomDdlReplayResult replay(List<TomMigrationArtifact> chain) {
    final builder = TomSchemaBuilder();
    final errors = <TomDdlReplayError>[];
    for (final artifact in chain) {
      for (final statement in splitStatements(artifact.sql)) {
        _apply(builder, statement, artifact.basename, errors);
      }
    }
    return TomDdlReplayResult(builder.build(), errors);
  }

  // --- Statement dispatch ---------------------------------------------------

  void _apply(
    TomSchemaBuilder builder,
    String statement,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    final words = _words(statement);
    if (words.isEmpty) return;
    final leader = words[0].toUpperCase();
    if (_ignoredLeaders.contains(leader)) return;

    final second = words.length > 1 ? words[1].toUpperCase() : '';
    if (leader == 'CREATE' && _objectWord(words) == 'TABLE') {
      _createTable(builder, statement, artifact, errors);
      return;
    }
    if (leader == 'DROP' && second == 'TABLE') {
      _dropTable(builder, statement, artifact, errors);
      return;
    }
    if (leader == 'ALTER' && second == 'TABLE') {
      _alterTable(builder, statement, artifact, errors);
      return;
    }
    // Indexes and views shape neither the columns nor the primary key the check
    // compares, so recognising them is enough.
    if ((leader == 'CREATE' || leader == 'DROP') &&
        const {
          'INDEX',
          'VIEW',
          'DATABASE',
          'SCHEMA',
          'TRIGGER',
        }.contains(_objectWord(words))) {
      return;
    }
    errors.add(
      TomDdlReplayError(
        artifact: artifact,
        message: 'Unsupported statement — the schema model may be incomplete',
        statement: _excerpt(statement),
      ),
    );
  }

  /// The object keyword of a `CREATE`/`DROP`, skipping qualifiers such as
  /// `UNIQUE`, `OR REPLACE` and `TEMPORARY`.
  String _objectWord(List<String> words) {
    for (final word in words.skip(1)) {
      final upper = word.toUpperCase();
      if (const {
        'OR',
        'REPLACE',
        'TEMPORARY',
        'TEMP',
        'UNIQUE',
        'FULLTEXT',
        'SPATIAL',
        'IF',
        'NOT',
        'EXISTS',
      }.contains(upper)) {
        continue;
      }
      return upper;
    }
    return '';
  }

  // --- CREATE TABLE ---------------------------------------------------------

  void _createTable(
    TomSchemaBuilder builder,
    String statement,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    final open = _firstBracket(statement);
    // The header is everything before the column list — or the whole statement
    // when there is no list, so that a `CREATE TABLE … AS SELECT` is recognised
    // by its form rather than reported as a statement missing a parenthesis.
    final header = open < 0 ? statement : statement.substring(0, open);
    final guarded = _hasIfNotExists(header);
    final name = _tableNameFrom(header);
    if (name == null) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'CREATE TABLE without a table name',
          statement: _excerpt(statement),
        ),
      );
      return;
    }
    // In every form the reader can model, the column list follows the table
    // name immediately, so anything else in the header is a form whose shape
    // the reader cannot derive: `AS SELECT`, `AS (SELECT …)`, `LIKE`, or a
    // vendor extension. Rejecting on the *form*, before touching the builder,
    // is what keeps the failure atomic — reading on found the SELECT's own
    // parenthesis and committed a table with a fabricated column list, or with
    // none at all, and every column the entity model declared on that table
    // then surfaced as a `missingColumn` divergence caused by the parse failure
    // rather than by any real disagreement.
    final trailing = _headerWordsAfterName(header);
    if (trailing.isNotEmpty) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message:
              'Unsupported CREATE TABLE form — only '
              'CREATE TABLE <name> (<column list>) is modelled',
          statement: _excerpt(statement),
        ),
      );
      return;
    }
    if (open < 0) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'CREATE TABLE without a column list',
          statement: _excerpt(statement),
        ),
      );
      return;
    }
    if (builder.hasTable(name)) {
      // `IF NOT EXISTS` makes a re-creation a deliberate no-op — that is how a
      // baseline artifact stays replayable over an existing database. Without
      // the guard the chain really would fail against a live server, so it is a
      // chain defect the check should surface.
      if (!guarded) {
        errors.add(
          TomDdlReplayError(
            artifact: artifact,
            message: 'Table "$name" already exists in the chain',
            statement: _excerpt(statement),
          ),
        );
      }
      return;
    }

    final close = _matchingParenthesis(statement, open);
    if (close < 0) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'CREATE TABLE with an unbalanced column list',
          statement: _excerpt(statement),
        ),
      );
      return;
    }

    builder.addTable(name, artifact);
    final primaryKey = <String>[];
    for (final entry in splitTopLevel(statement.substring(open + 1, close))) {
      final words = _words(entry);
      if (words.isEmpty) continue;
      if (_constraintLeaders.contains(words[0].toUpperCase())) {
        primaryKey.addAll(_primaryKeyColumns(entry));
        continue;
      }
      final column = _parseColumnDefinition(entry, artifact);
      if (column == null) {
        errors.add(
          TomDdlReplayError(
            artifact: artifact,
            message: 'Unreadable column definition in table "$name"',
            statement: _excerpt(entry),
          ),
        );
        continue;
      }
      builder.addColumn(name, column.column);
      if (column.isPrimaryKey) primaryKey.add(column.column.name);
    }
    if (primaryKey.isNotEmpty) builder.setPrimaryKey(name, primaryKey);
  }

  void _dropTable(
    TomSchemaBuilder builder,
    String statement,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    // `IF EXISTS` marks a drop as deliberately conditional — that is how a
    // cleanup artifact stays replayable over a database that may or may not
    // still carry the table. Without the guard the statement really would fail
    // against a live server when the table is absent, so it is a chain defect,
    // and the reader owes it the same report `ALTER TABLE` on an unknown table
    // gets. Staying silent here made a typo'd table name look like a clean
    // chain and then surface downstream as an entity table nothing creates.
    final guarded = _hasIfExists(statement);
    for (final name in _tableNamesFrom(statement)) {
      if (builder.hasTable(name)) {
        builder.dropTable(name);
        continue;
      }
      if (!guarded) {
        errors.add(
          TomDdlReplayError(
            artifact: artifact,
            message:
                'DROP TABLE on "$name", which the chain does not have at this '
                'point',
            statement: _excerpt(statement),
          ),
        );
      }
    }
  }

  // --- ALTER TABLE ----------------------------------------------------------

  void _alterTable(
    TomSchemaBuilder builder,
    String statement,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    // `ALTER TABLE <name> <action>[, <action>…]` — the table name ends where the
    // first action word begins, which is the third word of the statement.
    final words = _words(statement);
    if (words.length < 3) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'ALTER TABLE without an action',
          statement: _excerpt(statement),
        ),
      );
      return;
    }
    final table = _unquote(words[2]);
    if (!builder.hasTable(table)) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'ALTER TABLE on "$table", which no earlier artifact creates',
          statement: _excerpt(statement),
        ),
      );
      return;
    }
    // The actions are everything past the name, taken from the token list.
    // Locating them by searching the text for the name finds its *first*
    // occurrence instead, which is inside the leading keywords whenever the name
    // is a substring of them — `ABLE` within `TABLE`, or `ab` within `table` in
    // ordinary lowercase DDL. The result was not a parse error but a false
    // divergence: an unsupported action named after a fragment of a keyword,
    // and a column silently never added.
    for (final action in splitTopLevel(words.sublist(3).join(' '))) {
      _applyAlterAction(builder, table, action, artifact, errors);
    }
  }

  void _applyAlterAction(
    TomSchemaBuilder builder,
    String table,
    String action,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    final words = _words(action);
    if (words.isEmpty) return;
    final verb = words[0].toUpperCase();
    switch (verb) {
      case 'ADD':
        _alterAdd(builder, table, action, words, artifact, errors);
      case 'DROP':
        _alterDrop(builder, table, words);
      case 'MODIFY':
      case 'CHANGE':
        _alterRedefine(builder, table, action, words, verb, artifact, errors);
      case 'RENAME':
        _alterRename(builder, table, words, artifact);
      // Storage, charset and constraint-state changes do not move a column or a
      // key, so they cannot affect the comparison.
      case 'ENGINE':
      case 'CONVERT':
      case 'DEFAULT':
      case 'ALTER':
      case 'ENABLE':
      case 'DISABLE':
      case 'COMMENT':
      case 'AUTO_INCREMENT':
        return;
      default:
        errors.add(
          TomDdlReplayError(
            artifact: artifact,
            message: 'Unsupported ALTER TABLE action on "$table"',
            statement: _excerpt(action),
          ),
        );
    }
  }

  void _alterAdd(
    TomSchemaBuilder builder,
    String table,
    String action,
    List<String> words,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    final subject = _skipWords(words, 1, const {
      'COLUMN',
      'IF',
      'NOT',
      'EXISTS',
    });
    if (subject.isEmpty) return;
    final leader = subject[0].toUpperCase();
    if (_constraintLeaders.contains(leader)) {
      final primaryKey = _primaryKeyColumns(action);
      if (primaryKey.isNotEmpty) builder.setPrimaryKey(table, primaryKey);
      return;
    }
    final column = _parseColumnDefinition(subject.join(' '), artifact);
    if (column == null) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'Unreadable ADD COLUMN on "$table"',
          statement: _excerpt(action),
        ),
      );
      return;
    }
    if (builder.hasColumn(table, column.column.name)) {
      // `ADD COLUMN IF NOT EXISTS` is how an artifact catches up a database
      // created before the column existed, while staying a no-op on a fresh one
      // whose baseline already has it — so a collision under the guard is
      // exactly the intended behaviour, not a defect.
      if (!_hasIfNotExists(action)) {
        errors.add(
          TomDdlReplayError(
            artifact: artifact,
            message:
                'Column "${column.column.name}" already exists on "$table"',
            statement: _excerpt(action),
          ),
        );
      }
      return;
    }
    builder.addColumn(table, column.column);
    if (column.isPrimaryKey) {
      builder.setPrimaryKey(table, [column.column.name]);
    }
  }

  void _alterDrop(TomSchemaBuilder builder, String table, List<String> words) {
    final subject = _skipWords(words, 1, const {'COLUMN', 'IF', 'EXISTS'});
    if (subject.isEmpty) return;
    final leader = subject[0].toUpperCase();
    if (leader == 'PRIMARY') {
      builder.setPrimaryKey(table, const []);
      return;
    }
    // Dropping a key, index or foreign key leaves the columns in place.
    if (_constraintLeaders.contains(leader)) return;
    builder.dropColumn(table, _unquote(subject[0]));
  }

  void _alterRedefine(
    TomSchemaBuilder builder,
    String table,
    String action,
    List<String> words,
    String verb,
    String artifact,
    List<TomDdlReplayError> errors,
  ) {
    // MODIFY redefines a column in place; CHANGE renames it at the same time,
    // so its definition starts one word later (`CHANGE <old> <new> <type>`).
    final subject = _skipWords(words, 1, const {'COLUMN', 'IF', 'EXISTS'});
    if (subject.isEmpty) return;
    final oldName = _unquote(subject[0]);
    final definitionStart = verb == 'CHANGE' ? 1 : 0;
    if (subject.length <= definitionStart) return;
    final column = _parseColumnDefinition(
      subject.sublist(definitionStart).join(' '),
      artifact,
    );
    if (column == null) {
      errors.add(
        TomDdlReplayError(
          artifact: artifact,
          message: 'Unreadable $verb COLUMN on "$table"',
          statement: _excerpt(action),
        ),
      );
      return;
    }
    if (verb == 'CHANGE') builder.dropColumn(table, oldName);
    builder.addColumn(table, column.column);
  }

  void _alterRename(
    TomSchemaBuilder builder,
    String table,
    List<String> words,
    String artifact,
  ) {
    final subject = _skipWords(words, 1, const {'TO', 'AS'});
    if (subject.isEmpty) return;
    if (subject[0].toUpperCase() == 'COLUMN') {
      // `RENAME COLUMN <old> TO <new>` — and MariaDB's `TO`-less spelling, so
      // the separator is skipped between the names rather than assumed.
      final parts = _skipWords(subject, 1, const {'TO', 'AS'});
      if (parts.isEmpty) return;
      final renamed = _skipWords(parts, 1, const {'TO', 'AS'});
      if (renamed.isEmpty) return;
      builder.renameColumn(
        table,
        _unquote(parts[0]),
        _unquote(renamed[0]),
        artifact,
      );
      return;
    }
    builder.renameTable(table, _unquote(subject[0]));
  }

  // --- Column definitions ---------------------------------------------------

  ({TomSchemaColumn column, bool isPrimaryKey})? _parseColumnDefinition(
    String definition,
    String artifact,
  ) {
    final words = _words(definition);
    if (words.length < 2) return null;
    final name = _unquote(words[0]);
    if (name.isEmpty) return null;

    // The type runs from the second word up to the first modifier keyword, so
    // that multi-word types (`DOUBLE PRECISION`, `CHARACTER VARYING`) and
    // parenthesised ones (`DECIMAL(10,2)`, `ENUM('a','b')`) both survive.
    final typeWords = <String>[];
    var index = 1;
    while (index < words.length) {
      final upper = words[index].toUpperCase();
      if (typeWords.isNotEmpty && _columnModifierLeaders.contains(upper)) break;
      typeWords.add(words[index]);
      index++;
    }
    if (typeWords.isEmpty) return null;

    final modifiers = words
        .sublist(index)
        .map((w) => w.toUpperCase())
        .toList(growable: false);
    return (
      column: TomSchemaColumn(
        name: name,
        family: dialect.typeFamily(typeWords.join(' ')),
        declaredType: typeWords.join(' '),
        origin: artifact,
        nullable: !_containsSequence(modifiers, const ['NOT', 'NULL']),
      ),
      isPrimaryKey: _containsSequence(modifiers, const ['PRIMARY', 'KEY']),
    );
  }

  /// The column names of a `PRIMARY KEY (…)` clause, or empty when [entry] is
  /// any other constraint.
  List<String> _primaryKeyColumns(String entry) {
    final words = _words(entry);
    // `CONSTRAINT <name> PRIMARY KEY (…)` puts two words in front of the
    // keyword, so look for the pair rather than only at the head.
    var index = 0;
    while (index + 1 < words.length) {
      // Compared by keyword head, because the tokenizer keeps a parenthesised
      // group attached to the word before it: in `PRIMARY KEY(a, b)` — no space,
      // which MariaDB accepts — the second word is the whole `KEY(a, b)`. Read
      // whole it matches nothing, and the clause was silently skipped, leaving
      // the table with no primary key and the comparison with a divergence the
      // chain does not actually have.
      if (_keywordHead(words[index]) == 'PRIMARY' &&
          _keywordHead(words[index + 1]) == 'KEY') {
        // From `KEY` inclusive, because the group may be part of that very
        // token: `KEY(a, b)` is one word. Starting after it would find no list.
        // Skipping what precedes is not this slice's job — [_firstBracket]
        // already ignores brackets inside quoted names.
        final tail = words.sublist(index + 1).join(' ');
        final open = _firstBracket(tail);
        if (open < 0) return const [];
        final close = _matchingParenthesis(tail, open);
        if (close < 0) return const [];
        return [
          for (final part in splitTopLevel(tail.substring(open + 1, close)))
            _unquote(_words(part).isEmpty ? '' : _words(part).first),
        ]..removeWhere((name) => name.isEmpty);
      }
      index++;
    }
    return const [];
  }

  // --- Lexing ---------------------------------------------------------------

  /// Splits [sql] into statements, stripping comments.
  ///
  /// The reader parses structure out of DDL, so a comment is noise to it and is
  /// removed first. That is this method's whole contribution: the split itself
  /// is [TomSqlLexer.splitStatements], which keeps comments because a consumer
  /// that *sends* the statements must not lose an executable `/*! … */` one.
  ///
  /// Public because the split is the same one a caller needs to count or
  /// pre-filter statements, and re-implementing quote handling is exactly the
  /// kind of duplication that goes subtly wrong.
  static List<String> splitStatements(String sql) =>
      TomSqlLexer.splitStatements(stripComments(sql));

  /// Removes `--`, `#` and `/* … */` comments, leaving quoted text alone.
  ///
  /// A line comment collapses to its newline and a block comment to a single
  /// space, so removal cannot weld two tokens together.
  ///
  /// Note this removes MariaDB executable comments (`/*!40101 … */`) along with
  /// the rest. That is right for a *parser* — the reader compares declared
  /// structure — but wrong for anything that sends the SQL onward, which is why
  /// [TomSqlLexer.splitStatements] does not strip and this is a separate step.
  static String stripComments(String sql) {
    final out = StringBuffer();
    for (var i = 0; i < sql.length; i++) {
      final c = sql[i];
      if (TomSqlLexer.quoteCharacters.contains(c)) {
        final end = TomSqlLexer.endOfQuotedRun(sql, i);
        out.write(sql.substring(i, end + 1));
        i = end;
        continue;
      }
      if (TomSqlLexer.commentOpensAt(sql, i)) {
        // A line comment ends before its newline, a block comment at its `*/`;
        // either way leave whitespace behind so neighbouring tokens stay apart.
        out.write(sql[i] == '/' ? ' ' : '\n');
        i = TomSqlLexer.endOfComment(sql, i);
        continue;
      }
      out.write(c);
    }
    return out.toString();
  }

  /// Splits [text] on commas that are not inside parentheses or quotes.
  ///
  /// The one primitive a `CREATE TABLE` body, an `ALTER TABLE` action list and
  /// a key's column list all need — `DECIMAL(10, 2)` must stay one entry.
  static List<String> splitTopLevel(String text) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (TomSqlLexer.quoteCharacters.contains(c)) {
        final end = TomSqlLexer.endOfQuotedRun(text, i);
        buffer.write(text.substring(i, end + 1));
        i = end;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ',' && depth == 0) {
        final part = buffer.toString().trim();
        if (part.isNotEmpty) parts.add(part);
        buffer.clear();
        continue;
      }
      buffer.write(c);
    }
    final last = buffer.toString().trim();
    if (last.isNotEmpty) parts.add(last);
    return parts;
  }

  /// Splits [text] into words, keeping a parenthesised group attached to the
  /// word before it (`DECIMAL(10, 2)`, `ENUM('a', 'b')` stay single words).
  ///
  /// Because a group survives whole, re-joining a slice of the result
  /// reproduces that fragment of the statement — which is how a column
  /// definition is lifted out of the `ALTER` action it lives in, without
  /// searching the statement text for a name that may well occur twice.
  static List<String> _words(String text) {
    final words = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (TomSqlLexer.quoteCharacters.contains(c)) {
        final end = TomSqlLexer.endOfQuotedRun(text, i);
        buffer.write(text.substring(i, end + 1));
        i = end;
        continue;
      }
      if (c == '(') {
        depth++;
        buffer.write(c);
        continue;
      }
      if (c == ')') {
        depth--;
        buffer.write(c);
        continue;
      }
      if (depth == 0 && (c == ' ' || c == '\t' || c == '\n' || c == '\r')) {
        if (buffer.isNotEmpty) {
          words.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(c);
    }
    if (buffer.isNotEmpty) words.add(buffer.toString());
    return words;
  }

  static bool _hasIfNotExists(String text) =>
      RegExp(r'\bIF\s+NOT\s+EXISTS\b', caseSensitive: false).hasMatch(text);

  /// Whether [text] carries the `IF EXISTS` guard of a conditional `DROP`.
  ///
  /// Disjoint from [_hasIfNotExists] without needing to say so: `NOT` sits
  /// between the two words in `IF NOT EXISTS`, so `IF\s+EXISTS` cannot match it.
  static bool _hasIfExists(String text) =>
      RegExp(r'\bIF\s+EXISTS\b', caseSensitive: false).hasMatch(text);

  /// The table name in a `CREATE TABLE …` header, or `null` if it carries none.
  static String? _tableNameFrom(String header) {
    final names = _tableNamesFrom(header);
    return names.isEmpty ? null : names.first;
  }

  /// Every table named in a `CREATE TABLE …` / `DROP TABLE …` header.
  ///
  /// `DROP TABLE` takes a *list* — `DROP TABLE a, b`. Reading only the first
  /// name would leave the rest standing in the model, and they would then be
  /// reported downstream as tables the entity model has no entity for: a
  /// finding about a table the chain does in fact drop.
  ///
  /// Trailing `CASCADE` / `RESTRICT` are dropped by taking the first word of
  /// each comma-separated entry, which is also what makes this safe to share
  /// with `CREATE TABLE` — whose header, cut before the column list, is simply
  /// a one-entry list.
  static List<String> _tableNamesFrom(String header) {
    final words = _words(header);
    for (var i = 0; i < words.length; i++) {
      if (words[i].toUpperCase() != 'TABLE') continue;
      final rest = _skipWords(words, i + 1, const {'IF', 'NOT', 'EXISTS'});
      if (rest.isEmpty) return const [];
      final names = <String>[];
      for (final entry in splitTopLevel(rest.join(' '))) {
        final entryWords = _words(entry);
        if (entryWords.isEmpty) continue;
        final name = _unquote(entryWords.first);
        if (name.isNotEmpty) names.add(name);
      }
      return names;
    }
    return const [];
  }

  /// Whatever a `CREATE TABLE` header carries *after* the table name.
  ///
  /// Empty for every form the reader models, because the column list follows
  /// the name immediately. A non-empty result is therefore the signature of a
  /// form it does not: `AS SELECT …`, `AS (SELECT …)`, `LIKE other`, or a
  /// vendor extension nobody has taught it yet. Naming the shape by what is
  /// *absent* rather than listing the keywords to reject is what makes the next
  /// unknown form fail loudly instead of being half-read.
  static List<String> _headerWordsAfterName(String header) {
    final words = _words(header);
    for (var i = 0; i < words.length; i++) {
      if (words[i].toUpperCase() != 'TABLE') continue;
      final rest = _skipWords(words, i + 1, const {'IF', 'NOT', 'EXISTS'});
      return rest.length <= 1 ? const [] : rest.sublist(1);
    }
    return const [];
  }

  /// The index of the first `(` in [text] that opens a group, or `-1`.
  ///
  /// Brackets inside a quoted identifier are characters of a name, not
  /// structure: `CREATE TABLE \`w(1)\` (id BIGINT)` opens its column list at the
  /// *second* `(`. A plain `indexOf` took the first, splitting the statement
  /// inside the name — which registered the table as `w` and then read `1` as
  /// its column list.
  static int _firstBracket(String text) {
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (TomSqlLexer.quoteCharacters.contains(c)) {
        i = TomSqlLexer.endOfQuotedRun(text, i);
        continue;
      }
      if (c == '(') return i;
    }
    return -1;
  }

  /// The uppercased keyword at the head of [word], without any parenthesised
  /// group [_words] left attached to it.
  ///
  /// `KEY(a, b)` and `KEY` are the same keyword written with and without a
  /// space; only this makes them compare equal.
  static String _keywordHead(String word) {
    final open = word.indexOf('(');
    return (open < 0 ? word : word.substring(0, open)).toUpperCase();
  }

  /// [words] from [from] onwards with any leading member of [skippable] removed.
  static List<String> _skipWords(
    List<String> words,
    int from,
    Set<String> skippable,
  ) {
    var index = from;
    while (index < words.length &&
        skippable.contains(words[index].toUpperCase())) {
      index++;
    }
    return index >= words.length ? const [] : words.sublist(index);
  }

  /// The index of the `)` matching the `(` at [open], or `-1`.
  static int _matchingParenthesis(String text, int open) {
    var depth = 0;
    String? quote;
    for (var i = open; i < text.length; i++) {
      final c = text[i];
      if (quote != null) {
        if (c == r'\') {
          i++;
        } else if (c == quote) {
          quote = null;
        }
        continue;
      }
      if (c == "'" || c == '"' || c == '`') {
        quote = c;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static bool _containsSequence(List<String> words, List<String> sequence) {
    for (var i = 0; i + sequence.length <= words.length; i++) {
      var matched = true;
      for (var j = 0; j < sequence.length; j++) {
        if (words[i + j] != sequence[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return true;
    }
    return false;
  }

  static String _unquote(String word) =>
      word.replaceAll('`', '').replaceAll('"', '').trim();

  static String _excerpt(String statement) {
    final flat = statement.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 120 ? flat : '${flat.substring(0, 117)}...';
  }
}
