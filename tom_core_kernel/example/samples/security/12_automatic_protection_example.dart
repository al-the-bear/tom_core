/// Automatic protection: the tier switches, and the JSON tier at work.
///
/// Resource-key protection applies automatically in four tiers — endpoints,
/// JSON, database and UI — each with a switch that is on by default. A field
/// opts in with `@TomProtectedField`; the tiers grade it through
/// `TomResourceKeyProtection.automaticState` and withhold it when the grade
/// shows no content. The switches exist to be turned off: from a define, from
/// the command line through `applyArguments`, or from code with `disableAll`.
///
/// This example covers:
/// - The switch defaults
/// - The JSON tier leaving out a field the caller may not see
/// - A read-only grade that still serializes the field
/// - Switching one tier off, and the whole system off, from arguments
/// - The refusal of a misspelt setting
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/12_automatic_protection_example.dart
/// ```
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

/// A reflected record with one protected field.
///
/// Declared in the sample because the sample tree is one reflection domain:
/// the generator sweeps it into the registry `bootstrapSamples()` installs.
@tomReflector
class PayrollEntry {
  String? employee;

  @TomProtectedField('payroll.salary')
  int? salary;
}

TomPrincipal _clerk({
  List<String> resourceKeys = const [],
  Map<String, String> resourceRoles = const {},
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: '12', username: 'clerk'),
  aci: TomAccessControlInformation(
    resourceKeys: resourceKeys,
    resourceRoles: resourceRoles,
  ),
);

Map<String, Object?> _serializeAs(TomPrincipal principal, PayrollEntry entry) =>
    runZoned(
      () => tomReflectionInfo.getValues(entry),
      zoneValues: {TomPrincipal: principal},
    );

class AutomaticProtectionExample {
  static void example1Defaults() {
    print('1. The switch defaults:');
    TomResourceKeyProtection.restoreDefaults();

    final master = TomResourceKeyProtection.globalSettingProtectionDefault;
    final json =
        TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection;
    final database =
        TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection;
    print('   - resource keys enforced : $master');
    print('   - JSON tier              : $json');
    print('   - database tier          : $database');

    // The tiers are armed; resource keys become binding when a deployment
    // switches them on.
    assert(!master, 'resource-key enforcement is opt-in');
    assert(json && database, 'the tiers are on by default');
    print('');
  }

  static void example2JsonTier() {
    print('2. The JSON tier withholds what the caller may not see:');
    TomResourceKeyProtection.restoreDefaults();
    TomResourceKeyProtection.globalSettingProtectionDefault = true;

    final entry = PayrollEntry()
      ..employee = 'Ada'
      ..salary = 85000;

    final forClerk = _serializeAs(_clerk(), entry);
    final forPayroll = _serializeAs(_clerk(resourceKeys: ['payroll.*']), entry);
    print('   - a clerk without the key : $forClerk');
    print('   - a holder of payroll.*   : $forPayroll');

    // Left out rather than nulled, so a non-nullable reader keeps its default.
    assert(!forClerk.containsKey('salary'), 'the salary is withheld');
    assert(forPayroll['salary'] == 85000, 'a grant serializes it');

    TomResourceKeyProtection.restoreDefaults();
    print('');
  }

  static void example3ReadOnlyGrade() {
    print('3. A read-only grade still shows the value:');
    TomResourceKeyProtection.restoreDefaults();
    TomResourceKeyProtection.globalSettingProtectionDefault = true;
    TomResourceRoleRegistry.register('auditor', TomAuthState.read);

    final entry = PayrollEntry()
      ..employee = 'Ada'
      ..salary = 85000;
    final forAuditor = _serializeAs(
      _clerk(resourceRoles: {'payroll.salary': 'auditor'}),
      entry,
    );
    print('   - an auditor (read) : $forAuditor');
    assert(forAuditor['salary'] == 85000, 'read shows content');

    TomResourceRoleRegistry.reset();
    TomResourceKeyProtection.restoreDefaults();
    print('');
  }

  static void example4Arguments() {
    print('4. Switching tiers off from the command line:');
    TomResourceKeyProtection.restoreDefaults();

    // A server passes its whole argument list; anything outside the
    // tom.protection namespace is ignored.
    TomResourceKeyProtection.applyArguments([
      'port=8080',
      'tom.protection.json=false',
    ]);
    final jsonAfterOne =
        TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection;
    final databaseAfterOne =
        TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection;
    print(
      '   - tom.protection.json=false : json $jsonAfterOne, '
      'database $databaseAfterOne',
    );

    TomResourceKeyProtection.applyArguments(['tom.protection=false']);
    final uiAfterAll =
        TomResourceKeyProtection.globalSettingUseAutomaticUIProtection;
    print('   - tom.protection=false      : ui $uiAfterAll');

    assert(!jsonAfterOne && databaseAfterOne, 'one tier, and only that one');
    assert(!uiAfterAll, 'the whole system is off');

    TomResourceKeyProtection.restoreDefaults();
    print('');
  }

  static void example5MisspeltSetting() {
    print('5. A misspelt setting is refused, not ignored:');
    String? refusal;
    try {
      TomResourceKeyProtection.applyArguments(['tom.protection.jsn=false']);
    } on TomProtectionSettingException catch (e) {
      refusal = e.key;
    }
    print('   - tom.protection.jsn=false : $refusal');
    assert(
      refusal == 'security.protection.unknown_setting',
      'a tier believed off while on is the failure this prevents',
    );
    print('');
  }
}

void run() {
  print('=== 12: Automatic Protection Example ===\n');
  AutomaticProtectionExample.example1Defaults();
  AutomaticProtectionExample.example2JsonTier();
  AutomaticProtectionExample.example3ReadOnlyGrade();
  AutomaticProtectionExample.example4Arguments();
  AutomaticProtectionExample.example5MisspeltSetting();
  print('✓ All automatic protection examples passed!\n');
}

void main() {
  bootstrapSamples();
  run();
}
