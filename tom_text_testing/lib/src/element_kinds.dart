/// The kinds of screen element of the internationalisation guideline (section 3
/// of the workspace guideline `_agent_guidelines/i18n.md`): a name's type
/// suffix says which keys its entry in a resource file may have and which it
/// must have.
library;

/// One kind of screen element: the suffixes that name it, the keys its
/// entry may have and the keys it must have.
class TextElementKind {
  const TextElementKind({
    required this.suffixes,
    required this.allowed,
    this.required = const [],
    this.description = '',
  });

  /// The type suffixes of an element of this kind (`Button`), each written
  /// after a lowerCamelCase word: `saveButton`.
  final List<String> suffixes;

  /// The keys the entry may have. `error.*` allows every key under `error`.
  final List<String> allowed;

  /// The keys it must have, as alternatives: the entry is complete when it
  /// holds every key of one of the lists (`[['text'], ['one', 'many']]`).
  /// Empty: nothing is required.
  final List<List<String>> required;

  /// What the kind is, for messages.
  final String description;

  /// Whether [key] (dotted for a key in a group: `error.empty`) is allowed.
  bool allows(String key) {
    for (final pattern in allowed) {
      if (pattern == key) return true;
      if (pattern.endsWith('.*') &&
          key.startsWith(pattern.substring(0, pattern.length - 1))) {
        return true;
      }
    }
    return false;
  }

  /// The required keys [keys] lacks, for the alternative closest to complete
  /// (fewest missing, then most present); empty when one is complete.
  List<String> missingRequired(Set<String> keys) {
    if (required.isEmpty) return const [];
    List<String>? best;
    var bestPresent = -1;
    for (final alternative in required) {
      final missing = [
        for (final key in alternative)
          if (!keys.contains(key)) key,
      ];
      if (missing.isEmpty) return const [];
      final present = alternative.length - missing.length;
      // The alternative closest to complete: fewest keys missing, then the
      // one the entry has begun (most keys present).
      if (best == null ||
          missing.length < best.length ||
          (missing.length == best.length && present > bestPresent)) {
        best = missing;
        bestPresent = present;
      }
    }
    return best!;
  }

  /// The required keys as text: `label`, or `text | one + many`.
  String get requiredText => required.isEmpty
      ? 'none'
      : required.map((keys) => keys.join(' + ')).join(' | ');
}

/// The kinds of screen element a coverage check knows, found by suffix.
class TextElementKinds {
  const TextElementKinds(this.kinds);

  /// The kinds.
  final List<TextElementKind> kinds;

