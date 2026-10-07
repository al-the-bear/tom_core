/// Discovered components receive their dependencies through the constructor.
///
/// Discovery supplies every required parameter of a component's unnamed
/// constructor from the bean bound under exactly the parameter's declared type
/// — a registration made before the pass, or a component the pass builds first.
/// The fixtures are declared dependent-first on purpose: building them in
/// declaration order would need [CheckoutDesk] before the orders it requires,
/// so the pass passing at all shows it orders construction by the
/// constructors rather than by the registry.
///
/// The lazy form stays: [PingHandle] and [PongHandle] depend on each other
/// through `TomBean` fields, which is a cycle only through constructors would
/// make unbuildable.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_constructor_injection_test.reflection.dart';
import 'support/bean_selection_support.dart';

/// A clock registered before discovery; no component supplies one.
abstract class DeskClock {
  String now();
}

class FixedDeskClock implements DeskClock {
  @override
  String now() => '09:00';
}

/// Requires the orders positionally and the clock by a required named
/// parameter, and leaves an optional one to its default.
@tomReflector
@TomComponent(TomNoInterface)
class CheckoutDesk {
  CheckoutDesk(this.orders, {required this.clock, this.label = 'desk'});

  final OrderBook orders;
  final DeskClock clock;
  final String label;

  String checkout(int id) => '${clock.now()} ${orders.place(id)}';
}

/// An interface whose implementation holds its dependency `final`.
abstract class OrderBook {
  String place(int id);
}

@tomReflector
@TomComponent(OrderBook)
class StockedOrderBook implements OrderBook {
  StockedOrderBook(this.stock);

  final StockLedger stock;

  @override
  String place(int id) => 'placed ${stock.describe(id)}';
}

/// The leaf: no dependencies.
abstract class StockLedger {
  String describe(int id);
}

@tomReflector
@TomComponent(StockLedger)
class MemoryStockLedger implements StockLedger {
  @override
  String describe(int id) => 'item $id';
}

/// Mutual dependency through handles — supported, because neither resolves
/// during construction.
@tomReflector
@TomComponent(TomNoInterface)
class PingHandle {
  final TomBean<PongHandle> pong = TomBean();
}

@tomReflector
@TomComponent(TomNoInterface)
class PongHandle {
  final TomBean<PingHandle> ping = TomBean();
}

void discover() => discoverBeansIn(
  prodEnvironment,
  platformWeb,
  beforeDiscovery: () => TomBean.withType<DeskClock>(FixedDeskClock()),
);

void main() {
  initializeReflection();

  test('a chain of constructor dependencies is built dependencies first', () {
    discover();

    final desk = TomBean<CheckoutDesk>().get();
    expect(desk.checkout(7), equals('09:00 placed item 7'));
  });

  test('a supplied dependency is the bound bean, not a copy', () {
    discover();

    final desk = TomBean<CheckoutDesk>().get();
    final orders = TomBean<OrderBook>().get() as StockedOrderBook;
    expect(desk.orders, same(orders));
    expect(orders.stock, same(TomBean<StockLedger>().get()));
  });

  test('a registration made before the pass supplies a parameter', () {
    discover();

    expect(TomBean<CheckoutDesk>().get().clock, isA<FixedDeskClock>());
  });

  test('an optional parameter is left to its default', () {
    discover();

    expect(TomBean<CheckoutDesk>().get().label, equals('desk'));
  });

  test('a mutual dependency through handles still resolves', () {
    discover();

    final ping = TomBean<PingHandle>().get();
    final pong = TomBean<PongHandle>().get();
    expect(ping.pong.get(), same(pong));
    expect(pong.ping.get(), same(ping));
  });
}
