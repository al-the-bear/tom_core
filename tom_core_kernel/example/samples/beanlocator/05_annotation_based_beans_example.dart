/// Annotation-Based Bean Registration Example
///
/// This example demonstrates the ACTUAL use of bean annotations:
/// - `@tomReflector` + `@tomComponent` for concrete type beans
/// - `@tomReflector` + `@TomComponent(InterfaceType)` for interface-based beans
/// - Bean dependency injection using `TomBean<T>` fields
///
/// These annotations enable automatic bean discovery via
/// `initializeBeanContext()`, and this sample **performs that discovery
/// itself** rather than inheriting a registry someone else built:
///
/// ```bash
/// dart run --enable-asserts example/samples/beanlocator/05_annotation_based_beans_example.dart
/// ```
///
/// That is the point of the reset at the start of [run]. A sample about
/// annotation-based registration that resolves beans a *different* sample
/// registered demonstrates nothing about annotations — and cannot tell the two
/// apart, because a resolved bean looks the same either way. Clearing the
/// registry first and asserting it is empty is what makes the beans that
/// follow attributable to the annotations on this page.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Service Interfaces
// ============================================================================

/// Email service interface for sending emails.
abstract class EmailService {
  void sendEmail(String to, String subject, String body);
  List<String> get sentEmails;
}

/// Storage service interface for data persistence.
abstract class StorageService {
  void save(String key, String value);
  String? load(String key);
  String get storageName;
}

// ============================================================================
// ANNOTATED BEAN CLASSES - These are discovered automatically!
// ============================================================================

/// A logging helper service registered by its CONCRETE type.
///
/// With `@tomComponent` (no interface type), this bean is registered as
/// `TomBean<LoggingHelper>` and resolved using `TomBean<LoggingHelper>()`.
@tomReflector
@tomComponent
class LoggingHelper {
  final List<String> _logs = [];

  void log(String message) {
    final entry = '[LOG ${DateTime.now().toIso8601String()}] $message';
    _logs.add(entry);
    print('     $entry');
  }

  List<String> get logs => List.unmodifiable(_logs);
}

/// Default email service implementation.
///
/// With `@TomComponent(EmailService)`, this bean is registered under the
/// EmailService interface and resolved using `TomBean<EmailService>()`.
@tomReflector
@TomComponent(EmailService)
class DefaultEmailService implements EmailService {
  final List<String> _sent = [];

  @override
  void sendEmail(String to, String subject, String body) {
    final email = '$to: $subject';
    _sent.add(email);
    print('     [Email] Sending to $to');
    print('     [Email] Subject: $subject');
  }

  @override
  List<String> get sentEmails => List.unmodifiable(_sent);
}

/// Default storage service implementation.
///
/// With `@TomComponent(StorageService)`, this bean is registered under the
/// StorageService interface and resolved using `TomBean<StorageService>()`.
@tomReflector
@TomComponent(StorageService)
class DefaultStorageService implements StorageService {
  final Map<String, String> _storage = {};

  @override
  void save(String key, String value) {
    _storage[key] = value;
    print('     [Storage] Saved: $key = $value');
  }

  @override
  String? load(String key) => _storage[key];

  @override
  String get storageName => 'In-Memory Storage';
}

/// A notification service that demonstrates BEAN DEPENDENCIES.
///
/// This class uses `TomBean<T>` fields to inject other beans.
/// The dependencies are automatically resolved at runtime.
@tomReflector
@tomComponent
class NotificationService {
  // Bean dependencies - resolved lazily via TomBean<T>
  final TomBean<LoggingHelper> _logger = TomBean<LoggingHelper>();
  final TomBean<EmailService> _emailService = TomBean<EmailService>();
  final TomBean<StorageService> _storageService = TomBean<StorageService>();

  void sendNotification(String userId, String message) {
    // Use callable syntax for concise access
    _logger().log('Sending notification to $userId');

    // Send via email service
    _emailService().sendEmail('$userId@example.com', 'Notification', message);

    // Save timestamp to storage
    _storageService().save(
      'last_notification_$userId',
      DateTime.now().toIso8601String(),
    );

    _logger().log('Notification sent and recorded');
  }
}

// ============================================================================
// Example Class
// ============================================================================

class AnnotationBasedBeansExample {
  // Results for verification
  static late String emailServiceType;
  static late String storageServiceName;
  static late int emailsSentCount;
  static bool dependencyInjectionWorks = false;
  static late int loggedByNotification;
  static late bool callableSyntaxIsSameInstance;

