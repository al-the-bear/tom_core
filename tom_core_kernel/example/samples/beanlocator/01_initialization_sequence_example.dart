/// Demonstrates the startup sequence that makes the bean locator usable, and
/// what `initializeBeanContext()` checks on the way through.
///
/// Every other sample in this folder starts with beans already available. This
/// one is about getting there:
///
/// 1. **Reflection** — `initializeReflection()` is what makes an annotated
///    class visible to discovery at all.
/// 2. **The runtime** — an environment has to be *registered* before it can be
///    made current, because selection compares each candidate implementation
///    against the active deployment.
/// 3. **`initializeBeanContext()`** — the discovery pass: one implementation
///    chosen per interface and instantiated.
/// 4. **The first resolution** — and the fact that nothing was injected to
///    obtain it.
/// 5. **Startup validation** — a handle whose binding is missing fails *here*,
///    not at first use, which is the whole reason the pass resolves handles.
///
/// The runtime half of this — platform detection, environment hierarchies,
/// initializers — is the subject of `samples/runtime/03_…`; this sample
/// configures the minimum the locator needs and moves on.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// The beans this sample discovers
// ============================================================================

/// The interface a consumer depends on.
abstract class GreetingService {
  String greet(String name);
}

/// A bean registered under its own concrete type.
///
/// `@tomComponent` names no interface, so discovery registers this instance
/// under `StartupConfig` itself rather than under some abstraction.
@tomReflector
@tomComponent
class StartupConfig {
  String get salutation => 'Hello';
}

/// The implementation discovery selects for [GreetingService].
///
/// Its dependency is a *handle*, not a constructor parameter: discovery builds
/// this class by calling `StartupGreetingService()` and passing nothing, and
/// the handle resolves itself the first time it is read. That is also why a
/// bean must not call `get()` from its constructor — at that moment the pass
/// has not finished registering everything.
@tomReflector
@TomComponent(GreetingService)
class StartupGreetingService implements GreetingService {
  final TomBean<StartupConfig> config = TomBean();

  @override
  String greet(String name) => '${config().salutation} $name';
}

/// An interface no class implements, used in step 5 to show what startup
/// validation catches. It carries no annotation, so discovery never looks for
/// an implementation — only the handle declared against it does.
abstract class UnboundService {
  void doSomething();
}

// ============================================================================
// Captured results
// ============================================================================

late int annotatedClassCount;
late String environmentBeforeRegistering;
late String environmentAfterRegistering;
late String greeting;
late String discoveredImplementation;
late String validationErrorKey;

// ============================================================================
// Step 1: Reflection
// ============================================================================

void step1Reflection() {
  print('1. Reflection — the precondition for discovery:');

  // `initializeReflection()` (from the generated *.reflection.dart) is called
  // by the runner, or by this file's own main(). Without it `annotatedClasses`
  // is empty and initializeBeanContext() would quietly discover nothing —
  // there is no error to catch, just no beans.
  annotatedClassCount = tomReflector.annotatedClasses.length;

  print('   - annotated classes visible to discovery: $annotatedClassCount');
  print('   - among them: StartupConfig, StartupGreetingService');

  assert(annotatedClassCount > 0, 'initializeReflection() must run first');
}

// ============================================================================
// Step 2: The runtime
// ============================================================================

