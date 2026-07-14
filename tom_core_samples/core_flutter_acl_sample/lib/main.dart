/// Entry point for the Tom Core ACL feature tour.
///
/// The tour deliberately renders raw widget boxes (and, for the authorization
/// screen, the *direct-parameter* form of Tom widgets) so no
/// [TomTextResourceProvider] lookup is required for the **teaching snippets** —
/// each ACL snippet is copy-paste-ready on its own. The showcase's own
/// **interactive chrome** (the code panel's copy-button tooltip, the visibility
/// demo's toggle label) is different: it is real application text, so G-RES-1
/// applies and it is resolved from the [chromeTexts] bundle installed here (see
/// `common/chrome_texts.dart` for the exemption boundary). There is **no
/// reflection step**: an ACL layout binds no reflected entities.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'acl_app.dart';
import 'common/chrome_texts.dart';

void main() {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(chromeTexts),
  );
  runApp(const AclApp());
}
