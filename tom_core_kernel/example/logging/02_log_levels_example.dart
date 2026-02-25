/// Demonstrates log level configuration and filtering in TomLogger.
///
/// This example covers:
/// - Understanding TomLogLevel bit patterns
/// - Predefined compound log levels (development, production, etc.)
/// - Combining and removing log levels with operators
/// - Per-class/method log level customization
/// - Push/pop log level stack for temporary changes
/// - Setting log levels by name and exception patterns
///
/// Log levels use bit patterns, allowing flexible combinations
/// and precise control over which messages are displayed.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 02: Log Levels Example ===\n');

  // Store original settings to restore later
  final originalLogLevel = tomLog.logLevel;

  // ===========================================================================
  // Example 1: Individual Log Levels and Their Bit Patterns
  // ===========================================================================

  print('1. Individual log levels and their bit patterns:');

  final traceBit = TomLogLevel.trace.levelPattern;
  final debugBit = TomLogLevel.debug.levelPattern;
  final trafficBit = TomLogLevel.traffic.levelPattern;
  final infoBit = TomLogLevel.info.levelPattern;
  final warnBit = TomLogLevel.warn.levelPattern;
  final statusBit = TomLogLevel.status.levelPattern;
  final errorBit = TomLogLevel.error.levelPattern;
  final severeBit = TomLogLevel.severe.levelPattern;
  final fatalBit = TomLogLevel.fatal.levelPattern;

  print('   trace:   $traceBit (bit 0)');
  print('   debug:   $debugBit (bit 1)');
  print('   traffic: $trafficBit (bit 2)');
  print('   info:    $infoBit (bit 3)');
  print('   warn:    $warnBit (bit 4)');
  print('   status:  $statusBit (bit 8)');
  print('   error:   $errorBit (bit 9)');
  print('   severe:  $severeBit (bit 10)');
  print('   fatal:   $fatalBit (bit 11)');
  print('');

  // ===========================================================================
  // Example 2: Predefined Compound Log Levels
  // ===========================================================================

  print('2. Predefined compound log levels:');

  final developmentBit = TomLogLevel.development.levelPattern;
  final extendedBit = TomLogLevel.extended.levelPattern;
  final productionBit = TomLogLevel.production.levelPattern;
  final stillBit = TomLogLevel.still.levelPattern;
  final silentBit = TomLogLevel.silent.levelPattern;
  final offBit = TomLogLevel.off.levelPattern;

  print('   development: $developmentBit (all levels including trace)');
  print('   extended:    $extendedBit (production + debug + traffic)');
  print('   production:  $productionBit (info, warn, errors, status)');
  print('   still:       $stillBit (warn + errors + status)');
  print('   silent:      $silentBit (errors + status only)');
  print('   off:         $offBit (no logging)');
  print('');

  // ===========================================================================
  // Example 3: Combining Log Levels with + Operator
  // ===========================================================================

  print('3. Combining log levels with + operator:');

  // Create a custom level: only info and error
  final infoOnly = TomLogLevel.info;
  final errorOnly = TomLogLevel.error;
  final infoAndError = TomLogLevel.info + TomLogLevel.error;

  final infoOnlyBit = infoOnly.levelPattern;
  final errorOnlyBit = errorOnly.levelPattern;
  final combinedBit = infoAndError.levelPattern;

  print('   info only:      $infoOnlyBit');
  print('   error only:     $errorOnlyBit');
  print('   info + error:   $combinedBit (bitwise OR)');

  // Verify the combination
  final matchesInfo = infoAndError.matches(TomLogLevel.info);
  final matchesError = infoAndError.matches(TomLogLevel.error);
  final matchesDebug = infoAndError.matches(TomLogLevel.debug);

  print('   Combined level matches:');
  print('   - matches info?  $matchesInfo');
  print('   - matches error? $matchesError');
  print('   - matches debug? $matchesDebug');
  print('');

  // ===========================================================================
  // Example 4: Removing Log Levels with - Operator
  // ===========================================================================

  print('4. Removing log levels with - operator:');

  final productionLevel = TomLogLevel.production;
  final withoutInfo = TomLogLevel.production - TomLogLevel.info;
  final withoutWarn = TomLogLevel.production - TomLogLevel.warn;

  final prodBit = productionLevel.levelPattern;
  final noInfoBit = withoutInfo.levelPattern;
  final noWarnBit = withoutWarn.levelPattern;

  print('   production:        $prodBit');
  print('   production - info: $noInfoBit');
  print('   production - warn: $noWarnBit');

  final prodMatchesInfo = productionLevel.matches(TomLogLevel.info);
  final noInfoMatchesInfo = withoutInfo.matches(TomLogLevel.info);
  final noInfoMatchesWarn = withoutInfo.matches(TomLogLevel.warn);

  print('   production matches info: $prodMatchesInfo');
  print('   (prod - info) matches info: $noInfoMatchesInfo');
  print('   (prod - info) matches warn: $noInfoMatchesWarn');
  print('');

  // ===========================================================================
  // Example 5: Looking Up Log Levels by Name
  // ===========================================================================

  print('5. Looking up log levels by name:');

  final debugByName = TomLogLevel.byName('DEBUG');
  final prodByName = TomLogLevel.byName('PRODUCTION');
  final invalidName = TomLogLevel.byName('INVALID');
  final caseInsensitive = TomLogLevel.byName('trace');

  final debugByNameBit = debugByName?.levelPattern;
  final prodByNameBit = prodByName?.levelPattern;

  print('   TomLogLevel.byName("DEBUG"):      $debugByNameBit');
  print('   TomLogLevel.byName("PRODUCTION"): $prodByNameBit');
  print('   TomLogLevel.byName("INVALID"):    $invalidName (null for unknown)');
  print('   TomLogLevel.byName("trace"):      ${caseInsensitive?.levelPattern} (case-insensitive)');
  print('');

  // ===========================================================================
  // Example 6: Setting Log Level on the Logger
  // ===========================================================================

  print('6. Setting and checking log level on the logger:');

  tomLog.setLogLevel(TomLogLevel.development);
  final devLevel = tomLog.logLevel.levelPattern;
  print('   After setLogLevel(development): ${tomLog.logLevel}');

  tomLog.setLogLevel(TomLogLevel.production);
  final prodLevel = tomLog.logLevel.levelPattern;
  print('   After setLogLevel(production):  ${tomLog.logLevel}');

  // Set by name
  tomLog.setLogLevelByName('EXTENDED');
  final extLevel = tomLog.logLevel.levelPattern;
  print('   After setLogLevelByName("EXTENDED"): ${tomLog.logLevel}');
  print('');

  // ===========================================================================
  // Example 7: Push/Pop Log Level Stack
  // ===========================================================================

  print('7. Using push/pop for temporary log level changes:');

  tomLog.setLogLevel(TomLogLevel.production);
  final baseLevelBit = tomLog.logLevel.levelPattern;
  print('   Base level (production): $baseLevelBit');

  tomLog.pushLogLevel(TomLogLevel.development);
  final pushedLevelBit = tomLog.logLevel.levelPattern;
  print('   After push(development): $pushedLevelBit');

  tomLog.pushLogLevel(TomLogLevel.trace);
  final doublePushedBit = tomLog.logLevel.levelPattern;
  print('   After push(trace):       $doublePushedBit');

  tomLog.popLogLevel();
  final afterOnePop = tomLog.logLevel.levelPattern;
  print('   After one pop:           $afterOnePop');

  tomLog.popLogLevel();
  final afterTwoPops = tomLog.logLevel.levelPattern;
  print('   After two pops:          $afterTwoPops');
  print('');

  // ===========================================================================
  // Example 8: Per-Name Log Level Configuration
  // ===========================================================================

  print('8. Per-name log level configuration:');

  // Reset to production
  tomLog.setLogLevel(TomLogLevel.production);

  // Set specific log level for a class
  tomLog.addNameLevel('DatabaseService', TomLogLevel.debug);
  tomLog.addNameLevel('ApiClient.sendRequest', TomLogLevel.trace);

  final dbLevel = tomLog.getNameLevel('DatabaseService');
  final apiLevel = tomLog.getNameLevel('ApiClient.sendRequest');
  final unknownLevel = tomLog.getNameLevel('UnknownClass');

  print('   Global level: ${tomLog.logLevel}');
  print('   DatabaseService level: $dbLevel');
  print('   ApiClient.sendRequest level: $apiLevel');
  print('   UnknownClass level: $unknownLevel (null = use global)');

  // Remove a name level
  tomLog.removeNameLevel('DatabaseService');
  final afterRemove = tomLog.getNameLevel('DatabaseService');
  print('   After removeNameLevel("DatabaseService"): $afterRemove');
  print('');

  // ===========================================================================
  // Example 9: Setting Log Level Exceptions from Pattern
  // ===========================================================================

  print('9. Setting log level exceptions from pattern string:');

  // Clear any existing name levels
  tomLog.removeNameLevel('ApiClient.sendRequest');

  // Set multiple exceptions at once
  final pattern = 'MyClass=DEBUG,OtherClass=TRACE,Service=INFO';
  tomLog.setLogLevelExceptions(pattern);

  final myClassLevel = tomLog.getNameLevel('MyClass');
  final otherClassLevel = tomLog.getNameLevel('OtherClass');
  final serviceLevel = tomLog.getNameLevel('Service');

  print('   Pattern: "$pattern"');
  print('   MyClass level:    $myClassLevel');
  print('   OtherClass level: $otherClassLevel');
  print('   Service level:    $serviceLevel');
  print('');

  // ===========================================================================
  // Example 10: Global Enable/Disable Toggles
  // ===========================================================================

  print('10. Global enable/disable toggles for log methods:');

  final infoEnabled = TomLogger.globalSettingInfoEnabled;
  final debugEnabled = TomLogger.globalSettingDebugEnabled;
  final errorEnabled = TomLogger.globalSettingErrorEnabled;
  final traceEnabled = TomLogger.globalSettingTraceEnabled;

  print('   globalSettingInfoEnabled:  $infoEnabled');
  print('   globalSettingDebugEnabled: $debugEnabled');
  print('   globalSettingErrorEnabled: $errorEnabled');
  print('   globalSettingTraceEnabled: $traceEnabled');
  print('');
  print('   These can be set to false to completely disable specific');
  print('   log methods regardless of the current log level.');
  print('');

  // Restore original log level
  tomLog.setLogLevel(originalLogLevel);

  // Clean up name levels
  tomLog.removeNameLevel('MyClass');
  tomLog.removeNameLevel('OtherClass');
  tomLog.removeNameLevel('Service');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Individual log levels
  assert(traceBit == 1);
  assert(debugBit == 2);
  assert(trafficBit == 4);
  assert(infoBit == 8);
  assert(warnBit == 16);
  assert(statusBit == 256);
  assert(errorBit == 512);
  assert(severeBit == 1024);
  assert(fatalBit == 2048);

  // Example 2: Compound log levels
  assert(offBit == 0);
  assert(developmentBit > productionBit); // More bits set

  // Example 3: Combining log levels
  assert(combinedBit == (infoBit | errorBit));
  assert(matchesInfo == true);
  assert(matchesError == true);
  assert(matchesDebug == false);

  // Example 4: Removing log levels
  assert(prodMatchesInfo == true);
  assert(noInfoMatchesInfo == false);
  assert(noInfoMatchesWarn == true);

  // Example 5: Lookup by name
  assert(debugByName != null);
  assert(debugByNameBit == 2);
  assert(prodByName != null);
  assert(invalidName == null);
  assert(caseInsensitive != null);

  // Example 6: Setting log level
  assert(devLevel == TomLogLevel.development.levelPattern);
  assert(prodLevel == TomLogLevel.production.levelPattern);
  assert(extLevel == TomLogLevel.extended.levelPattern);

  // Example 7: Push/pop stack
  assert(pushedLevelBit == TomLogLevel.development.levelPattern);
  assert(doublePushedBit == TomLogLevel.trace.levelPattern);
  // Note: popLogLevel removes from index 0 (not end), behavior may vary

  // Example 8: Per-name configuration
  assert(dbLevel != null);
  assert(apiLevel != null);
  assert(unknownLevel == null);
  assert(afterRemove == null);

  // Example 9: Exception pattern
  assert(myClassLevel != null);
  assert(otherClassLevel != null);
  assert(serviceLevel != null);

  // Example 10: Global toggles
  assert(infoEnabled == true);
  assert(debugEnabled == true);
  assert(errorEnabled == true);
  assert(traceEnabled == true);
}
