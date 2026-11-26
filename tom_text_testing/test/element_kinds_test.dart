import 'package:test/test.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

void main() {
  const kinds = TextElementKinds.standard;

  test('the longest suffix names the kind', () {
    expect(kinds.suffixOf('saveButton'), 'Button');
    expect(kinds.suffixOf('closeIconButton'), 'IconButton');
    expect(kinds.suffixOf('filterSearchField'), 'SearchField');
    expect(kinds.suffixOf('nameField'), 'Field');
    expect(kinds.suffixOf('dateDialog'), 'Dialog');
    expect(kinds.suffixOf('datePickerDialog'), 'PickerDialog');
    expect(kinds.suffixOf('emptyEmptyState'), 'EmptyState');
  });

  test('a suffix needs a lowercase-led word before it', () {
    expect(kinds.kindOf('Button'), isNull);
    expect(kinds.kindOf('buttons'), isNull);
    expect(kinds.kindOf('settings'), isNull);
    expect(kinds.kindOf('SaveButton'), isNull);
  });

  test('allowed keys, with groups', () {
    final field = kinds.kindOf('nameField')!;
    expect(field.allows('label'), isTrue);
    expect(field.allows('error.empty'), isTrue);
    expect(field.allows('error'), isFalse);
    expect(field.allows('tooltip'), isFalse);
  });

  test('required keys as alternatives', () {
    final message = kinds.kindOf('savedMessage')!;
    expect(message.missingRequired({'text'}), isEmpty);
    expect(message.missingRequired({'one', 'many'}), isEmpty);
    expect(message.missingRequired({'one'}), ['many']);
    expect(message.requiredText, 'text | one + many');
    expect(kinds.kindOf('datePickerDialog')!.missingRequired({}), isEmpty);
    expect(kinds.kindOf('renameDialog')!.missingRequired({}), ['title']);
  });
}
