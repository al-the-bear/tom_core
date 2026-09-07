/// Advanced Access Control Example
///
/// This example demonstrates advanced access control mechanisms:
/// - TomEntitlementAccess for entitlement-based access with pattern matching
/// - TomResourceKeyAccess for field-level protection
/// - TomCustomAccess for custom authorization handlers
/// - TomResourceKeyProtection helper functions
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/03_advanced_access_control_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Test Principals Setup
// ============================================================================

final premiumPrincipal = TomPrincipal(
  authenticated: true,
  user: TomUser(id: 1, username: 'premium_user'),
  aci: TomAccessControlInformation(
    roles: ['user'],
    groups: ['premium-subscribers'],
    entitlements: [
      'feature.reports.view',
      'feature.reports.export',
      'feature.dashboard.edit',
      'feature.premium.analytics',
    ],
    resourceKeys: ['user.email', 'user.phone', 'user.salary'],
  ),
);

final basicPrincipal = TomPrincipal(
  authenticated: true,
  user: TomUser(id: 2, username: 'basic_user'),
  aci: TomAccessControlInformation(
    roles: ['user'],
    groups: ['basic-plan'],
    entitlements: ['feature.reports.view', 'feature.dashboard.view'],
    resourceKeys: ['user.email'],
  ),
);

final guestPrincipal = TomPrincipal(
  authenticated: false,
  user: TomUser(),
  aci: TomAccessControlInformation(),
);

// ============================================================================
// Example Class: TomEntitlementAccess
// ============================================================================

class EntitlementAccessExample {
  static bool? exactMatchPremium;
  static bool? exactMatchBasic;
  static bool? patternMatchPremium;
  static bool? patternMatchBasic;
  static bool? multiPatternPremium;
  static bool entitlementAccessWorks = false;

  static void example1ExactEntitlementMatch() {
    print('1. Exact entitlement matching:');

    // Check for exact entitlement
    const exportAccess = TomEntitlementAccess(['feature.reports.export']);

    exactMatchPremium = exportAccess.checkAccessibility(premiumPrincipal);
    exactMatchBasic = exportAccess.checkAccessibility(basicPrincipal);

    print('   - Premium has export: $exactMatchPremium');
    print('   - Basic has export: $exactMatchBasic');

    // Assertions
    assert(exactMatchPremium == true, 'Premium should have export entitlement');
    assert(
      exactMatchBasic == false,
      'Basic should not have export entitlement',
    );
  }

  static void example2PatternEntitlementMatch() {
    print('\n2. Pattern-based entitlement matching:');

    // Match any reports entitlement using regex pattern
    const reportsAccess = TomEntitlementAccess([r'feature\.reports\..*']);

    patternMatchPremium = reportsAccess.checkAccessibility(premiumPrincipal);
    patternMatchBasic = reportsAccess.checkAccessibility(basicPrincipal);

    print('   - Pattern: feature\\.reports\\..*');
    print('   - Premium matches: $patternMatchPremium');
    print('   - Basic matches: $patternMatchBasic');

    // Both should match since both have at least feature.reports.view
    assert(patternMatchPremium == true, 'Premium should match reports pattern');
    assert(patternMatchBasic == true, 'Basic should match reports pattern');
  }

  static void example3MultiplePatterns() {
    print('\n3. Multiple patterns (OR logic):');

    // Match premium features OR admin access
    const premiumOrAdminAccess = TomEntitlementAccess([
      r'feature\.premium\..*',
      r'admin\..*',
    ]);

    multiPatternPremium = premiumOrAdminAccess.checkAccessibility(
      premiumPrincipal,
    );
    final multiPatternBasic = premiumOrAdminAccess.checkAccessibility(
      basicPrincipal,
    );

    print('   - Patterns: [premium.*, admin.*]');
    print('   - Premium matches: $multiPatternPremium');
    print('   - Basic matches: $multiPatternBasic');

    entitlementAccessWorks =
        exactMatchPremium == true &&
        exactMatchBasic == false &&
        multiPatternPremium == true;

    // Assertions
    assert(multiPatternPremium == true, 'Premium should match premium pattern');
    assert(multiPatternBasic == false, 'Basic should not match either pattern');
    assert(entitlementAccessWorks, 'Entitlement access should work');
  }
}

// ============================================================================
// Example Class: TomResourceKeyAccess
// ============================================================================

class ResourceKeyAccessExample {
  static bool? emailAccessPremium;
  static bool? emailAccessBasic;
  static bool? salaryAccessPremium;
  static bool? salaryAccessBasic;
  static bool? salaryAccessUnprotected;
  static bool resourceKeyAccessWorks = false;

