/// Annotation-Based Bean Registration Example
///
/// This example demonstrates the ACTUAL use of bean annotations:
/// - `@tomReflector` + `@tomComponent` for concrete type beans
/// - `@tomReflector` + `@TomComponent(InterfaceType)` for interface-based beans
/// - Bean dependency injection using `TomBean<T>` fields
///
/// These annotations enable automatic bean discovery via initializeBeanContext().
///
/// NOTE: When running from 00_run_all_examples.dart, initializeReflection() is
/// called there, which enables all annotated classes to be discovered.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

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
    _emailService().sendEmail(
      '$userId@example.com',
      'Notification',
      message,
    );
    
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
    
    logger.log('Hello from concrete type bean!');
    print('   Log count: ${logger.logs.length}');
    print('');
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
    print('   Calling notificationService.sendNotification():');
    notificationService.sendNotification('user123', 'Welcome!');
    
    // Verify dependency injection worked
    final emailService = TomBean<EmailService>().get();
    dependencyInjectionWorks = emailService.sentEmails.isNotEmpty;
    print('');
    print('   Dependency injection successful: $dependencyInjectionWorks');
    print('');
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
    
    print('   Both syntaxes return the same instance:');
    print('   - emailBean.get() == emailBean(): ${identical(email1, email2)}');
    print('');
    print('   Method chaining with callable syntax:');
    emailBean().sendEmail('chain@example.com', 'Callable', 'Body');
    print('');
  }

  /// Example 6: How initializeBeanContext() discovers beans
  static void example6InitializationSequence() {
    print('6. Bean initialization sequence:');
    print('');
    print('   ┌─────────────────────────────────────────────────────────┐');
    print('   │ INITIALIZATION SEQUENCE (in main()):                    │');
    print('   │                                                         │');
    print('   │   1. initializeReflection();                           │');
    print('   │      → Makes @tomReflector classes discoverable         │');
    print('   │                                                         │');
    print('   │   2. TomPlatformUtils.setCurrentPlatform(utils);        │');
    print('   │      → Sets platform for @platformXxx selection         │');
    print('   │                                                         │');
    print('   │   3. initializeBeanContext(environment: "dev");         │');
    print('   │      → Scans for @TomComponent classes                  │');
    print('   │      → Instantiates beans based on environment/platform │');
    print('   │      → Validates TomBean<T> references                  │');
    print('   └─────────────────────────────────────────────────────────┘');
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
    print('   Resolution priority: exact match > platform > environment > default');
    print('');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('═══════════════════════════════════════════════════════════════════');
    print('05: ANNOTATION-BASED BEANS EXAMPLE');
    print('═══════════════════════════════════════════════════════════════════\n');

    // Note: initializeReflection() should be called by 00_run_all_examples.dart
    // For standalone execution, we need to set up beans manually
    _ensureBeansRegistered();

    example1AnnotationPatterns();
    example2ConcreteTypeBeans();
    example3InterfaceBeans();
    example4BeanDependencies();
    example5CallableSyntax();
    example6InitializationSequence();
    example7AdvancedAnnotations();

    print('✓ All annotation-based bean examples completed!\n');
    print('Summary:');
    print('  - Email service type: $emailServiceType');
    print('  - Storage service: $storageServiceName');
    print('  - Emails sent: $emailsSentCount');
    print('  - Dependency injection works: $dependencyInjectionWorks\n');
  }

  /// Ensures beans are registered (for standalone execution)
  static void _ensureBeansRegistered() {
    // Check if beans are already registered (from initializeBeanContext)
    try {
      TomBean<LoggingHelper>().get();
      print('   Beans already registered via initializeBeanContext()\n');
    } catch (_) {
      // Beans not registered - register manually for standalone execution
      print('   Registering beans manually (standalone execution)...\n');
      TomBean.withType(LoggingHelper, LoggingHelper());
      TomBean.withType(EmailService, DefaultEmailService());
      TomBean.withType(StorageService, DefaultStorageService());
      TomBean.withType(NotificationService, NotificationService());
    }
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() => AnnotationBasedBeansExample.run();

void main() => run();
