import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/circle_settings.dart';
import '../../../../core/utils/firestore_helpers.dart';
import '../../../../core/widgets/watm_components.dart';
import 'dashboard_shared_widgets.dart';
import '../../../../core/utils/live_query.dart';

/// Full circle screen content: header, members, encouragements.
/// Extracted from `firebase_member_dashboard.dart`.
class CirclePanel extends StatelessWidget {
  const CirclePanel({required this.groupId, required this.onEncourage, super.key});

  final String groupId;
  final VoidCallback onEncourage;

  @override
  Widget build(BuildContext context) {
    final reference = FirebaseFirestore.instance.collection('groups').doc(groupId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.doc(reference),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmCard(child: Text('تعذر تحميل الدائرة الآن.'));
        }
        if (!snapshot.hasData) {
          return const WatmCard(child: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data?.data();
        if (data == null) return const NoCirclePanel();
        final storedName = firstNonEmptyString(
          data,
          const ['name', 'title'],
          fallback: 'دائرتي',
        );
        final name = buildCircleDisplayName(
          goal: firstNonEmptyString(data, const ['goal']),
          duration: firstNonEmptyString(data, const ['duration']),
          interactionTime: firstNonEmptyString(
            data,
            const ['interactionTime'],
          ),
          fallback: storedName,
        );
        final storedMaxMembers = parseIntOrZero(data['maxMembers']);
        final maxMembers = storedMaxMembers > 0 ? storedMaxMembers : kCircleMaxMembers;
        return Column(
          children: [
            WatmCard(
              color: AppColors.seaSoft,
              borderColor: AppColors.sea,
              child: Column(
                children: [
                  const Icon(Icons.groups_2_outlined, color: AppColors.sea, size: 42),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.universe,
                    ),
                  ),
                  Text('حتى $maxMembers أعضاء', style: const TextStyle(color: AppColors.earth)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MembersPanel(groupId: groupId, maxMembers: maxMembers),
            const SizedBox(height: 14),
            EncouragementsPanel(groupId: groupId),
            const SizedBox(height: 14),
            WatmButton(label: 'شجّع عضواً', onPressed: onEncourage),
          ],
        );
      },
    );
  }
}

/// Circle members list (up to [kCircleMaxMembers]), with the top-scoring
/// member marked as the team captain. Extracted from
/// `firebase_member_dashboard.dart`.
class MembersPanel extends StatelessWidget {
  const MembersPanel({
    required this.groupId,
    this.maxMembers = kCircleMaxMembers,
    super.key,
  });

  final String groupId;
  final int maxMembers;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
        'members:$groupId:$maxMembers',
        FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .orderBy('personalStreak', descending: true)
            .limit(maxMembers),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmCard(child: Text('تعذر قراءة أعضاء الدائرة.'));
        }
        if (!snapshot.hasData) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final members = [...?snapshot.data?.docs];
        // "Points" today are represented by each member's check-in streak;
        // the captain is whoever has earned the most. Sorting (rather than
        // just picking a max) also surfaces the captain at the top of the
        // list. Everyone tied at 0 keeps their original order, and in that
        // case no one has "earned" the role yet, so no badge is shown.
        members.sort((a, b) => parseIntOrZero(b.data()['personalStreak'])
            .compareTo(parseIntOrZero(a.data()['personalStreak'])));
        final captainId = members.isEmpty
            ? null
            : parseIntOrZero(members.first.data()['personalStreak']) > 0
                ? members.first.id
                : null;

        return WatmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'الأعضاء (${members.length} من $maxMembers)',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (members.isEmpty)
                const Text('لم تتم إضافة أعضاء بعد.', style: TextStyle(color: AppColors.earth))
              else
                ...members.map((document) {
                  final data = document.data();
                  final name = firstNonEmptyString(
                    data,
                    const ['firstName', 'displayName', 'name'],
                    fallback: 'عضو',
                  );
                  final streak = parseIntOrZero(data['personalStreak']);
                  final isCaptain = document.id == captainId;
                  final status = firstNonEmptyString(
                    data,
                    const ['status', 'shortStatus'],
                    fallback: streak > 0 ? '$streak أيام التزام' : 'بدأ رحلته',
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        WatmAvatar(initial: name.characters.first),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCaptain) ...[
                                    const SizedBox(width: 6),
                                    const _CaptainBadge(),
                                  ],
                                ],
                              ),
                              Text(status, style: const TextStyle(color: AppColors.earth, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

/// Small "team captain" badge shown next to the top-scoring member's name.
class _CaptainBadge extends StatelessWidget {
  const _CaptainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.natureSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.nature),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 13, color: AppColors.universe),
          SizedBox(width: 4),
          Text(
            'كابتن الدائرة',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.universe,
            ),
          ),
        ],
      ),
    );
  }
}

/// Last 5 encouragements sent inside the circle. Extracted from
/// `firebase_member_dashboard.dart`.
class EncouragementsPanel extends StatelessWidget {
  const EncouragementsPanel({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
        'encouragements:recent:$groupId',
        FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('encouragements')
            .orderBy('createdAt', descending: true)
            .limit(5),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmCard(
            child: Text(
              'تعذر تحميل آخر التشجيعات الآن.',
              style: TextStyle(color: AppColors.earth),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final documents = [...?snapshot.data?.docs];
        return WatmCard(
          color: AppColors.natureSoft,
          borderColor: AppColors.nature,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'آخر التشجيعات',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (documents.isEmpty)
                const Text(
                  'كن أول من يرسل دفعة إيجابية اليوم.',
                  style: TextStyle(color: AppColors.earth),
                )
              else
                ...documents.take(5).map((document) {
                  final data = document.data();
                  final sender = firstNonEmptyString(data, const ['senderName'], fallback: 'عضو');
                  final recipient =
                      firstNonEmptyString(data, const ['recipientName'], fallback: 'عضو');
                  final message = firstNonEmptyString(data, const ['message'], fallback: 'أنا معك.');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$sender ← $recipient',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.earth,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
