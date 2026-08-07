import 'package:flutter_test/flutter_test.dart';
import 'package:watm_app/core/utils/circle_settings.dart';

void main() {
  group('circle matching settings', () {
    test('matching timeout prevents an endless loading screen', () {
      expect(kCircleMatchingTimeout, const Duration(seconds: 25));
      expect(
        kCircleMatchingCleanupTimeout,
        lessThan(kCircleMatchingTimeout),
      );
    });

    test('builds a stable key from the four hard matching criteria', () {
      expect(
        buildCircleMatchingKey(
          goalCode: 2,
          durationCode: 1,
          ageCode: 0,
          interactionTimeCode: 3,
        ),
        'g2-d1-a0-t3',
      );
    });

    test('different durations, ages, or interaction times use different circles', () {
      final base = buildCircleMatchingKey(
        goalCode: 2,
        durationCode: 1,
        ageCode: 0,
        interactionTimeCode: 3,
      );
      expect(
        buildCircleMatchingKey(
          goalCode: 2,
          durationCode: 2,
          ageCode: 0,
          interactionTimeCode: 3,
        ),
        isNot(base),
      );
      expect(
        buildCircleMatchingKey(
          goalCode: 2,
          durationCode: 1,
          ageCode: 0,
          interactionTimeCode: 1,
        ),
        isNot(base),
      );
      expect(
        buildCircleMatchingKey(
          goalCode: 2,
          durationCode: 1,
          ageCode: 1,
          interactionTimeCode: 3,
        ),
        isNot(base),
      );
    });

    test('age band groups members into 7-year brackets starting at 13', () {
      expect(ageBandCode(13), 0);
      expect(ageBandCode(19), 0);
      expect(ageBandCode(20), 1);
      expect(ageBandCode(26), 1);
      expect(ageBandCode(27), 2);
      // Out-of-range input is clamped instead of throwing or going negative.
      expect(ageBandCode(5), ageBandCode(13));
      expect(ageBandCode(150), ageBandCode(100));
    });

    test('age band label matches its band boundaries', () {
      expect(ageBandLabel(13), '13–19 سنة');
      expect(ageBandLabel(19), '13–19 سنة');
      expect(ageBandLabel(20), '20–26 سنة');
    });

    test('circle title is a stable motivational name for its criteria', () {
      final first = buildCircleDisplayName(
        goal: 'خسارة حتى 5 كغم',
        duration: 'خلال شهر',
        interactionTime: 'المساء',
      );
      // Deterministic: the exact same criteria always produce the exact
      // same name, so every member of that circle sees the same title.
      expect(
        buildCircleDisplayName(
          goal: 'خسارة حتى 5 كغم',
          duration: 'خلال شهر',
          interactionTime: 'المساء',
        ),
        first,
      );
      expect(first, startsWith('دائرة '));
      // No longer a raw dump of the criteria strings themselves.
      expect(first, isNot(contains('خسارة حتى 5 كغم')));
    });

    test('circle reference code is short and stable', () {
      expect(buildCircleReferenceCode('group-ABC123xyz'), 'W-123XYZ');
      expect(buildCircleReferenceCode('group-ABC123xyz'), 'W-123XYZ');
      expect(buildCircleReferenceCode('---'), isEmpty);
    });

    test('keeps a circle forming before five members', () {
      expect(circleStatusForMemberCount(1), 'forming');
      expect(circleStatusForMemberCount(4), 'forming');
    });

    test('activates a circle from five through six members', () {
      expect(circleStatusForMemberCount(5), 'active');
      expect(circleStatusForMemberCount(6), 'active');
    });

    test('marks a circle full at seven members', () {
      expect(circleStatusForMemberCount(7), 'full');
      expect(circleStatusForMemberCount(8), 'full');
    });
  });
}
