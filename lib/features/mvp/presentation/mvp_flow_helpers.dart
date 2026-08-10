/// Converts a saved journey step into a safe screen to restore on app launch.
///
/// Steps 29–33 are member activities opened from the dashboard. They are
/// intentionally transient: relaunching the app must return an active member
/// to the dashboard instead of reopening the last activity.
int normalizeMvpRestoredStep({
  required int step,
  required bool hasMemberAccess,
  // Trial/membership flags are deprecated in the free build.
  required bool isTrial,
  required int trialDaysLeft,
}) {
  final safeStep = step.clamp(0, 34).toInt();

  // If the user already has member access (e.g., belongs to a circle)
  // restore them to the dashboard.
  if (hasMemberAccess && safeStep >= 28) {
    return 28;
  }

  // If the saved step pointed at a trial/renewal flow, map it to the
  // free onboarding start (basic information) so the user can continue.
  if (!hasMemberAccess && safeStep >= 16) {
    return 6;
  }

  return safeStep;
}
