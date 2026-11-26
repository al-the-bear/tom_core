import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A resource provider that holds no text and records each key asked for,
/// and how: the way the text-key catalogues are held to the code.
///
/// A key asked through the String family (`exists`, `getText`,
/// `getTextOrNull`) and never as an object (`getObjectOrNull`) is a text key.
/// Asked with `exists` or `getText`, a missing resource shows the dotted key,
/// so the key is required; asked only with `getTextOrNull`, it is optional.
/// Non-text values (colours, sizes) are answered from [objects], so a widget
/// that demands one still builds.
class RecordingTextResourceProvider extends TomTextResourceProvider {
  RecordingTextResourceProvider([TomTextResourceProvider? objects])
    : _objects = objects ?? TomTextResourceProvider.from(const {});

  final TomTextResourceProvider _objects;

  /// Each key asked for, with the methods it was asked through.
  final Map<String, Set<String>> asked = {};

  void _note(String key, String how) =>
      asked.putIfAbsent(key, () => <String>{}).add(how);

  @override
  bool exists(String s) {
    _note(s, 'exists');
    return false;
  }

  @override
  bool existsObject(String s) {
    _note(s, 'existsObject');
    return _objects.existsObject(s);
  }

  @override
  String getText(String s) {
    _note(s, 'getText');
    return s;
  }

  @override
  String? getTextOrNull(String s) {
    _note(s, 'getTextOrNull');
    return null;
  }

  @override
  Object? getObjectOrNull(String s) {
    _note(s, 'getObjectOrNull');
    return _objects.getObjectOrNull(s);
  }

  /// The text keys asked for under [path], as suffixes after `<path>.`, each
  /// with whether it was required.
  Map<String, bool> textKeysUnder(String path) => {
    for (final entry in asked.entries)
      if (entry.key.startsWith('$path.') &&
          !entry.value.contains('getObjectOrNull'))
        entry.key.substring(path.length + 1):
            entry.value.contains('exists') || entry.value.contains('getText'),
  };
}
