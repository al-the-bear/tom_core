/// A storage location the user has told the application about.
library;

/// A named storage location (a repository, a folder) the user has registered.
///
/// The `locations` group is a **convenience registry, not an access-control
/// list**. Nothing consults it before opening a locator — a document opened by
/// path works whether or not its location is listed. It lets an application
/// offer somewhere to save without the user retyping an address, which is why
/// it holds no credential: the credential for a location is a token, keyed by
/// host, and a second copy here would be a secret with two homes.
class TomStorageLocation {
  /// The name of the settings group that holds the registered locations.
  static const groupName = 'locations';

  /// What the location is called in the UI.
  final String displayName;

  /// The locator prefix the location resolves to.
  ///
  /// **This is the identity.** Two locations may carry the same display name —
  /// a `notes` repository and a `notes` folder are not a mistake — so the label
  /// is a label and never a key.
  final String locator;

  const TomStorageLocation({required this.displayName, required this.locator});

  TomStorageLocation copyWith({String? displayName, String? locator}) =>
      TomStorageLocation(
        displayName: displayName ?? this.displayName,
        locator: locator ?? this.locator,
      );

  @override
  bool operator ==(Object other) =>
      other is TomStorageLocation &&
      other.displayName == displayName &&
      other.locator == locator;

  @override
  int get hashCode => Object.hash(displayName, locator);

  @override
  String toString() => 'TomStorageLocation("$displayName" → $locator)';
}