  /// Example 1: Demonstrate that annotated beans are auto-discovered
  static void example1AnnotationPatterns() {
    print('1. Annotation patterns for bean registration:');
    print('');
    print('   CONCRETE TYPE (no interface):');
    print('   ┌─────────────────────────────────────┐');
    print('   │ @tomReflector                       │');
    print('   │ @tomComponent                       │');
    print('   │ class LoggingHelper { ... }         │');
    print('   └─────────────────────────────────────┘');
    print('   → Registered as: TomBean<LoggingHelper>');
    print('');
    print('   INTERFACE-BASED:');
    print('   ┌─────────────────────────────────────┐');
    print('   │ @tomReflector                       │');
    print('   │ @TomComponent(EmailService)         │');
    print('   │ class DefaultEmailService           │');
    print('   │     implements EmailService { ... } │');
    print('   └─────────────────────────────────────┘');
    print('   → Registered as: TomBean<EmailService>');
    print('');
  }

  /// Example 2: Resolving concrete type beans
  static void example2ConcreteTypeBeans() {
    print('2. Resolving concrete type beans:');
    print('');

    // Resolve the LoggingHelper bean by its concrete type
    final logger = TomBean<LoggingHelper>().get();
    print('   Resolved LoggingHelper: ${logger.runtimeType}');

    final before = logger.logs.length;
    logger.log('Hello from concrete type bean!');
    print('   Log count: ${logger.logs.length}');
    print('');

    // `@tomComponent` names no interface, so the key is the class itself and
    // the handle's type argument is what the registry was keyed under.
    assert(logger.logs.length == before + 1, 'the resolved bean is live');

    // Resolving twice returns the registered instance, not a fresh one:
    // discovery instantiates once and the registry hands that object out.
    assert(
      identical(TomBean<LoggingHelper>().get(), logger),
      'a bean is a singleton within the context',
    );
  }

  /// Example 3: Resolving interface-based beans
  static void example3InterfaceBeans() {
    print('3. Resolving interface-based beans:');
    print('');

    // Resolve by interface - gets the DefaultEmailService
    final emailService = TomBean<EmailService>().get();
    emailServiceType = emailService.runtimeType.toString();
    print('   Resolved EmailService: $emailServiceType');

    emailService.sendEmail('user@example.com', 'Test Subject', 'Test body');
    emailsSentCount = emailService.sentEmails.length;
    print('   Emails sent: $emailsSentCount');
    print('');

    // Resolve StorageService
    final storageService = TomBean<StorageService>().get();
    storageServiceName = storageService.storageName;
    print('   Resolved StorageService: ${storageService.runtimeType}');
    print('   Storage name: $storageServiceName');

    storageService.save('test_key', 'test_value');
    final loaded = storageService.load('test_key');
    print('   Loaded value: $loaded');
    print('');

    // `@TomComponent(EmailService)` registers the *implementation* under the
    // *interface*, which is why the handle names the abstraction and the object
    // it yields is the concrete class.
    assert(emailService is DefaultEmailService, 'interface -> implementation');
    assert(storageService is DefaultStorageService);
    assert(emailsSentCount == 1, 'a fresh context has sent exactly one');
    assert(storageServiceName == 'In-Memory Storage');
    assert(loaded == 'test_value', 'the storage bean holds state across calls');
  }

