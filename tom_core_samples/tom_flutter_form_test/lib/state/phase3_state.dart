import 'package:tom_core_kernel/tom_core_kernel.dart';

// ---------------------------------------------------------------------------
// Phase 3 state — numeric / date-time / duration demo backings
// ---------------------------------------------------------------------------
//
// Backing TomClasses for Demos I and J. Each form binds one of these so
// bind / save / discard / TomFormInspector all work the same way as in
// Phase 1+2 demos. Field-side state (e.g. TimeOfDay, Duration, ranges)
// lives on the form itself — TomField extends TomObject<T> and carries
// its own value, so non-trivial value types don't need a custom
// upstream observable.

@tomReflector
class NumericDemoState extends TomClass {
  late final quantity = TomInt(8);
  late final priceUSD = TomDouble(199.99);
  late final priceGeneric = TomDouble(199.99);
  late final discount = TomDouble(0.15);
  late final brightness = TomInt(50);
  late final taxRate = TomDouble(7.5);
}

@tomReflector
class DateTimeDemoState extends TomClass {
  late final eventDate = TomDateTime(DateTime(2026, 5, 12));
  late final eventDateInline = TomDateTime(DateTime(2026, 5, 12));
  late final eventDateTime = TomDateTime(DateTime(2026, 5, 12, 9, 30));
}

NumericDemoState phase3NumericState = NumericDemoState();
DateTimeDemoState phase3DateState = DateTimeDemoState();
