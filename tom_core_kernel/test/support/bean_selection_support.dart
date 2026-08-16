/// Shared helpers for the bean-locator selection suites.
///
/// The four-tier interface selection is driven entirely by process-global
/// state — the bean context, the active environment, the active platform — so
/// every selection test has the same shape: put the runtime into a known
/// state, run one discovery pass, then assert what got bound. These helpers
/// carry that shape so the tests themselves only state the interesting part.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The environments the selection fixtures are annotated with.
///
/// Selection compares environments and platforms with `==`, and neither
/// [TomEnvironment] nor [TomPlatform] overrides it — so the comparison is
/// identity. Const expressions are canonicalised, which makes an annotation
/// and an identically written `const` value the same instance; a *runtime*
/// `TomEnvironment('prod')` would not match. Naming the constants here keeps
/// that requirement visible and lets the annotation and the value handed to
/// [TomRuntime] be literally the same thing.
const prodEnvironment = TomEnvironment('prod');

/// The second environment used to show that a selector actually selects.
const devEnvironment = TomEnvironment('dev');

/// Activates [environment] and [platform], then runs one full discovery pass.
///
/// Resets both global registries first: [TomRuntime.reset] so environments do
/// not accumulate across tests, and [TomBean.resetBeanContext] so a bean bound
/// by an earlier pass cannot short-circuit this one — `_instantiateInterfaceBean`
/// returns early when the interface is already registered, which would
/// silently make a re-selection test assert the *previous* selection.
///
/// [beforeDiscovery] runs in the one window where a manual registration can
/// take precedence over discovery: after the context is emptied, before the
/// pass reads it. Registering earlier is wiped by the reset and registering
/// later throws, so the window is the whole mechanism — which is why it lives
/// here rather than being re-derived by each test that needs it.
void discoverBeansIn(
  TomEnvironment environment,
  TomPlatform platform, {
  void Function()? beforeDiscovery,
}) {
  TomRuntime.reset();
  TomRuntime.addEnvironment(environment);
  TomRuntime.setCurrentEnvironment(environment.env);
  TomRuntime.setCurrentPlatform(platform);

  TomBean.resetBeanContext();
  beforeDiscovery?.call();
  initializeBeanContext();
}

/// Runs [body] and returns the [TomBeanLocatorException] it throws, or null
/// when it completes normally.
///
/// Lets a test pin the *specific* error contract — which key, which
/// parameters — rather than merely that some exception escaped.
TomBeanLocatorException? locatorExceptionOf(void Function() body) {
  try {
    body();
  } on TomBeanLocatorException catch (e) {
    return e;
  }
  return null;
}

/// Runs [body] and returns the `key` of the [TomBeanLocatorException] it
/// throws, or `<did-not-throw>` when it completes normally.
String keyOfThrow(void Function() body) =>
    locatorExceptionOf(body)?.key ?? '<did-not-throw>';
