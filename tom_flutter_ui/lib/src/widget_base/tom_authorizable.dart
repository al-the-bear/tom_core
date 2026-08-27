// `TomAuthorizable` is declared by tom_core_kernel; widget_base re-exports it
// so a widget implementing the interface needs only the widget_base barrel.
//
// Via the kernel's public barrel, not the `src/tombase/security/` path that
// declares it: `lib/src/` is private by Dart convention, and naming it would
// couple this package to the kernel's internal layout.
export 'package:tom_core_kernel/tom_core_kernel.dart' show TomAuthorizable;