  static void example4ResourceKeyAccess() {
    print('\n4. Resource key access control:');

    // Enable resource protection for this test
    TomResourceKeyProtection.globalSettingProtectionDefault = true;

    // Check access to email (both have)
    const emailAccess = TomResourceKeyAccess('user.email');
    // Check access to salary (only premium has)
    const salaryAccess = TomResourceKeyAccess('user.salary');

    print('   - Resource key protection enabled');
    print('   - Premium resource keys: ${premiumPrincipal.aci.resourceKeys}');
    print('   - Basic resource keys: ${basicPrincipal.aci.resourceKeys}');

    // Asked the same way as every other control in the family: hand it the
    // principal you want an answer about. No zone is installed here, and none
    // is needed — the argument is the operand.
    emailAccessPremium = emailAccess.checkAccessibility(premiumPrincipal);
    emailAccessBasic = emailAccess.checkAccessibility(basicPrincipal);
    salaryAccessPremium = salaryAccess.checkAccessibility(premiumPrincipal);
    salaryAccessBasic = salaryAccess.checkAccessibility(basicPrincipal);

    print('   - Premium may see email:  $emailAccessPremium');
    print('   - Basic may see email:    $emailAccessBasic');
    print('   - Premium may see salary: $salaryAccessPremium');
    print('   - Basic may see salary:   $salaryAccessBasic');

    resourceKeyAccessWorks =
        emailAccessPremium == true &&
        emailAccessBasic == true &&
        salaryAccessPremium == true &&
        salaryAccessBasic == false;

    // Reset protection setting. The master switch is the second operand of
    // this control and of nothing else: with it off, resource keys are not
    // enforced, so the principal who was just refused is now let through.
    TomResourceKeyProtection.globalSettingProtectionDefault = false;
    salaryAccessUnprotected = salaryAccess.checkAccessibility(basicPrincipal);

    print(
      '   - Protection off, basic may see salary: $salaryAccessUnprotected',
    );

    // Assertions
    assert(salaryAccessPremium == true, 'Premium should have salary access');
    assert(salaryAccessBasic == false, 'Basic should not have salary access');
    assert(resourceKeyAccessWorks, 'Resource key access should work');
    assert(
      salaryAccessUnprotected == true,
      'the global switch gates the whole rule, not just the default',
    );
  }
}

// ============================================================================
// Example Class: TomResourceKeyProtection
// ============================================================================

class ResourceKeyProtectionExample {
  static late String protectedEmail;
  static late String unprotectedEmail;
  static bool? isEmailProtected;
  static bool? isSalaryProtected;

  static void example5ProtectFunction() {
    print('\n5. TomResourceKeyProtection.protect() function:');

    // The protection depends on zone context
    // Here we demonstrate the API without zone context
    TomResourceKeyProtection.globalSettingProtectionDefault = false;

    final realEmail = 'john@example.com';
    final fallback = '[hidden]';

    // When protection is disabled, always returns real value
    protectedEmail = TomResourceKeyProtection.protect(
      realEmail,
      fallback,
      'user.email',
    );

    print('   - Protection disabled: $protectedEmail');
    assert(
      protectedEmail == realEmail,
      'Should return real value when disabled',
    );

    // Reset
    TomResourceKeyProtection.globalSettingProtectionDefault = false;
  }

  static void example6TomProtectHelpers() {
    print('\n6. tomProtect() and tomProtected() helper functions:');

    TomResourceKeyProtection.globalSettingProtectionDefault = false;

    // tomProtect is a shorthand for TomResourceKeyProtection.protect
    final protectedValue = tomProtect(
      'sensitive data',
      '[redacted]',
      'data.key',
    );
    print('   - tomProtect(): $protectedValue');

    // tomProtected checks if a resource is protected
    final isProtected = tomProtected('some.resource.key');
    print('   - tomProtected(): $isProtected');

    // Assertions
    assert(
      protectedValue == 'sensitive data',
      'Should return real when disabled',
    );
    assert(isProtected == false, 'Should not be protected when disabled');

    TomResourceKeyProtection.globalSettingProtectionDefault = false;
  }
}

// ============================================================================
// Example Class: TomCustomAccess
// ============================================================================

/// A [TomAccessControlHandler]: does this principal own this document?
///
/// A top-level function rather than a closure so it can be named by its type
/// below — the point being that the extension point is an ordinary function
/// signature, not a class to subclass.
bool _isDocumentOwner(TomPrincipal? principal, String docId) {
  if (principal == null) return false;
  // Simulate ownership check - user 1 owns document 123
  if (principal.id == 1 && docId == '123') return true;
  // User 2 owns document 456
  if (principal.id == 2 && docId == '456') return true;
  return false;
}

class CustomAccessExample {
  static bool? documentOwnerAccess;
  static bool? documentNonOwnerAccess;
  static bool handlerRegistered = false;
  static bool customAccessWorks = false;

