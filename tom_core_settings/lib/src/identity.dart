/// Who this user is when they write something another person will read.
library;

/// The display name and stable author id used to attribute authored content.
///
/// A *settings* identity, not an account: nothing authenticates it and nothing
/// checks it. It exists because authored content carries an author, and the
/// alternative to asking is stamping everything `unknown`.
class TomIdentity {
  /// The name of the settings group that holds it.
  static const groupName = 'identity';

  /// The author id used when the group states nothing.
  ///
  /// A sentinel rather than an empty string or a null, because it travels: it
  /// is written into shared content and merged between devices, and a field
  /// that is sometimes absent and sometimes `''` gives a merge two spellings of
  /// one fact to disagree about.
  static const unknownAuthorId = 'unknown';

  /// What the user is called — shown beside what they wrote.
  final String displayName;

  /// The stable key their authored content is attributed to.
  ///
  /// Separate from [displayName] because a rename must not orphan everything
  /// the user has already written.
  final String authorId;

  const TomIdentity({required this.displayName, required this.authorId});

  /// What a build with no settings attributes content to.
  static const unknown = TomIdentity(
    displayName: '',
    authorId: unknownAuthorId,
  );

  bool get isUnknown => this == unknown;

  /// The author id to record on content a user makes, or null when [authorId]
  /// is the [unknownAuthorId] sentinel — for optional author fields, where
  /// `unknown` would be a placeholder written into a shared file.
  static String? attributionOf(String authorId) =>
      authorId == unknownAuthorId ? null : authorId;

  TomIdentity copyWith({String? displayName, String? authorId}) => TomIdentity(
    displayName: displayName ?? this.displayName,
    authorId: authorId ?? this.authorId,
  );

  @override
  bool operator ==(Object other) =>
      other is TomIdentity &&
      other.displayName == displayName &&
      other.authorId == authorId;

  @override
  int get hashCode => Object.hash(displayName, authorId);

  @override
  String toString() =>
      'TomIdentity($authorId'
      '${displayName.isEmpty ? '' : ' "$displayName"'})';
}