  /// Example 4: Bean dependencies with `TomBean<T>`
  static void example4BeanDependencies() {
    print('4. Bean dependencies with TomBean<T>:');
    print('');
    print('   NotificationService uses TomBean<T> fields:');
    print('   ┌────────────────────────────────────────────────┐');
    print('   │ @tomReflector                                  │');
    print('   │ @tomComponent                                  │');
    print('   │ class NotificationService {                    │');
    print('   │   TomBean<LoggingHelper> _logger = TomBean();  │');
    print('   │   TomBean<EmailService> _email = TomBean();    │');
    print('   │   TomBean<StorageService> _storage = TomBean();│');
    print('   │ }                                              │');
    print('   └────────────────────────────────────────────────┘');
    print('');

    // Resolve the notification service
    final notificationService = TomBean<NotificationService>().get();

    // The container's own view of the collaborators, taken *before* the call.
    // "Did injection work?" is not "is anything in the sent list" — example 3
    // already put something there, so that question answers itself whether or
    // not a single handle resolved. It is "did the work this call performed
    // land on the instances the container holds", which needs a before/after.
    final emailService = TomBean<EmailService>().get();
    final logger = TomBean<LoggingHelper>().get();
    final storage = TomBean<StorageService>().get();
    final sentBefore = emailService.sentEmails.length;
    final loggedBefore = logger.logs.length;

    print('   Calling notificationService.sendNotification():');
    notificationService.sendNotification('user123', 'Welcome!');

    final sentAfter = emailService.sentEmails.length;
    loggedByNotification = logger.logs.length - loggedBefore;
    dependencyInjectionWorks = sentAfter == sentBefore + 1;
    print('');
    print('   Dependency injection successful: $dependencyInjectionWorks');
    print('');

    // Each of the three `TomBean<T>` fields resolved to the container's
    // instance: the email arrived on the registered EmailService, both log
    // lines on the registered LoggingHelper, the timestamp in the registered
    // StorageService. A handle that resolved to a fresh object would leave all
    // three unchanged and still print the same output.
    assert(dependencyInjectionWorks, 'the injected EmailService is the bean');
    assert(loggedByNotification == 2, 'the injected LoggingHelper is the bean');
    assert(
      storage.load('last_notification_user123') != null,
      'the injected StorageService is the bean',
    );
    assert(
      emailService.sentEmails.last == 'user123@example.com: Notification',
      'the notification went out through the injected service',
    );
  }

  /// Example 5: Callable syntax for TomBean
  static void example5CallableSyntax() {
    print('5. TomBean callable syntax for concise access:');
    print('');

    final emailBean = TomBean<EmailService>();

    // Traditional .get() syntax
    final email1 = emailBean.get();

    // Callable () syntax - equivalent and more concise
    final email2 = emailBean();

    callableSyntaxIsSameInstance = identical(email1, email2);
    print('   Both syntaxes return the same instance:');
    print('   - emailBean.get() == emailBean(): $callableSyntaxIsSameInstance');
    print('');
    print('   Method chaining with callable syntax:');
    final sentBefore = email1.sentEmails.length;
    emailBean().sendEmail('chain@example.com', 'Callable', 'Body');
    print('');

    // `call()` is not a second lookup path — it forwards to `get()`, so the two
    // spellings cannot diverge.
    assert(callableSyntaxIsSameInstance, 'call() and get() are one path');
    assert(
      email1.sentEmails.length == sentBefore + 1,
      'chaining off the callable reaches the same bean',
    );
  }

  /// Example 6: How initializeBeanContext() discovers beans
  ///
  /// This is the sequence this file ran before example 1 — not a description of
  /// one it might have run.
  static void example6InitializationSequence() {
    print('6. Bean initialization sequence:');
    print('');
    print('   ┌─────────────────────────────────────────────────────────┐');
    print('   │ INITIALIZATION SEQUENCE (this file, before example 1):  │');
    print('   │                                                         │');
    print('   │   1. initializeReflection();                            │');
    print('   │      → Makes @tomReflector classes discoverable          │');
    print('   │      → here: bootstrapSamples() in main()                │');
    print('   │                                                         │');
    print('   │   2. TomRuntime.addEnvironment / setCurrentEnvironment;  │');
    print('   │      TomRuntime.setCurrentPlatform(...);                 │');
    print('   │      → the selectors @TomEnvironment / @platformXxx      │');
    print('   │        are matched against                               │');
    print('   │                                                         │');
    print('   │   3. initializeBeanContext();                            │');
    print('   │      → Scans for @TomComponent classes                   │');
    print('   │      → Instantiates beans based on environment/platform  │');
    print('   │      → Validates TomBean<T> references                   │');
    print('   └─────────────────────────────────────────────────────────┘');
    print('');
    print('   Step 3 takes no arguments: the environment comes from the');
    print('   runtime configured in step 2, not from a parameter.');
    print('');
    print('   After initialization, beans are available via TomBean<T>()');
    print('');
  }

