/// Bean Dependency Patterns Example
///
/// This example shows how beans can declare dependencies on other beans
/// using `TomBean<T>` fields, and demonstrates actual dependency resolution.
///
/// Key patterns:
/// - Declaring `TomBean<Interface>` fields for dependencies
/// - Using TomBean.fromName() for named dependencies
/// - Using TomBean.withName() to register named beans
/// - Callable syntax: service() instead of service.get()
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Service Interfaces
// ============================================================================

/// A logging service interface.
abstract class LoggingService {
  void info(String message);
  void error(String message);
  List<String> get logs;
}

/// A user service interface.
abstract class UserService {
  String getUserName(int id);
}

/// A payment gateway interface.
abstract class PaymentGateway {
  bool charge(String userId, double amount);
  String get gatewayName;
}

/// An order service interface.
abstract class OrderService {
  String createOrder(int userId, String item, double price);
}

// ============================================================================
// Service Implementations
// ============================================================================

/// Console logging implementation that captures logs for verification.
class ConsoleLoggingService implements LoggingService {
  final List<String> _logs = [];

  @override
  List<String> get logs => List.unmodifiable(_logs);

  @override
  void info(String message) {
    _logs.add('[INFO] $message');
    print('     [INFO] $message');
  }

  @override
  void error(String message) {
    _logs.add('[ERROR] $message');
    print('     [ERROR] $message');
  }
}

/// User service implementation.
class UserServiceImpl implements UserService {
  final LoggingService _logger;

  UserServiceImpl(this._logger);

  @override
  String getUserName(int id) {
    final name = 'User_$id';
    _logger.info('Retrieved user: $name');
    return name;
  }
}

/// Primary payment gateway.
class PrimaryPaymentGateway implements PaymentGateway {
  @override
  String get gatewayName => 'PrimaryGateway';

  @override
  bool charge(String userId, double amount) {
    print(
      '     [$gatewayName] Charging $userId: \$${amount.toStringAsFixed(2)}',
    );
    return true;
  }
}

/// Backup payment gateway.
class BackupPaymentGateway implements PaymentGateway {
  @override
  String get gatewayName => 'BackupGateway';

  @override
  bool charge(String userId, double amount) {
    print(
      '     [$gatewayName] Charging $userId: \$${amount.toStringAsFixed(2)}',
    );
    return true;
  }
}

/// Order service that depends on user service, logging, and payment.
class OrderServiceImpl implements OrderService {
  final UserService _userService;
  final LoggingService _logger;
  final PaymentGateway _payment;

  OrderServiceImpl(this._userService, this._logger, this._payment);

  @override
  String createOrder(int userId, String item, double price) {
    final userName = _userService.getUserName(userId);
    _logger.info(
      'Creating order for $userName: $item @ \$${price.toStringAsFixed(2)}',
    );

    final charged = _payment.charge(userName, price);
    if (!charged) {
      _logger.error('Payment failed for $userName');
      throw Exception('Payment failed');
    }

    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    _logger.info('Order created: $orderId');
    return orderId;
  }
}

/// Demonstrates how a service class uses TomBean fields for dependencies.
class ExampleServiceWithBeans {
  final TomBean<PaymentGateway> payment = TomBean.fromName(
    'sample_primaryPayment',
  );
  final TomBean<LoggingService> logger = TomBean.fromName('sample_logger');

  String lastPaymentGateway = '';
  String lastLoggerType = '';

  void doWork() {
    // Using callable syntax: payment() instead of payment.get()
    lastPaymentGateway = payment().gatewayName;
    lastLoggerType = logger().runtimeType.toString();

    print('   - Payment gateway resolved: $lastPaymentGateway');
    print('   - Logger resolved: $lastLoggerType');

    logger().info('ExampleServiceWithBeans.doWork() called');
    payment().charge('example_user', 10.00);
  }
}

// ============================================================================
// Example Class
// ============================================================================

class BeanDependencyPatternsExample {
  // Captured results
  static late String orderId;
  static late int logCount;
  static late String primaryGatewayName;
  static late String backupGatewayName;
  static bool sameInstance = false;
  static late String errorKey;
  static late String paymentUsed;

  // -------------------------------------------------------------------------
  // Example 1: Manual dependency wiring
  // -------------------------------------------------------------------------
  static void example1ManualDependencyWiring() {
    print('1. Manual dependency wiring (simulates what TomBean does):');
    print('   Creating services with explicit dependencies...');

    // Create the logging service (no dependencies)
    final logger = ConsoleLoggingService();

    // Create user service (depends on logger)
    final userService = UserServiceImpl(logger);

    // Create payment gateway
    final primaryPayment = PrimaryPaymentGateway();

    // Create order service (depends on userService, logger, payment)
    final orderService = OrderServiceImpl(userService, logger, primaryPayment);

    // Use the order service - this triggers the whole dependency chain
    print('\n   Creating an order (triggers dependency chain):');
    orderId = orderService.createOrder(42, 'Widget Pro', 99.95);
    print('   - Order ID: $orderId');

    // Show captured logs
    print('\n   Captured logs from dependency chain:');
    for (final log in logger.logs) {
      print('   - $log');
    }

    logCount = logger.logs.length;

    // Assertions
    assert(orderId.startsWith('ORD-'), 'Order ID should start with ORD-');
    assert(logCount == 3, 'Should have 3 log entries');
    assert(
      logger.logs[0].contains('Retrieved user'),
      'First log should be user retrieval',
    );
  }

