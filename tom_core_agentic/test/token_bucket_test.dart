import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('TokenBucketPolicy', () {
    test('rejects a capacity below 1', () {
      expect(
        () => TokenBucketPolicy(
          capacity: 0,
          refillTokens: 1,
          refillPeriod: const Duration(seconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a non-positive refill rate', () {
      expect(
        () => TokenBucketPolicy(
          capacity: 1,
          refillTokens: 0,
          refillPeriod: const Duration(seconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a non-positive refill period', () {
      expect(
        () => TokenBucketPolicy(
          capacity: 1,
          refillTokens: 1,
          refillPeriod: Duration.zero,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TokenBucket', () {
    late DateTime now;
    TokenBucket bucketWith(TokenBucketPolicy policy) =>
        TokenBucket(policy: policy, clock: () => now);

    setUp(() => now = DateTime.utc(2026, 1, 1));

    test('a fresh bucket starts full at capacity', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 3,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 1),
      ));
      expect(bucket.tryTake('p'), isNull);
      expect(bucket.tryTake('p'), isNull);
      expect(bucket.tryTake('p'), isNull);
      // Fourth take exhausts the bucket.
      expect(bucket.tryTake('p'), isNotNull);
    });

    test('returns the wait until one token refills when empty', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 1,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 10),
      ));
      expect(bucket.tryTake('p'), isNull);
      final wait = bucket.tryTake('p');
      expect(wait, const Duration(seconds: 10));
    });

    test('refills continuously over elapsed wall-clock time', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 2,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 1),
      ));
      expect(bucket.tryTake('p'), isNull);
      expect(bucket.tryTake('p'), isNull);
      expect(bucket.tryTake('p'), isNotNull); // empty
      now = now.add(const Duration(seconds: 1)); // one token refilled
      expect(bucket.tryTake('p'), isNull);
    });

    test('a rejected take does not push the retry window further out', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 1,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 4),
      ));
      expect(bucket.tryTake('p'), isNull);
      final first = bucket.tryTake('p')!;
      final second = bucket.tryTake('p')!;
      expect(second, lessThanOrEqualTo(first));
    });

    test('keys are independent', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 1,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 1),
      ));
      expect(bucket.tryTake('a'), isNull);
      expect(bucket.tryTake('b'), isNull); // b has its own full bucket
      expect(bucket.keyCount, 2);
    });

    test('rejects an empty key', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 1,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 1),
      ));
      expect(() => bucket.tryTake(''), throwsA(isA<ArgumentError>()));
    });

    test('clear resets every bucket to full', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 1,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 1),
      ));
      expect(bucket.tryTake('p'), isNull);
      expect(bucket.tryTake('p'), isNotNull);
      bucket.clear();
      expect(bucket.keyCount, 0);
      expect(bucket.tryTake('p'), isNull);
    });

    test('a backwards clock does not credit the bucket', () {
      final bucket = bucketWith(TokenBucketPolicy(
        capacity: 2,
        refillTokens: 1,
        refillPeriod: const Duration(seconds: 1),
      ));
      expect(bucket.tryTake('p'), isNull);
      expect(bucket.tryTake('p'), isNull); // empty
      now = now.subtract(const Duration(seconds: 100)); // clock jumps back
      expect(bucket.tryTake('p'), isNotNull); // still empty, no future credit
    });
  });
}
