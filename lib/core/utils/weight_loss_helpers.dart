double? parseWeightKg(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

bool isValidCurrentWeight(double? value) {
  return value != null && value >= 35 && value <= 350;
}

bool isValidTargetWeight({
  required double? currentWeight,
  required double? targetWeight,
}) {
  return isValidCurrentWeight(currentWeight) &&
      targetWeight != null &&
      targetWeight >= 30 &&
      targetWeight < currentWeight!;
}

double weightLossGoalKg({
  required double currentWeight,
  required double targetWeight,
}) {
  return currentWeight - targetWeight;
}

int weightLossBandCode(double kilograms) {
  if (kilograms <= 5) return 0;
  if (kilograms <= 10) return 1;
  if (kilograms <= 15) return 2;
  return 3;
}

String weightLossBandLabel(double kilograms) {
  final code = weightLossBandCode(kilograms);
  if (code == 0) return 'خسارة حتى 5 كغم';
  if (code == 1) return 'خسارة 6–10 كغم';
  if (code == 2) return 'خسارة 11–15 كغم';
  return 'خسارة أكثر من 15 كغم';
}

String formatWeightKg(double kilograms) {
  final rounded = kilograms.roundToDouble();
  if ((kilograms - rounded).abs() < 0.001) {
    return rounded.toInt().toString();
  }
  return kilograms.toStringAsFixed(1);
}

int dailyCommitmentScore(Set<int> selections) {
  return selections.where((index) => index >= 0 && index <= 2).length;
}
