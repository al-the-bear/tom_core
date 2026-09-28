// CE-TX — the closed message-key catalogue.
//
// The registry exists to REJECT things, so the rejections are the
// demonstration rather than a footnote: both fire where the specification is
// authored, not where the text is rendered. A missing key discovered at render
// time is a blank label in front of a user; discovered here it is a stack
// trace in front of the author who can fix it.
//
// Run with:
//   dart run --enable-asserts example/message_key_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

void main() {
  requireAsserts();
  print('== CE-TX: message keys ==');

  final messages = TomMessageKeyRegistry(baseLocale: 'en')
    ..register(
      TomMessageKey(
        key: 'app.order.placed',
        baseCopy: 'Order placed',
        role: TomMessageRole.notification,
        category: TomMessageCategory.uiCopy,
        localeCopy: {'de': 'Bestellung aufgegeben'},
      ),
    )
    ..register(
      TomMessageKey(
        key: 'app.error.amount.tooLarge',
        baseCopy: 'Amount may not exceed {max}.',
        role: TomMessageRole.error,
        category: TomMessageCategory.errorCopy,
        errorCode: 'amount.tooLarge',
        parameters: ['max'],
      ),
    );

  // A locale with copy gets it; a locale without falls back to the base copy
  // rather than to nothing.
  print('  de: ${messages.resolve('app.order.placed', 'de')}');
  print('  fr: ${messages.resolve('app.order.placed', 'fr')}');
  assert(messages.resolve('app.order.placed', 'de') == 'Bestellung aufgegeben');
  assert(messages.resolve('app.order.placed', 'fr') == 'Order placed');

  // Error copy is reachable from the error code, which is how a failure
  // raised deep in a service finds the sentence that renders it.
  final byCode = messages.forErrorCode('amount.tooLarge');
  print('  amount.tooLarge -> ${byCode?.key}');
  assert(byCode?.key == 'app.error.amount.tooLarge');
  assert(messages.forErrorCode('no.such.code') == null);

  // Rejection one: the catalogue is closed, so an unknown key is an error and
  // not an empty string.
  var rejected = 0;
  try {
    messages.resolve('app.missing', 'en');
  } on ArgumentError catch (error) {
    rejected++;
    print('  refused unknown key: ${error.message}');
  }

  // Rejection two: error copy must name the error code it renders, so a
  // failure can never reach a user with no sentence attached to it.
  try {
    messages.register(
      TomMessageKey(
        key: 'app.error.loose',
        baseCopy: 'Something failed',
        role: TomMessageRole.error,
        category: TomMessageCategory.errorCopy,
      ),
    );
  } on ArgumentError catch (error) {
    rejected++;
    print('  refused error copy with no code: ${error.message}');
  }

  // Rejection three: a key is registered once.
  try {
    messages.register(
      TomMessageKey(key: 'app.order.placed', baseCopy: 'Duplicate'),
    );
  } on ArgumentError catch (error) {
    rejected++;
    print('  refused duplicate key: ${error.message}');
  }

  assert(rejected == 3, 'all three refusals must fire');
  assert(messages.keys.length == 2, 'no refused entry was stored');
  print('  3 refusals, catalogue still holds ${messages.keys.length} keys');
}