  /// Example 7: Platform and environment annotations (informational)
  static void example7AdvancedAnnotations() {
    print('7. Advanced annotation patterns (for reference):');
    print('');
    print('   ENVIRONMENT-SPECIFIC:');
    print('   ┌──────────────────────────────────────────────┐');
    print('   │ @tomReflector                                │');
    print('   │ @TomComponent(EmailService)                  │');
    print('   │ @TomEnvironment("prod")                      │');
    print('   │ class SmtpEmailService implements EmailService│');
    print('   └──────────────────────────────────────────────┘');
    print('');
    print('   PLATFORM-SPECIFIC:');
    print('   ┌──────────────────────────────────────────────┐');
    print('   │ @tomReflector                                │');
    print('   │ @TomComponent(StorageService)                │');
    print('   │ @platformIos                                 │');
    print('   │ class IosStorageService implements StorageService│');
    print('   └──────────────────────────────────────────────┘');
    print('');
    print(
      '   Resolution priority: exact match > platform > environment > default',
    );
    print('');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 05: Annotation-Based Beans Example ===\n');

    _registerBeansByDiscovery();

    example1AnnotationPatterns();
    example2ConcreteTypeBeans();
    example3InterfaceBeans();
    example4BeanDependencies();
    example5CallableSyntax();
    example6InitializationSequence();
    example7AdvancedAnnotations();

    // The runtime is process-global and this sample configured it. Sample 01
    // hands it back the same way; leaving 'dev' current would make the next
    // sample's environment depend on whether this one ran.
    TomRuntime.reset();

    print('✓ All annotation-based bean examples passed!\n');
    print('Summary:');
    print('  - Email service type: $emailServiceType');
    print('  - Storage service: $storageServiceName');
    print('  - Emails sent: $emailsSentCount');
    print('  - Dependency injection works: $dependencyInjectionWorks\n');

    assert(emailServiceType == 'DefaultEmailService');
    assert(storageServiceName == 'In-Memory Storage');
    assert(dependencyInjectionWorks);
    assert(callableSyntaxIsSameInstance);
  }

  /// Registers this file's four beans the way the sample is about: by letting
  /// discovery read the annotations.
  ///
  /// Nothing here registers a bean by hand. That is the whole claim, and it is
  /// only checkable because the registry is emptied first — a bean resolved out
  /// of a registry someone else filled proves nothing about the annotations on
  /// this page, and looks exactly like one that discovery produced.
  static void _registerBeansByDiscovery() {
    // Clearing is what makes the assertions below attributable. The group
    // runner reaches this file with beans already present (sample 01 ran a
    // discovery pass of its own), so without the reset the "after" state would
    // be indistinguishable from the "before" one.
    TomBean.resetBeanContext();
    assert(
      TomBean.getBeanByType(LoggingHelper) == null,
      'the registry starts empty, so what follows is this pass\'s work',
    );

    // Discovery consults the runtime only for a class that carries a selector
    // (`@TomEnvironment`, `@platformX`) — none here do — but the registry it
    // scans spans the whole samples tree, and some of those do. Configuring the
    // runtime first is the documented order: an environment must be
    // *registered* before it can be made current, because `setCurrentEnvironment`
    // resolves a name and silently falls back when the name is unknown.
    TomRuntime.addEnvironment(const TomEnvironment('dev', isDevelopment: true));
    TomRuntime.setCurrentEnvironment('dev');
    TomRuntime.setCurrentPlatform(platformLinux);

    initializeBeanContext();

    print('   Beans registered by initializeBeanContext() — from annotations,');
    print('   not from any TomBean.withType() call in this file.\n');

    // What the two annotation forms produce, which is the difference the
    // sample teaches:
    //
    //   @tomComponent            -> keyed under the class itself
    //   @TomComponent(Interface) -> keyed under the interface, and *not* under
    //                               the implementing class
    assert(TomBean.getBeanByType(LoggingHelper) is LoggingHelper);
    assert(TomBean.getBeanByType(NotificationService) is NotificationService);
    assert(TomBean.getBeanByType(EmailService) is DefaultEmailService);
    assert(TomBean.getBeanByType(StorageService) is DefaultStorageService);
    assert(
      TomBean.getBeanByType(DefaultEmailService) == null,
      '@TomComponent(EmailService) registers under the interface only',
    );
    assert(
      TomBean.getBeanByType(DefaultStorageService) == null,
      '@TomComponent(StorageService) registers under the interface only',
    );
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() => AnnotationBasedBeansExample.run();

/// Standalone entry point.
///
/// `bootstrapSamples()` rather than `requireAsserts()`: this sample's beans are
/// built by reflection, so it needs the generated registry installed as well as
/// the assert flag checked.
void main() {
  bootstrapSamples();
  run();
}
