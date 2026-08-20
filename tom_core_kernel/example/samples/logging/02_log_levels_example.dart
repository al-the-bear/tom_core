/// Demonstrates log level configuration and filtering in TomLogger.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Individual Log Levels and Their Bit Patterns
// =============================================================================

class LogLevelBitPatternsExample {
  static int traceBit = 0;
  static int debugBit = 0;
  static int infoBit = 0;
  static int errorBit = 0;
  static bool bitPatternsWork = false;

  static void example1BitPatterns() {
    traceBit = TomLogLevel.trace.levelPattern;
    debugBit = TomLogLevel.debug.levelPattern;
    infoBit = TomLogLevel.info.levelPattern;
    errorBit = TomLogLevel.error.levelPattern;

    // Bit patterns should be powers of 2 (single bits)
    bitPatternsWork = traceBit == 1 && debugBit == 2;

    assert(traceBit == 1, 'Trace should be bit 0');
    assert(debugBit == 2, 'Debug should be bit 1');
    assert(infoBit > 0, 'Info bit should be positive');
    assert(errorBit > 0, 'Error bit should be positive');
    assert(bitPatternsWork, 'Bit patterns should work');
  }
}

// =============================================================================
// EXAMPLE 2: Predefined Compound Log Levels
// =============================================================================

class CompoundLogLevelsExample {
  static int developmentBit = 0;
  static int productionBit = 0;
  static int silentBit = 0;
  static int offBit = 0;
  static bool compoundLevelsWork = false;

  static void example2CompoundLevels() {
    developmentBit = TomLogLevel.development.levelPattern;
    productionBit = TomLogLevel.production.levelPattern;
    silentBit = TomLogLevel.silent.levelPattern;
    offBit = TomLogLevel.off.levelPattern;

    // Development includes all levels, so it should have the highest bit pattern
    compoundLevelsWork = developmentBit > productionBit && offBit == 0;

    assert(developmentBit > productionBit, 'Development includes more levels');
    assert(productionBit > silentBit, 'Production includes more than silent');
    assert(offBit == 0, 'Off should have no bits set');
    assert(compoundLevelsWork, 'Compound levels should work');
  }
}

// =============================================================================
// EXAMPLE 3: Combining Log Levels with + Operator
// =============================================================================

class CombiningLogLevelsExample {
  static int infoOnlyBit = 0;
  static int errorOnlyBit = 0;
  static int combinedBit = 0;
  static bool matchesInfo = false;
  static bool matchesError = false;
  static bool matchesDebug = false;

  static void example3CombiningLevels() {
    final infoOnly = TomLogLevel.info;
    final errorOnly = TomLogLevel.error;
    final infoAndError = TomLogLevel.info + TomLogLevel.error;

    infoOnlyBit = infoOnly.levelPattern;
    errorOnlyBit = errorOnly.levelPattern;
    combinedBit = infoAndError.levelPattern;

    matchesInfo = infoAndError.matches(TomLogLevel.info);
    matchesError = infoAndError.matches(TomLogLevel.error);
    matchesDebug = infoAndError.matches(TomLogLevel.debug);

    assert(combinedBit == (infoOnlyBit | errorOnlyBit), 'Should be bitwise OR');
    assert(matchesInfo, 'Combined should match info');
    assert(matchesError, 'Combined should match error');
    assert(!matchesDebug, 'Combined should not match debug');
  }
}

// =============================================================================
// EXAMPLE 4: Removing Log Levels with - Operator
// =============================================================================

class RemovingLogLevelsExample {
  static int prodBit = 0;
  static int noInfoBit = 0;
  static bool prodMatchesInfo = false;
  static bool noInfoMatchesInfo = false;
  static bool noInfoMatchesWarn = false;

  static void example4RemovingLevels() {
    final productionLevel = TomLogLevel.production;
    final withoutInfo = TomLogLevel.production - TomLogLevel.info;

    prodBit = productionLevel.levelPattern;
    noInfoBit = withoutInfo.levelPattern;

    prodMatchesInfo = productionLevel.matches(TomLogLevel.info);
    noInfoMatchesInfo = withoutInfo.matches(TomLogLevel.info);
    noInfoMatchesWarn = withoutInfo.matches(TomLogLevel.warn);

    assert(prodMatchesInfo, 'Production should include info');
    assert(!noInfoMatchesInfo, 'Production - info should not include info');
    assert(noInfoMatchesWarn, 'Production - info should still include warn');
  }
}

