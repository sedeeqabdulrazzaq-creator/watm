/// Converts a saved journey step into a safe screen to restore on app launch.
///
/// Steps 29–33 are member activities opened from the dashboard. They are
/// intentionally transient: relaunching the app must return an active member
/// to the dashboard instead of reopening the last activity.
int normalizeMvpRestoredStep({
  required int step,
  required bool hasMemberAccess,
  required bool isTrial,
  required int trialDaysLeft,
}) {
  final safeStep = step.clamp(0, 34).toInt();

  if (!hasMemberAccess && safeStep >= 16) {
    return 16;
  }

  if (hasMemberAccess && safeStep >= 28) {
    if (isTrial && trialDaysLeft <= 0) {
      return 34;
    }
    return 28;
  }

  return safeStep;
}
