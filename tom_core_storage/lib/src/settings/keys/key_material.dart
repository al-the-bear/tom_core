/// What a key for an encrypted container is made of.
library;

import 'dart:typed_data';

/// The key material for one encrypted container: a passphrase, a key file, or
/// both.
///
/// The three fields sit at two levels:
///
/// - [passphrase] and [keyFileBytes] are the *material*. They open a file.
/// - [keyFileLocator] is a *pointer* to material. It is what settings store,
///   because a path is not the secret — the bytes are, and the bytes are never
///   stored.
///
/// So material read back from settings routinely names a key file it has not
/// read. That is [isResolvable] being false while [isEmpty] is also false, and
/// keeping the two apart lets a caller *skip* such an entry at start-up instead
/// of throwing on it.
class TomKeyMaterial {
  final String? passphrase;

  /// The key file's contents — present only once something has read them.
  final Uint8List? keyFileBytes;

  /// Where the key file lives (a storage locator), when it is known.
  final String? keyFileLocator;

  const TomKeyMaterial({
    this.passphrase,
    this.keyFileBytes,
    this.keyFileLocator,
  });

  /// Whether this states nothing at all — the "no key saved" case.
  bool get isEmpty =>
      (passphrase == null || passphrase!.isEmpty) &&
      (keyFileBytes == null || keyFileBytes!.isEmpty) &&
      (keyFileLocator == null || keyFileLocator!.isEmpty);

  /// Whether enough *material* (not merely a pointer to it) is present to open
  /// a file.
  bool get isResolvable =>
      (passphrase != null && passphrase!.isNotEmpty) ||
      (keyFileBytes != null && keyFileBytes!.isNotEmpty);

  TomKeyMaterial copyWith({
    String? passphrase,
    Uint8List? keyFileBytes,
    String? keyFileLocator,
  }) => TomKeyMaterial(
    passphrase: passphrase ?? this.passphrase,
    keyFileBytes: keyFileBytes ?? this.keyFileBytes,
    keyFileLocator: keyFileLocator ?? this.keyFileLocator,
  );

  /// Refuses material that cannot open anything, in the words a caller shows.
  ///
  /// Throws [StateError] when the material is not [isResolvable] — including
  /// a key file that is named but unread. Every registry calls this before
  /// accepting material, so every binding refuses the same input with the same
  /// sentence.
  void requireResolvable() {
    if (isResolvable) return;
    throw StateError(
      isEmpty
          ? 'A key needs a passphrase and/or a key file.'
          : 'The key file "$keyFileLocator" has not been read, so this '
                'material cannot open anything yet.',
    );
  }
}
