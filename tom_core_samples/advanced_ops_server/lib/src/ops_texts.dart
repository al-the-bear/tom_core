/// Where the ops server's user-facing text comes from.
///
/// Two YAML bundles under `assets/`, one per locale, loaded into a
/// [TomLocalizedTextResources], installed as the process-wide bean and read
/// from there by [TomEmailService]. Nothing a recipient reads is written in
/// Dart.
///
/// ## Why a bundle *set* rather than one bundle
///
/// The kernel's `TomTextResourceProvider` holds one installed bundle, which is
/// right for a client — one user, one screen, one language — and wrong here.
/// A digest pass renders for everybody with open work in a single loop, so the
/// locale has to be an argument rather than process state. That is precisely
/// what `tom_core_server`'s `resources` module adds, and the digest is the
/// suite's demonstration of it: `OpsDigestSummary.locale` travels with the
/// recipient, and the same template key produces German for one person and
/// English for the next in the same pass.
///
/// ## Why the bundles are files
///
/// Text a translator has to edit must not be a Dart literal, or every
/// correction is a rebuild. The auth server externalised its client texts to
/// `assets/resources_*.json` for the same reason (`auth_resource_bundles.dart`);
/// YAML is used here because email bodies are multi-line and a block scalar is
/// readable where an escaped JSON string is not.
///
/// A missing bundle raises rather than yielding an empty set. An empty bundle
/// set would send every digest with a blank subject, and a blank mail that was
/// *delivered* is worse than a start-up failure that was not.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// The resource key prefix the digest's subject and body live under.
///
/// A constant rather than a literal at the call site because the same key names
/// four resources across two bundles; a typo in one of five spellings would
/// show up as one language quietly missing a sentence.
const String opsDigestTemplateKey = 'email.ops_digest';

/// Sub-key of the sentence included only when someone has overdue work.
const String opsDigestOverdueSubKey = 'overdue_line';

/// Sub-key of the sentence included only when a due date is still ahead.
const String opsDigestNextDueSubKey = 'next_due_line';

/// Loads and caches the ops server's localised text.
class OpsTexts {
  const OpsTexts._();

  /// Where the bundles live, relative to the working directory — the same
  /// convention `assets/datasources_default.yaml` already follows.
  static const String assetDirectory = 'assets';

  /// The locale tags this server ships text for.
  static const List<String> localeTags = ['en', 'de'];

  /// The locale a recipient without one is served in.
  static const String defaultLocaleTag = 'en';

  /// Installs the bundle set as the process-wide
  /// [TomLocalizedTextResources] bean, and returns it.
  ///
  /// The bean *is* the cache. An earlier version of this class kept a
  /// `static TomLocalizedTextResources?` of its own, which is a process-wide
  /// singleton with none of a bean's advantages: nothing else could reach it,
  /// and no test or deployment could substitute a different set without
  /// editing this file. `TomBean` already provides exactly that, and the
  /// framework's services read it — a `TomEmailService` built with no `texts`
  /// argument resolves this one.
  ///
  /// Idempotent: a second call answers the installed set rather than reading
  /// the files again, so a caller may treat it as "make sure the text is
  /// there" without tracking whether boot already did.
  static TomLocalizedTextResources install({
    String directory = assetDirectory,
  }) {
    final installed = TomLocalizedTextResources.resolve();
    if (installed != null) return installed;
    final texts = load(directory: directory);
    TomBean.withType(TomLocalizedTextResources, texts);
    return texts;
  }

  /// The installed bundle set, installing it from [assetDirectory] on the
  /// first call.
  static TomLocalizedTextResources resources() => install();

  /// Reads the bundles from [directory] without consulting the cache.
  ///
  /// Public and parameterised so a test can point at a fixture directory, and
  /// so a reload is a call rather than a restart.
  static TomLocalizedTextResources load({String directory = assetDirectory}) {
    final bundles = <String, Map<String, dynamic>>{};
    for (final tag in localeTags) {
      final path = '$directory/text_$tag.yaml';
      if (!File(path).existsSync()) {
        throw StateError(
          'Text bundle not found: $path (cwd: ${Directory.current.path})',
        );
      }
      bundles[tag] = TomYaml.loadYamlFile(path);
    }
    return TomLocalizedTextResources(
      bundles: bundles,
      defaultLocale: TomTextLocale(defaultLocaleTag),
    );
  }
}