  static void example7RegisterHandler() {
    print('\n7. Registering custom access handler:');

    // The handler's shape is TomAccessControlHandler — the whole extension
    // point of the custom control, and deliberately narrow: a principal, a
    // resource id, a boolean. It is not graded and it is not async, so a check
    // that needs a database round trip belongs behind a cache, not here.
    const TomAccessControlHandler isDocumentOwner = _isDocumentOwner;

    // Register a custom handler for document ownership checks
    if (!TomCustomAccess.handlerExists('isDocumentOwner')) {
      TomCustomAccess.registerHandler('isDocumentOwner', isDocumentOwner);
    }

    handlerRegistered = TomCustomAccess.handlerExists('isDocumentOwner');
    print('   - Handler "isDocumentOwner" registered: $handlerRegistered');

    // Assertions
    assert(handlerRegistered, 'Handler should be registered');
    // The registry hands back the very function that was registered, so a
    // handler can be shared between a control and a direct call.
    assert(
      identical(TomCustomAccess.getHandler('isDocumentOwner'), isDocumentOwner),
    );
    assert(isDocumentOwner(null, '123') == false);
  }

  static void example8UseCustomHandler() {
    print('\n8. Using custom access handler:');

    // Create access control instances for different documents
    const doc123Access = TomCustomAccess(
      handler: 'isDocumentOwner',
      resourceId: '123',
    );

    const doc456Access = TomCustomAccess(
      handler: 'isDocumentOwner',
      resourceId: '456',
    );

    // Check access - premium user (id=1) owns doc 123
    documentOwnerAccess = doc123Access.checkAccessibility(premiumPrincipal);
    documentNonOwnerAccess = doc456Access.checkAccessibility(premiumPrincipal);

    print('   - Premium owns doc 123: $documentOwnerAccess');
    print('   - Premium owns doc 456: $documentNonOwnerAccess');

    // Basic user (id=2) owns doc 456
    final basicOwnsDoc456 = doc456Access.checkAccessibility(basicPrincipal);
    print('   - Basic owns doc 456: $basicOwnsDoc456');

    customAccessWorks =
        documentOwnerAccess == true &&
        documentNonOwnerAccess == false &&
        basicOwnsDoc456 == true;

    // Assertions
    assert(documentOwnerAccess == true, 'Premium should own doc 123');
    assert(documentNonOwnerAccess == false, 'Premium should not own doc 456');
    assert(basicOwnsDoc456 == true, 'Basic should own doc 456');
    assert(customAccessWorks, 'Custom access should work');
  }

  static void example9VerifyHandler() {
    print('\n9. Verifying handler existence:');

    const validAccess = TomCustomAccess(
      handler: 'isDocumentOwner',
      resourceId: '123',
    );

    const invalidAccess = TomCustomAccess(
      handler: 'nonExistentHandler',
      resourceId: '123',
    );

    final validHandlerExists = validAccess.verifyHandler();
    final invalidHandlerExists = invalidAccess.verifyHandler();

    print('   - Valid handler exists: $validHandlerExists');
    print('   - Invalid handler exists: $invalidHandlerExists');

    // Assertions
    assert(validHandlerExists == true, 'Valid handler should exist');
    assert(invalidHandlerExists == false, 'Invalid handler should not exist');
  }
}

// ============================================================================
// Example Class: Global Settings
// ============================================================================

class GlobalSettingsExample {
  static void example10GlobalProtectionSettings() {
    print('\n10. Global protection settings:');

    // Show available global settings
    print(
      '   - globalSettingProtectionDefault: '
      '${TomResourceKeyProtection.globalSettingProtectionDefault}',
    );
    print(
      '   - globalSettingUseAutomaticEndpointProtection: '
      '${TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection}',
    );
    print(
      '   - globalSettingUseAutomaticJsonProtection: '
      '${TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection}',
    );
    print(
      '   - globalSettingUseAutomaticDatabaseProtection: '
      '${TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection}',
    );

    // These can be configured at app startup
    // TomResourceKeyProtection.globalSettingProtectionDefault = true;
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 03: Advanced Access Control Example ===\n');

  // Entitlement access examples
  EntitlementAccessExample.example1ExactEntitlementMatch();
  EntitlementAccessExample.example2PatternEntitlementMatch();
  EntitlementAccessExample.example3MultiplePatterns();

  // Resource key access examples
  ResourceKeyAccessExample.example4ResourceKeyAccess();

  // Resource key protection examples
  ResourceKeyProtectionExample.example5ProtectFunction();
  ResourceKeyProtectionExample.example6TomProtectHelpers();

  // Custom access examples
  CustomAccessExample.example7RegisterHandler();
  CustomAccessExample.example8UseCustomHandler();
  CustomAccessExample.example9VerifyHandler();

  // Global settings
  GlobalSettingsExample.example10GlobalProtectionSettings();

  print('\n✓ All advanced access control examples passed!\n');
}

void main() {
  prepareSampleProcess();
  run();
}
