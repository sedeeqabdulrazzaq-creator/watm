/// Centralized feature flag for age-based circle matching.
///
/// When disabled (false), all users are placed in the same matching pool
/// regardless of age. When enabled (true), matching respects age-group
/// boundaries to keep members close in age.
///
/// The age field remains private in user profiles regardless of this flag.
/// The minimum required age is always 16 years.
///
/// To reactivate age-based matching, change this single flag to true and
/// rebuild. All age-related infrastructure is preserved and will be used
/// immediately.
class MatchingConfig {
  MatchingConfig._();

  /// Set to false to disable age-based circle matching.
  /// Set to true to enable age-based circle matching.
  static const bool ageMatchingEnabled = false;

  /// Set to false to disable interaction-time-based circle matching.
  /// Set to true to enable interaction-time-based circle matching.
  ///
  /// Every matching criterion narrows the pool a new member can be placed
  /// into: with age already off, a circle still needs an exact match on
  /// goal band (4) x duration (4) x interaction time (4) = 64 possible
  /// buckets. Early on, with only a handful of users total, the odds of two
  /// people landing in the same bucket are low, so almost everyone ends up
  /// alone in a "forming" circle of one instead of ever reaching the
  /// five-member "active" threshold in circle_settings.dart.
  ///
  /// Disabling this flag drops interaction time from the key, cutting the
  /// pool to 16 buckets (goal x duration only) — circles fill faster while
  /// the user base is small. Re-enable once enough users sign up that exact
  /// matches on all three criteria happen routinely; existing circles are
  /// unaffected either way, since matchingKey is fixed at creation time.
  static const bool interactionTimeMatchingEnabled = false;
}
