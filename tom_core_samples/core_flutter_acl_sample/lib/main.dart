/// Entry point for the Tom Core ACL feature tour.
///
/// The tour deliberately renders raw widget boxes (and, for the authorization
/// screen, the *direct-parameter* form of Tom widgets) so no
/// [TomTextResourceProvider] lookup is required — each ACL snippet is
/// copy-paste-ready on its own. We still install an empty application provider
/// so any widget that probes the singleton finds a valid (empty) scope rather
/// than triggering lazy defaults. There is **no reflection step**: an ACL
/// layout binds no reflected entities.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'acl_app.dart';

void main() {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),
  );
  runApp(const AclApp());
}
