/// Demonstrates type-based and environment-selected bean registration.
///
/// Where `03_named_beans_example.dart` covers name-keyed beans, this example
/// covers the *type*-keyed surface of [TomBean]:
///
/// - [TomBean.withType] — register an instance under a `Type` key.
/// - resolving by interface with `TomBean<Interface>().get()` and callable
///   `TomBean<Interface>()()` syntax.
/// - [TomBean.installByEnvironment] — pick exactly one implementation by the
///   active environment name (explicit or from [TomRuntime]).
/// - the static accessors [TomBean.getBeanByType] / [TomBean.getBeanByName].
/// - the two distinct type-path errors: `no_bean_found_uninitialized` (nothing
///   registered) and `more_than_one_implementation_found` (ambiguous).
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example service interface + environment-specific implementations
// ============================================================================

/// A payment gateway abstraction with per-environment implementations.
abstract class PaymentGateway {
  String charge(int cents);
}

/// Production gateway — talks to the real processor.
class LivePaymentGateway implements PaymentGateway {
  @override
  String charge(int cents) => 'LIVE charged $cents cents';
}

/// Sandbox gateway — used in test/dev, never moves money.
class SandboxPaymentGateway implements PaymentGateway {
  @override
  String charge(int cents) => 'SANDBOX pretended to charge $cents cents';
}

/// A second interface used to show ambiguous resolution.
abstract class Notifier {}

class EmailNotifier implements Notifier {}

class SmsNotifier implements Notifier {}

void run() {
  print('=== 06: Type & Environment Registration Example ===\n');

  // Isolate this example's registrations from any earlier example.
  TomBean.resetBeanContext();

  // -------------------------------------------------------------------------
  // Example 1: Register a bean by type, resolve it through its interface
  // -------------------------------------------------------------------------
  print('1. Register by type, resolve by interface:');

  TomBean.withType(PaymentGateway, SandboxPaymentGateway());

  final gatewayViaGet = TomBean<PaymentGateway>().get();
  final gatewayViaCall = TomBean<PaymentGateway>()(); // callable syntax

  print('   - via get():  ${gatewayViaGet.charge(500)}');
  print('   - via call(): ${gatewayViaCall.charge(500)}');

  // -------------------------------------------------------------------------
  // Example 2: Static accessor by type
  // -------------------------------------------------------------------------
  print('\n2. Static accessor TomBean.getBeanByType:');

  final byType = TomBean.getBeanByType(PaymentGateway);
  print('   - getBeanByType(PaymentGateway): ${byType.runtimeType}');
  print(
    '   - getBeanByType(String) (unregistered): '
    '${TomBean.getBeanByType(String)}',
  );

  // -------------------------------------------------------------------------
  // Example 3: installByEnvironment with an explicit environment name
  // -------------------------------------------------------------------------
  print('\n3. installByEnvironment (explicit environment = "test"):');

  TomBean.resetBeanContext();
  TomBean.installByEnvironment<PaymentGateway>({
    'prod': LivePaymentGateway.new,
    'test': SandboxPaymentGateway.new,
  }, environment: 'test');

  final selected = TomBean<PaymentGateway>().get();
  print('   - installed implementation: ${selected.runtimeType}');
  print('   - result: ${selected.charge(1000)}');

  // -------------------------------------------------------------------------
  // Example 4: installByEnvironment reading the active TomRuntime environment
  // -------------------------------------------------------------------------
  print('\n4. installByEnvironment (active TomRuntime environment):');

  TomBean.resetBeanContext();
  TomRuntime.addEnvironment(const TomEnvironment('prod'));
  TomRuntime.setCurrentEnvironment('prod');

  TomBean.installByEnvironment<PaymentGateway>({
    'prod': LivePaymentGateway.new,
    'test': SandboxPaymentGateway.new,
  });

  final selectedFromRuntime = TomBean<PaymentGateway>().get();
  print('   - active environment: ${TomRuntime.getCurrentEnvironment().env}');
  print('   - installed implementation: ${selectedFromRuntime.runtimeType}');

  // -------------------------------------------------------------------------
  // Example 5: The two type-path errors
  // -------------------------------------------------------------------------
  print('\n5. Type-path error keys:');

  TomBean.resetBeanContext();

  String uninitializedKey = '';
  try {
    TomBean<PaymentGateway>().get();
  } on TomBeanLocatorException catch (e) {
    uninitializedKey = e.key;
    print('   - nothing registered -> ${e.key}');
  }

  String ambiguousKey = '';
  TomBean.withType(EmailNotifier, EmailNotifier());
  TomBean.withType(SmsNotifier, SmsNotifier());
  try {
    TomBean<Notifier>().get();
  } on TomBeanLocatorException catch (e) {
    ambiguousKey = e.key;
    print('   - two implementations -> ${e.key}');
  }

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: type registration resolves through the interface both ways.
  assert(gatewayViaGet is SandboxPaymentGateway);
  assert(gatewayViaCall is SandboxPaymentGateway);

  // Example 2: static accessor returns the registered instance / null.
  assert(byType is SandboxPaymentGateway);
  assert(TomBean.getBeanByType(String) == null);

  // Example 3: explicit environment selects the sandbox implementation.
  assert(selected is SandboxPaymentGateway);

  // Example 4: runtime environment "prod" selects the live implementation.
  assert(selectedFromRuntime is LivePaymentGateway);

  // Example 5: the two distinct type-path error keys.
  assert(
    uninitializedKey == 'beanlocator.bean_access.no_bean_found_uninitialized',
  );
  assert(
    ambiguousKey ==
        'beanlocator.bean_access.more_than_one_implementation_found',
  );
}

void main() => run();