  // -------------------------------------------------------------------------
  // Example 2: Named bean registration with TomBean.withName
  // -------------------------------------------------------------------------
  static void example2NamedBeanRegistration() {
    print('\n2. Named bean registration with TomBean.withName:');
    print('   Registering payment gateways by name...');

    // Register payment gateways with unique names
    final primaryBean = TomBean.withName(
      'sample_primaryPayment',
      PrimaryPaymentGateway(),
    );
    final backupBean = TomBean.withName(
      'sample_backupPayment',
      BackupPaymentGateway(),
    );

    // Access using the TomBean callable syntax
    print('   - Primary gateway: ${primaryBean().gatewayName}');
    print('   - Backup gateway: ${backupBean().gatewayName}');

    primaryGatewayName = primaryBean().gatewayName;
    backupGatewayName = backupBean().gatewayName;

    // Assertions
    assert(
      primaryGatewayName == 'PrimaryGateway',
      'Primary gateway name should match',
    );
    assert(
      backupGatewayName == 'BackupGateway',
      'Backup gateway name should match',
    );
  }

  // -------------------------------------------------------------------------
  // Example 3: Resolving named beans with TomBean.fromName
  // -------------------------------------------------------------------------
  static void example3ResolvingNamedBeans() {
    print('\n3. Resolving named beans with TomBean.fromName:');

    // Resolve the beans we registered above
    final resolvedPrimary = TomBean<PaymentGateway>.fromName(
      'sample_primaryPayment',
    );
    final resolvedBackup = TomBean<PaymentGateway>.fromName(
      'sample_backupPayment',
    );

    print('   - Resolved primary: ${resolvedPrimary().gatewayName}');
    print('   - Resolved backup: ${resolvedBackup().gatewayName}');

    // Verify they are the same instances
    final primaryBean = TomBean<PaymentGateway>.fromName(
      'sample_primaryPayment',
    );
    sameInstance = identical(primaryBean(), resolvedPrimary());
    print('   - Same instance? $sameInstance');

    // Assertions
    assert(sameInstance, 'Should be the same instance');
  }

  // -------------------------------------------------------------------------
  // Example 4: Static bean access methods
  // -------------------------------------------------------------------------
  static void example4StaticBeanAccess() {
    print('\n4. Static bean access methods:');

    // Register a logger bean
    TomBean.withName("sample_logger", ConsoleLoggingService());
    TomBean.withType(ConsoleLoggingService, ConsoleLoggingService());

    // Get by name
    final byName = TomBean.getBeanByName('sample_primaryPayment');
    print('   - getBeanByName("sample_primaryPayment"): ${byName.runtimeType}');

    // Get by type
    final byType = TomBean.getBeanByType(ConsoleLoggingService);
    print('   - getBeanByType(ConsoleLoggingService): $byType');

    // Assertions
    assert(byName is PrimaryPaymentGateway, 'Should be PrimaryPaymentGateway');
    assert(byType is ConsoleLoggingService, 'Should be ConsoleLoggingService');
  }

  // -------------------------------------------------------------------------
  // Example 5: Error handling for missing beans
  // -------------------------------------------------------------------------
  static void example5ErrorHandling() {
    print('\n5. Error handling for missing beans:');

    errorKey = '';

    try {
      TomBean<PaymentGateway>.fromName('nonexistent_gateway').get();
    } on TomBeanLocatorException catch (e) {
      errorKey = e.key;
      print('   - Exception caught!');
      print('   - Error key: ${e.key}');
      print('   - Message: ${e.defaultUserMessage}');
    }

    // Assertions
    assert(errorKey.isNotEmpty, 'Should have caught an exception');
    assert(
      errorKey.contains('beanlocator'),
      'Error key should contain beanlocator',
    );
  }

  // -------------------------------------------------------------------------
  // Example 6: Using beans in a service class pattern
  // -------------------------------------------------------------------------
  static void example6ServiceClassPattern() {
    print('\n6. Using beans in a service class pattern:');
    print('   Creating a service that holds TomBean references...');

    final exampleService = ExampleServiceWithBeans();
    exampleService.doWork();

    paymentUsed = exampleService.lastPaymentGateway;
    final loggerUsed = exampleService.lastLoggerType;

    print('   - Payment gateway used: $paymentUsed');
    print('   - Logger type used: $loggerUsed');

    // Assertions
    assert(paymentUsed == 'PrimaryGateway', 'Should use primary gateway');
    assert(loggerUsed == 'ConsoleLoggingService', 'Should use console logger');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 02: Bean Dependency Patterns Example ===\n');

    example1ManualDependencyWiring();
    example2NamedBeanRegistration();
    example3ResolvingNamedBeans();
    example4StaticBeanAccess();
    example5ErrorHandling();
    example6ServiceClassPattern();

    print('\n=== Bean Dependency Patterns Example Complete ===\n');
  }
}

void run() => BeanDependencyPatternsExample.run();

void main() {
  requireAsserts();
  run();
}