void step2Runtime() {
  print('\n2. The runtime — registered before it can be made current:');

  // setCurrentEnvironment resolves a *name* against the registry. An unknown
  // name is not an error: it falls back. So getting the order wrong does not
  // fail loudly here — it silently selects implementations for the fallback
  // environment instead of the one that was asked for.
  TomRuntime.setCurrentEnvironment('dev');
  environmentBeforeRegistering = TomRuntime.getCurrentEnvironment().env;
  print(
    '   - setCurrentEnvironment("dev") before registering it '
    '-> "$environmentBeforeRegistering"',
  );

  TomRuntime.addEnvironment(const TomEnvironment('dev', isDevelopment: true));
  TomRuntime.setCurrentEnvironment('dev');
  environmentAfterRegistering = TomRuntime.getCurrentEnvironment().env;
  print('   - after addEnvironment(...) -> "$environmentAfterRegistering"');

  // Naming the platform keeps this sample self-contained. An application
  // detects it instead: TomPlatformUtils.setCurrentPlatform(...) followed by
  // TomRuntime.initializePlatform() — see samples/runtime/03_….
  TomRuntime.setCurrentPlatform(platformLinux);
  print('   - platform: ${TomRuntime.getCurrentPlatform()?.name}');

  assert(environmentBeforeRegistering == 'default', 'unknown name falls back');
  assert(environmentAfterRegistering == 'dev', 'registered name resolves');
}

// ============================================================================
// Step 3: Discovery
// ============================================================================

void step3DiscoverBeans() {
  print('\n3. initializeBeanContext() — the discovery pass:');

  initializeBeanContext();

  // Discovery registers under Type keys: a concrete bean under its own runtime
  // type, an interface implementation under the interface.
  final config = TomBean.getBeanByType(StartupConfig);
  final greeter = TomBean.getBeanByType(GreetingService);
  discoveredImplementation = greeter.runtimeType.toString();

  print('   - StartupConfig   -> ${config.runtimeType}  (own type)');
  print('   - GreetingService -> $discoveredImplementation  (interface)');

  assert(config is StartupConfig, 'concrete bean registered under its type');
  assert(greeter is StartupGreetingService, 'implementation chosen');
}

// ============================================================================
// Step 4: The first resolution
// ============================================================================

void step4ResolveFirstBean() {
  print('\n4. The first resolution — nothing was injected to get it:');

  greeting = TomBean<GreetingService>().get().greet('Ada');

  print('   - TomBean<GreetingService>().get().greet("Ada") -> "$greeting"');
  print('   - the "Hello" came from StartupConfig, which the greeter resolved');
  print('     through its own handle on first use');

  assert(greeting == 'Hello Ada', 'the bean resolved its own dependency');
}

// ============================================================================
// Step 5: Startup validation
// ============================================================================

void step5StartupValidation() {
  print('\n5. Startup validation — a missing binding fails at boot:');

  // A handle constructed before the pass is pending, and the pass resolves it.
  // Nothing implements UnboundService, so this is a wiring bug — and it is
  // reported now rather than whenever some request first happens to need it.
  TomBean<UnboundService>();

  try {
    initializeBeanContext();
    print('   - ERROR: the unresolvable handle should have been reported');
  } on TomBeanLocatorException catch (e) {
    validationErrorKey = e.key;
    print('   - declaring TomBean<UnboundService>() then re-running the pass:');
    print('     ${e.key}');
  }

  assert(
    validationErrorKey == 'beanlocator.bean_access.no_bean_found_uninitialized',
    'the unbound handle is reported by the pass',
  );
}

// ============================================================================
// Run
// ============================================================================

void run() {
  print('=== 01: Startup Sequence Example ===\n');

  // Both registries are process-global and the samples runner executes every
  // module in one process, so this sample brackets itself: it starts from a
  // clean slate and leaves one behind. Its output is then a property of this
  // file, and the samples that follow build their own registrations.
  TomRuntime.reset();
  TomBean.resetBeanContext();

  step1Reflection();
  step2Runtime();
  step3DiscoverBeans();
  step4ResolveFirstBean();
  step5StartupValidation();

  TomBean.resetBeanContext();
  TomRuntime.reset();

  print('\n=== Startup Sequence Example Complete ===\n');
}

/// Standalone entry point. The runner calls `initializeReflection()` once for
/// the whole sample tree; run on its own, this file has to call it itself —
/// step 1 is precisely about that precondition.
void main() {
  bootstrapSamples();
  run();
}
