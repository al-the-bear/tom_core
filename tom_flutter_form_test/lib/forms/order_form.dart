import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase2a_state.dart';
import 'order_item_form.dart';

// ---------------------------------------------------------------------------
// OrderForm — header + TomListForm<OrderItem, OrderItemForm> for line items.
// ---------------------------------------------------------------------------

/// Order header plus a `TomListForm<OrderItem, OrderItemForm>` for line items.
///
/// Exercises `tom_flutter_ui`'s §13 List Forms pattern: a parent form owns an
/// item-list form whose sub-forms share resources via the listId ('items'),
/// and bind / save / discard fan out to every sub-form.
@tomReflector
class OrderForm extends TomForm<Order> {
  OrderForm() : super(formId: 'order');

  late final orderNumber = TomFormStringInput(
    'orderNumber',
    '',
    form: this,
    labelTextOverride: 'Order #',
    validators: [Validators.required()],
  );

  late final customer = TomFormStringInput(
    'customer',
    '',
    form: this,
    labelTextOverride: 'Customer',
    validators: [Validators.required()],
  );

  /// The list-of-sub-forms — events bubble up to this form's bus so
  /// EventLogPanel listeners attached at the parent see add/remove/
  /// reorder events alongside per-field events.
  late final OrderItemsListForm items = OrderItemsListForm(parentForm: this);

  @override
  void createFormElements() {}

  @override
  void onBound() {
    final order = currentBinding;
    if (order != null) {
      items.bind(order.items);
    }
  }

  @override
  void onUnbinding() {
    items.unbind();
  }
}

/// List form variant that exposes a `validateList` rule — Demo H-C uses
/// it to surface "at least one item required" through `TomErrorView`.
class OrderItemsListForm extends TomListForm<OrderItem, OrderItemForm> {
  OrderItemsListForm({super.parentForm})
    : super(listId: 'items', formFactory: (_) => OrderItemForm());

  @override
  OrderItem createItem() => OrderItem();

  @override
  Future<List<String>> validateList() async {
    if (length == 0) return ['error.items.minRequired'];
    return const [];
  }
}
