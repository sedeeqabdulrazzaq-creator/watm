/// Default number of members a circle holds when the group's Firestore
/// document does not explicitly set a `maxMembers` field. Every
/// circle-facing query and display (member list, encouragement picker,
/// header count) reads this constant so the cap stays consistent across
/// the app instead of being repeated as a magic number in each file.
const int kCircleMaxMembers = 7;

/// A circle can be entered immediately while it is being formed, and its
/// shared activity starts once five compatible members have joined.
const int kCircleMinimumStartMembers = 5;

/// Matching must never leave the member on an endless loading screen. This
/// limit covers Firestore writes and the atomic matching transaction.
const Duration kCircleMatchingTimeout = Duration(seconds: 25);

/// شبكة أمان أخيرة حول المعاملة كلها.
///
/// كانت 150 ثانية، وهي مدة تجعل أي فشل يبدو تعليقاً أبدياً أثناء التطوير.
/// 40 ثانية تكفي لخمس محاولات ثم تُظهر شاشة إعادة المحاولة بسرعة.
const Duration kCircleMatchingSafetyTimeout = Duration(seconds: 40);

/// Removing the short-lived matching key is best-effort and should not delay
/// navigation after a successful match or a handled failure.
const Duration kCircleMatchingCleanupTimeout = Duration(seconds: 5);

String buildCircleMatchingKey({
  required int goalCode,
  required int durationCode,
  required int ageCode,
  required int interactionTimeCode,
}) {
  return 'g$goalCode-d$durationCode-a$ageCode-t$interactionTimeCode';
}

/// Buckets age into 7-year bands starting at the minimum onboarding age
/// (13), so a circle's members are always close in age -- and, in
/// practice, closer in life stage and mindset too. Matching now weighs
/// goal, then duration/commitment, then this age band.
int ageBandCode(int age) {
  final clamped = age.clamp(13, 100);
  return (clamped - 13) ~/ 7;
}

/// Human-readable label for the band `ageBandCode` returns, e.g. "20–26 سنة".
String ageBandLabel(int age) {
  final band = ageBandCode(age);
  final start = 13 + band * 7;
  final end = start + 6;
  return '$start–$end سنة';
}

/// Motivational Arabic words shown after "دائرة" instead of a raw dump of
/// the matching criteria (goal + duration + interaction time), which read
/// like data, not a name members would feel good belonging to. The same
/// combination of criteria always maps to the same word (picked by a
/// stable hash), so every member of a given circle — and the same member
/// across app restarts — sees one consistent name.
const List<String> _circleMotivationalWords = [
  'الانطلاقة',
  'الإصرار',
  'الثبات',
  'الأمل',
  'العزيمة',
  'الإرادة',
  'التغيير',
  'النجاح',
  'الطاقة',
  'الالتزام',
  'الشجاعة',
  'التمكين',
  'الصمود',
  'الحماس',
  'الانضباط',
  'القوة',
  'الإشراق',
  'التوازن',
  'الثقة',
  'البداية الجديدة',
];

/// Builds the member-facing circle title from the same three criteria used by
/// automatic matching, so every circle formed from one matching key always
/// gets the same name.
String buildCircleDisplayName({
  required String goal,
  required String duration,
  required String interactionTime,
  String fallback = 'دائرتك',
}) {
  final criteria = <String>[
    goal.trim(),
    duration.trim(),
    interactionTime.trim(),
  ].where((value) => value.isNotEmpty).toList(growable: false);

  if (criteria.isEmpty) return fallback;
  final seed = criteria.join('|');
  final index = seed.hashCode.abs() % _circleMotivationalWords.length;
  return 'دائرة ${_circleMotivationalWords[index]}';
}

/// Short, stable reference shown in every circle screen. It lets support and
/// members distinguish two circles even if legacy records share the same
/// title. A Firestore document ID is not a credential, and signed-in members
/// already receive their own group ID through the private user document.
String buildCircleReferenceCode(String groupId) {
  final normalized = groupId
      .replaceAll(RegExp('[^A-Za-z0-9]'), '')
      .toUpperCase();
  if (normalized.isEmpty) return '';
  final suffix = normalized.length <= 6
      ? normalized
      : normalized.substring(normalized.length - 6);
  return 'W-$suffix';
}

String circleStatusForMemberCount(int memberCount) {
  if (memberCount >= kCircleMaxMembers) return 'full';
  if (memberCount >= kCircleMinimumStartMembers) return 'active';
  return 'forming';
}
