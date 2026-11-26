// A fixture: read as text by the coverage check, never compiled.
import 'package:flutter/widgets.dart';

Widget build(String kind) => Column(
  children: [
    TomTextButton(tomId: 'files.openButton'),
    TomTextField(tomId: 'files.nameField'),
    TomText(tomId: 'files.titleText'),
    TomText(tomId: 'files.caption'),
    TomText(tomId: 'files.dottedButton'),
    TomText(tomId: 'files.nullButton'),
    TomText(tomId: 'files.listButton'),
    TomText(tomId: 'files.missingText'),
    TomText(tomId: 'files.$kind'),
    TomText(tomId: 'broken_demo.files.openButton'),
    Text('Hello world'),
    Text('Allowed words'),
    Text(kind == 'a' ? 'Yes' : 'save'),
  ],
);

void report(String f) {
  debugPrint('Debug only text here');
  final a = Msg('save.failedMessage.text', params: {'file': f});
  final b = Msg('save.countMessage.many', params: {'count': 2});
  final c = Msg('save.failedMessage.title');
  final d = Msg('save.countMessage.one');
  // A comment holding tomId: 'files.commented' is not a use, and
  // 'Commented words' is no literal.
  throw StateError('Developer message for the log');
}
