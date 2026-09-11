import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(() {
    // Initialize timezone database before running tests
    tz_data.initializeTimeZones();
  });

  group('TomTimezone', () {
    group('UTC timezone', () {
      test('utc static field should have timezone name "UTC"', () {
        expect(TomTimezone.utc.timezone, equals('UTC'));
      });

      test('utc static field should have offset of 0 minutes', () {
        expect(TomTimezone.utc.timezoneOffsetMin, equals(0));
      });
    });

    group('fromName', () {
      test('should return UTC timezone for "UTC"', () {
        final tzUtc = TomTimezone.fromName('UTC');
        expect(tzUtc, isNotNull);
        expect(tzUtc!.timezone, equals('UTC'));
      });

      test('should return timezone for "America/New_York"', () {
        final tzNy = TomTimezone.fromName('America/New_York');
        expect(tzNy, isNotNull);
        expect(tzNy!.timezone, equals('America/New_York'));
      });

      test('should return timezone for "Europe/Berlin"', () {
        final tzBerlin = TomTimezone.fromName('Europe/Berlin');
        expect(tzBerlin, isNotNull);
        expect(tzBerlin!.timezone, equals('Europe/Berlin'));
      });

      test('should return timezone for "Asia/Tokyo"', () {
        final tzTokyo = TomTimezone.fromName('Asia/Tokyo');
        expect(tzTokyo, isNotNull);
        expect(tzTokyo!.timezone, equals('Asia/Tokyo'));
        // Tokyo is UTC+9 (540 minutes), no DST
        expect(tzTokyo.timezoneOffsetMin, equals(540));
      });

      test('should return timezone for "Australia/Sydney"', () {
        final tzSydney = TomTimezone.fromName('Australia/Sydney');
        expect(tzSydney, isNotNull);
        expect(tzSydney!.timezone, equals('Australia/Sydney'));
      });

      test('should be case insensitive', () {
        final tz1 = TomTimezone.fromName('Europe/London');
        final tz2 = TomTimezone.fromName('europe/london');
        final tz3 = TomTimezone.fromName('EUROPE/LONDON');
        expect(tz1, isNotNull);
        expect(tz2, isNotNull);
        expect(tz3, isNotNull);
        expect(tz1!.timezone, equals(tz2!.timezone));
        expect(tz2.timezone, equals(tz3!.timezone));
      });

      test('should return null for unknown timezone', () {
        final tzUnknown = TomTimezone.fromName('Unknown/Timezone');
        expect(tzUnknown, isNull);
      });
    });

    group('timezones map', () {
      test('should contain multiple timezones after initialization', () {
        final timezones = TomTimezone.timezones;
        expect(timezones.length, greaterThan(100));
      });

      test('should contain common timezones', () {
        final timezones = TomTimezone.timezones;
        expect(timezones.containsKey('UTC'), isTrue);
        expect(timezones.containsKey('AMERICA/NEW_YORK'), isTrue);
        expect(timezones.containsKey('EUROPE/LONDON'), isTrue);
        expect(timezones.containsKey('ASIA/TOKYO'), isTrue);
        expect(timezones.containsKey('AUSTRALIA/SYDNEY'), isTrue);
        expect(timezones.containsKey('AMERICA/LOS_ANGELES'), isTrue);
      });
    });

    group('firstWithOffset', () {
      test('should return a timezone with offset 0 for UTC', () {
        final tzZero = TomTimezone.firstWithOffset(0);
        expect(tzZero, isNotNull);
        expect(tzZero!.timezoneOffsetMin, equals(0));
      });

      test('should return a timezone with offset 540 for Tokyo time', () {
        final tzTokyo = TomTimezone.firstWithOffset(540);
        expect(tzTokyo, isNotNull);
        expect(tzTokyo!.timezoneOffsetMin, equals(540));
      });
    });

    group('allWithOffset', () {
      test('should return list of timezones with given offset', () {
        final tzList = TomTimezone.allWithOffset(0);
        expect(tzList, isNotNull);
        expect(tzList!.isNotEmpty, isTrue);
        for (final timezone in tzList) {
          expect(timezone.timezoneOffsetMin, equals(0));
        }
      });

      test('should return multiple timezones for common offsets', () {
        // UTC+0 should have multiple timezones (UTC, Europe/London in winter, etc.)
        final tzList = TomTimezone.allWithOffset(0);
        expect(tzList, isNotNull);
        expect(tzList!.length, greaterThan(1));
      });

      test('should return null for non-existent offset', () {
        // An offset that likely doesn't exist (e.g., 999 minutes = 16h39m)
        final tzList = TomTimezone.allWithOffset(999);
        expect(tzList, isNull);
      });
    });

    // =========================================================================
    // The lookups hand out views, not the index
    // =========================================================================
    //
    // Handing back the internal collection itself would let one line from
    // outside the class corrupt the database for the life of the process: the
    // index is built once at first access and never rebuilt, so nothing would
    // repair it. The damage would also be quiet — sorting a returned list, or
    // filtering it with `removeWhere`, reads as ordinary work, and the
    // consequence appears somewhere else entirely, as `firstWithOffset`
    // answering with a different zone or `fromName` resolving a name the IANA
    // database has never held.
    //
    // So the refusal has to be at the call, which is the only place a caller
    // can act on it. Each test asserts two things, and they fail to different
    // mistakes: that the write throws, which a live collection does not, and
    // that the lookups still answer afterwards, which an unmodifiable view over
    // the wrong collection — an empty one, a snapshot taken too early — would
    // not. Refusing to be written is worth nothing if the price is refusing to
    // be read.
    group('the lookup results are unmodifiable', () {
      test('the timezone map refuses a write, and keeps its contents', () {
        final map = TomTimezone.timezones;
        final before = map.length;

        expect(
          () => map['ZZZ'] = TomTimezone.utc,
          throwsUnsupportedError,
          reason: 'A write here would make fromName resolve an invented name.',
        );
        expect(() => map.remove('UTC'), throwsUnsupportedError);
        expect(() => map.clear(), throwsUnsupportedError);

        expect(TomTimezone.fromName('ZZZ'), isNull);
        expect(TomTimezone.fromName('UTC'), isNotNull);
        expect(TomTimezone.timezones.length, equals(before));
      });

      test('an offset bucket refuses a write, and keeps its contents', () {
        final bucket = TomTimezone.allWithOffset(0)!;
        final before = bucket.length;
        final first = TomTimezone.firstWithOffset(0)!.timezone;

        expect(() => bucket.add(TomTimezone.utc), throwsUnsupportedError);
        // The two that do not read as dangerous, which is why they are here.
        expect(() => bucket.sort(), throwsUnsupportedError);
        expect(
          () => bucket.removeWhere((tz) => tz.timezone != 'UTC'),
          throwsUnsupportedError,
        );

        expect(TomTimezone.allWithOffset(0), hasLength(before));
        expect(TomTimezone.firstWithOffset(0)!.timezone, equals(first));
      });

      test('a view still reads what the index holds', () {
        // The other half of the contract: unmodifiable must not mean stale or
        // partial. Both getters answer with everything the class itself sees.
        final map = TomTimezone.timezones;
        expect(map.containsKey('UTC'), isTrue);
        expect(map['EUROPE/LONDON']?.timezone, equals('Europe/London'));

        final bucket = TomTimezone.allWithOffset(0)!;
        expect(bucket, contains(TomTimezone.firstWithOffset(0)));
        for (final zone in bucket) {
          expect(zone.timezoneOffsetMin, equals(0));
        }
      });
    });

    // The offset lookups answer "who is at this offset *right now*", and the
    // documentation says so in three places. These tests are what those
    // sentences are measured against — without them the caveat is a claim
    // about behaviour that nothing holds to the behaviour.
    //
    // Every assertion here is phrased so that it holds in either season: the
    // zone's two offsets are read from the database rather than written down,
    // and which of them is current is derived. A test that hard-coded "New
    // York is at -300" would pass all winter and fail all summer, which is the
    // very mistake the documentation was making.
    group('offset lookups answer for the current moment', () {
      // Both offsets a northern-hemisphere DST zone takes, read from the
      // database rather than assumed.
      const winter = 1; // January
      const summer = 7; // July
      final newYork = TomTimezone.fromName('America/New_York')!;
      final winterOffset = newYork.getUtcOffsetOn(
        DateTime.utc(2024, winter, 15),
      );
      final summerOffset = newYork.getUtcOffsetOn(
        DateTime.utc(2024, summer, 15),
      );

      test('a DST zone sits in the bucket for the offset it has now', () {
        final current = newYork.timezoneOffsetMin;
        expect(
          current,
          anyOf(equals(winterOffset), equals(summerOffset)),
          reason:
              'The zone reports an offset that is neither of the two it takes '
              'across the year, so the rest of this group is testing a '
              'premise that no longer holds.',
        );
        expect(
          TomTimezone.allWithOffset(current)?.map((tz) => tz.timezone),
          contains(newYork.timezone),
          reason:
              'A zone is indexed under the offset it had when the index was '
              'built. If it is missing from its own current bucket, offset '
              'lookup cannot find it at all.',
        );
      });

      test('and in no other bucket, including its other season', () {
        final other = newYork.timezoneOffsetMin == winterOffset
            ? summerOffset
            : winterOffset;

        expect(
          TomTimezone.allWithOffset(other)?.map((tz) => tz.timezone) ??
              const [],
          isNot(contains(newYork.timezone)),
          reason:
              'The zone appears in the bucket for the offset it holds in the '
              'other half of the year. Offset lookup would then be '
              'season-independent, and the shelf-life caveat the module '
              'documents would be describing a hazard that does not exist.',
        );
      });

      test('so a third of the database moves between buckets each year', () {
        final movers = TomTimezone.timezones.values
            .where(
              (tz) =>
                  tz.getUtcOffsetOn(DateTime.utc(2024, winter, 15)) !=
                  tz.getUtcOffsetOn(DateTime.utc(2024, summer, 15)),
            )
            .length;

        expect(
          movers,
          greaterThan(50),
          reason:
              'Only a handful of zones change offset across the year, so the '
              'documented caveat is describing a corner case rather than a '
              'property of the database. Either the database shrank or the '
              'offsets stopped being read per-instant.',
        );
      });

      test('the buckets partition the database by current offset', () {
        final byOffset = <String, int>{};
        for (final zone in TomTimezone.timezones.values) {
          final bucket = TomTimezone.allWithOffset(zone.timezoneOffsetMin);
          expect(
            bucket?.map((tz) => tz.timezone),
            contains(zone.timezone),
            reason:
                '${zone.timezone} is not in the bucket for its own current '
                'offset, so the index and the getter disagree about what the '
                'zone\'s offset is.',
          );
          byOffset[zone.timezone] = zone.timezoneOffsetMin;
        }

        // Non-vacuity: the loop above passes trivially over an empty database.
        expect(byOffset, hasLength(greaterThan(300)));
        expect(byOffset.values.toSet(), hasLength(greaterThan(20)));
      });

      test('"first" means first in the bucket, not most prominent', () {
        for (final offset in [0, 60, 330, 540]) {
          expect(
            TomTimezone.firstWithOffset(offset)?.timezone,
            equals(TomTimezone.allWithOffset(offset)?.first.timezone),
            reason:
                'firstWithOffset returned something other than the head of '
                'allWithOffset for $offset. The documentation tells callers '
                'not to expect the well-known zone precisely because the two '
                'are the same list in the same order.',
          );
        }
      });
    });

    group('findTimezone', () {
      test(
        'should throw TomTimezoneException when name does not match offset',
        () {
          expect(
            () => TomTimezone.findTimezone('UTC', 60),
            throwsA(isA<TomTimezoneException>()),
          );
        },
      );

      test(
        'should throw TomTimezoneException for America/New_York with wrong offset',
        () {
          expect(
            () => TomTimezone.findTimezone('America/New_York', 0),
            throwsA(isA<TomTimezoneException>()),
          );
        },
      );

      test('should return timezone when name and offset match', () {
        final utcTz = TomTimezone.fromName('UTC');
        final tzResult = TomTimezone.findTimezone(
          'UTC',
          utcTz!.timezoneOffsetMin,
        );
        expect(tzResult, isNotNull);
        expect(tzResult!.timezone, equals('UTC'));
      });

      test('should return Asia/Tokyo when name and offset match', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final tzResult = TomTimezone.findTimezone(
          'Asia/Tokyo',
          tokyoTz!.timezoneOffsetMin,
        );
        expect(tzResult, isNotNull);
        expect(tzResult!.timezone, equals('Asia/Tokyo'));
      });

      test('should return first timezone with offset when name is null', () {
        final tzResult = TomTimezone.findTimezone(null, 0);
        expect(tzResult, isNotNull);
        expect(tzResult!.timezoneOffsetMin, equals(0));
      });

      test('should return null when both name and offset are null', () {
        final tzResult = TomTimezone.findTimezone(null, null);
        expect(tzResult, isNull);
      });

      // A name-only lookup (offset null) must return the named zone instead of
      // throwing a name/offset-mismatch exception.
      test(
        'should return named zone when name is given and offset is null',
        () {
          final tzResult = TomTimezone.findTimezone('Asia/Tokyo', null);
          expect(tzResult, isNotNull);
          expect(tzResult!.timezone, equals('Asia/Tokyo'));
        },
      );

      test('should return UTC when name is "UTC" and offset is null', () {
        final tzResult = TomTimezone.findTimezone('UTC', null);
        expect(tzResult, isNotNull);
        expect(tzResult!.timezone, equals('UTC'));
      });

      // An unknown name is a fault here, not an empty answer: fromName returns
      // null for the same name. Both offset shapes are pinned because a
      // name-only lookup looks like the case that would be let through.
      test('should throw TomTimezoneException for an unknown name', () {
        expect(
          () => TomTimezone.findTimezone('Mars/Olympus', 0),
          throwsA(isA<TomTimezoneException>()),
        );
      });

      test(
        'should throw TomTimezoneException for an unknown name when offset is null',
        () {
          expect(TomTimezone.fromName('Mars/Olympus'), isNull);
          expect(
            () => TomTimezone.findTimezone('Mars/Olympus', null),
            throwsA(isA<TomTimezoneException>()),
          );
        },
      );
    });

    group('convertMinutesToUtcOffset', () {
      test('should return "Z" for 0 minutes', () {
        expect(TomTimezone.convertMinutesToUtcOffset(0), equals('Z'));
      });

      test('should return "+01:00" for 60 minutes', () {
        expect(TomTimezone.convertMinutesToUtcOffset(60), equals('+01:00'));
      });

      test('should return "-05:00" for -300 minutes (EST)', () {
        expect(TomTimezone.convertMinutesToUtcOffset(-300), equals('-05:00'));
      });

      test('should return "-04:00" for -240 minutes (EDT)', () {
        expect(TomTimezone.convertMinutesToUtcOffset(-240), equals('-04:00'));
      });

      test('should return "+05:30" for 330 minutes (India)', () {
        expect(TomTimezone.convertMinutesToUtcOffset(330), equals('+05:30'));
      });

      test('should return "+09:00" for 540 minutes (Tokyo)', () {
        expect(TomTimezone.convertMinutesToUtcOffset(540), equals('+09:00'));
      });

      test('should return "-09:30" for -570 minutes', () {
        expect(TomTimezone.convertMinutesToUtcOffset(-570), equals('-09:30'));
      });

      test('should return "+12:00" for 720 minutes (Auckland)', () {
        expect(TomTimezone.convertMinutesToUtcOffset(720), equals('+12:00'));
      });

      test('should return "-08:00" for -480 minutes (PST)', () {
        expect(TomTimezone.convertMinutesToUtcOffset(-480), equals('-08:00'));
      });
    });

    group('getUtcOffsetOn', () {
      test('should return offset 0 for UTC at any date', () {
        final utc = TomTimezone.utc;
        expect(utc.getUtcOffsetOn(DateTime.utc(2024, 1, 15)), equals(0));
        expect(utc.getUtcOffsetOn(DateTime.utc(2024, 7, 15)), equals(0));
      });

      test('should return consistent offset for Tokyo (no DST)', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        // Tokyo doesn't observe DST, so offset should be 540 all year
        expect(tokyo.getUtcOffsetOn(DateTime.utc(2024, 1, 15)), equals(540));
        expect(tokyo.getUtcOffsetOn(DateTime.utc(2024, 7, 15)), equals(540));
      });

      test(
        'should return different offsets for New York in winter vs summer',
        () {
          final newYork = TomTimezone.fromName('America/New_York')!;
          // Winter (EST): -300 minutes (-5 hours)
          final winterOffset = newYork.getUtcOffsetOn(
            DateTime.utc(2024, 1, 15),
          );
          // Summer (EDT): -240 minutes (-4 hours)
          final summerOffset = newYork.getUtcOffsetOn(
            DateTime.utc(2024, 7, 15),
          );
          expect(winterOffset, equals(-300));
          expect(summerOffset, equals(-240));
        },
      );

      test(
        'should return different offsets for Berlin in winter vs summer',
        () {
          final berlin = TomTimezone.fromName('Europe/Berlin')!;
          // Winter (CET): +60 minutes (+1 hour)
          final winterOffset = berlin.getUtcOffsetOn(DateTime.utc(2024, 1, 15));
          // Summer (CEST): +120 minutes (+2 hours)
          final summerOffset = berlin.getUtcOffsetOn(DateTime.utc(2024, 7, 15));
          expect(winterOffset, equals(60));
          expect(summerOffset, equals(120));
        },
      );
    });

    group('toTZDateTime', () {
      test('should convert DateTime to TZDateTime in UTC', () {
        final utc = TomTimezone.utc;
        final dt = DateTime.utc(2024, 6, 15, 12, 30, 0);
        final tzDt = utc.toTZDateTime(dt);
        expect(tzDt.year, equals(2024));
        expect(tzDt.month, equals(6));
        expect(tzDt.day, equals(15));
        expect(tzDt.hour, equals(12));
        expect(tzDt.minute, equals(30));
      });

      test('should convert DateTime to TZDateTime in Tokyo timezone', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final dt = DateTime.utc(2024, 6, 15, 3, 0, 0); // 3 AM UTC
        final tzDt = tokyo.toTZDateTime(dt);
        // Tokyo is UTC+9, so 3 AM UTC = 12 PM Tokyo
        expect(tzDt.hour, equals(12));
        expect(tzDt.day, equals(15));
      });

      test('should convert DateTime to TZDateTime in New York timezone', () {
        final newYork = TomTimezone.fromName('America/New_York')!;
        final dt = DateTime.utc(2024, 7, 15, 16, 0, 0); // 4 PM UTC in summer
        final tzDt = newYork.toTZDateTime(dt);
        // Summer: NYC is UTC-4, so 4 PM UTC = 12 PM NYC
        expect(tzDt.hour, equals(12));
        expect(tzDt.day, equals(15));
      });
    });

    group('now', () {
      test('should return current time in UTC timezone', () {
        final utc = TomTimezone.utc;
        final now = utc.now();
        final dartNow = DateTime.now().toUtc();
        // Allow 2 seconds difference for test execution time
        expect(now.difference(dartNow).inSeconds.abs(), lessThan(2));
      });

      test('should return current time in Tokyo timezone', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final now = tokyo.now();
        // Verify it returns a TZDateTime with Tokyo location
        expect(now, isA<tz.TZDateTime>());
        expect((now as tz.TZDateTime).location.name, equals('Asia/Tokyo'));
      });
    });

    group('changeLocation', () {
      test('should convert time from UTC to Tokyo', () {
        final utc = TomTimezone.utc;
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final utcTime = DateTime.utc(2024, 6, 15, 0, 0, 0); // Midnight UTC
        final tokyoTime = TomTimezone.changeLocation(utcTime, utc, tokyo);
        // Midnight UTC = 9 AM Tokyo
        expect(tokyoTime.hour, equals(9));
      });

      test('should convert time from Tokyo to New York', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;
        // Noon on a Tokyo clock. Tokyo is UTC+9, so this is 3 AM UTC, which is
        // 11 PM on July 14 in New York (EDT, UTC-4). Note the reading is given
        // as it stands: resolving it against Tokyo is the method's own job.
        final tokyoNoon = DateTime.utc(2024, 7, 15, 12, 0, 0);
        final nyTime = TomTimezone.changeLocation(tokyoNoon, tokyo, newYork);
        expect(nyTime.hour, equals(23));
        expect(nyTime.day, equals(14));
      });

      // The assertion whose absence let the source zone sit dead: everything
      // is held fixed except `inTimezone`, so a result that ignored it would
      // return the same hour three times.
      test('should vary the result with the source timezone alone', () {
        final utc = TomTimezone.utc;
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final berlin = TomTimezone.fromName('Europe/Berlin')!;
        final reading = DateTime.utc(2024, 6, 15, 5, 0, 0);

        // Read as a UTC clock: 5 AM UTC is 7 AM in Berlin (CEST, UTC+2).
        final fromUtc = TomTimezone.changeLocation(reading, utc, berlin);
        expect(fromUtc.hour, equals(7));
        // Read as a Tokyo clock: 5 AM there is 8 PM UTC the previous day,
        // which is 10 PM on June 14 in Berlin.
        final fromTokyo = TomTimezone.changeLocation(reading, tokyo, berlin);
        expect(fromTokyo.hour, equals(22));
        expect(fromTokyo.day, equals(14));
        // Read as a Berlin clock, rendered in Berlin: unchanged.
        expect(
          TomTimezone.changeLocation(reading, berlin, berlin).hour,
          equals(5),
        );
      });

      // A non-UTC `DateTime` is the constructor most callers reach for, and it
      // used to make the answer depend on the host machine's zone. Only the
      // calendar fields are read now, so the two constructions agree and the
      // result is the same on every machine.
      test('should read the calendar fields of a non-UTC DateTime', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;
        final localReading = DateTime(2024, 7, 15, 12, 0, 0);
        final utcReading = DateTime.utc(2024, 7, 15, 12, 0, 0);

        final fromLocal = TomTimezone.changeLocation(
          localReading,
          tokyo,
          newYork,
        );
        final fromUtc = TomTimezone.changeLocation(utcReading, tokyo, newYork);

        expect(fromLocal.isAtSameMomentAs(fromUtc), isTrue);
        expect(fromLocal.hour, equals(23));
        expect(fromLocal.day, equals(14));
      });

      test('should carry sub-second parts through the conversion', () {
        final utc = TomTimezone.utc;
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final reading = DateTime.utc(2024, 6, 15, 0, 0, 30, 250, 125);
        final converted = TomTimezone.changeLocation(reading, utc, tokyo);
        expect(converted.second, equals(30));
        expect(converted.millisecond, equals(250));
        expect(converted.microsecond, equals(125));
      });

      // Pins the two readings a wall clock cannot express unambiguously. The
      // choice is `package:timezone`'s, made by its guess-and-correct
      // `Location.translateToUtc`, not a policy this method states; these
      // tests exist so that a change in it is caught here rather than in a
      // caller. Berlin springs forward 2 AM -> 3 AM on 2024-03-31 and falls
      // back 3 AM -> 2 AM on 2024-10-27; both edge readings land on CET.
      test('should resolve a spring-forward gap reading deterministically', () {
        final berlin = TomTimezone.fromName('Europe/Berlin')!;
        final utc = TomTimezone.utc;
        // 2:30 AM never showed on a Berlin clock that day.
        final gap = DateTime.utc(2024, 3, 31, 2, 30, 0);
        final asUtc = TomTimezone.changeLocation(gap, berlin, utc);
        // Taken as CET (UTC+1), the offset in force before the jump.
        expect(asUtc.hour, equals(1));
        expect(asUtc.minute, equals(30));
      });

      test('should resolve an ambiguous fall-back reading predictably', () {
        final berlin = TomTimezone.fromName('Europe/Berlin')!;
        final utc = TomTimezone.utc;
        // 2:30 AM showed twice that day: once as CEST (UTC+2), then as CET.
        final ambiguous = DateTime.utc(2024, 10, 27, 2, 30, 0);
        final asUtc = TomTimezone.changeLocation(ambiguous, berlin, utc);
        // Taken as CET (UTC+1), the second of the two passes.
        expect(asUtc.hour, equals(1));
        expect(asUtc.minute, equals(30));
      });
    });

    group('changeToThisLocation', () {
      test('should agree with changeLocation targeting this timezone', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;
        final reading = DateTime.utc(2024, 7, 15, 12, 0, 0);

        expect(
          newYork.changeToThisLocation(reading, tokyo),
          equals(TomTimezone.changeLocation(reading, tokyo, newYork)),
        );
      });

      test('should read the reading in the given source timezone', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;
        // Noon on a Tokyo clock is 11 PM the previous day in New York.
        final tokyoNoon = DateTime.utc(2024, 7, 15, 12, 0, 0);
        final nyTime = newYork.changeToThisLocation(tokyoNoon, tokyo);
        expect(nyTime.hour, equals(23));
        expect(nyTime.day, equals(14));
      });

      test('should vary the result with the source timezone alone', () {
        final utc = TomTimezone.utc;
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final berlin = TomTimezone.fromName('Europe/Berlin')!;
        final reading = DateTime.utc(2024, 6, 15, 5, 0, 0);

        expect(berlin.changeToThisLocation(reading, utc).hour, equals(7));
        expect(berlin.changeToThisLocation(reading, tokyo).hour, equals(22));
        expect(berlin.changeToThisLocation(reading, berlin).hour, equals(5));
      });
    });
  });

  group('TomTimezoned', () {
    group('constructor', () {
      test('should create with default UTC timezone', () {
        final tt = TomTimezoned.fromDateTime(DateTime.utc(2024, 6, 15, 12, 30));
        expect(tt.timezone.timezone, equals('UTC'));
      });

      test('should create with America/New_York timezone', () {
        final nyTz = TomTimezone.fromName('America/New_York');
        final tt = TomTimezoned.fromDateTime(
          DateTime.utc(2024, 6, 15, 12, 30),
          nyTz,
        );
        expect(tt.timezone.timezone, equals('America/New_York'));
      });

      test('should create with Europe/Berlin timezone', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final tt = TomTimezoned.fromDateTime(
          DateTime.utc(2024, 6, 15, 12, 30),
          berlinTz,
        );
        expect(tt.timezone.timezone, equals('Europe/Berlin'));
      });

      test('should create with Asia/Tokyo timezone', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final tt = TomTimezoned.fromDateTime(
          DateTime.utc(2024, 6, 15, 12, 30),
          tokyoTz,
        );
        expect(tt.timezone.timezone, equals('Asia/Tokyo'));
      });
    });

    group('now factory', () {
      test('should create current time with UTC timezone by default', () {
        final tt = TomTimezoned.now();
        expect(tt.timezone.timezone, equals('UTC'));
        final now = DateTime.now().toUtc();
        expect(tt.difference(now).inSeconds.abs(), lessThan(2));
      });

      test('should create current time with Europe/London timezone', () {
        final londonTz = TomTimezone.fromName('Europe/London');
        final tt = TomTimezoned.now(londonTz);
        expect(tt.timezone.timezone, equals('Europe/London'));
      });

      test('should create current time with Australia/Sydney timezone', () {
        final sydneyTz = TomTimezone.fromName('Australia/Sydney');
        final tt = TomTimezoned.now(sydneyTz);
        expect(tt.timezone.timezone, equals('Australia/Sydney'));
      });
    });

    group('fromDateTime factory', () {
      test('should convert DateTime to TomTimezoned', () {
        final dt = DateTime.utc(2024, 6, 15, 12, 30, 45, 123);
        final tt = TomTimezoned.fromDateTime(dt);
        expect(tt.year, equals(2024));
        expect(tt.month, equals(6));
        expect(tt.day, equals(15));
        expect(tt.hour, equals(12));
        expect(tt.minute, equals(30));
        expect(tt.second, equals(45));
        expect(tt.millisecond, equals(123));
      });

      test('should convert local DateTime to UTC', () {
        final localDt = DateTime(2024, 6, 15, 12, 30);
        final tt = TomTimezoned.fromDateTime(localDt);
        expect(tt.isUtc, isTrue);
      });

      test('should preserve timezone when specified', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final dt = DateTime.utc(2024, 12, 25, 10, 0, 0);
        final tt = TomTimezoned.fromDateTime(dt, berlinTz);
        expect(tt.timezone.timezone, equals('Europe/Berlin'));
      });
    });

    group('toString', () {
      test('should include timezone in string representation', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final tt = TomTimezoned.fromDateTime(
          DateTime.utc(2024, 6, 15, 12, 30),
          tokyoTz,
        );
        final str = tt.toString();
        expect(str.contains('Asia/Tokyo'), isTrue);
      });

      test('toString output should be parseable by isTomTimezonedString', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final tt = TomTimezoned.fromDateTime(
          DateTime.utc(2024, 6, 15, 12, 30),
          tokyoTz,
        );
        final str = tt.toString();
        expect(TomTimezoned.isTomTimezonedString(str), isTrue);
      });
    });

    group('isTomTimezonedString', () {
      test('should return true for valid TomTimezoned string with UTC', () {
        expect(
          TomTimezoned.isTomTimezonedString('2024-06-15T12:30:00.000Z_Z_UTC'),
          isTrue,
        );
      });

      test(
        'should return true for valid TomTimezoned string with complex timezone',
        () {
          expect(
            TomTimezoned.isTomTimezonedString(
              '2024-06-15T12:30:00.000Z_-04:00_America/New_York',
            ),
            isTrue,
          );
        },
      );

      test(
        'should return true for a TomTimezoned string with stray whitespace',
        () {
          // Nothing emits the space — the serialized form ends where the zone
          // name ends — but the predicate trims before matching, so a value
          // that picked one up in transit is still recognised rather than
          // silently failing to be a timezoned string at all.
          expect(
            TomTimezoned.isTomTimezonedString(
              '  2024-06-15T12:30:00.000Z_+09:00_Asia/Tokyo ',
            ),
            isTrue,
          );
        },
      );

      test('should return false for invalid string', () {
        expect(TomTimezoned.isTomTimezonedString('invalid'), isFalse);
        expect(TomTimezoned.isTomTimezonedString('2024-06-15'), isFalse);
      });
    });

    group('toDateTime', () {
      test('should convert to DateTime in UTC timezone', () {
        final tt = TomTimezoned.fromDateTime(DateTime.utc(2024, 6, 15, 12, 30));
        final localDt = tt.toDateTime();
        expect(localDt.year, equals(2024));
        expect(localDt.month, equals(6));
        expect(localDt.day, equals(15));
        expect(localDt.hour, equals(12));
      });

      test('should convert to DateTime in Tokyo timezone', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final tt = TomTimezoned.fromDateTime(
          DateTime.utc(2024, 6, 15, 3, 0),
          tokyoTz,
        );
        final localDt = tt.toDateTime();
        // 3 AM UTC = 12 PM Tokyo
        expect(localDt.hour, equals(12));
      });
    });
  });

  group('TomZonedDate', () {
    group('constructor', () {
      test('should create date with default values', () {
        final date = TomZonedDate();
        expect(date.year, equals(1970));
        expect(date.month, equals(1));
        expect(date.day, equals(1));
        expect(date.hour, equals(0));
        expect(date.minute, equals(0));
        expect(date.second, equals(0));
      });

      test('should create date with specified values', () {
        final date = TomZonedDate(year: 2024, month: 6, day: 15);
        expect(date.year, equals(2024));
        expect(date.month, equals(6));
        expect(date.day, equals(15));
      });

      test('should create date with Europe/Paris timezone', () {
        final parisTz = TomTimezone.fromName('Europe/Paris');
        final date = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: parisTz,
        );
        expect(date.timezone.timezone, equals('Europe/Paris'));
      });

      test('should create date with America/Los_Angeles timezone', () {
        final laTz = TomTimezone.fromName('America/Los_Angeles');
        final date = TomZonedDate(
          year: 2024,
          month: 12,
          day: 25,
          timezone: laTz,
        );
        expect(date.timezone.timezone, equals('America/Los_Angeles'));
        expect(date.year, equals(2024));
        expect(date.month, equals(12));
        expect(date.day, equals(25));
      });
    });

    group('fromDateTime factory', () {
      test('should create TomZonedDate from DateTime', () {
        // Read through the local accessors even though the default zone is
        // UTC and the two frames coincide here. The inherited DateTime
        // components are the UTC storage, which is a detail of how the value
        // is kept rather than what it means.
        final dt = DateTime.utc(2024, 6, 15, 12, 30, 45);
        final date = TomZonedDate.fromDateTime(dt);
        expect(date.localYear, equals(2024));
        expect(date.localMonth, equals(6));
        expect(date.localDay, equals(15));
      });

      test('should create TomZonedDate with Asia/Singapore timezone', () {
        final sgTz = TomTimezone.fromName('Asia/Singapore');
        final dt = DateTime.utc(2024, 8, 9);
        final date = TomZonedDate.fromDateTime(dt, sgTz);
        expect(date.timezone.timezone, equals('Asia/Singapore'));
      });

      // The type's defining invariant, which this factory has to establish
      // rather than inherit from whatever DateTime it was handed.
      test('should discard the time components of the incoming DateTime', () {
        final date = TomZonedDate.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5, 123, 456),
        );
        expect(date.localYear, equals(2026));
        expect(date.localMonth, equals(8));
        expect(date.localDay, equals(11));
        expect(date.localHour, isZero);
        expect(date.localMinute, isZero);
        expect(date.localSecond, isZero);
        expect(date.localMillisecond, isZero);
        expect(date.localMicrosecond, isZero);
      });

      test('should anchor to local midnight in a non-UTC timezone', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final date = TomZonedDate.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5, 123),
          berlinTz,
        );
        expect(date.localHour, isZero);
        expect(date.localMinute, isZero);
        expect(date.localSecond, isZero);
        expect(date.localMillisecond, isZero);
      });

      test('should keep the calendar day of the target timezone', () {
        // 22:30 UTC is already the next day in Berlin (CEST, +02:00). The
        // question a date-only type answers is "which calendar day is this,
        // *there*", so the answer is the 12th; reading the UTC date would
        // give the 11th. This is the case that separates the two readings,
        // which is why it is asserted apart from the truncation above.
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final date = TomZonedDate.fromDateTime(
          DateTime.utc(2026, 8, 11, 22, 30),
          berlinTz,
        );
        expect(date.localYear, equals(2026));
        expect(date.localMonth, equals(8));
        expect(date.localDay, equals(12));
      });

      test('should agree with the primary constructor', () {
        // Two routes to one value. If they disagree, one of them is wrong and
        // no assertion naming only components can say which.
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final fromParts = TomZonedDate(
          year: 2026,
          month: 8,
          day: 11,
          timezone: berlinTz,
        );
        final fromInstant = TomZonedDate.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47),
          berlinTz,
        );
        expect(fromInstant.toString(), equals(fromParts.toString()));
      });

      test('should accept a local DateTime, not only a UTC one', () {
        // `DateTime.now()` is local, and the shipped examples pass it in.
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final date = TomZonedDate.fromDateTime(
          DateTime(2026, 8, 11, 13, 47).toUtc(),
          berlinTz,
        );
        expect(date.localHour, isZero);
        expect(date.localMinute, isZero);
      });

      test('should round-trip through its serialized form', () {
        // parseFromString feeds the parsed instant back through this factory,
        // so an anchoring the factory does not preserve is one that storage
        // silently loses.
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final original = TomZonedDate(
          year: 2026,
          month: 8,
          day: 11,
          timezone: berlinTz,
        );
        final parsed = TomZonedDate.parseFromString(original.toString());
        expect(parsed.toString(), equals(original.toString()));
        expect(parsed.localDay, equals(11));
        expect(parsed.localHour, isZero);
      });

      test('should produce a value its own predicate accepts', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final date = TomZonedDate.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5),
          berlinTz,
        );
        expect(TomZonedDate.isDate(date), isTrue);
      });

      // The anchoring is "the start of the day there", and on a handful of
      // zone-days that is not midnight: Chile springs forward at 00:00 on
      // 2024-09-08, so the day begins at 01:00. Seven such zone-days exist in
      // 2024 (Cairo, Asuncion, Coyhaique, Havana, Santiago, Beirut, Azores)
      // and five in 2025. A test that only ever feeds a zone whose midnight
      // exists cannot tell "anchored to the start of the day" apart from
      // "hour forced to zero", and those two differ exactly here.
      group('when the local midnight does not exist', () {
        final santiago = TomTimezone.fromName('America/Santiago');

        test('should anchor to the first instant the day actually has', () {
          final date = TomZonedDate.fromDateTime(
            DateTime.utc(2024, 9, 8, 15, 30),
            santiago,
          );
          expect(date.localYear, equals(2024));
          expect(date.localMonth, equals(9));
          expect(date.localDay, equals(8));
          expect(
            date.localHour,
            equals(1),
            reason:
                '00:00 does not exist in Santiago on 2024-09-08, so the day '
                'starts at 01:00',
          );
          expect(date.localMinute, isZero);
          expect(date.localSecond, isZero);
        });

        test('should still agree with the primary constructor', () {
          // The reason the factory delegates rather than truncating: one
          // definition of "the start of the day, there", so both routes
          // normalize the missing midnight the same way.
          final fromParts = TomZonedDate(
            year: 2024,
            month: 9,
            day: 8,
            timezone: santiago,
          );
          final fromInstant = TomZonedDate.fromDateTime(
            DateTime.utc(2024, 9, 8, 15, 30),
            santiago,
          );
          expect(fromInstant.toString(), equals(fromParts.toString()));
        });

        test('should still satisfy isDate', () {
          // The predicate has to recognise what the constructor produces. It
          // asks the database when the day began; insisting on a zero hour
          // would reject this value, which is a well-formed date.
          final date = TomZonedDate.fromDateTime(
            DateTime.utc(2024, 9, 8, 15, 30),
            santiago,
          );
          expect(TomZonedDate.isDate(date), isTrue);
          expect(date.localHour, isNot(isZero));
        });

        test('should round-trip through its serialized form', () {
          final date = TomZonedDate.fromDateTime(
            DateTime.utc(2024, 9, 8, 15, 30),
            santiago,
          );
          final parsed = TomZonedDate.parseFromString(date.toString());
          expect(parsed.toString(), equals(date.toString()));
          expect(parsed.localDay, equals(8));
          expect(parsed.localHour, equals(1));
        });
      });
    });

    group('toString', () {
      test('should return string with correct prefix', () {
        final date = TomZonedDate(year: 2024, month: 6, day: 15);
        final str = date.toString();
        expect(str.startsWith(TomZonedDate.serializationPrefix), isTrue);
        expect(str.contains('2024-06-15'), isTrue);
      });

      test('should include timezone in output', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final date = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: berlinTz,
        );
        final str = date.toString();
        expect(str.contains('Europe/Berlin'), isTrue);
      });

      test('toString output should be parseable by parseFromString', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final date = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: berlinTz,
        );
        final str = date.toString();
        expect(TomZonedDate.isTomZonedDateString(str), isTrue);
        final parsed = TomZonedDate.parseFromString(str);
        expect(parsed.year, equals(date.year));
        expect(parsed.month, equals(date.month));
        expect(parsed.day, equals(date.day));
        expect(parsed.timezone.timezone, equals(date.timezone.timezone));
      });
    });

    group('isTomZonedDateString', () {
      test('should return true for valid TomZonedDate string with UTC', () {
        expect(
          TomZonedDate.isTomZonedDateString(
            '@D@2024-06-15T00:00:00.000Z_Z_UTC',
          ),
          isTrue,
        );
      });

      test('should return true for TomZonedDate with complex timezone', () {
        expect(
          TomZonedDate.isTomZonedDateString(
            '@D@2024-06-15T00:00:00.000Z_-07:00_America/Los_Angeles',
          ),
          isTrue,
        );
      });

      test('should return true for TomZonedDate with stray whitespace', () {
        // The predicate trims; nothing emits the space.
        expect(
          TomZonedDate.isTomZonedDateString(
            '  @D@2024-06-15T00:00:00.000Z_+09:00_Asia/Tokyo ',
          ),
          isTrue,
        );
      });

      test('should return false for invalid string', () {
        expect(TomZonedDate.isTomZonedDateString('invalid'), isFalse);
        expect(
          TomZonedDate.isTomZonedDateString(
            '@X@2024-06-15T12:30:00.000Z_Z_UTC',
          ),
          isFalse,
        );
      });
    });

    group('isDate', () {
      test('should return true for date-only DateTime', () {
        expect(TomZonedDate.isDate(DateTime.utc(2024, 6, 15)), isTrue);
      });

      test('should return false for DateTime with time components', () {
        expect(TomZonedDate.isDate(DateTime.utc(2024, 6, 15, 12)), isFalse);
        expect(TomZonedDate.isDate(DateTime.utc(2024, 6, 15, 0, 30)), isFalse);
        expect(
          TomZonedDate.isDate(DateTime.utc(2024, 6, 15, 0, 0, 1)),
          isFalse,
        );
      });

      test('should accept a TomZonedDate in a non-UTC timezone', () {
        // The canonical construction. Midnight in Tokyo is 15:00 the previous
        // afternoon in UTC, and UTC is the frame these values store, so
        // judging the stored components would reject the very type the
        // predicate is named after.
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final date = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: tokyoTz,
        );
        expect(date.hour, equals(15)); // the stored frame
        expect(TomZonedDate.isDate(date), isTrue);
      });

      test('should accept a TomZonedDate west of UTC too', () {
        // Westward the stored day is the same but the stored hour is not.
        final laTz = TomTimezone.fromName('America/Los_Angeles');
        final date = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: laTz,
        );
        expect(date.hour, equals(7));
        expect(TomZonedDate.isDate(date), isTrue);
      });

      test(
        'should give the same answer for a value and its local DateTime',
        () {
          // The two ways of asking must not disagree; if they can, the caller
          // has to know which frame the predicate reads, and that is the trap.
          final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
          final date = TomZonedDate(
            year: 2024,
            month: 6,
            day: 15,
            timezone: tokyoTz,
          );
          expect(
            TomZonedDate.isDate(date),
            equals(TomZonedDate.isDate(date.toDateTime())),
          );
        },
      );

      test('should reject a zoned value that carries a time of day', () {
        // Reading the local frame must not make everything pass.
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          timezone: tokyoTz,
        );
        expect(TomZonedDate.isDate(dt), isFalse);
      });

      test('should accept a day whose midnight the zone skipped', () {
        // The predicate's job is to recognise what the type produces. Chile
        // springs forward at 00:00 on 2024-09-08, so the constructor anchors
        // to 01:00 — the first instant the day has. Asking for zeroed
        // components would call a canonically built date not a date.
        final santiago = TomTimezone.fromName('America/Santiago');
        final date = TomZonedDate(
          year: 2024,
          month: 9,
          day: 8,
          timezone: santiago,
        );
        expect(date.localHour, equals(1));
        expect(TomZonedDate.isDate(date), isTrue);
      });

      test('should agree with itself across frames on a skipped midnight', () {
        // The same invariant as the Tokyo case above, on the input that can
        // break it: `toDateTime()` hands back a TZDateTime, which knows its
        // zone and so gets the same question asked of it. A predicate that
        // recognised the anchoring only through TomTimezoned would answer
        // differently here, and the caller would have to know which of the
        // two they were holding.
        final santiago = TomTimezone.fromName('America/Santiago');
        final date = TomZonedDate(
          year: 2024,
          month: 9,
          day: 8,
          timezone: santiago,
        );
        expect(
          TomZonedDate.isDate(date),
          equals(TomZonedDate.isDate(date.toDateTime())),
        );
      });

      test('should still reject an off-anchor value in such a zone', () {
        // Widening must not turn into "any hour in a DST zone passes".
        final santiago = TomTimezone.fromName('America/Santiago');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 9,
          day: 8,
          hour: 2,
          timezone: santiago,
        );
        expect(TomZonedDate.isDate(dt), isFalse);
      });
    });
  });

  group('TomZonedTime', () {
    group('constructor', () {
      test('should create time with default values', () {
        final time = TomZonedTime();
        expect(time.hour, equals(0));
        expect(time.minute, equals(0));
        expect(time.second, equals(0));
        expect(time.millisecond, equals(0));
      });

      test('should create time with specified values', () {
        final time = TomZonedTime(
          hour: 14,
          minute: 30,
          second: 45,
          millisecond: 123,
        );
        expect(time.hour, equals(14));
        expect(time.minute, equals(30));
        expect(time.second, equals(45));
        expect(time.millisecond, equals(123));
      });

      test('should create time with Europe/London timezone', () {
        final londonTz = TomTimezone.fromName('Europe/London');
        final time = TomZonedTime(hour: 14, minute: 30, timezone: londonTz);
        expect(time.timezone.timezone, equals('Europe/London'));
      });

      test('should create time with Pacific/Auckland timezone', () {
        final aucklandTz = TomTimezone.fromName('Pacific/Auckland');
        final time = TomZonedTime(hour: 9, minute: 0, timezone: aucklandTz);
        expect(time.timezone.timezone, equals('Pacific/Auckland'));
      });
    });

    group('fromDateTime factory', () {
      test('should create TomZonedTime from DateTime', () {
        // Local accessors, for the same reason as the date factory above.
        final dt = DateTime.utc(2024, 6, 15, 14, 30, 45, 123);
        final time = TomZonedTime.fromDateTime(dt);
        expect(time.localHour, equals(14));
        expect(time.localMinute, equals(30));
        expect(time.localSecond, equals(45));
        expect(time.localMillisecond, equals(123));
      });

      test('should create TomZonedTime with Asia/Kolkata timezone', () {
        final kolkataTz = TomTimezone.fromName('Asia/Kolkata');
        final dt = DateTime.utc(2024, 6, 15, 10, 30);
        final time = TomZonedTime.fromDateTime(dt, kolkataTz);
        expect(time.timezone.timezone, equals('Asia/Kolkata'));
      });

      // The mirror of the date invariant: a time-only value carries no date,
      // so whatever date arrived has to be replaced by the epoch anchor.
      test('should re-anchor the date to the Unix epoch', () {
        final time = TomZonedTime.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5, 123, 456),
        );
        expect(time.localYear, equals(1970));
        expect(time.localMonth, equals(1));
        expect(time.localDay, equals(1));
        expect(time.localHour, equals(13));
        expect(time.localMinute, equals(47));
        expect(time.localSecond, equals(5));
        expect(time.localMillisecond, equals(123));
        expect(time.localMicrosecond, equals(456));
      });

      test('should keep the wall-clock time of the target timezone', () {
        // 13:47 UTC is 15:47 in Berlin during CEST. A time-of-day value in
        // Berlin is the Berlin reading, not the UTC one.
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final time = TomZonedTime.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5),
          berlinTz,
        );
        expect(time.localYear, equals(1970));
        expect(time.localMonth, equals(1));
        expect(time.localDay, equals(1));
        expect(time.localHour, equals(15));
        expect(time.localMinute, equals(47));
        expect(time.localSecond, equals(5));
      });

      test('should agree with the primary constructor', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final fromParts = TomZonedTime(
          hour: 15,
          minute: 47,
          second: 5,
          timezone: berlinTz,
        );
        final fromInstant = TomZonedTime.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5),
          berlinTz,
        );
        expect(fromInstant.toString(), equals(fromParts.toString()));
      });

      test('should round-trip through its serialized form', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final original = TomZonedTime(
          hour: 15,
          minute: 47,
          second: 5,
          millisecond: 123,
          timezone: berlinTz,
        );
        final parsed = TomZonedTime.parseFromString(original.toString());
        expect(parsed.toString(), equals(original.toString()));
        expect(parsed.localHour, equals(15));
        expect(parsed.localYear, equals(1970));
      });

      test('should produce a value its own predicate accepts', () {
        final time = TomZonedTime.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5),
          TomTimezone.fromName('Europe/Berlin'),
        );
        expect(TomZonedTime.isTime(time), isTrue);
      });

      // The mirror of the date type's missing midnight. 1970-01-01 is a real
      // local date in the zone, not a fixed UTC instant, so it is read with
      // the offset the zone had *then*. Samoa is the clearest case: it was
      // UTC-11 on 1970-01-01 and is UTC+13 today, having crossed the date
      // line in 2011. Feeding a zone whose offset has never moved cannot tell
      // "anchored in the zone's 1970" apart from "anchored at the UTC epoch".
      group('when the zone stood elsewhere in 1970', () {
        final apia = TomTimezone.fromName('Pacific/Apia');
        final instant = DateTime.utc(2026, 8, 11, 13, 47, 5);

        test('should keep the wall-clock reading and drop the date', () {
          // 13:47 UTC is 02:47 the *next* day in Apia. A time-of-day keeps
          // the clock reading and discards the day it fell on, including the
          // fact that it had rolled over.
          final time = TomZonedTime.fromDateTime(instant, apia);
          expect(time.localHour, equals(2));
          expect(time.localMinute, equals(47));
          expect(time.localSecond, equals(5));
          expect(time.localYear, equals(1970));
          expect(time.localMonth, equals(1));
          expect(time.localDay, equals(1));
        });

        test('should anchor with the offset the zone had in 1970', () {
          // Read in the UTC frame the value is stored in. At Samoa's 1970
          // offset of -11 the anchor stores 1970-01-01T13:47Z; at today's +13
          // it would store 1969-12-31T13:47Z. The date is what separates
          // them, which is why it is asserted rather than the hour.
          final utc = TomZonedTime.fromDateTime(instant, apia).toUtc();
          expect(utc.year, equals(1970));
          expect(utc.month, equals(1));
          expect(utc.day, equals(1));
        });

        test('should still agree with the primary constructor', () {
          final fromParts = TomZonedTime(
            hour: 2,
            minute: 47,
            second: 5,
            timezone: apia,
          );
          final fromInstant = TomZonedTime.fromDateTime(instant, apia);
          expect(fromInstant.toString(), equals(fromParts.toString()));
        });

        test('should still satisfy isTime', () {
          expect(
            TomZonedTime.isTime(TomZonedTime.fromDateTime(instant, apia)),
            isTrue,
          );
        });
      });
    });

    group('toString', () {
      test('should return string with correct prefix', () {
        final time = TomZonedTime(hour: 14, minute: 30, second: 45);
        final str = time.toString();
        expect(str.startsWith(TomZonedTime.serializationPrefix), isTrue);
        expect(str.contains('14:30:45'), isTrue);
      });

      test('should include timezone in output', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final time = TomZonedTime(hour: 9, minute: 0, timezone: tokyoTz);
        final str = time.toString();
        expect(str.contains('Asia/Tokyo'), isTrue);
      });

      test('toString output should be parseable by parseFromString', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final time = TomZonedTime(
          hour: 14,
          minute: 30,
          second: 45,
          millisecond: 123,
          timezone: tokyoTz,
        );
        final str = time.toString();
        expect(TomZonedTime.isTomZonedTimeString(str), isTrue);
        final parsed = TomZonedTime.parseFromString(str);
        expect(parsed.hour, equals(time.hour));
        expect(parsed.minute, equals(time.minute));
        expect(parsed.second, equals(time.second));
        expect(parsed.millisecond, equals(time.millisecond));
        expect(parsed.timezone.timezone, equals(time.timezone.timezone));
      });
    });

    group('isTomZonedTimeString', () {
      test('should return true for valid TomZonedTime string with UTC', () {
        expect(
          TomZonedTime.isTomZonedTimeString(
            '@T@1970-01-01T14:30:45.000Z_Z_UTC',
          ),
          isTrue,
        );
      });

      test('should return true for TomZonedTime with complex timezone', () {
        expect(
          TomZonedTime.isTomZonedTimeString(
            '@T@1970-01-01T09:00:00.000Z_+09:00_Asia/Tokyo',
          ),
          isTrue,
        );
      });

      test('should return true for TomZonedTime with stray whitespace', () {
        // The predicate trims; nothing emits the space.
        expect(
          TomZonedTime.isTomZonedTimeString(
            '  @T@1970-01-01T09:00:00.000Z_+09:00_Asia/Tokyo ',
          ),
          isTrue,
        );
      });

      test('should return false for invalid string', () {
        expect(TomZonedTime.isTomZonedTimeString('invalid'), isFalse);
        expect(
          TomZonedTime.isTomZonedTimeString(
            '@D@2024-06-15T00:00:00.000Z_Z_UTC',
          ),
          isFalse,
        );
      });
    });

    group('isTime', () {
      test('should return true for time-only DateTime (epoch date)', () {
        expect(TomZonedTime.isTime(DateTime.utc(1970, 1, 1, 14, 30)), isTrue);
      });

      test('should return false for DateTime with non-epoch date', () {
        expect(TomZonedTime.isTime(DateTime.utc(2024, 6, 15, 14, 30)), isFalse);
        expect(TomZonedTime.isTime(DateTime.utc(1970, 1, 2, 14, 30)), isFalse);
      });

      test(
        'should accept a TomZonedTime whose stored date is not the epoch',
        () {
          // 00:30 in Tokyo is 15:30 on 1969-12-31 in UTC, so the stored frame
          // disagrees with the epoch anchor by a whole year — the sharpest form
          // of the disagreement, and the type's own canonical construction.
          final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
          final time = TomZonedTime(hour: 0, minute: 30, timezone: tokyoTz);
          expect(time.year, equals(1969)); // the stored frame
          expect(TomZonedTime.isTime(time), isTrue);
        },
      );

      test('should accept a TomZonedTime west of UTC too', () {
        // Westward the stored date runs past the epoch instead of before it.
        final laTz = TomTimezone.fromName('America/Los_Angeles');
        final time = TomZonedTime(hour: 23, minute: 30, timezone: laTz);
        expect(time.day, equals(2));
        expect(TomZonedTime.isTime(time), isTrue);
      });

      test(
        'should give the same answer for a value and its local DateTime',
        () {
          final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
          final time = TomZonedTime(hour: 0, minute: 30, timezone: tokyoTz);
          expect(
            TomZonedTime.isTime(time),
            equals(TomZonedTime.isTime(time.toDateTime())),
          );
        },
      );

      test('should reject a zoned value that carries a real date', () {
        final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          timezone: tokyoTz,
        );
        expect(TomZonedTime.isTime(dt), isFalse);
      });
    });

    group('inTimezoneOn', () {
      test('should return DateTime with correct time on given date', () {
        final nyTz = TomTimezone.fromName('America/New_York')!;
        final standup = TomZonedTime(hour: 9, minute: 0, timezone: nyTz);

        // Apply to a specific date
        final march10 = DateTime(2024, 3, 10);
        final result = standup.inTimezoneOn(march10);

        expect(result.year, equals(2024));
        expect(result.month, equals(3));
        expect(result.day, equals(10));
        expect(result.hour, equals(9));
        expect(result.minute, equals(0));
      });

      test('should handle DST transition correctly', () {
        final nyTz = TomTimezone.fromName('America/New_York')!;
        final time = TomZonedTime(hour: 9, minute: 0, timezone: nyTz);

        // March 10, 2024 - DST starts (clocks spring forward at 2 AM)
        final dstDay = DateTime(2024, 3, 10);
        final resultDst = time.inTimezoneOn(dstDay);

        // January 15, 2024 - Standard time
        final standardDay = DateTime(2024, 1, 15);
        final resultStandard = time.inTimezoneOn(standardDay);

        // Both should show 9:00 local time, but different UTC
        expect(resultDst.hour, equals(9));
        expect(resultStandard.hour, equals(9));

        // DST offset is -4:00, Standard is -5:00
        expect(resultDst.timeZoneOffset.inHours, equals(-4));
        expect(resultStandard.timeZoneOffset.inHours, equals(-5));
      });

      test('should work with UTC timezone', () {
        final utcTime = TomZonedTime(
          hour: 14,
          minute: 30,
          timezone: TomTimezone.utc,
        );
        final someDate = DateTime(2024, 6, 15);
        final result = utcTime.inTimezoneOn(someDate);

        expect(result.year, equals(2024));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
        expect(result.hour, equals(14));
        expect(result.minute, equals(30));
        expect(result.timeZoneOffset.inMinutes, equals(0));
      });

      test('should preserve seconds and milliseconds', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final time = TomZonedTime(
          hour: 14,
          minute: 30,
          second: 45,
          millisecond: 123,
          timezone: tokyo,
        );

        final date = DateTime(2024, 6, 15);
        final result = time.inTimezoneOn(date);

        expect(result.second, equals(45));
        expect(result.millisecond, equals(123));
      });
    });
  });

  group('TomTimezoned factory constructor', () {
    test('should create TomTimezoned with local time converted to UTC', () {
      final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
      final tt = TomTimezoned(
        year: 2024,
        month: 6,
        day: 15,
        hour: 14,
        minute: 30,
        timezone: tokyo,
      );

      // Tokyo is UTC+9, so 14:30 Tokyo = 05:30 UTC
      expect(tt.localHour, equals(14));
      expect(tt.localMinute, equals(30));
      expect(tt.hour, equals(5)); // UTC
      expect(tt.minute, equals(30));
      expect(tt.timezone.timezone, equals('Asia/Tokyo'));
    });

    test('should default to UTC timezone', () {
      final tt = TomTimezoned(year: 2024, month: 6, day: 15, hour: 12);

      expect(tt.timezone.timezone, equals('UTC'));
      expect(tt.hour, equals(12));
      expect(tt.localHour, equals(12));
    });

    test('should handle negative UTC offset', () {
      final nyTz = TomTimezone.fromName('America/New_York')!;
      // June 15, 2024 - NY is in EDT (UTC-4)
      final tt = TomTimezoned(
        year: 2024,
        month: 6,
        day: 15,
        hour: 10,
        minute: 0,
        timezone: nyTz,
      );

      // 10:00 EDT = 14:00 UTC
      expect(tt.localHour, equals(10));
      expect(tt.hour, equals(14)); // UTC
    });

    test('should handle date change across timezone boundary', () {
      final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
      // Early morning in Tokyo = previous day in UTC
      final tt = TomTimezoned(
        year: 2024,
        month: 6,
        day: 15,
        hour: 2,
        minute: 0,
        timezone: tokyo,
      );

      // 02:00 June 15 Tokyo = 17:00 June 14 UTC
      expect(tt.localDay, equals(15));
      expect(tt.localHour, equals(2));
      expect(tt.day, equals(14)); // UTC day
      expect(tt.hour, equals(17)); // UTC hour
    });
  });

  group('TomZonedDateTime', () {
    group('constructor', () {
      test('should create datetime with default values', () {
        final dt = TomZonedDateTime();
        expect(dt.year, equals(1970));
        expect(dt.month, equals(1));
        expect(dt.day, equals(1));
        expect(dt.hour, equals(0));
        expect(dt.minute, equals(0));
      });

      test('should create datetime with specified values', () {
        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          second: 45,
        );
        expect(dt.year, equals(2024));
        expect(dt.month, equals(6));
        expect(dt.day, equals(15));
        expect(dt.hour, equals(14));
        expect(dt.minute, equals(30));
        expect(dt.second, equals(45));
      });

      test('should create datetime with America/Chicago timezone', () {
        final chicagoTz = TomTimezone.fromName('America/Chicago');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 7,
          day: 4,
          hour: 12,
          timezone: chicagoTz,
        );
        expect(dt.timezone.timezone, equals('America/Chicago'));
      });

      test('should create datetime with Europe/Moscow timezone', () {
        final moscowTz = TomTimezone.fromName('Europe/Moscow');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 1,
          day: 1,
          hour: 0,
          timezone: moscowTz,
        );
        expect(dt.timezone.timezone, equals('Europe/Moscow'));
      });
    });

    group('fromDateTime factory', () {
      test('should create TomZonedDateTime from DateTime', () {
        final dartDt = DateTime.utc(2024, 6, 15, 14, 30, 45, 123, 456);
        final dt = TomZonedDateTime.fromDateTime(dartDt);
        expect(dt.year, equals(2024));
        expect(dt.month, equals(6));
        expect(dt.day, equals(15));
        expect(dt.hour, equals(14));
        expect(dt.minute, equals(30));
        expect(dt.second, equals(45));
        expect(dt.millisecond, equals(123));
        expect(dt.microsecond, equals(456));
      });

      test('should create TomZonedDateTime with Asia/Hong_Kong timezone', () {
        final hkTz = TomTimezone.fromName('Asia/Hong_Kong');
        final dartDt = DateTime.utc(2024, 2, 10, 8, 0);
        final dt = TomZonedDateTime.fromDateTime(dartDt, hkTz);
        expect(dt.timezone.timezone, equals('Asia/Hong_Kong'));
      });

      test('should create TomZonedDateTime with Africa/Cairo timezone', () {
        final cairoTz = TomTimezone.fromName('Africa/Cairo');
        final dartDt = DateTime.utc(2024, 10, 1, 12, 0);
        final dt = TomZonedDateTime.fromDateTime(dartDt, cairoTz);
        expect(dt.timezone.timezone, equals('Africa/Cairo'));
      });

      test('should keep every component — this type anchors nothing', () {
        // The sibling factories truncate because their types promise an
        // anchoring. This one promises none, so truncating here would be the
        // bug. Stated as a test so the symmetry is deliberate.
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final dt = TomZonedDateTime.fromDateTime(
          DateTime.utc(2026, 8, 11, 13, 47, 5, 123, 456),
          berlinTz,
        );
        expect(dt.localYear, equals(2026));
        expect(dt.localMonth, equals(8));
        expect(dt.localDay, equals(11));
        expect(dt.localHour, equals(15));
        expect(dt.localMinute, equals(47));
        expect(dt.localSecond, equals(5));
        expect(dt.localMillisecond, equals(123));
        expect(dt.localMicrosecond, equals(456));
      });
    });

    group('toString', () {
      test('should return string with correct prefix', () {
        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
        );
        final str = dt.toString();
        expect(str.startsWith(TomZonedDateTime.serializationPrefix), isTrue);
        expect(str.contains('2024-06-15'), isTrue);
        expect(str.contains('14:30'), isTrue);
      });

      test('should include timezone in output', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          timezone: berlinTz,
        );
        final str = dt.toString();
        expect(str.contains('Europe/Berlin'), isTrue);
      });

      test('toString output should be parseable by parseFromString', () {
        final berlinTz = TomTimezone.fromName('Europe/Berlin');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          second: 45,
          millisecond: 123,
          timezone: berlinTz,
        );
        final str = dt.toString();
        expect(TomZonedDateTime.isTomZonedDateTimeString(str), isTrue);
        final parsed = TomZonedDateTime.parseFromString(str);
        expect(parsed.year, equals(dt.year));
        expect(parsed.month, equals(dt.month));
        expect(parsed.day, equals(dt.day));
        expect(parsed.hour, equals(dt.hour));
        expect(parsed.minute, equals(dt.minute));
        expect(parsed.second, equals(dt.second));
        expect(parsed.millisecond, equals(dt.millisecond));
        expect(parsed.timezone.timezone, equals(dt.timezone.timezone));
      });
    });

    group('isTomZonedDateTimeString', () {
      test('should return true for valid TomZonedDateTime string with UTC', () {
        expect(
          TomZonedDateTime.isTomZonedDateTimeString(
            '@X@2024-06-15T14:30:00.000Z_Z_UTC',
          ),
          isTrue,
        );
      });

      test('should return true for TomZonedDateTime with complex timezone', () {
        expect(
          TomZonedDateTime.isTomZonedDateTimeString(
            '@X@2024-06-15T14:30:00.000Z_-04:00_America/New_York',
          ),
          isTrue,
        );
      });

      test('should return true for TomZonedDateTime with stray whitespace', () {
        // The predicate trims; nothing emits the space.
        expect(
          TomZonedDateTime.isTomZonedDateTimeString(
            '  @X@2024-06-15T14:30:00.000Z_+09:00_Asia/Tokyo ',
          ),
          isTrue,
        );
      });

      test('should return false for invalid string', () {
        expect(TomZonedDateTime.isTomZonedDateTimeString('invalid'), isFalse);
        expect(
          TomZonedDateTime.isTomZonedDateTimeString(
            '@D@2024-06-15T00:00:00.000Z_Z_UTC',
          ),
          isFalse,
        );
      });
    });

    group('complex timezone scenarios', () {
      test('should handle date near DST transition', () {
        final nyTz = TomTimezone.fromName('America/New_York');
        // March 10, 2024 is when DST starts in US (2 AM -> 3 AM)
        final dtBeforeDst = TomZonedDateTime(
          year: 2024,
          month: 3,
          day: 10,
          hour: 1,
          timezone: nyTz,
        );
        expect(dtBeforeDst.localHour, equals(1));

        final dtAfterDst = TomZonedDateTime(
          year: 2024,
          month: 3,
          day: 10,
          hour: 3,
          timezone: nyTz,
        );
        expect(dtAfterDst.localHour, equals(3));
      });

      test('should handle negative UTC offset timezones', () {
        final laTz = TomTimezone.fromName('America/Los_Angeles');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 12,
          day: 31,
          hour: 23,
          minute: 59,
          timezone: laTz,
        );
        expect(dt.timezone.timezone, equals('America/Los_Angeles'));
        expect(dt.localHour, equals(23));
        expect(dt.localMinute, equals(59));
      });

      test('should handle positive UTC offset timezones', () {
        final sydneyTz = TomTimezone.fromName('Australia/Sydney');
        final dt = TomZonedDateTime(
          year: 2024,
          month: 1,
          day: 1,
          hour: 0,
          minute: 0,
          timezone: sydneyTz,
        );
        expect(dt.timezone.timezone, equals('Australia/Sydney'));
        expect(dt.localYear, equals(2024));
        expect(dt.localMonth, equals(1));
        expect(dt.localDay, equals(1));
      });
    });
  });

  group('convertToTzSameInstant', () {
    group('TomZonedDateTime.convertToTzSameInstant', () {
      test('should convert Tokyo to New York and match TZDateTime', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;

        // Create a datetime in Tokyo: June 15, 2024 at 14:30
        final tokyoDt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          timezone: tokyo,
        );

        // Convert to New York using our method
        final nyDt = tokyoDt.convertToTzSameInstant(newYork);

        // Do the same with TZDateTime for comparison
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final nyLocation = tz.getLocation('America/New_York');
        final tzTokyoDt = tz.TZDateTime(tokyoLocation, 2024, 6, 15, 14, 30);
        final tzNyDt = tz.TZDateTime.from(tzTokyoDt, nyLocation);

        // Compare results
        expect(nyDt.localYear, equals(tzNyDt.year));
        expect(nyDt.localMonth, equals(tzNyDt.month));
        expect(nyDt.localDay, equals(tzNyDt.day));
        expect(nyDt.localHour, equals(tzNyDt.hour));
        expect(nyDt.localMinute, equals(tzNyDt.minute));
        expect(nyDt.timezone.timezone, equals('America/New_York'));
      });

      test('should convert UTC to London during summer (BST)', () {
        final utc = TomTimezone.utc;
        final london = TomTimezone.fromName('Europe/London')!;

        // June 15 - London is in BST (UTC+1)
        final utcDt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 12,
          minute: 0,
          timezone: utc,
        );

        final londonDt = utcDt.convertToTzSameInstant(london);

        // Verify with TZDateTime
        final utcLocation = tz.UTC;
        final londonLocation = tz.getLocation('Europe/London');
        final tzUtcDt = tz.TZDateTime(utcLocation, 2024, 6, 15, 12, 0);
        final tzLondonDt = tz.TZDateTime.from(tzUtcDt, londonLocation);

        expect(londonDt.localHour, equals(tzLondonDt.hour));
        expect(londonDt.localHour, equals(13)); // UTC+1 during BST
      });

      test('should convert UTC to London during winter (GMT)', () {
        final utc = TomTimezone.utc;
        final london = TomTimezone.fromName('Europe/London')!;

        // January 15 - London is in GMT (UTC+0)
        final utcDt = TomZonedDateTime(
          year: 2024,
          month: 1,
          day: 15,
          hour: 12,
          minute: 0,
          timezone: utc,
        );

        final londonDt = utcDt.convertToTzSameInstant(london);

        // Verify with TZDateTime
        final utcLocation = tz.UTC;
        final londonLocation = tz.getLocation('Europe/London');
        final tzUtcDt = tz.TZDateTime(utcLocation, 2024, 1, 15, 12, 0);
        final tzLondonDt = tz.TZDateTime.from(tzUtcDt, londonLocation);

        expect(londonDt.localHour, equals(tzLondonDt.hour));
        expect(londonDt.localHour, equals(12)); // Same as UTC during GMT
      });

      test('should handle date change when converting westward', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final la = TomTimezone.fromName('America/Los_Angeles')!;

        // Early morning in Tokyo
        final tokyoDt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 2,
          minute: 0,
          timezone: tokyo,
        );

        final laDt = tokyoDt.convertToTzSameInstant(la);

        // Verify with TZDateTime
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final laLocation = tz.getLocation('America/Los_Angeles');
        final tzTokyoDt = tz.TZDateTime(tokyoLocation, 2024, 6, 15, 2, 0);
        final tzLaDt = tz.TZDateTime.from(tzTokyoDt, laLocation);

        expect(laDt.localYear, equals(tzLaDt.year));
        expect(laDt.localMonth, equals(tzLaDt.month));
        expect(laDt.localDay, equals(tzLaDt.day)); // Should be previous day
        expect(laDt.localHour, equals(tzLaDt.hour));
        expect(laDt.localDay, equals(14)); // Previous day in LA
      });

      test('should handle date change when converting eastward', () {
        final la = TomTimezone.fromName('America/Los_Angeles')!;
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

        // Late night in LA
        final laDt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 14,
          hour: 23,
          minute: 0,
          timezone: la,
        );

        final tokyoDt = laDt.convertToTzSameInstant(tokyo);

        // Verify with TZDateTime
        final laLocation = tz.getLocation('America/Los_Angeles');
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final tzLaDt = tz.TZDateTime(laLocation, 2024, 6, 14, 23, 0);
        final tzTokyoDt = tz.TZDateTime.from(tzLaDt, tokyoLocation);

        expect(tokyoDt.localYear, equals(tzTokyoDt.year));
        expect(tokyoDt.localMonth, equals(tzTokyoDt.month));
        expect(tokyoDt.localDay, equals(tzTokyoDt.day)); // Should be next day
        expect(tokyoDt.localHour, equals(tzTokyoDt.hour));
        expect(tokyoDt.localDay, equals(15)); // Next day in Tokyo
      });

      test('should preserve the same instant in time', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;

        final tokyoDt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          timezone: tokyo,
        );

        final nyDt = tokyoDt.convertToTzSameInstant(newYork);

        // Verify with TZDateTime that both represent the same instant
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final nyLocation = tz.getLocation('America/New_York');
        final tzTokyo = tz.TZDateTime(tokyoLocation, 2024, 6, 15, 14, 30);
        final tzNy = tz.TZDateTime.from(tzTokyo, nyLocation);

        // Our conversion should match TZDateTime conversion
        expect(nyDt.localYear, equals(tzNy.year));
        expect(nyDt.localMonth, equals(tzNy.month));
        expect(nyDt.localDay, equals(tzNy.day));
        expect(nyDt.localHour, equals(tzNy.hour));
        expect(nyDt.localMinute, equals(tzNy.minute));

        // Both TZDateTimes represent the same instant
        expect(
          tzTokyo.millisecondsSinceEpoch,
          equals(tzNy.millisecondsSinceEpoch),
        );
      });

      test('should convert to same timezone (no-op)', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

        final dt = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          timezone: tokyo,
        );

        final sameTzDt = dt.convertToTzSameInstant(tokyo);

        expect(sameTzDt.localYear, equals(dt.localYear));
        expect(sameTzDt.localMonth, equals(dt.localMonth));
        expect(sameTzDt.localDay, equals(dt.localDay));
        expect(sameTzDt.localHour, equals(dt.localHour));
        expect(sameTzDt.localMinute, equals(dt.localMinute));
        expect(sameTzDt.timezone.timezone, equals(tokyo.timezone));
      });

      test('should handle DST transition - spring forward', () {
        final newYork = TomTimezone.fromName('America/New_York')!;
        final utc = TomTimezone.utc;

        // March 10, 2024 - US DST starts (clocks spring forward at 2am)
        // 6:30 UTC = 1:30 AM EST (before DST)
        // 7:30 UTC = 3:30 AM EDT (after DST)
        final beforeDst = TomZonedDateTime(
          year: 2024,
          month: 3,
          day: 10,
          hour: 6,
          minute: 30,
          timezone: utc,
        );

        final afterDst = TomZonedDateTime(
          year: 2024,
          month: 3,
          day: 10,
          hour: 7,
          minute: 30,
          timezone: utc,
        );

        final nyBefore = beforeDst.convertToTzSameInstant(newYork);
        final nyAfter = afterDst.convertToTzSameInstant(newYork);

        // Verify with TZDateTime
        final utcLocation = tz.UTC;
        final nyLocation = tz.getLocation('America/New_York');
        final tzBeforeUtc = tz.TZDateTime(utcLocation, 2024, 3, 10, 6, 30);
        final tzAfterUtc = tz.TZDateTime(utcLocation, 2024, 3, 10, 7, 30);
        final tzNyBefore = tz.TZDateTime.from(tzBeforeUtc, nyLocation);
        final tzNyAfter = tz.TZDateTime.from(tzAfterUtc, nyLocation);

        expect(nyBefore.localHour, equals(tzNyBefore.hour));
        expect(nyAfter.localHour, equals(tzNyAfter.hour));
        expect(nyBefore.localHour, equals(1)); // 1:30 AM EST
        expect(nyAfter.localHour, equals(3)); // 3:30 AM EDT
      });
    });

    group('TomZonedDate.convertToTzSameInstant', () {
      test('should convert date between timezones', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;

        final tokyoDate = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: tokyo,
        );

        final nyDate = tokyoDate.convertToTzSameInstant(newYork);

        // Verify with TZDateTime
        // Tokyo June 15 at 00:00 local = June 14 at 15:00 UTC
        // In New York (UTC-4 in June DST) = June 14 at 11:00 local
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final nyLocation = tz.getLocation('America/New_York');
        final tzTokyoDt = tz.TZDateTime(tokyoLocation, 2024, 6, 15, 0, 0);
        final tzNyDt = tz.TZDateTime.from(tzTokyoDt, nyLocation);

        expect(nyDate.localHour, equals(tzNyDt.hour));
        expect(nyDate.localMinute, equals(tzNyDt.minute));
        expect(nyDate.localDay, equals(tzNyDt.day));
        expect(nyDate.timezone.timezone, equals('America/New_York'));
      });

      test('should handle date that crosses midnight when converting', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final la = TomTimezone.fromName('America/Los_Angeles')!;

        // Midnight in Tokyo (June 15) is still June 14 in LA
        final tokyoDate = TomZonedDate(
          year: 2024,
          month: 6,
          day: 15,
          timezone: tokyo,
        );

        final laDate = tokyoDate.convertToTzSameInstant(la);

        // Verify with TZDateTime
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final laLocation = tz.getLocation('America/Los_Angeles');
        final tzTokyoDt = tz.TZDateTime(tokyoLocation, 2024, 6, 15, 0, 0);
        final tzLaDt = tz.TZDateTime.from(tzTokyoDt, laLocation);

        expect(laDate.localDay, equals(tzLaDt.day));
        expect(laDate.localMonth, equals(tzLaDt.month));
        expect(laDate.localDay, equals(14)); // Previous day in LA
      });
    });

    group('TomZonedTime.convertToTzSameInstant', () {
      test('should convert time between timezones', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final utc = TomTimezone.utc;

        final tokyoTime = TomZonedTime(hour: 14, minute: 30, timezone: tokyo);

        final utcTime = tokyoTime.convertToTzSameInstant(utc);

        // Tokyo is UTC+9, so 14:30 Tokyo = 5:30 UTC
        expect(utcTime.localHour, equals(5));
        expect(utcTime.localMinute, equals(30));
        expect(utcTime.timezone.timezone, equals('UTC'));
      });

      test('should handle time that crosses midnight when converting', () {
        final utc = TomTimezone.utc;
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

        // 23:00 UTC = 08:00 next day in Tokyo
        final utcTime = TomZonedTime(hour: 23, minute: 0, timezone: utc);

        final tokyoTime = utcTime.convertToTzSameInstant(tokyo);

        // Verify with TZDateTime (using base date 1970-01-01)
        final utcLocation = tz.UTC;
        final tokyoLocation = tz.getLocation('Asia/Tokyo');
        final tzUtcDt = tz.TZDateTime(utcLocation, 1970, 1, 1, 23, 0);
        final tzTokyoDt = tz.TZDateTime.from(tzUtcDt, tokyoLocation);

        expect(tokyoTime.localHour, equals(tzTokyoDt.hour));
        expect(tokyoTime.localHour, equals(8)); // 8:00 next day
      });

      test('should preserve minute precision', () {
        final la = TomTimezone.fromName('America/Los_Angeles')!;
        final newYork = TomTimezone.fromName('America/New_York')!;

        final laTime = TomZonedTime(
          hour: 10,
          minute: 45,
          second: 30,
          timezone: la,
        );

        final nyTime = laTime.convertToTzSameInstant(newYork);

        // LA to NY is +3 hours
        expect(nyTime.localHour, equals(13));
        expect(nyTime.localMinute, equals(45));
        expect(nyTime.localSecond, equals(30));
      });
    });

    group('Round-trip conversions', () {
      test('should return to original when converting back and forth', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final newYork = TomTimezone.fromName('America/New_York')!;

        final original = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          second: 45,
          timezone: tokyo,
        );

        final toNy = original.convertToTzSameInstant(newYork);
        final backToTokyo = toNy.convertToTzSameInstant(tokyo);

        expect(backToTokyo.localYear, equals(original.localYear));
        expect(backToTokyo.localMonth, equals(original.localMonth));
        expect(backToTokyo.localDay, equals(original.localDay));
        expect(backToTokyo.localHour, equals(original.localHour));
        expect(backToTokyo.localMinute, equals(original.localMinute));
        expect(backToTokyo.localSecond, equals(original.localSecond));
      });

      test('should handle multiple timezone conversions', () {
        final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
        final london = TomTimezone.fromName('Europe/London')!;
        final newYork = TomTimezone.fromName('America/New_York')!;
        final la = TomTimezone.fromName('America/Los_Angeles')!;

        final original = TomZonedDateTime(
          year: 2024,
          month: 6,
          day: 15,
          hour: 12,
          minute: 0,
          timezone: tokyo,
        );

        // Chain conversions
        final toLondon = original.convertToTzSameInstant(london);
        final toNy = toLondon.convertToTzSameInstant(newYork);
        final toLa = toNy.convertToTzSameInstant(la);
        final backToTokyo = toLa.convertToTzSameInstant(tokyo);

        // All should represent the same instant
        expect(
          original.toUtc().millisecondsSinceEpoch,
          equals(backToTokyo.toUtc().millisecondsSinceEpoch),
        );
        expect(backToTokyo.localHour, equals(original.localHour));
      });
    });
  });

  // The counterpart pair, and the reason the names differ.
  //
  // `convertToTzSameInstant` answers "when was this, over there" and is *not*
  // closed over a date-only or time-only type: preserving the instant moves the
  // local day and gives a date a time of day, which is precisely what the
  // type's anchoring otherwise guarantees it has not got. These methods answer
  // the other question — "what date is this, expressed over there" — and are
  // closed. A shared name for two operations that disagree about which of them
  // they mean is what these tests exist to keep apart.
  group('convertToTzSameDate / convertToTzSameTime re-anchor', () {
    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final newYork = TomTimezone.fromName('America/New_York')!;

    test('a date keeps its calendar day and stays anchored to midnight', () {
      final dateInTokyo = TomZonedDate(
        year: 2024,
        month: 6,
        day: 15,
        timezone: tokyo,
      );

      final sameDate = dateInTokyo.convertToTzSameDate(newYork);

      expect(sameDate.localYear, equals(2024));
      expect(sameDate.localMonth, equals(6));
      expect(sameDate.localDay, equals(15), reason: 'the same calendar day');
      expect(sameDate.localHour, equals(0), reason: 'still a date, not a time');
      expect(sameDate.timezone.timezone, equals('America/New_York'));

      // The instant necessarily moves — that is the trade, and the difference
      // from the instant-preserving sibling, which lands on the 14th at 11:00.
      final sameInstant = dateInTokyo.convertToTzSameInstant(newYork);
      expect(sameInstant.localDay, equals(14));
      expect(sameInstant.localHour, equals(11));
    });

    test('a time keeps its clock reading and still satisfies isTime', () {
      final standupTokyo = TomZonedTime(hour: 9, minute: 30, timezone: tokyo);

      final sameTime = standupTokyo.convertToTzSameTime(newYork);

      expect(sameTime.localHour, equals(9), reason: 'the same clock reading');
      expect(sameTime.localMinute, equals(30));
      expect(
        TomZonedTime.isTime(sameTime),
        isTrue,
        reason: 'closed over the type: still anchored to 1970-01-01',
      );
      expect(sameTime.timezone.timezone, equals('America/New_York'));
    });

    test('the instant-preserving sibling can leave a time unanchored', () {
      // Why the pair exists. 00:30 in Tokyo is 10:30 on 1969-12-31 in New
      // York, so the same-instant reading fails the type's own predicate.
      final lateTokyo = TomZonedTime(hour: 0, minute: 30, timezone: tokyo);

      final sameInstant = lateTokyo.convertToTzSameInstant(newYork);

      expect(TomZonedTime.isTime(sameInstant), isFalse);
      expect(
        TomZonedTime.isTime(lateTokyo.convertToTzSameTime(newYork)),
        isTrue,
      );
    });

    test('re-anchoring twice returns to where it started', () {
      // Closed operations compose: a date round-tripped through another zone is
      // the date it began as. The instant-preserving pair has no such property.
      final start = TomZonedDate(
        year: 2024,
        month: 12,
        day: 31,
        timezone: tokyo,
      );

      final back = start
          .convertToTzSameDate(newYork)
          .convertToTzSameDate(tokyo);

      expect(back.localYear, equals(start.localYear));
      expect(back.localMonth, equals(start.localMonth));
      expect(back.localDay, equals(start.localDay));
    });
  });

  // parseFromString must throw a FormatException when the timezone name does
  // not resolve, instead of silently downgrading to UTC.
  group('parseFromString unknown timezone', () {
    test('TomTimezoned.parseFromString throws for unknown zone', () {
      expect(
        () => TomTimezoned.parseFromString(
          '2024-06-15T05:30:00.000Z_+09:00_Unknown/Zone',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('TomZonedDate.parseFromString throws for unknown zone', () {
      expect(
        () => TomZonedDate.parseFromString(
          '@D@2024-06-15T00:00:00.000Z_+09:00_Unknown/Zone',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('TomZonedTime.parseFromString throws for unknown zone', () {
      expect(
        () => TomZonedTime.parseFromString(
          '@T@1970-01-01T09:00:00.000Z_+09:00_Unknown/Zone',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('TomZonedDateTime.parseFromString throws for unknown zone', () {
      expect(
        () => TomZonedDateTime.parseFromString(
          '@X@2024-06-15T14:30:00.000Z_+09:00_Unknown/Zone',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('TomTimezoned.parseFromString still resolves a known zone', () {
      final tt = TomTimezoned.parseFromString(
        '2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo',
      );
      expect(tt.timezone.timezone, equals('Asia/Tokyo'));
    });
  });

  group('serialized form', () {
    // The instant section is the only part of the serialized form that names a
    // point in time. Without its `Z` it names a wall-clock reading with no
    // zone attached, and nothing else in the string supplies one — the offset
    // that follows is derived from the zone and is not consulted. Accepting
    // such a string means resolving it against whatever zone the host machine
    // is in, which makes the parsed value depend on where it was parsed.
    //
    // These tests therefore assert rejection, which is the one answer that is
    // the same on every host.
    group('rejects an instant without its Z', () {
      test('TomTimezoned', () {
        const s = '2024-06-15T05:30:00.000_+09:00_Asia/Tokyo';
        expect(TomTimezoned.isTomTimezonedString(s), isFalse);
        expect(
          () => TomTimezoned.parseFromString(s),
          throwsA(isA<FormatException>()),
        );
      });

      test('TomZonedDate', () {
        const s = '@D@2024-06-14T15:00:00.000_+09:00_Asia/Tokyo';
        expect(TomZonedDate.isTomZonedDateString(s), isFalse);
        expect(
          () => TomZonedDate.parseFromString(s),
          throwsA(isA<FormatException>()),
        );
      });

      test('TomZonedTime', () {
        const s = '@T@1970-01-01T09:00:00.000_+09:00_Asia/Tokyo';
        expect(TomZonedTime.isTomZonedTimeString(s), isFalse);
        expect(
          () => TomZonedTime.parseFromString(s),
          throwsA(isA<FormatException>()),
        );
      });

      test('TomZonedDateTime', () {
        const s = '@X@2024-06-15T05:30:00.000_+09:00_Asia/Tokyo';
        expect(TomZonedDateTime.isTomZonedDateTimeString(s), isFalse);
        expect(
          () => TomZonedDateTime.parseFromString(s),
          throwsA(isA<FormatException>()),
        );
      });
    });

    test('reads the instant as UTC, whatever zone the host is in', () {
      // The value this string names is fixed by its own `Z`, so the assertion
      // below holds identically on a UTC host and on one at +09:00. That
      // independence is the whole point of requiring the Z.
      final dt = TomZonedDateTime.parseFromString(
        '@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo',
      );
      expect(dt.hour, equals(5));
      expect(dt.millisecondsSinceEpoch, equals(1718429400000));
    });

    test('accepting the format is the same question as parsing it', () {
      // The predicates gate the parsers everywhere they are used, so a string
      // the predicate accepts and the parser rejects would be a contradiction
      // no caller could defend against. Resolving the zone is the deliberate
      // exception: the predicate judges shape, not whether the zone exists.
      const forms = [
        '2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo',
        '2024-06-15T05:30:00Z_Z_UTC',
        '2024-06-15T05:30:00.123456Z_-04:00_America/New_York',
        '2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo',
        '2024-06-15T05:30:00.000_+09:00_Asia/Tokyo',
        '2024-06-15T05:30:00.000Z_Asia/Tokyo',
        'not a serialized value',
        '',
      ];
      for (final form in forms) {
        final accepted = TomTimezoned.isTomTimezonedString(form);
        var parsed = true;
        try {
          TomTimezoned.parseFromString(form);
        } on FormatException {
          parsed = false;
        }
        expect(parsed, equals(accepted), reason: 'disagreed on "$form"');
      }
      // Non-vacuity: the table must exercise both answers.
      expect(TomTimezoned.isTomTimezonedString(forms.first), isTrue);
      expect(TomTimezoned.isTomTimezonedString(forms.last), isFalse);
    });

    test('round-trips a value carrying microseconds', () {
      // `toIso8601String` emits six fractional digits as soon as the
      // microsecond component is non-zero, so a form that admits only three
      // would reject values the library itself produces.
      final tokyoTz = TomTimezone.fromName('Asia/Tokyo');
      final original = TomZonedDateTime(
        year: 2024,
        month: 6,
        day: 15,
        hour: 5,
        minute: 30,
        millisecond: 123,
        microsecond: 456,
        timezone: tokyoTz,
      );
      final serialized = original.toString();
      expect(serialized, contains('.123456Z'));
      expect(TomZonedDateTime.isTomZonedDateTimeString(serialized), isTrue);
      final restored = TomZonedDateTime.parseFromString(serialized);
      expect(restored.microsecondsSinceEpoch, original.microsecondsSinceEpoch);
      expect(restored.timezone.timezone, equals('Asia/Tokyo'));
    });

    test('takes the zone as authoritative and the offset as derived', () {
      // The offset is a second rendering of information the zone already
      // carries, and the IANA database revises historical offsets, so an
      // incoming offset is not evidence about the value and is not checked
      // against the zone. Re-serializing restates it from the zone — which
      // offset the zone gives is the next test's subject.
      final dt = TomZonedDateTime.parseFromString(
        '@X@2024-06-15T05:30:00.000Z_-11:30_Asia/Tokyo',
      );
      expect(dt.timezone.timezone, equals('Asia/Tokyo'));
      expect(dt.hour, equals(5));
      expect(dt.toString(), contains('_+09:00_Asia/Tokyo'));
    });

    test('writes the offset at the value\'s own instant, not today\'s', () {
      // Asia/Tokyo above cannot tell the two apart: it has no DST, so its
      // offset now and its offset at the value's instant are the same number.
      // A DST zone separates them, and the serialized offset is the one the
      // zone had at the value's instant — the offset its own local fields are
      // computed with — so it does not depend on when the string was written.
      final newYork = TomTimezone.fromName('America/New_York')!;
      final now = newYork.getCurrentUtcOffset();

      // Whichever season we are in, the other one has a different offset.
      final year = DateTime.now().toUtc().year;
      final instant = [
        DateTime.utc(year, 1, 15, 12),
        DateTime.utc(year, 7, 15, 12),
      ].firstWhere((when) => newYork.getUtcOffsetOn(when) != now);
      final atInstant = newYork.getUtcOffsetOn(instant);

      // Non-vacuity: the two readings must actually differ, or the assertion
      // below would hold under either rule.
      expect(atInstant, isNot(equals(now)));

      final value = TomZonedDateTime.fromDateTime(instant, newYork);
      final serialized = value.toString();

      expect(
        serialized,
        contains('_${TomTimezone.convertMinutesToUtcOffset(atInstant)}_'),
        reason: 'the serialized offset is the zone\'s offset at the instant',
      );
      expect(
        serialized,
        isNot(contains(TomTimezone.convertMinutesToUtcOffset(now))),
        reason: 'it is not the zone\'s offset today',
      );

      // The round trip keeps the instant and the zone, and re-serializing
      // writes the same string — the offset no longer drifts with the season.
      final restored = TomZonedDateTime.parseFromString(serialized);
      expect(restored.microsecondsSinceEpoch, value.microsecondsSinceEpoch);
      expect(restored.timezone.timezone, equals('America/New_York'));
      expect(restored.toString(), equals(serialized));
    });

    group('the offset on either side of a DST boundary', () {
      // Fixed instants, so the expected strings are the same on every day
      // the suite runs: one January and one July value per zone, whichever
      // of the two is "now".
      final berlin = TomTimezone.fromName('Europe/Berlin')!;
      final newYork = TomTimezone.fromName('America/New_York')!;
      final january = DateTime.utc(2024, 1, 15, 12);
      final july = DateTime.utc(2024, 7, 15, 12);

      test('TomTimezoned', () {
        expect(
          TomTimezoned.fromDateTime(january, berlin).toString(),
          '2024-01-15T12:00:00.000Z_+01:00_Europe/Berlin',
        );
        expect(
          TomTimezoned.fromDateTime(july, berlin).toString(),
          '2024-07-15T12:00:00.000Z_+02:00_Europe/Berlin',
        );
      });

      test('TomZonedDateTime', () {
        expect(
          TomZonedDateTime.fromDateTime(january, newYork).toString(),
          '@X@2024-01-15T12:00:00.000Z_-05:00_America/New_York',
        );
        expect(
          TomZonedDateTime.fromDateTime(july, newYork).toString(),
          '@X@2024-07-15T12:00:00.000Z_-04:00_America/New_York',
        );
      });

      test('TomZonedDate', () {
        // A date is stored as its local midnight, so the offset is the one in
        // force at that midnight.
        expect(
          TomZonedDate(
            year: 2024,
            month: 1,
            day: 15,
            timezone: berlin,
          ).toString(),
          '@D@2024-01-14T23:00:00.000Z_+01:00_Europe/Berlin',
        );
        expect(
          TomZonedDate(
            year: 2024,
            month: 7,
            day: 15,
            timezone: berlin,
          ).toString(),
          '@D@2024-07-14T22:00:00.000Z_+02:00_Europe/Berlin',
        );
      });

      test('TomZonedTime', () {
        // A time is stored on the epoch day, and its local fields use the
        // zone's offset there — Berlin kept no summer time in 1970 — so that
        // is the offset it writes, whatever the season now.
        final nine = TomZonedTime(hour: 9, timezone: berlin);
        expect(nine.localHour, 9);
        expect(
          nine.toString(),
          '@T@1970-01-01T08:00:00.000Z_+01:00_Europe/Berlin',
        );
      });
    });

    test('toString is the whole form, prefix included', () {
      // `getSerializationPrefix()` names the prefix a type uses; it is not an
      // ingredient to be added to the rendering, which already carries it.
      // Joining the two doubles the prefix into a string no parser accepts —
      // a failure that shows up only when something reads the result back, and
      // so never in code that merely prints it.
      final tz = TomTimezone.utc;
      final values = <TomTimezoned>[
        TomZonedDateTime(year: 2024, month: 6, day: 15, hour: 12, timezone: tz),
        TomZonedDate(year: 2024, month: 6, day: 15, timezone: tz),
        TomZonedTime(hour: 12, timezone: tz),
      ];

      for (final value in values) {
        final serialized = value.toString();
        final prefix = value.getSerializationPrefix();
        expect(prefix, isNotEmpty);
        expect(serialized, startsWith(prefix));
        expect(
          TomTimezoned.isTomTimezonedString('$prefix$serialized'),
          isFalse,
        );
      }

      // The unprefixed base names no prefix at all, so there is nothing to add
      // and nothing the doubling could produce.
      final base = TomTimezoned.fromDateTime(DateTime.utc(2024, 6, 15, 12), tz);
      expect(base.getSerializationPrefix(), isEmpty);
      expect(TomTimezoned.isTomTimezonedString(base.toString()), isTrue);
    });
  });
}