// =============================================================================
// EXAMPLE 5: Looking Up Log Levels by Name
// =============================================================================

class LevelByNameExample {
  static int? debugByNameBit;
  static int? prodByNameBit;
  static TomLogLevel? invalidName;
  static TomLogLevel? caseInsensitive;

  static void example5LevelByName() {
    final debugByName = TomLogLevel.byName('DEBUG');
    final prodByName = TomLogLevel.byName('PRODUCTION');
    invalidName = TomLogLevel.byName('INVALID');
    caseInsensitive = TomLogLevel.byName('trace');

    debugByNameBit = debugByName?.levelPattern;
    prodByNameBit = prodByName?.levelPattern;

    assert(
      debugByNameBit == TomLogLevel.debug.levelPattern,
      'DEBUG should match',
    );
    assert(
      prodByNameBit == TomLogLevel.production.levelPattern,
      'PRODUCTION should match',
    );
    assert(invalidName == null, 'Invalid name should return null');
    assert(caseInsensitive != null, 'Should be case-insensitive');
  }
}

// =============================================================================
// EXAMPLE 6: Setting Log Level on the Logger
// =============================================================================

class SetLogLevelExample {
  static int devLevel = 0;
  static int prodLevel = 0;
  static int extLevel = 0;
  static bool levelChangesWork = false;

  static void example6SetLogLevel() {
    final originalLogLevel = tomLog.logLevel;

    tomLog.setLogLevel(TomLogLevel.development);
    devLevel = tomLog.logLevel.levelPattern;

    tomLog.setLogLevel(TomLogLevel.production);
    prodLevel = tomLog.logLevel.levelPattern;

    // Set by name
    tomLog.setLogLevelByName('EXTENDED');
    extLevel = tomLog.logLevel.levelPattern;

    levelChangesWork =
        devLevel == TomLogLevel.development.levelPattern &&
        prodLevel == TomLogLevel.production.levelPattern &&
        extLevel == TomLogLevel.extended.levelPattern;

    tomLog.setLogLevel(originalLogLevel);

    assert(
      devLevel == TomLogLevel.development.levelPattern,
      'Dev level should match',
    );
    assert(
      prodLevel == TomLogLevel.production.levelPattern,
      'Prod level should match',
    );
    assert(
      extLevel == TomLogLevel.extended.levelPattern,
      'Ext level should match',
    );
    assert(levelChangesWork, 'Level changes should work');
  }
}

// =============================================================================
// EXAMPLE 7: Push/Pop Log Level Stack
// =============================================================================

class PushPopLogLevelExample {
  static int baseLevelBit = 0;
  static int pushedLevelBit = 0;
  static int afterPopBit = 0;
  static bool pushPopWorks = false;

  static void example7PushPopLogLevel() {
    final originalLogLevel = tomLog.logLevel;

    tomLog.setLogLevel(TomLogLevel.production);
    baseLevelBit = tomLog.logLevel.levelPattern;

    tomLog.pushLogLevel(TomLogLevel.development);
    pushedLevelBit = tomLog.logLevel.levelPattern;

    tomLog.popLogLevel();
    afterPopBit = tomLog.logLevel.levelPattern;

    pushPopWorks =
        baseLevelBit == TomLogLevel.production.levelPattern &&
        pushedLevelBit == TomLogLevel.development.levelPattern &&
        afterPopBit == TomLogLevel.production.levelPattern;

    tomLog.setLogLevel(originalLogLevel);

    assert(
      baseLevelBit == TomLogLevel.production.levelPattern,
      'Base should be production',
    );
    assert(
      pushedLevelBit == TomLogLevel.development.levelPattern,
      'Pushed should be development',
    );
    assert(
      afterPopBit == TomLogLevel.production.levelPattern,
      'After pop should be production',
    );
    assert(pushPopWorks, 'Push/pop should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  LogLevelBitPatternsExample.example1BitPatterns();
  CompoundLogLevelsExample.example2CompoundLevels();
  CombiningLogLevelsExample.example3CombiningLevels();
  RemovingLogLevelsExample.example4RemovingLevels();
  LevelByNameExample.example5LevelByName();
  SetLogLevelExample.example6SetLogLevel();
  PushPopLogLevelExample.example7PushPopLogLevel();
}

void main() {
  requireAsserts();
  run();
}