  /// The table of the guideline's section 3.
  static const standard = TextElementKinds([
    TextElementKind(
      suffixes: ['Text'],
      allowed: ['label', 'semanticsLabel'],
      required: [
        ['label'],
      ],
      description: 'a text on its own',
    ),
    TextElementKind(
      suffixes: ['IconButton'],
      allowed: ['tooltip'],
      required: [
        ['tooltip'],
      ],
      description: 'a button showing only an icon',
    ),
    TextElementKind(
      suffixes: ['Button'],
      allowed: ['label', 'tooltip'],
      required: [
        ['label'],
      ],
      description: 'a button with a caption',
    ),
    TextElementKind(
      suffixes: ['Fab'],
      allowed: ['label', 'tooltip'],
      required: [
        ['tooltip'],
      ],
      description: 'a floating action button',
    ),
    TextElementKind(
      suffixes: ['MenuItem'],
      allowed: ['label'],
      required: [
        ['label'],
      ],
      description: 'an entry of a menu',
    ),
    TextElementKind(
      suffixes: ['SearchField'],
      allowed: ['hint'],
      required: [
        ['hint'],
      ],
      description: 'a search box',
    ),
    TextElementKind(
      suffixes: ['Field'],
      allowed: ['label', 'hint', 'helper', 'error.*'],
      required: [
        ['label'],
      ],
      description: 'a text input',
    ),
    TextElementKind(
      suffixes: ['Select'],
      allowed: ['label', 'hint', 'helper', 'tooltip', 'error.*'],
      required: [
        ['label'],
        ['tooltip'],
      ],
      description: 'a choice from a list',
    ),
    TextElementKind(
      suffixes: ['Option'],
      allowed: ['label'],
      required: [
        ['label'],
      ],
      description: 'one fixed choice',
    ),
    TextElementKind(
      suffixes: ['Switch', 'Checkbox', 'Radio'],
      allowed: ['label', 'subtitle'],
      required: [
        ['label'],
      ],
      description: 'a toggle with its caption',
    ),
    TextElementKind(
      suffixes: ['Slider'],
      allowed: ['label'],
      description: 'a slider',
    ),
    TextElementKind(
      suffixes: ['PickerDialog'],
      allowed: [
        'title',
        'help',
        'cancel',
        'confirm',
        'save',
        'fieldLabel',
        'fieldHint',
        'fieldStartLabel',
        'fieldStartHint',
        'fieldEndLabel',
        'fieldEndHint',
        'errorFormat',
        'errorInvalid',
        'errorInvalidRange',
        'hourLabel',
        'minuteLabel',
      ],
      description:
          'a date or time picker (Flutter words every key that is absent)',
    ),
    TextElementKind(
      suffixes: ['Dialog'],
      allowed: ['title', 'semanticLabel'],
      required: [
        ['title'],
      ],
      description: 'a dialog',
    ),
    TextElementKind(
      suffixes: ['Tooltip'],
      allowed: ['tooltip'],
      required: [
        ['tooltip'],
      ],
      description: 'a tooltip around something that is not a button',
    ),
    TextElementKind(
      suffixes: ['Tile'],
      allowed: ['label', 'subtitle'],
      required: [
        ['label'],
      ],
      description: 'a row with a title',
    ),
    TextElementKind(
      suffixes: ['Chip'],
      allowed: ['label', 'tooltip', 'deleteButtonTooltipMessage'],
      required: [
        ['label'],
      ],
      description: 'a chip',
    ),
    TextElementKind(
      suffixes: ['Tab'],
      allowed: ['text'],
      required: [
        ['text'],
      ],
      description: 'a fixed tab',
    ),
    TextElementKind(
      suffixes: ['Bar'],
      allowed: ['label'],
      required: [
        ['label'],
      ],
      description: 'an app bar or tool bar with a title',
    ),
    TextElementKind(
      suffixes: ['Badge'],
      allowed: ['label'],
      required: [
        ['label'],
      ],
      description: 'a badge',
    ),
    TextElementKind(
      suffixes: ['Banner'],
      allowed: ['message'],
      required: [
        ['message'],
      ],
      description: 'a banner',
    ),
    TextElementKind(
      suffixes: ['Progress'],
      allowed: ['semanticsLabel', 'semanticsValue'],
      description: 'a progress indicator',
    ),
    TextElementKind(
      suffixes: ['Icon', 'Image'],
      allowed: ['alt'],
      description: 'an icon or image that means something',
    ),
    TextElementKind(
      suffixes: ['EmptyState'],
      allowed: ['title', 'description', 'actionLabel'],
      required: [
        ['title'],
      ],
      description: 'what a view shows when it has nothing',
    ),
    TextElementKind(
      suffixes: ['Action'],
      allowed: ['label', 'tooltip', 'description'],
      required: [
        ['label'],
      ],
      description: 'an action or command',
    ),
    TextElementKind(
      suffixes: ['View', 'Panel', 'Section', 'Page'],
      allowed: ['title', 'description', 'empty'],
      required: [
        ['title'],
      ],
      description: 'a titled area',
    ),
    TextElementKind(
      suffixes: ['Message'],
      // `two` and `few`: plural forms a language other than English adds
      // (section 6).
      allowed: ['text', 'title', 'zero', 'one', 'two', 'few', 'many'],
      required: [
        ['text'],
        ['one', 'many'],
      ],
      description: 'a sentence shown to the user',
    ),
  ]);

  /// The kind [name] names by its suffix (the longest suffix that matches
  /// after at least one lowercase-led word), or null.
  TextElementKind? kindOf(String name) {
    TextElementKind? best;
    var bestLength = 0;
    for (final kind in kinds) {
      for (final suffix in kind.suffixes) {
        if (suffix.length <= bestLength) continue;
        if (name.length <= suffix.length || !name.endsWith(suffix)) continue;
        final word = name.substring(0, name.length - suffix.length);
        if (!_word.hasMatch(word)) continue;
        best = kind;
        bestLength = suffix.length;
      }
    }
    return best;
  }

  /// The suffix [name] ends in ([kindOf]'s), or null.
  String? suffixOf(String name) {
    final kind = kindOf(name);
    if (kind == null) return null;
    String? best;
    for (final suffix in kind.suffixes) {
      if (name.endsWith(suffix) &&
          (best == null || suffix.length > best.length)) {
        best = suffix;
      }
    }
    return best;
  }

  static final RegExp _word = RegExp(r'^[a-z][a-zA-Z0-9]*$');
}
