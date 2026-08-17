import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // =========================================================================
  // UTILITY FUNCTIONS
  // =========================================================================

  group('limited', () {
    test('should return full string when shorter than maxLength', () {
      final result = limited('Hello', 10);
      expect(result, equals('Hello'));
    });

    test('should truncate string when longer than maxLength', () {
      final result = limited('Hello World', 5);
      expect(result, equals('Hello...'));
    });

    test('should return exact string when equal to maxLength', () {
      final result = limited('Hello', 5);
      expect(result, equals('Hello'));
    });

    test('should handle empty string', () {
      final result = limited('', 5);
      expect(result, equals(''));
    });

    test('should handle null object', () {
      final result = limited(null, 10);
      expect(result, equals('null'));
    });

    test('should handle zero maxLength', () {
      final result = limited('Hello', 0);
      expect(result, equals('...'));
    });

    test('should convert objects to string before limiting', () {
      final result = limited(12345, 3);
      expect(result, equals('123...'));
    });

    test('should handle list objects', () {
      final result = limited([1, 2, 3], 5);
      expect(result, equals('[1, 2...'));
    });
  });

  // =========================================================================
  // TOM LOG LEVEL
  // =========================================================================

  group('TomLogLevel', () {
    group('constructor', () {
      test('should create level with specified pattern', () {
        final level = TomLogLevel(42);
        expect(level.levelPattern, equals(42));
      });

      test('should create level with zero pattern', () {
        final level = TomLogLevel(0);
        expect(level.levelPattern, equals(0));
      });
    });

    group('static levels', () {
      test('should have correct bit pattern for trace', () {
        expect(TomLogLevel.trace.levelPattern, equals(1));
      });

      test('should have correct bit pattern for debug', () {
        expect(TomLogLevel.debug.levelPattern, equals(2));
      });

      test('should have correct bit pattern for traffic', () {
        expect(TomLogLevel.traffic.levelPattern, equals(4));
      });

      test('should have correct bit pattern for info', () {
        expect(TomLogLevel.info.levelPattern, equals(8));
      });

      test('should have correct bit pattern for warn', () {
        expect(TomLogLevel.warn.levelPattern, equals(16));
      });

      test('should have correct bit pattern for status', () {
        expect(TomLogLevel.status.levelPattern, equals(256));
      });

      test('should have correct bit pattern for error', () {
        expect(TomLogLevel.error.levelPattern, equals(512));
      });

      test('should have correct bit pattern for severe', () {
        expect(TomLogLevel.severe.levelPattern, equals(1024));
      });

      test('should have correct bit pattern for fatal', () {
        expect(TomLogLevel.fatal.levelPattern, equals(2048));
      });

      test('should have correct bit pattern for all', () {
        expect(TomLogLevel.all.levelPattern, equals(65535));
      });

      test('should have correct bit pattern for none', () {
        expect(TomLogLevel.none.levelPattern, equals(0));
      });

      test('should have off equal to none', () {
        expect(TomLogLevel.off.levelPattern, equals(TomLogLevel.none.levelPattern));
      });
    });

    group('compound levels', () {
      test('should have errors combining error, severe, and fatal', () {
        final errors = TomLogLevel.errors;
        expect(errors.matches(TomLogLevel.error), isTrue);
        expect(errors.matches(TomLogLevel.severe), isTrue);
        expect(errors.matches(TomLogLevel.fatal), isTrue);
        expect(errors.matches(TomLogLevel.info), isFalse);
      });

      test('should have production combining info, warn, errors, and status', () {
        final production = TomLogLevel.production;
        expect(production.matches(TomLogLevel.info), isTrue);
        expect(production.matches(TomLogLevel.warn), isTrue);
        expect(production.matches(TomLogLevel.error), isTrue);
        expect(production.matches(TomLogLevel.status), isTrue);
        expect(production.matches(TomLogLevel.debug), isFalse);
        expect(production.matches(TomLogLevel.trace), isFalse);
      });

      test('should have extended combining production, debug, and traffic', () {
        final extended = TomLogLevel.extended;
        expect(extended.matches(TomLogLevel.info), isTrue);
        expect(extended.matches(TomLogLevel.debug), isTrue);
        expect(extended.matches(TomLogLevel.traffic), isTrue);
        expect(extended.matches(TomLogLevel.trace), isFalse);
      });

      test('should have development combining extended and trace', () {
        final development = TomLogLevel.development;
        expect(development.matches(TomLogLevel.trace), isTrue);
        expect(development.matches(TomLogLevel.debug), isTrue);
        expect(development.matches(TomLogLevel.info), isTrue);
      });

      test('should have still combining warn, errors, and status', () {
        final still = TomLogLevel.still;
        expect(still.matches(TomLogLevel.warn), isTrue);
        expect(still.matches(TomLogLevel.error), isTrue);
        expect(still.matches(TomLogLevel.status), isTrue);
        expect(still.matches(TomLogLevel.info), isFalse);
      });

      test('should have silent combining errors and status', () {
        final silent = TomLogLevel.silent;
        expect(silent.matches(TomLogLevel.error), isTrue);
        expect(silent.matches(TomLogLevel.status), isTrue);
        expect(silent.matches(TomLogLevel.warn), isFalse);
        expect(silent.matches(TomLogLevel.info), isFalse);
      });
    });

    group('operator +', () {
      test('should combine two levels with bitwise OR', () {
        final combined = TomLogLevel.info + TomLogLevel.debug;
        expect(combined.matches(TomLogLevel.info), isTrue);
        expect(combined.matches(TomLogLevel.debug), isTrue);
        expect(combined.matches(TomLogLevel.warn), isFalse);
      });

      test('should combine multiple levels', () {
        final combined = TomLogLevel.trace + TomLogLevel.debug + TomLogLevel.info;
        expect(combined.matches(TomLogLevel.trace), isTrue);
        expect(combined.matches(TomLogLevel.debug), isTrue);
        expect(combined.matches(TomLogLevel.info), isTrue);
        expect(combined.matches(TomLogLevel.warn), isFalse);
      });

      test('should be idempotent when adding same level', () {
        final combined = TomLogLevel.info + TomLogLevel.info;
        expect(combined.levelPattern, equals(TomLogLevel.info.levelPattern));
      });

      test('should combine with none without change', () {
        final combined = TomLogLevel.info + TomLogLevel.none;
        expect(combined.levelPattern, equals(TomLogLevel.info.levelPattern));
      });
    });

    group('operator -', () {
      test('should remove a level with bitwise AND NOT', () {
        final production = TomLogLevel.production;
        final noInfo = production - TomLogLevel.info;
        expect(noInfo.matches(TomLogLevel.info), isFalse);
        expect(noInfo.matches(TomLogLevel.warn), isTrue);
        expect(noInfo.matches(TomLogLevel.error), isTrue);
      });

      test('should have no effect when removing non-existent level', () {
        final info = TomLogLevel.info;
        final result = info - TomLogLevel.debug;
        expect(result.levelPattern, equals(TomLogLevel.info.levelPattern));
      });

      test('should result in none when removing all levels', () {
        final result = TomLogLevel.info - TomLogLevel.info;
        expect(result.levelPattern, equals(0));
      });

      test('should support chained removal', () {
        final result = TomLogLevel.production - TomLogLevel.info - TomLogLevel.warn;
        expect(result.matches(TomLogLevel.info), isFalse);
        expect(result.matches(TomLogLevel.warn), isFalse);
        expect(result.matches(TomLogLevel.error), isTrue);
      });
    });

    group('matches', () {
      test('should return true when levels overlap', () {
        final production = TomLogLevel.production;
        expect(production.matches(TomLogLevel.info), isTrue);
      });

      test('should return false when levels do not overlap', () {
        final production = TomLogLevel.production;
        expect(production.matches(TomLogLevel.trace), isFalse);
      });

      test('should return false for none level', () {
        expect(TomLogLevel.none.matches(TomLogLevel.info), isFalse);
        expect(TomLogLevel.info.matches(TomLogLevel.none), isFalse);
      });

      test('should return true when matching all', () {
        expect(TomLogLevel.all.matches(TomLogLevel.info), isTrue);
        expect(TomLogLevel.all.matches(TomLogLevel.trace), isTrue);
        expect(TomLogLevel.all.matches(TomLogLevel.fatal), isTrue);
      });
    });

    group('byName', () {
      test('should return trace for TRACE', () {
        final level = TomLogLevel.byName('TRACE');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });

      test('should return debug for DEBUG', () {
        final level = TomLogLevel.byName('DEBUG');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.debug.levelPattern));
      });

      test('should return traffic for TRAFFIC', () {
        final level = TomLogLevel.byName('TRAFFIC');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.traffic.levelPattern));
      });

      test('should return info for INFO', () {
        final level = TomLogLevel.byName('INFO');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.info.levelPattern));
      });

      test('should return warn for WARN', () {
        final level = TomLogLevel.byName('WARN');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.warn.levelPattern));
      });

      test('should return status for STATUS', () {
        final level = TomLogLevel.byName('STATUS');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.status.levelPattern));
      });

      test('should return error for ERROR', () {
        final level = TomLogLevel.byName('ERROR');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.error.levelPattern));
      });

      test('should return severe for SEVERE', () {
        final level = TomLogLevel.byName('SEVERE');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.severe.levelPattern));
      });

      test('should return fatal for FATAL', () {
        final level = TomLogLevel.byName('FATAL');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.fatal.levelPattern));
      });

      test('should return all for ALL', () {
        final level = TomLogLevel.byName('ALL');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.all.levelPattern));
      });

      test('should return off for OFF', () {
        final level = TomLogLevel.byName('OFF');
        expect(level, isNotNull);
        expect(level!.levelPattern, equals(TomLogLevel.off.levelPattern));
      });

      test('should be case insensitive', () {
        expect(TomLogLevel.byName('info'), isNotNull);
        expect(TomLogLevel.byName('Info'), isNotNull);
        expect(TomLogLevel.byName('INFO'), isNotNull);
        expect(TomLogLevel.byName('iNfO'), isNotNull);
      });

      test('should return null for unknown name', () {
        final level = TomLogLevel.byName('UNKNOWN');
        expect(level, isNull);
      });

      test('should return null for empty string', () {
        final level = TomLogLevel.byName('');
        expect(level, isNull);
      });

      test('should return compound levels', () {
        expect(TomLogLevel.byName('DEVELOPMENT'), isNotNull);
        expect(TomLogLevel.byName('EXTENDED'), isNotNull);
        expect(TomLogLevel.byName('ERRORS'), isNotNull);
        expect(TomLogLevel.byName('PRODUCTION'), isNotNull);
        expect(TomLogLevel.byName('STILL'), isNotNull);
        expect(TomLogLevel.byName('SILENT'), isNotNull);
      });
    });

    group('toString', () {
      test('should return string representation with level pattern', () {
        final level = TomLogLevel(42);
        expect(level.toString(), equals('TomLogLevel 42'));
      });

      test('should show zero for none level', () {
        expect(TomLogLevel.none.toString(), equals('TomLogLevel 0'));
      });
    });
  });

  // =========================================================================
  // TOM LOGGER
  // =========================================================================

  group('TomLogger', () {
    late TomLogger logger;
    late _MockLogOutput mockOutput;

    setUp(() {
      logger = TomLogger();
      mockOutput = _MockLogOutput();
      logger.logOutput = mockOutput;
    });

    group('constants', () {
      test('should have INFO constant with correct format', () {
        expect(TomLogger.INFO, equals('INFO   '));
      });

      test('should have ERROR constant with correct format', () {
        expect(TomLogger.ERROR, equals('ERROR  '));
      });

      test('should have WARN constant with correct format', () {
        expect(TomLogger.WARN, equals('WARN   '));
      });

      test('should have DEBUG constant with correct format', () {
        expect(TomLogger.DEBUG, equals('DEBUG  '));
      });

      test('should have TRACE constant with correct format', () {
        expect(TomLogger.TRACE, equals('TRACE  '));
      });

      test('should have TRAFFIC constant with correct format', () {
        expect(TomLogger.TRAFFIC, equals('TRAFFIC'));
      });

      test('should have SEVERE constant with correct format', () {
        expect(TomLogger.SEVERE, equals('SEVERE '));
      });

      test('should have FATAL constant with correct format', () {
        expect(TomLogger.FATAL, equals('FATAL  '));
      });

      test('should have STATUS constant with correct format', () {
        expect(TomLogger.STATUS, equals('STATUS '));
      });
    });

    group('setLogLevel', () {
      test('should set the log level', () {
        logger.setLogLevel(TomLogLevel.trace);
        expect(logger.logLevel.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });

      test('should update log level when called multiple times', () {
        logger.setLogLevel(TomLogLevel.trace);
        logger.setLogLevel(TomLogLevel.info);
        expect(logger.logLevel.levelPattern, equals(TomLogLevel.info.levelPattern));
      });
    });

    group('pushLogLevel', () {
      test('should push log level and update current level', () {
        logger.setLogLevel(TomLogLevel.production);
        logger.pushLogLevel(TomLogLevel.trace);
        expect(logger.logLevel.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });

      test('should allow multiple pushes', () {
        logger.pushLogLevel(TomLogLevel.info);
        logger.pushLogLevel(TomLogLevel.debug);
        logger.pushLogLevel(TomLogLevel.trace);
        expect(logger.logLevel.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });
    });

    group('popLogLevel', () {
      test('should restore previous level after pop', () {
        logger.setLogLevel(TomLogLevel.production);
        logger.pushLogLevel(TomLogLevel.trace);
        logger.popLogLevel();
        // After pop, it should restore to first element in stack
        expect(logger.logLevel, isNotNull);
      });

      test('should not fail when stack has only initial level', () {
        logger.setLogLevel(TomLogLevel.production);
        logger.popLogLevel();
        expect(logger.logLevel, isNotNull);
      });
    });

    group('info', () {
      test('should log info message when enabled', () {
        TomLogger.globalSettingInfoEnabled = true;
        logger.setLogLevel(TomLogLevel.info);
        logger.info('test message');
        expect(mockOutput.lastMessage, equals('test message'));
        expect(mockOutput.lastLevel, equals(TomLogger.INFO));
      });

      test('should not log when info is disabled', () {
        TomLogger.globalSettingInfoEnabled = false;
        logger.info('test message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingInfoEnabled = true;
      });

      test('should not store message when log level does not match', () {
        mockOutput.reset();
        logger.setLogLevel(TomLogLevel.none);
        logger.info('test message');
        // The output method is called, but since levels don't match,
        // the message should not be stored
        expect(mockOutput.lastMessage, isNull);
      });
    });

    group('warn', () {
      test('should log warn message when enabled', () {
        TomLogger.globalSettingWarnEnabled = true;
        logger.setLogLevel(TomLogLevel.warn);
        logger.warn('warning message');
        expect(mockOutput.lastMessage, equals('warning message'));
        expect(mockOutput.lastLevel, equals(TomLogger.WARN));
      });

      test('should not log when warn is disabled', () {
        TomLogger.globalSettingWarnEnabled = false;
        logger.warn('warning message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingWarnEnabled = true;
      });
    });

    group('error', () {
      test('should log error message when enabled', () {
        TomLogger.globalSettingErrorEnabled = true;
        logger.setLogLevel(TomLogLevel.error);
        logger.error('error message');
        expect(mockOutput.lastMessage, equals('error message'));
        expect(mockOutput.lastLevel, equals(TomLogger.ERROR));
      });

      test('should not log when error is disabled', () {
        TomLogger.globalSettingErrorEnabled = false;
        logger.error('error message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingErrorEnabled = true;
      });
    });

    group('debug', () {
      test('should log debug message when enabled', () {
        TomLogger.globalSettingDebugEnabled = true;
        logger.setLogLevel(TomLogLevel.debug);
        logger.debug('debug message');
        expect(mockOutput.lastMessage, equals('debug message'));
        expect(mockOutput.lastLevel, equals(TomLogger.DEBUG));
      });

      test('should not log when debug is disabled', () {
        TomLogger.globalSettingDebugEnabled = false;
        logger.debug('debug message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingDebugEnabled = true;
      });
    });

    group('trace', () {
      test('should log trace message when enabled', () {
        TomLogger.globalSettingTraceEnabled = true;
        logger.setLogLevel(TomLogLevel.trace);
        logger.trace('trace message');
        expect(mockOutput.lastMessage, equals('trace message'));
        expect(mockOutput.lastLevel, equals(TomLogger.TRACE));
      });

      test('should not log when trace is disabled', () {
        TomLogger.globalSettingTraceEnabled = false;
        logger.trace('trace message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingTraceEnabled = true;
      });
    });

    group('traffic', () {
      test('should log traffic message when enabled', () {
        TomLogger.globalSettingTrafficEnabled = true;
        logger.setLogLevel(TomLogLevel.traffic);
        logger.traffic('traffic message');
        expect(mockOutput.lastMessage, equals('traffic message'));
        expect(mockOutput.lastLevel, equals(TomLogger.TRAFFIC));
      });

      test('should not log when traffic is disabled', () {
        TomLogger.globalSettingTrafficEnabled = false;
        logger.traffic('traffic message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingTrafficEnabled = true;
      });
    });

    group('severe', () {
      test('should log severe message when enabled', () {
        TomLogger.globalSettingSevereEnabled = true;
        logger.setLogLevel(TomLogLevel.severe);
        logger.severe('severe message');
        expect(mockOutput.lastMessage, equals('severe message'));
        expect(mockOutput.lastLevel, equals(TomLogger.SEVERE));
      });

      test('should not log when severe is disabled', () {
        TomLogger.globalSettingSevereEnabled = false;
        logger.severe('severe message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingSevereEnabled = true;
      });
    });

    group('fatal', () {
      test('should log fatal message when enabled', () {
        TomLogger.globalSettingFatalEnabled = true;
        logger.setLogLevel(TomLogLevel.fatal);
        logger.fatal('fatal message');
        expect(mockOutput.lastMessage, equals('fatal message'));
        expect(mockOutput.lastLevel, equals(TomLogger.FATAL));
      });

      test('should not log when fatal is disabled', () {
        TomLogger.globalSettingFatalEnabled = false;
        logger.fatal('fatal message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingFatalEnabled = true;
      });
    });

    group('status', () {
      test('should log status message when enabled', () {
        TomLogger.globalSettingStatusEnabled = true;
        logger.setLogLevel(TomLogLevel.status);
        logger.status('status message');
        expect(mockOutput.lastMessage, equals('status message'));
        expect(mockOutput.lastLevel, equals(TomLogger.STATUS));
      });

      test('should not log when status is disabled', () {
        TomLogger.globalSettingStatusEnabled = false;
        logger.status('status message');
        expect(mockOutput.lastMessage, isNull);
        TomLogger.globalSettingStatusEnabled = true;
      });
    });

    group('addNameLevel', () {
      test('should add name level', () {
        logger.addNameLevel('MyClass', TomLogLevel.trace);
        expect(logger.getNameLevel('MyClass'), isNotNull);
        expect(logger.getNameLevel('MyClass')!.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });

      test('should overwrite existing name level', () {
        logger.addNameLevel('MyClass', TomLogLevel.trace);
        logger.addNameLevel('MyClass', TomLogLevel.debug);
        expect(logger.getNameLevel('MyClass')!.levelPattern, equals(TomLogLevel.debug.levelPattern));
      });
    });

    group('getNameLevel', () {
      test('should return null for non-existent name', () {
        expect(logger.getNameLevel('NonExistent'), isNull);
      });

      test('should return level for existing name', () {
        logger.addNameLevel('TestClass', TomLogLevel.info);
        expect(logger.getNameLevel('TestClass'), isNotNull);
      });
    });

    group('removeNameLevel', () {
      test('should remove existing name level', () {
        logger.addNameLevel('MyClass', TomLogLevel.trace);
        logger.removeNameLevel('MyClass');
        expect(logger.getNameLevel('MyClass'), isNull);
      });

      test('should not fail when removing non-existent name', () {
        logger.removeNameLevel('NonExistent');
        expect(logger.getNameLevel('NonExistent'), isNull);
      });
    });

    group('setLogLevelByName', () {
      test('should set log level for valid name', () {
        logger.setLogLevelByName('TRACE');
        expect(logger.logLevel.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });

      test('should not change level for empty string', () {
        final originalLevel = logger.logLevel.levelPattern;
        logger.setLogLevelByName('');
        expect(logger.logLevel.levelPattern, equals(originalLevel));
      });

      test('should handle case insensitivity', () {
        logger.setLogLevelByName('debug');
        expect(logger.logLevel.levelPattern, equals(TomLogLevel.debug.levelPattern));
      });
    });

    group('setLogLevelExceptions', () {
      test('should set log level exceptions from pattern', () {
        logger.setLogLevelExceptions('MyClass=DEBUG,OtherClass=TRACE');
        expect(logger.getNameLevel('MyClass')!.levelPattern, equals(TomLogLevel.debug.levelPattern));
        expect(logger.getNameLevel('OtherClass')!.levelPattern, equals(TomLogLevel.trace.levelPattern));
      });

      test('should not fail for empty pattern', () {
        logger.setLogLevelExceptions('');
        // Should not throw
      });

      test('should handle single entry', () {
        logger.setLogLevelExceptions('SingleClass=INFO');
        expect(logger.getNameLevel('SingleClass')!.levelPattern, equals(TomLogLevel.info.levelPattern));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final str = logger.toString();
        expect(str, startsWith('TomLogger'));
      });
    });

    group('globalSettingDetermineCaller', () {
      test('should be true by default', () {
        expect(TomLogger.globalSettingDetermineCaller, isTrue);
      });
    });
  });

  // =========================================================================
  // TOM LOG OUTPUT
  // =========================================================================

  group('TomLogOutput', () {
    group('globalSettingRemoteLogEndpoint', () {
      test('should have default value of /remotelog', () {
        expect(TomLogOutput.globalSettingRemoteLogEndpoint, equals('/remotelog'));
      });
    });

    group('convertToString', () {
      late _TestLogOutput output;

      setUp(() {
        output = _TestLogOutput();
      });

      test('should return string as-is', () {
        expect(output.convertToString('hello'), equals('hello'));
      });

      test('should call function and convert result', () {
        expect(output.convertToString(() => 'lazy value'), equals('lazy value'));
      });

      test('should use logRepresentation for TomLoggable objects', () {
        final loggable = _TestLoggable('custom log output');
        expect(output.convertToString(loggable), equals('custom log output'));
      });

      test('should use toString for other objects', () {
        final obj = _TestObject(42);
        expect(output.convertToString(obj), equals('TestObject(42)'));
      });

      test('should handle nested function calls', () {
        expect(output.convertToString(() => () => 'nested'), equals('nested'));
      });

      test('should handle integer values', () {
        expect(output.convertToString(42), equals('42'));
      });
    });
  });

  // =========================================================================
  // TOM CONSOLE LOG OUTPUT
  // =========================================================================

  group('TomConsoleLogOutput', () {
    group('globalSettingStderrLogLevel', () {
      test('should include errors and status by default', () {
        final level = TomConsoleLogOutput.globalSettingStderrLogLevel;
        expect(level.matches(TomLogLevel.error), isTrue);
        expect(level.matches(TomLogLevel.severe), isTrue);
        expect(level.matches(TomLogLevel.fatal), isTrue);
        expect(level.matches(TomLogLevel.status), isTrue);
      });
    });

    group('globalSettingStdoutLogLevel', () {
      test('should exclude errors and status by default', () {
        final level = TomConsoleLogOutput.globalSettingStdoutLogLevel;
        expect(level.matches(TomLogLevel.info), isTrue);
        expect(level.matches(TomLogLevel.debug), isTrue);
        expect(level.matches(TomLogLevel.trace), isTrue);
        expect(level.matches(TomLogLevel.error), isFalse);
        expect(level.matches(TomLogLevel.status), isFalse);
      });
    });

    group('useExtendedFormat', () {
      test('should be false by default', () {
        final output = TomConsoleLogOutput();
        expect(output.useExtendedFormat, isFalse);
      });
    });
  });

  // =========================================================================
  // TOM LOGGABLE
  // =========================================================================

  group('TomLoggable', () {
    test('should provide logRepresentation', () {
      final loggable = _TestLoggable('test output');
      expect(loggable.logRepresentation, equals('test output'));
    });
  });

  // =========================================================================
  // TOM REMOTE LOG MESSAGE
  // =========================================================================

  group('TomRemoteLogMessage', () {
    group('default constructor', () {
      test('should create message with default values', () {
        final message = TomRemoteLogMessage();
        expect(message.sender, equals(''));
        expect(message.level, equals(''));
        expect(message.message, equals(''));
        expect(message.isolateName, equals(''));
        expect(message.loggerLevel, equals(0));
        expect(message.logLevel, equals(0));
      });
    });

    group('TomRemoteLogMessage.of', () {
      test('should create message with all fields populated', () {
        final fixedTimestamp = DateTime(2026, 1, 2, 12, 30, 45);
        TomRemoteLogMessage.globalSettingSenderId = 'test-sender';

        final message = TomRemoteLogMessage.of(
          TomLogLevel.production.levelPattern,
          TomLogLevel.info.levelPattern,
          'INFO   ',
          'test message',
          'main',
          fixedTimestamp.toIso8601String(),
          'TestClass.testMethod',
        );

        expect(message.sender, equals('test-sender'));
        expect(message.loggerLevel, equals(TomLogLevel.production.levelPattern));
        expect(message.logLevel, equals(TomLogLevel.info.levelPattern));
        expect(message.level, equals('INFO   '));
        expect(message.message, equals('test message'));
        expect(message.isolateName, equals('main'));
        expect(message.timeStamp, equals('2026-01-02T12:30:45.000'));
        expect(message.origin, equals('TestClass.testMethod'));

        TomRemoteLogMessage.globalSettingSenderId = 'RDEF';
      });
    });

    group('globalSettingSenderId', () {
      test('should have default value of RDEF', () {
        expect(TomRemoteLogMessage.globalSettingSenderId, equals('RDEF'));
      });

      test('should be configurable', () {
        final original = TomRemoteLogMessage.globalSettingSenderId;
        TomRemoteLogMessage.globalSettingSenderId = 'custom-id';
        expect(TomRemoteLogMessage.globalSettingSenderId, equals('custom-id'));
        TomRemoteLogMessage.globalSettingSenderId = original;
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final message = TomRemoteLogMessage.of(
          8,
          8,
          'INFO   ',
          'test',
          'main',
          '2026-01-02T12:00:00.000',
          null,
        );
        expect(message.toString(), equals('TomRemoteLogMessage main INFO    test'));
      });
    });
  });

  // =========================================================================
  // TOM REMOTE LOG RESULT
  // =========================================================================

  group('TomRemoteLogResult', () {
    group('default constructor', () {
      test('should create result with no error', () {
        final result = TomRemoteLogResult();
        expect(result.hasError, isFalse);
        expect(result.errorMessage, isEmpty);
      });
    });

    group('TomRemoteLogResult.withError', () {
      test('should create result with error', () {
        final result = TomRemoteLogResult.withError('Something went wrong');
        expect(result.hasError, isTrue);
        expect(result.errorMessage, equals('Something went wrong'));
      });

      test('should handle empty error message', () {
        final result = TomRemoteLogResult.withError('');
        expect(result.hasError, isTrue);
        expect(result.errorMessage, isEmpty);
      });
    });

    group('toString', () {
      test('should return string representation for success', () {
        final result = TomRemoteLogResult();
        expect(result.toString(), equals('TomRemoteLogResult false '));
      });

      test('should return string representation for error', () {
        final result = TomRemoteLogResult.withError('error msg');
        expect(result.toString(), equals('TomRemoteLogResult true error msg'));
      });
    });
  });

  // =========================================================================
  // TOM LOGGING CONTEXT
  // =========================================================================

  group('TomLoggingContext', () {
    group('constructor', () {
      test('should create context with inRemoteLogging false by default', () {
        final context = TomLoggingContext();
        expect(context.inRemoteLogging, isFalse);
      });

      test('should create context with specified inRemoteLogging value', () {
        final context = TomLoggingContext(inRemoteLogging: true);
        expect(context.inRemoteLogging, isTrue);
      });
    });
  });

  // =========================================================================
  // TOM REMOTE LOG SERVER
  // =========================================================================

  group('TomRemoteLogServer', () {
    late _MockLogOutput mockOutput;

    setUp(() {
      mockOutput = _MockLogOutput();
      TomRemoteLogServer.localOutput = mockOutput;
    });

    group('receive', () {
      test('should process message successfully', () {
        final server = TomRemoteLogServer();
        final message = TomRemoteLogMessage.of(
          TomLogLevel.production.levelPattern,
          TomLogLevel.info.levelPattern,
          'INFO   ',
          'test message',
          'worker-1',
          '2026-01-02T12:00:00.000',
          'TestClass.method',
        );
        message.sender = 'client-001';

        final result = server.receive(message);

        expect(result.hasError, isFalse);
        expect(mockOutput.lastMessage, equals('test message'));
        expect(mockOutput.lastIsolateName, equals('client-001_worker-1'));
      });

      test('should return error result on failure', () {
        TomRemoteLogServer.localOutput = _FailingLogOutput();
        final server = TomRemoteLogServer();
        final message = TomRemoteLogMessage();
        message.timeStamp = 'invalid-timestamp';

        final result = server.receive(message);

        expect(result.hasError, isTrue);
        expect(result.errorMessage, equals('Failed to log message on server side'));
      });

      // Security §3 (CWE-117): a remote client controls every field of the
      // message, which this server reconstructs into its own local log stream.
      // Control characters in those fields let a client forge extra log lines
      // (CR/LF spoofing) or inject terminal escape sequences (ESC) into a
      // console reading the log. `receive` must strip control characters from
      // the untrusted fields before they reach the output sink.
      test('strips control characters from untrusted fields (CWE-117)', () {
        final server = TomRemoteLogServer();
        final message = TomRemoteLogMessage.of(
          TomLogLevel.production.levelPattern,
          TomLogLevel.info.levelPattern,
          'IN\u001bFO',
          'line one\r\nFORGED 2099 INFO injected line',
          'work\ner-1',
          '2026-01-02T12:00:00.000',
          'Test\rClass.method',
        );
        message.sender = 'cli\nent-001';

        final result = server.receive(message);

        expect(result.hasError, isFalse);
        // No CR/LF/ESC survives in any reconstructed field.
        for (final field in <String?>[
          mockOutput.lastMessage,
          mockOutput.lastLevel,
          mockOutput.lastIsolateName,
          mockOutput.lastOrigin,
        ]) {
          expect(field, isNotNull);
          expect(field, isNot(contains('\n')));
          expect(field, isNot(contains('\r')));
          expect(field, isNot(contains('\u001b')));
        }
        // The visible text is preserved, only the control chars are removed.
        expect(mockOutput.lastMessage,
            equals('line oneFORGED 2099 INFO injected line'));
        expect(mockOutput.lastIsolateName, equals('client-001_worker-1'));
        expect(mockOutput.lastLevel, equals('INFO'));
        expect(mockOutput.lastOrigin, equals('TestClass.method'));
      });
    });
  });

  // =========================================================================
  // TOM INTER ISOLATE LOG MESSAGE
  // =========================================================================

  group('TomInterIsolateLogMessage', () {
    group('constructor', () {
      test('should create message with all fields', () {
        final fixedTime = DateTime(2026, 1, 2, 10, 30, 0);
        final message = TomInterIsolateLogMessage(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          'test message',
          'worker',
          fixedTime,
          'TestClass.method',
        );

        expect(message.loggerLevel.levelPattern, equals(TomLogLevel.production.levelPattern));
        expect(message.logLevel.levelPattern, equals(TomLogLevel.info.levelPattern));
        expect(message.level, equals('INFO   '));
        expect(message.message, equals('test message'));
        expect(message.isolateName, equals('worker'));
        expect(message.timeStamp, equals(fixedTime));
        expect(message.origin, equals('TestClass.method'));
      });

      test('should allow null origin', () {
        final message = TomInterIsolateLogMessage(
          TomLogLevel.info,
          TomLogLevel.info,
          'INFO   ',
          'message',
          'isolate',
          DateTime.now(),
          null,
        );

        expect(message.origin, isNull);
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final message = TomInterIsolateLogMessage(
          TomLogLevel.info,
          TomLogLevel.info,
          'INFO   ',
          'log content',
          'worker-2',
          DateTime(2026, 1, 2),
          null,
        );

        expect(
          message.toString(),
          equals('TomInterIsolateLogMessage worker-2 INFO    log content'),
        );
      });
    });
  });

  // =========================================================================
  // TOM LOGGING EXECUTOR
  // =========================================================================

  group('TomLoggingExecutor', () {
    late TomLoggingExecutor executor;
    late _MockLogOutput mockOutput;

    setUp(() {
      executor = TomLoggingExecutor();
      mockOutput = _MockLogOutput();
      tomLog.logOutput = mockOutput;
    });

    tearDown(() {
      tomLog.logOutput = TomConsoleLogOutput();
    });

    group('execute', () {
      test('should process TomInterIsolateLogMessage', () {
        final fixedTime = DateTime(2026, 1, 2, 15, 45, 0);
        final message = TomInterIsolateLogMessage(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          'executor test',
          'worker',
          fixedTime,
          'Test.method',
        );

        final result = executor.execute(message);

        expect(result, isTrue);
        expect(mockOutput.lastMessage, equals('executor test'));
      });

      test('should return noResult for non-log messages', () {
        final result = executor.execute('random string');
        expect(result, equals(TomExecutor.noResult));
      });

      test('should return noResult for unrelated object types', () {
        final result = executor.execute(123);
        expect(result, equals(TomExecutor.noResult));
      });
    });
  });

  // =========================================================================
  // GLOBAL TOMLOG INSTANCE
  // =========================================================================

  group('tomLog global instance', () {
    test('should be initialized', () {
      expect(tomLog, isNotNull);
      expect(tomLog, isA<TomLogger>());
    });

    test('should have production log level by default', () {
      // Create a fresh logger to test defaults
      final freshLogger = TomLogger();
      expect(freshLogger.logLevel.matches(TomLogLevel.info), isTrue);
      expect(freshLogger.logLevel.matches(TomLogLevel.trace), isFalse);
    });

    test('should have console log output by default', () {
      final freshLogger = TomLogger();
      expect(freshLogger.logOutput, isA<TomConsoleLogOutput>());
    });
  });

  // =========================================================================
  // TOM REMOTE LOG OUTPUT
  // =========================================================================

  group('TomRemoteLogOutput', () {
    group('globalSettingFallbackOutput', () {
      test('should be TomConsoleLogOutput by default', () {
        expect(TomRemoteLogOutput.globalSettingFallbackOutput, isA<TomConsoleLogOutput>());
      });
    });

    group('remoteEndpoint', () {
      test('should be null by default', () {
        expect(TomRemoteLogOutput.remoteEndpoint, isNull);
      });
    });

    group('output', () {
      late _MockLogOutput fallbackOutput;

      setUp(() {
        fallbackOutput = _MockLogOutput();
        TomRemoteLogOutput.globalSettingFallbackOutput = fallbackOutput;
        TomRemoteLogOutput.remoteEndpoint = null;
      });

      tearDown(() {
        TomRemoteLogOutput.globalSettingFallbackOutput = TomConsoleLogOutput();
      });

      test('should use fallback when remoteEndpoint is null', () {
        final remoteOutput = TomRemoteLogOutput();
        final fixedTime = DateTime(2026, 1, 2, 10, 0, 0);

        remoteOutput.output(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          'test message',
          'main',
          fixedTime,
          null,
        );

        expect(fallbackOutput.lastMessage, equals('test message'));
      });

      test('should send to the remote endpoint when one is configured', () async {
        final endpoint = _MockLogEndpoint();
        TomRemoteLogOutput.remoteEndpoint = endpoint;
        addTearDown(() => TomRemoteLogOutput.remoteEndpoint = null);

        final remoteOutput = TomRemoteLogOutput();
        final fixedTime = DateTime(2026, 1, 2, 10, 0, 0);

        remoteOutput.output(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          'hello remote',
          'main',
          fixedTime,
          'Origin.method',
        );

        await endpoint.sent.future;

        expect(endpoint.sendCount, equals(1));
        expect(endpoint.lastMessage?.message, equals('hello remote'));
        expect(endpoint.lastMessage?.isolateName, equals('main'));
        expect(endpoint.lastMessage?.origin, equals('Origin.method'));
        // The remote path must not touch the local fallback on success.
        expect(fallbackOutput.outputCalled, isFalse);
      });

      test('should fall back locally when the remote send throws', () async {
        final endpoint = _MockLogEndpoint(throwOnSend: true);
        TomRemoteLogOutput.remoteEndpoint = endpoint;
        addTearDown(() => TomRemoteLogOutput.remoteEndpoint = null);

        fallbackOutput.completeOnOutput = Completer<void>();
        final remoteOutput = TomRemoteLogOutput();
        final fixedTime = DateTime(2026, 1, 2, 10, 0, 0);

        remoteOutput.output(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          'will fail',
          'main',
          fixedTime,
          null,
        );

        await endpoint.sent.future;
        await fallbackOutput.completeOnOutput!.future;

        expect(endpoint.sendCount, equals(1));
        // The send failure must be surfaced through the local fallback so the
        // record is not lost.
        expect(fallbackOutput.outputCalled, isTrue);
      });

      test('re-entrancy guard sends to fallback without calling the endpoint',
          () {
        final endpoint = _MockLogEndpoint();
        TomRemoteLogOutput.remoteEndpoint = endpoint;
        addTearDown(() => TomRemoteLogOutput.remoteEndpoint = null);

        final remoteOutput = TomRemoteLogOutput();
        final fixedTime = DateTime(2026, 1, 2, 10, 0, 0);

        // Simulate already being inside a remote-logging operation.
        runZoned(
          () {
            remoteOutput.output(
              TomLogLevel.production,
              TomLogLevel.info,
              'INFO   ',
              'reentrant',
              'main',
              fixedTime,
              null,
            );
          },
          zoneValues: {
            TomLoggingContext: TomLoggingContext(inRemoteLogging: true),
          },
        );

        // The guard short-circuits to the fallback synchronously and never
        // re-enters the endpoint.
        expect(endpoint.sendCount, equals(0));
        expect(fallbackOutput.outputCalled, isTrue);
        expect(fallbackOutput.lastMessage, equals('reentrant'));
      });
    });

    group('resilience', () {
      late _MockLogOutput fallbackOutput;

      setUp(() {
        fallbackOutput = _MockLogOutput();
        TomRemoteLogOutput.globalSettingFallbackOutput = fallbackOutput;
        TomRemoteLogOutput.remoteEndpoint = null;
        TomRemoteLogOutput.globalSettingMaxSendRetries = 0;
        TomRemoteLogOutput.globalSettingRetryBackoff = Duration.zero;
        TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 0;
        TomRemoteLogOutput.globalSettingReplayStore = TomInMemoryLogReplayStore();
        TomRemoteLogOutput.clearReplayQueue();
      });

      tearDown(() {
        TomRemoteLogOutput.globalSettingFallbackOutput = TomConsoleLogOutput();
        TomRemoteLogOutput.remoteEndpoint = null;
        TomRemoteLogOutput.globalSettingMaxSendRetries = 0;
        TomRemoteLogOutput.globalSettingRetryBackoff = Duration.zero;
        TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 0;
        TomRemoteLogOutput.globalSettingReplayStore = TomInMemoryLogReplayStore();
        TomRemoteLogOutput.clearReplayQueue();
      });

      final fixedTime = DateTime(2026, 1, 2, 10, 0, 0);

      Future<void> emit(TomRemoteLogOutput out, String message) {
        out.output(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          message,
          'main',
          fixedTime,
          null,
        );
        // output() is async fire-and-forget; drain the microtask/timer queue so
        // the awaited send + retry + fallback have completed before asserting.
        return Future<void>.delayed(Duration.zero);
      }

      group('defaults', () {
        test('replay queue is disabled by default', () {
          expect(TomRemoteLogOutput.globalSettingReplayQueueMaxSize, equals(0));
          expect(TomRemoteLogOutput.replayQueueLength, equals(0));
        });

        test('max retries and backoff default to none', () {
          expect(TomRemoteLogOutput.globalSettingMaxSendRetries, equals(0));
          expect(TomRemoteLogOutput.globalSettingRetryBackoff, Duration.zero);
        });
      });

      group('returned-error routing', () {
        test('a server-rejected record is written to the fallback, not dropped',
            () async {
          final endpoint =
              _MockLogEndpoint(script: const [_SendOutcome.returnError]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          await emit(TomRemoteLogOutput(), 'rejected record');

          // One attempt, then the record is surfaced locally rather than lost.
          expect(endpoint.sendCount, equals(1));
          expect(fallbackOutput.outputCalled, isTrue);
          expect(fallbackOutput.lastMessage, equals('rejected record'));
        });

        test('an unreachable endpoint is not reported as a server rejection',
            () async {
          // Since TomServerEndpoint translates "no response arrived" into a
          // returned error rather than a throw, an outage and a server-side
          // rejection reach this output through the same branch. Both must
          // route the record to the fallback — but the warning that accompanies
          // it has to say which one happened, or the operator reading the log
          // during an outage is told the server refused a record that no
          // server ever saw.
          final endpoint =
              _MockLogEndpoint(script: const [_SendOutcome.noResponse]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          await emit(TomRemoteLogOutput(), 'record during outage');

          // Not dropped: the resilience contract is unchanged by *how* the
          // failure is signalled.
          expect(endpoint.sendCount, equals(1));
          expect(fallbackOutput.lastMessage, equals('record during outage'));

          final warning = fallbackOutput.messages.firstWhere(
            (m) => m.startsWith('Could not send log message'),
            orElse: () => '',
          );
          expect(warning, contains('Connection refused'));
          expect(warning, isNot(contains('rejected')));
        });
      });

      group('retry with backoff', () {
        test('retries until a transient failure recovers', () async {
          TomRemoteLogOutput.globalSettingMaxSendRetries = 3;
          final endpoint = _MockLogEndpoint(script: const [
            _SendOutcome.throwError,
            _SendOutcome.throwError,
            _SendOutcome.ok,
          ]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          await emit(TomRemoteLogOutput(), 'eventually ok');

          // Two failures then success = three sends; no fallback needed.
          expect(endpoint.sendCount, equals(3));
          expect(endpoint.accepted.map((m) => m.message),
              equals(['eventually ok']));
          expect(fallbackOutput.outputCalled, isFalse);
        });

        test('gives up after exhausting the retry budget and falls back',
            () async {
          TomRemoteLogOutput.globalSettingMaxSendRetries = 2;
          final endpoint =
              _MockLogEndpoint(script: const [_SendOutcome.throwError]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          await emit(TomRemoteLogOutput(), 'always fails');

          // First attempt + 2 retries = 3 sends, all failing.
          expect(endpoint.sendCount, equals(3));
          expect(fallbackOutput.outputCalled, isTrue);
          expect(fallbackOutput.lastMessage, equals('always fails'));
        });

        test('backoff waits between retries', () async {
          TomRemoteLogOutput.globalSettingMaxSendRetries = 2;
          // Retry k waits backoff × k: 20ms then 40ms = 60ms minimum before the
          // third (successful) attempt. A lower-bound assertion stays robust.
          const backoff = Duration(milliseconds: 20);
          TomRemoteLogOutput.globalSettingRetryBackoff = backoff;
          final endpoint = _MockLogEndpoint(script: const [
            _SendOutcome.throwError,
            _SendOutcome.throwError,
            _SendOutcome.ok,
          ]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          final stopwatch = Stopwatch()..start();
          TomRemoteLogOutput().output(
            TomLogLevel.production,
            TomLogLevel.info,
            'INFO   ',
            'delayed',
            'main',
            fixedTime,
            null,
          );
          // Wait until the third attempt lands (or a generous timeout).
          while (endpoint.sendCount < 3 && stopwatch.elapsedMilliseconds < 5000) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          stopwatch.stop();

          expect(endpoint.sendCount, equals(3));
          expect(endpoint.accepted.map((m) => m.message), equals(['delayed']));
          // Total wait spans both backoffs (20 + 40 = 60ms); assert a safe
          // lower bound to prove the delays actually happened.
          expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(55));
        });
      });

      group('replay queue', () {
        test('buffers a failed record and drains it on the next send',
            () async {
          TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 5;
          final endpoint = _MockLogEndpoint(script: const [
            _SendOutcome.throwError, // first record fails -> queued
            _SendOutcome.ok, // drain of queued record succeeds
            _SendOutcome.ok, // then the second record itself
          ]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          final out = TomRemoteLogOutput();
          await emit(out, 'first');
          expect(TomRemoteLogOutput.replayQueueLength, equals(1));

          await emit(out, 'second');

          // The queued 'first' drains before 'second' is sent, in order.
          expect(TomRemoteLogOutput.replayQueueLength, equals(0));
          expect(endpoint.accepted.map((m) => m.message),
              equals(['first', 'second']));
        });

        test('drops the oldest record on overflow', () async {
          TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 2;
          // Every send throws so nothing drains and the queue keeps filling.
          final endpoint =
              _MockLogEndpoint(script: const [_SendOutcome.throwError]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          final out = TomRemoteLogOutput();
          await emit(out, 'r1');
          await emit(out, 'r2');
          await emit(out, 'r3');

          // Capacity 2, so the oldest ('r1') was dropped; 'r2','r3' remain.
          expect(TomRemoteLogOutput.replayQueueLength, equals(2));

          // Recover the endpoint and flush: only the surviving two replay.
          endpoint.accepted.clear();
          TomRemoteLogOutput.remoteEndpoint =
              _MockLogEndpoint(script: const [_SendOutcome.ok]);
          final recovered =
              TomRemoteLogOutput.remoteEndpoint as _MockLogEndpoint;
          await emit(out, 'r4');

          expect(TomRemoteLogOutput.replayQueueLength, equals(0));
          expect(recovered.accepted.map((m) => m.message),
              equals(['r2', 'r3', 'r4']));
        });

        test('stops draining when the endpoint is still down', () async {
          TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 5;
          // Records keep failing, so the queue never drains.
          final endpoint =
              _MockLogEndpoint(script: const [_SendOutcome.throwError]);
          TomRemoteLogOutput.remoteEndpoint = endpoint;

          final out = TomRemoteLogOutput();
          await emit(out, 'a');
          await emit(out, 'b');

          // Both remain buffered; nothing was accepted.
          expect(TomRemoteLogOutput.replayQueueLength, equals(2));
          expect(endpoint.accepted, isEmpty);
        });
      });

      group('durable replay store', () {
        late Directory tempDir;

        // A message factory that stamps the payload into every field we
        // serialize, so a round-trip through disk is fully verifiable.
        TomRemoteLogMessage record(String message) => TomRemoteLogMessage.of(
              TomLogLevel.production.levelPattern,
              TomLogLevel.info.levelPattern,
              'INFO   ',
              message,
              'main',
              '2026-01-02T10:00:00.000',
              'origin.$message',
            );

        setUp(() {
          tempDir = Directory.systemTemp.createTempSync('tom_log_replay_');
        });

        tearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        test('file store supports the full store contract', () {
          final store =
              TomFileLogReplayStore('${tempDir.path}/queue.json');

          expect(store.length, equals(0));
          expect(store.oldest, isNull);

          store.append(record('a'));
          store.append(record('b'));
          store.append(record('c'));

          expect(store.length, equals(3));
          expect(store.snapshot().map((m) => m.message),
              equals(['a', 'b', 'c']));
          expect(store.oldest?.message, equals('a'));

          store.removeOldest();
          expect(store.snapshot().map((m) => m.message), equals(['b', 'c']));

          store.trim(1);
          expect(store.snapshot().map((m) => m.message), equals(['c']));

          store.clear();
          expect(store.length, equals(0));
          expect(store.oldest, isNull);
        });

        test('a non-positive trim clears the file store', () {
          final store = TomFileLogReplayStore('${tempDir.path}/queue.json');
          store.append(record('a'));
          store.append(record('b'));

          store.trim(0);

          expect(store.length, equals(0));
        });

        test('records survive a simulated restart', () {
          final path = '${tempDir.path}/queue.json';

          // First process: buffer three records, then "exit".
          final first = TomFileLogReplayStore(path);
          first.append(record('a'));
          first.append(record('b'));
          first.append(record('c'));

          // Second process: a fresh store at the same path resumes the queue.
          final second = TomFileLogReplayStore(path);
          expect(second.length, equals(3));
          final reloaded = second.snapshot();
          expect(reloaded.map((m) => m.message), equals(['a', 'b', 'c']));
          // Every serialized field round-tripped, not just the message.
          expect(reloaded.first.level, equals('INFO   '));
          expect(reloaded.first.isolateName, equals('main'));
          expect(reloaded.first.origin, equals('origin.a'));
          expect(reloaded.first.loggerLevel,
              equals(TomLogLevel.production.levelPattern));
        });

        test('a bounded trim persists across a restart', () {
          final path = '${tempDir.path}/queue.json';

          final first = TomFileLogReplayStore(path);
          first.append(record('r1'));
          first.append(record('r2'));
          first.append(record('r3'));
          first.trim(2);

          final second = TomFileLogReplayStore(path);
          expect(second.snapshot().map((m) => m.message), equals(['r2', 'r3']));
        });

        test('buffered records replay after a restart once the endpoint '
            'recovers', () async {
          final path = '${tempDir.path}/queue.json';
          TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 5;

          // First process: endpoint is down, so records queue to disk.
          TomRemoteLogOutput.globalSettingReplayStore =
              TomFileLogReplayStore(path);
          TomRemoteLogOutput.remoteEndpoint =
              _MockLogEndpoint(script: const [_SendOutcome.throwError]);
          final firstOut = TomRemoteLogOutput();
          await emit(firstOut, 'a');
          await emit(firstOut, 'b');
          expect(TomRemoteLogOutput.replayQueueLength, equals(2));

          // Simulate a restart: a brand-new store instance at the same path
          // reloads the records the previous process buffered.
          TomRemoteLogOutput.globalSettingReplayStore =
              TomFileLogReplayStore(path);
          expect(TomRemoteLogOutput.replayQueueLength, equals(2));

          // The endpoint recovers; the next emit drains the buffered records
          // oldest-first ahead of the new one.
          final recovered = _MockLogEndpoint(script: const [_SendOutcome.ok]);
          TomRemoteLogOutput.remoteEndpoint = recovered;
          final secondOut = TomRemoteLogOutput();
          await emit(secondOut, 'c');

          expect(TomRemoteLogOutput.replayQueueLength, equals(0));
          expect(recovered.accepted.map((m) => m.message),
              equals(['a', 'b', 'c']));
        });
      });
    });
  });

  // =========================================================================
  // TOM ISOLATE LOG OUTPUT
  // =========================================================================

  group('TomIsolateLogOutput', () {
    group('constructor', () {
      test('should store the worker pool it is given', () async {
        final pool = await TomWorkerPool.withSize(1, _testLoggingContext());
        addTearDown(pool.close);

        final output = TomIsolateLogOutput(pool);

        expect(output.workerPool, same(pool));
      });
    });

    group('output', () {
      /// Runs [body] and collects anything the fire-and-forget dispatch throws.
      ///
      /// `output` deliberately does not await its pooled delivery, so it always
      /// returns normally and the *call* proves nothing. Dispatching to a
      /// closed pool does fail, though, and the rejected future reports to the
      /// zone it was created in — which turns "did a log line reach the pool?"
      /// into something a test can actually observe.
      Future<List<Object>> escapedErrorsFrom(void Function() body) async {
        final escaped = <Object>[];
        runZonedGuarded(body, (e, _) => escaped.add(e));
        await Future<void>.delayed(Duration(milliseconds: 50));
        return escaped;
      }

      test('does not route to the pool when the level is gated out', () async {
        final pool = await TomWorkerPool.withSize(1, _testLoggingContext());
        pool.close();
        final output = TomIsolateLogOutput(pool);

        // trace does not match a production logger level, so the gate must
        // short-circuit before the pool is ever asked to do anything.
        final escaped = escapedErrorsFrom(
          () => output.output(
            TomLogLevel.production,
            TomLogLevel.trace,
            'TRACE  ',
            'gated out',
            'main',
            DateTime(2026, 1, 2),
            null,
          ),
        );

        expect(await escaped, isEmpty);
      });

      test('routes to the pool when the level matches', () async {
        final pool = await TomWorkerPool.withSize(1, _testLoggingContext());
        pool.close();
        final output = TomIsolateLogOutput(pool);

        // The control for the test above: error matches a production logger
        // level, so this line must reach the pool. Without this, an empty
        // `escaped` list would be equally consistent with the detection
        // never working at all.
        final escaped = escapedErrorsFrom(
          () => output.output(
            TomLogLevel.production,
            TomLogLevel.error,
            'ERROR  ',
            'routed',
            'main',
            DateTime(2026, 1, 2),
            null,
          ),
        );

        expect(await escaped, contains(isA<TomWorkerException>()));
      });
    });
  });

  // =========================================================================
  // TOM CREATOR LOG OUTPUT
  // =========================================================================

  group('TomCreatorLogOutput', () {
    group('fallbackOutput', () {
      test('should be TomConsoleLogOutput by default', () {
        expect(TomCreatorLogOutput.fallbackOutput, isA<TomConsoleLogOutput>());
      });
    });

    group('output', () {
      late _MockConsoleLogOutput fallback;

      setUp(() {
        fallback = _MockConsoleLogOutput();
        TomCreatorLogOutput.fallbackOutput = fallback;
      });

      tearDown(() {
        TomCreatorLogOutput.fallbackOutput = TomConsoleLogOutput();
      });

      test('falls back to local output when not in a worker isolate', () {
        // In the main isolate TomWorker.canSendToCreator() is false, so the
        // creator output must route to its fallback.
        final output = TomCreatorLogOutput();

        output.output(
          TomLogLevel.production,
          TomLogLevel.info,
          'INFO   ',
          'creator message',
          'main',
          DateTime(2026, 1, 2),
          null,
        );

        expect(fallback.outputCalled, isTrue);
        expect(fallback.lastMessage, equals('creator message'));
      });

      test('does not output when the level is gated out', () {
        final output = TomCreatorLogOutput();

        output.output(
          TomLogLevel.production,
          TomLogLevel.trace,
          'TRACE  ',
          'gated out',
          'main',
          DateTime(2026, 1, 2),
          null,
        );

        expect(fallback.outputCalled, isFalse);
      });
    });
  });

  // =========================================================================
  // TOM ISOLATE LOGGING
  // =========================================================================

  group('TomIsolateLogging', () {
    test('startLoggingToCreator swaps tomLog.logOutput to TomCreatorLogOutput',
        () {
      final original = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = original);

      TomIsolateLogging.startLoggingToCreator();

      expect(tomLog.logOutput, isA<TomCreatorLogOutput>());
    });
  });

  // =========================================================================
  // TOM LOGGING WORKER CONTEXT
  // =========================================================================

  group('TomLoggingWorkerContext', () {
    test('is a TomWorkerContext', () {
      final context = _testLoggingContext();
      expect(context, isA<TomWorkerContext>());
    });

    test('initializeIsolate registers a TomLoggingExecutor', () async {
      // initializeIsolate mutates the global TomWorker.executors list, so
      // snapshot it and restore afterwards to avoid leaking into other tests.
      final before = List<TomExecutor>.from(TomWorker.executors);
      addTearDown(() {
        TomWorker.executors
          ..clear()
          ..addAll(before);
      });

      final context = _testLoggingContext();
      await context.initializeIsolate();

      // Registering the executor is the whole of the hook's contract; it
      // reports a failure by throwing, so completing normally is the success
      // signal and there is no return value to check.
      expect(TomWorker.executors.length, equals(before.length + 1));
      expect(TomWorker.executors.last, isA<TomLoggingExecutor>());
    });
  });
}

/// Builds a logging worker context for the isolate-logging tests.
///
/// Uses literal environment/platform values rather than [TomRuntime] so the
/// test does not depend on the global runtime singleton being initialised.
TomLoggingWorkerContext _testLoggingContext() {
  return TomLoggingWorkerContext(
    const TomEnvironment('test', isTest: true),
    platformWeb,
    const <String>[],
    'L',
  );
}

// =============================================================================
// TEST HELPERS
// =============================================================================

/// Mock log output for testing
class _MockLogOutput extends TomLogOutput {
  String? lastMessage;
  String? lastLevel;
  String? lastIsolateName;
  String? lastOrigin;
  DateTime? lastTimeStamp;
  TomLogLevel? lastLoggerLevel;
  TomLogLevel? lastLogLevel;
  bool outputCalled = false;

  /// Optional completer signalled on the first `output` call. Lets async
  /// fire-and-forget paths (e.g. [TomRemoteLogOutput.output]) be awaited
  /// deterministically instead of relying on timers.
  Completer<void>? completeOnOutput;

  /// Every accepted message in order. A failed remote send writes two lines —
  /// a warning naming the cause, then the record itself — and `lastMessage`
  /// only keeps the second, so assertions about the cause read this instead.
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    outputCalled = true;
    if (logLevel.matches(loggerLevel)) {
      lastLoggerLevel = loggerLevel;
      lastLogLevel = logLevel;
      lastLevel = level;
      lastMessage = convertToString(message);
      lastIsolateName = isolateName;
      lastTimeStamp = timeStamp;
      lastOrigin = origin;
      messages.add(lastMessage!);
    }
    if (completeOnOutput != null && !completeOnOutput!.isCompleted) {
      completeOnOutput!.complete();
    }
  }

  void reset() {
    lastMessage = null;
    lastLevel = null;
    lastIsolateName = null;
    lastOrigin = null;
    lastTimeStamp = null;
    lastLoggerLevel = null;
    lastLogLevel = null;
    outputCalled = false;
    messages.clear();
  }
}

/// Console-typed mock used where the slot is statically typed
/// [TomConsoleLogOutput] (e.g. [TomCreatorLogOutput.fallbackOutput]). Records
/// the last call without writing to the real console.
class _MockConsoleLogOutput extends TomConsoleLogOutput {
  String? lastMessage;
  bool outputCalled = false;

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    outputCalled = true;
    if (logLevel.matches(loggerLevel)) {
      lastMessage = convertToString(message);
    }
  }
}

/// How a single scripted [_MockLogEndpoint] send should behave.
enum _SendOutcome {
  /// Succeed with an empty result and no error.
  ok,

  /// Throw a transport exception.
  throwError,

  /// Return a non-null [TomServerCallError] (a server-side rejection).
  returnError,

  /// Return the error a real [TomServerEndpoint] produces when no response
  /// arrives at all — a refused connection, an expired deadline, an abort.
  noResponse,
}

/// Mock remote endpoint that records the messages it is handed and behaves
/// according to a script, exercising [TomRemoteLogOutput]'s send, retry and
/// fallback paths without any real network. The channel/specs handed to
/// `super` are never used because [send] is fully overridden.
class _MockLogEndpoint
    extends TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult> {
  _MockLogEndpoint({bool throwOnSend = false, List<_SendOutcome>? script})
      : script = script ??
            (throwOnSend
                ? const [_SendOutcome.throwError]
                : const [_SendOutcome.ok]),
        super(
          TomServerChannel('localhost', 80),
          TomServerCallSpecs('POST', Uri.parse('http://localhost/remotelog')),
        );

  /// Per-call outcomes; the last entry repeats once the script is exhausted.
  final List<_SendOutcome> script;

  int sendCount = 0;
  TomRemoteLogMessage? lastMessage;

  /// Every message this endpoint accepted (`ok` outcomes), in order — lets a
  /// test assert the exact drain/replay ordering.
  final List<TomRemoteLogMessage> accepted = [];
  final Completer<void> sent = Completer<void>();

  @override
  Future<(TomRemoteLogResult, TomServerCallError?)> send(
    TomRemoteLogMessage load, [
    TomRemoteLogResult? responseObject,
  ]) async {
    final outcome =
        script[sendCount < script.length ? sendCount : script.length - 1];
    sendCount++;
    lastMessage = load;
    if (!sent.isCompleted) {
      sent.complete();
    }
    switch (outcome) {
      case _SendOutcome.throwError:
        throw Exception('network down');
      case _SendOutcome.returnError:
        return (
          responseObject ?? TomRemoteLogResult(),
          TomServerCallError(statusCode: 500),
        );
      case _SendOutcome.noResponse:
        // Exactly the shape TomServerEndpoint.send returns for an unreachable
        // server: no status, no body, the underlying failure in `exception`.
        // That contract is pinned by the "TomServerEndpoint.send with no
        // response" group in http_connection_test.dart; this reproduces it so
        // the log output's routing can be tested without a live socket.
        return (
          responseObject ?? TomRemoteLogResult(),
          TomServerCallError(
            statusCode: 0,
            internalError: TomServerCallError.noResponseError,
            exception: Exception('Connection refused'),
          ),
        );
      case _SendOutcome.ok:
        accepted.add(load);
        return (responseObject ?? TomRemoteLogResult(), null);
    }
  }
}

/// A log output that always fails
class _FailingLogOutput extends TomLogOutput {
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    throw Exception('Intentional failure');
  }
}

/// Test implementation of TomLogOutput for testing convertToString
class _TestLogOutput extends TomLogOutput {
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    // Not used in tests
  }
}

/// Test implementation of TomLoggable
class _TestLoggable implements TomLoggable {
  final String _representation;

  _TestLoggable(this._representation);

  @override
  String get logRepresentation => _representation;
}

/// Test object for toString conversion
class _TestObject {
  final int value;

  _TestObject(this.value);

  @override
  String toString() => 'TestObject($value)';
}
