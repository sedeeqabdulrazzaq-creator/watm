import 'package:flutter_test/flutter_test.dart';
import 'package:watm_app/core/utils/weight_loss_helpers.dart';

void main() {
  group('weight loss helpers', () {
    test('parses Arabic-friendly decimal input', () {
      expect(parseWeightKg(' 92,5 '), 92.5);
      expect(parseWeightKg('80'), 80);
      expect(parseWeightKg(''), isNull);
    });

    test('accepts a realistic target below the current weight', () {
      expect(isValidCurrentWeight(92), isTrue);
      expect(
        isValidTargetWeight(currentWeight: 92, targetWeight: 82),
        isTrue,
      );
      expect(
        isValidTargetWeight(currentWeight: 92, targetWeight: 95),
        isFalse,
      );
    });

    test('builds stable matching bands from the loss goal', () {
      expect(weightLossBandCode(5), 0);
      expect(weightLossBandCode(8), 1);
      expect(weightLossBandCode(15), 2);
      expect(weightLossBandCode(20), 3);
      expect(weightLossBandLabel(8), 'خسارة 6–10 كغم');
    });

    test('counts only the three daily commitments', () {
      expect(dailyCommitmentScore({0, 1, 2}), 3);
      expect(dailyCommitmentScore({1, 3}), 1);
      expect(dailyCommitmentScore({3}), 0);
    });
  });
}
