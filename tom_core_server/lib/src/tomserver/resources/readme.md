# resources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Resource text chosen by the **recipient's** locale rather than the process's.

The kernel's `TomTextResourceProvider` is a singleton with no locale dimension:
one installed bundle, swapped when the user's language changes. That is exactly
right on a client, where one user looks at one screen — and exactly wrong on a
server, which renders text for many users in many languages *concurrently*.
There is no moment at which a server could meaningfully "switch to German": it
is answering a German user and an English one in the same event loop.

So the locale has to be an **argument**, not ambient state. That is the only
thing this module adds. Everything about how a key resolves — the dot-notation
tree walk, the flat-key fallback, what counts as a `String` — stays in the
kernel provider, because a second resolution semantics for one bundle format
would make the first key that resolved on a client but not in an email a
genuinely hard bug to see.

## Key types

| Type | What it is |
| ---- | ---------- |
| `TomLocalizedTextResources` | One `TomTextResourceProvider` per locale, plus the rule for choosing which one answers. `textOrNull` is the only lookup offered, and `resolve()` finds the set a deployment installed as a bean. |
| `TomTextLocale` | A language, optionally narrowed by a country. `TomTextLocale.fromPrincipal` reads the one a principal carries. |
| `TomResourceLocaleException` | Raised when a locale cannot be formed from what a caller supplied — configuration or a user record, never a browser, so it is never client-visible. |

Two rules are worth knowing before the guide.

**The fallback is per key, not per bundle.** A lookup walks the requested
locale's exact tag (`de_AT`), then its bare language (`de`), then the default
locale's tag and language. So a half-translated `de` bundle serves the strings
it has and falls through for the rest, which is what a translation in progress
looks like; the alternative makes the first untranslated key revert a whole
message to another language.

**A miss is `null`, never the key.** The kernel provider answers an unknown key
with the key itself, which on a screen is the right failure — the button reads
`two_factor.totp.enrol.submit`, and it gets fixed. In an email it is not: nobody
sees the subject line before the recipient does. So only `textOrNull` exists and
the caller decides how loudly to fail; `TomEmailService` fails at send.

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  final texts = TomLocalizedTextResources(
    defaultLocale: TomTextLocale('en'),
    bundles: {
      'en': {'mail': {'subject': 'Your invoice'}},
      'de': {'mail': {'subject': 'Ihre Rechnung'}},
    },
  );

  print(texts.textOrNull('mail.subject', locale: TomTextLocale('de')));
  // Ihre Rechnung
  print(texts.textOrNull('mail.missing')); // null — never the key
}
```

See [`doc/resources.md`](../../../../doc/resources.md) for the full treatment:
why the kernel provider is not enough, the fallback chain, locale parsing and
what a deployment supplies.
`example/resources/resources_example.dart` runs the whole surface in memory —
bundles are maps, and nothing there opens a file or a connection — and
`test/resources_test.dart` covers the module.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
