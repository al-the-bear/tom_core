import 'package:tom_core_kernel/tom_core_kernel.dart';

// ---------------------------------------------------------------------------
// Company Profile — Root State
// ---------------------------------------------------------------------------

/// A deeply nested company profile demonstrating TomClass composition.
///
/// Currently only string fields are editable via forms (TomFormStringInput,
/// TomFormStringDropdown). Numeric, boolean, and collection fields are
/// included for future phases when additional field widgets are available.
@tomReflector
class CompanyProfile extends TomClass {
  // --- Basic info (string — immediately editable) ---
  late final name = TomString('');
  late final industry = TomString('');
  late final taxId = TomString('');
  late final website = TomString('');
  late final description = TomString('');

  // --- Nested sections ---
  late final headquarters = Address();
  late final ceo = Person();
  late final settings = CompanySettings();

  // --- Collections (future: list/tree editing) ---
  late final departments = TomList<Department>();
  late final tags = TomList<TomString>();
}

// ---------------------------------------------------------------------------
// Address — Reusable Nested Section
// ---------------------------------------------------------------------------

@tomReflector
class Address extends TomClass {
  late final street = TomString('');
  late final street2 = TomString('');
  late final city = TomString('');
  late final state = TomString('');
  late final zipCode = TomString('');
  late final country = TomString('');
}

// ---------------------------------------------------------------------------
// Person — Reusable Nested Section
// ---------------------------------------------------------------------------

@tomReflector
class Person extends TomClass {
  late final firstName = TomString('');
  late final lastName = TomString('');
  late final email = TomString('');
  late final phone = TomString('');
  late final title = TomString('');
}

// ---------------------------------------------------------------------------
// Department — Collection Element
// ---------------------------------------------------------------------------

@tomReflector
class Department extends TomClass {
  late final name = TomString('');
  late final code = TomString('');
  late final budget = TomString(''); // String until TomFormDoubleInput exists
  late final manager = Person();
  late final employees = TomList<Employee>();
}

// ---------------------------------------------------------------------------
// Employee — Nested Collection Element
// ---------------------------------------------------------------------------

@tomReflector
class Employee extends TomClass {
  late final employeeId = TomString('');
  late final firstName = TomString('');
  late final lastName = TomString('');
  late final email = TomString('');
  late final role = TomString('');
  late final department = TomString('');
  late final skills = TomList<Skill>();
}

// ---------------------------------------------------------------------------
// Skill — Leaf Collection Element (tree depth: 3)
// ---------------------------------------------------------------------------

@tomReflector
class Skill extends TomClass {
  late final name = TomString('');
  late final level = TomString(''); // beginner | intermediate | expert
}

// ---------------------------------------------------------------------------
// Company Settings — Nested Section with Sub-Sections
// ---------------------------------------------------------------------------

@tomReflector
class CompanySettings extends TomClass {
  late final timezone = TomString('UTC');
  late final locale = TomString('en_US');
  late final currency = TomString('USD');
  late final dateFormat = TomString('yyyy-MM-dd');
  late final notifications = NotificationPrefs();
}

// ---------------------------------------------------------------------------
// Notification Preferences — Leaf Nested Section
// ---------------------------------------------------------------------------

@tomReflector
class NotificationPrefs extends TomClass {
  late final emailEnabled = TomBool(true);
  late final smsEnabled = TomBool(false);
  late final frequency = TomString('daily');
  late final emailAddress = TomString('');
}

// ApplicationState and demoState global are in application_state.dart
