// ignore_for_file: unused_local_variable
/// Demonstrates bean dependency injection patterns with executable code.
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

// =============================================================================
// Service Interfaces
// =============================================================================

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

// =============================================================================
// Service Implementations
// =============================================================================

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

/// Primary payment gateway (e.g., Stripe).
class PrimaryPaymentGateway implements PaymentGateway {
  @override
  String get gatewayName => 'PrimaryGateway';

  @override
  bool charge(String userId, double amount) {
    print('     [$gatewayName] Charging $userId: \$${amount.toStringAsFixed(2)}');
    return true;
  }
}

/// Backup payment gateway (e.g., PayPal).
class BackupPaymentGateway implements PaymentGateway {
  @override
  String get gatewayName => 'BackupGateway';

  @override
  bool charge(String userId, double amount) {
    print('     [$gatewayName] Charging $userId: \$${amount.toStringAsFixed(2)}');
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
    _logger.info('Creating order for $userName: $item @ \$${price.toStringAsFixed(2)}');

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

void run() {
  print('=== 02: Bean Dependency Patterns Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Manual dependency wiring (simulating DI container)
  // -------------------------------------------------------------------------
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
  final orderId = orderService.createOrder(42, 'Widget Pro', 99.95);
  print('   - Order ID: $orderId');

  // Show captured logs
  print('\n   Captured logs from dependency chain:');
  for (final log in logger.logs) {
    print('   - $log');
  }

  final logCount1 = logger.logs.length;

  // -------------------------------------------------------------------------
  // Example 2: Named bean registration with TomBean.withName
  // -------------------------------------------------------------------------
  print('\n2. Named bean registration with TomBean.withName:');
  print('   Registering payment gateways by name...');

  // Register payment gateways with unique names for this example
  final primaryBean =
      TomBean.withName('ex2_primaryPayment', PrimaryPaymentGateway());
  final backupBean =
      TomBean.withName('ex2_backupPayment', BackupPaymentGateway());

  // Access using the TomBean callable syntax
  print('   - Primary gateway: ${primaryBean().gatewayName}');
  print('   - Backup gateway: ${backupBean().gatewayName}');

  final primaryGatewayName = primaryBean().gatewayName;
  final backupGatewayName = backupBean().gatewayName;

  // -------------------------------------------------------------------------
  // Example 3: Resolving named beans with TomBean.fromName
  // -------------------------------------------------------------------------
  print('\n3. Resolving named beans with TomBean.fromName:');

  // Resolve the beans we registered above
  final resolvedPrimary =
      TomBean<PaymentGateway>.fromName('ex2_primaryPayment');
  final resolvedBackup = TomBean<PaymentGateway>.fromName('ex2_backupPayment');

  print('   - Resolved primary: ${resolvedPrimary().gatewayName}');
  print('   - Resolved backup: ${resolvedBackup().gatewayName}');

  // Verify they are the same instances
  final sameInstance = identical(primaryBean(), resolvedPrimary());
  print('   - Same instance? $sameInstance');

  // -------------------------------------------------------------------------
  // Example 4: Static bean access methods
  // -------------------------------------------------------------------------
  print('\n4. Static bean access methods:');

  // Get by name
  final byName = TomBean.getBeanByName('ex2_primaryPayment');
  print('   - getBeanByName("ex2_primaryPayment"): ${byName.runtimeType}');

  // Register the same logger under both a name and its type so it can be
  // resolved either way: fromName('ex2_logger') (used by the service pattern
  // below) and getBeanByType(ConsoleLoggingService) (used here).
  final loggerService = ConsoleLoggingService();
  TomBean.withName('ex2_logger', loggerService);
  TomBean.withType(ConsoleLoggingService, loggerService);
  final byType = TomBean.getBeanByType(ConsoleLoggingService);
  print('   - getBeanByType(ConsoleLoggingService): ${byType.runtimeType}');

  // -------------------------------------------------------------------------
  // Example 5: Error handling for missing beans
  // -------------------------------------------------------------------------
  print('\n5. Error handling for missing beans:');

  String errorKey = '';
  String errorMessage = '';

  try {
    TomBean<PaymentGateway>.fromName('nonexistent_gateway').get();
  } on TomBeanLocatorException catch (e) {
    errorKey = e.key;
    errorMessage = e.defaultUserMessage;
    print('   - Exception caught!');
    print('   - Error key: $errorKey');
    print('   - Message: $errorMessage');
  }

  // -------------------------------------------------------------------------
  // Example 6: Using beans in a service class pattern
  // -------------------------------------------------------------------------
  print('\n6. Using beans in a service class pattern:');
  print('   Creating a service that holds TomBean references...');

  // This simulates how a @TomComponent class would declare dependencies
  final exampleService = ExampleServiceWithBeans();
  exampleService.doWork();

  final paymentUsed = exampleService.lastPaymentGateway;
  final loggerUsed = exampleService.lastLoggerType;

  print('   - Payment gateway used: $paymentUsed');
  print('   - Logger type used: $loggerUsed');

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Dependency chain execution
  assert(orderId.startsWith('ORD-'), 'Order ID should start with ORD-');
  assert(logCount1 == 3, 'Should have 3 log entries');
  assert(logger.logs[0].contains('Retrieved user'));
  assert(logger.logs[1].contains('Creating order'));
  assert(logger.logs[2].contains('Order created'));

  // Example 2: Named bean registration
  assert(primaryGatewayName == 'PrimaryGateway');
  assert(backupGatewayName == 'BackupGateway');

  // Example 3: Named bean resolution
  assert(sameInstance, 'Should be the same instance');

  // Example 4: Static access
  assert(byName is PrimaryPaymentGateway);
  assert(byType is ConsoleLoggingService);

  // Example 5: Error handling. A *named* lookup miss raises the by-name key
  // (an unnamed/type lookup miss would instead raise no_bean_found_uninitialized).
  assert(errorKey == 'beanlocator.bean_access.bean_not_found_by_name');
  assert(errorMessage.contains('PaymentGateway'));

  // Example 6: Service pattern
  assert(paymentUsed == 'PrimaryGateway');
  assert(loggerUsed == 'ConsoleLoggingService');
}

// =============================================================================
// Example Service Class Pattern
// =============================================================================

/// Demonstrates how a service class uses TomBean fields for dependencies.
///
/// In production, this would be annotated with @TomComponent and @tomReflector.
/// The TomBean fields would be automatically resolved by the bean context.
class ExampleServiceWithBeans {
  // These TomBean fields would be auto-resolved in a real application
  final TomBean<PaymentGateway> payment =
      TomBean.fromName('ex2_primaryPayment');
  final TomBean<ConsoleLoggingService> logger = TomBean.fromName('ex2_logger');

  String lastPaymentGateway = '';
  String lastLoggerType = '';

  void doWork() {
    // Using callable syntax: payment() instead of payment.get()
    lastPaymentGateway = payment().gatewayName;
    lastLoggerType = logger().runtimeType.toString();

    print('   - Payment gateway resolved: $lastPaymentGateway');
    print('   - Logger resolved: $lastLoggerType');

    // Use the services
    logger().info('ExampleServiceWithBeans.doWork() called');
    payment().charge('example_user', 10.00);
  }
}
