import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/circle_settings.dart';
import '../../../../core/utils/firestore_helpers.dart';
import '../../../../core/widgets/watm_components.dart';
import '../../../../core/utils/live_query.dart';

/// "مكانك محفوظ" prompt shown after 2+ days of absence.
/// Extracted from `firebase_member_dashboard.dart`.
class ReturnAfterAbsencePrompt extends StatelessWidget {
  const ReturnAfterAbsencePrompt({
    required this.userId,
    required this.onOpen,
    super.key,
  });

  final String userId;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayId = dailyDocId(today);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // اللافتة تحتاج آخر تسجيل فقط. معرّفات الوثائق بصيغة YYYY-MM-DD،
      // فأحدثها أبجدياً هو أحدثها زمنياً — وثيقة واحدة بدل السجل كله.
      stream: LiveQuery.query(
        'checkIns:latest:$userId',
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('checkIns')
            .orderBy(FieldPath.documentId, descending: true)
            .limit(1),
      ),
      builder: (context, checkInSnapshot) {
        final dates = (checkInSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map((document) => firstTimestamp(document.data(), const ['day', 'createdAt']))
            .where((date) => date.millisecondsSinceEpoch > 0)
            .toList()
          ..sort((a, b) => b.compareTo(a));
        if (dates.isEmpty) return const SizedBox.shrink();
        final last = dates.first;
        final lastDay = DateTime(last.year, last.month, last.day);
        final absenceDays = today.difference(lastDay).inDays;
        if (absenceDays < 2) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: LiveQuery.doc(
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('returns')
                .doc(todayId),
          ),
          builder: (context, returnSnapshot) {
            if (returnSnapshot.data?.exists == true) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: WatmCard(
                color: AppColors.natureSoft,
                borderColor: AppColors.nature,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: AppColors.sky),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'مكانك محفوظ',
                            style: TextStyle(
                              color: AppColors.universe,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مرّ $absenceDays أيام منذ آخر حضور. عُد بخطوة صغيرة بلا تعويض أو لوم.',
                      style: const TextStyle(
                        color: AppColors.earth,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 14),
                    WatmButton(
                      label: 'أعود اليوم',
                      onPressed: () => onOpen(absenceDays),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Encouragements notification bell/card shown on the home tab.
/// Extracted from `firebase_member_dashboard.dart`.
class NotificationsSummary extends StatelessWidget {
  const NotificationsSummary({
    required this.groupId,
    required this.userId,
    required this.onOpen,
    super.key,
  });

  final String groupId;
  final String userId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
        'encouragements:for:$groupId:$userId',
        FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('encouragements')
            .where('recipientId', isEqualTo: userId),
      ),
      builder: (context, encouragementSnapshot) {
        if (encouragementSnapshot.hasError) {
          return const WatmCard(
            child: Text('تعذر تحميل تشجيعاتك الآن.'),
          );
        }
        if (!encouragementSnapshot.hasData) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final receivedIds = {
          for (final document in encouragementSnapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            document.id,
        };
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LiveQuery.query(
            'notificationReads:$userId',
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notificationReads'),
          ),
          builder: (context, readSnapshot) {
            if (readSnapshot.hasError) {
              return const WatmCard(
                child: Text('تعذر تحميل حالة الإشعارات الآن.'),
              );
            }
            if (!readSnapshot.hasData) {
              return const WatmCard(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.sea),
                ),
              );
            }
            final readIds = {
              for (final document in readSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                document.id,
            };
            final unread = receivedIds.difference(readIds).length;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(22),
                child: WatmCard(
                  color: unread > 0 ? AppColors.natureSoft : AppColors.white,
                  borderColor:
                      unread > 0 ? AppColors.nature : AppColors.border,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: unread > 0
                              ? AppColors.nature
                              : AppColors.seaSoft,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.universe,
                            ),
                            if (unread > 0)
                              Positioned(
                                top: -8,
                                right: -10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.sea,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unread > 0
                                  ? 'لديك $unread تشجيعات جديدة'
                                  : 'تشجيعات دائرتك',
                              style: const TextStyle(
                                color: AppColors.universe,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'افتح الرسائل الداعمة التي وصلتك.',
                              style: TextStyle(
                                color: AppColors.earth,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: AppColors.sea,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Today's check-in status card shown on the home tab.
/// Extracted from `firebase_member_dashboard.dart`.
class TodayPanel extends StatelessWidget {
  const TodayPanel({required this.userId, required this.onCheckIn, super.key});

  final String userId;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final id = dailyDocId(now);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.doc(
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('checkIns')
            .doc(id),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmCard(child: Text('تعذر تحميل تسجيل اليوم.'));
        }
        if (!snapshot.hasData) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final checked = snapshot.data?.exists ?? false;
        final values = snapshot.data?.data() ?? <String, dynamic>{};
        final streak = parseIntOrZero(values['streak']);
        final hasCommitmentDetails = values['commitmentScore'] is int;
        final commitmentScore = parseIntOrZero(values['commitmentScore']);
        return WatmCard(
          color: checked ? AppColors.natureSoft : AppColors.white,
          borderColor: checked ? AppColors.nature : AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: checked ? AppColors.nature : AppColors.seaSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      checked ? Icons.check_rounded : Icons.today_outlined,
                      color: AppColors.universe,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checked ? 'تم تسجيل حضورك اليوم' : 'كيف كان التزامك اليوم؟',
                          style: const TextStyle(
                            color: AppColors.universe,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          checked && hasCommitmentDetails
                              ? '$commitmentScore من 3 التزامات • $streak أيام متتالية'
                              : streak > 0
                                  ? '$streak أيام متتالية'
                                  : 'ابدأ خطوتك الأولى بهدوء.',
                          style: const TextStyle(color: AppColors.earth),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!checked) ...[
                const SizedBox(height: 16),
                WatmButton(label: 'تسجيل اليوم', onPressed: onCheckIn),
              ] else if (hasCommitmentDetails) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CommitmentBadge(
                      label: 'الحركة',
                      completed: values['moved'] == true,
                    ),
                    _CommitmentBadge(
                      label: 'الطعام',
                      completed: values['followedFoodPlan'] == true,
                    ),
                    _CommitmentBadge(
                      label: 'الماء',
                      completed: values['hydrated'] == true,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommitmentBadge extends StatelessWidget {
  const _CommitmentBadge({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: completed ? AppColors.nature : AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_rounded : Icons.remove_rounded,
            size: 16,
            color: AppColors.universe,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.universe,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circle-name summary card shown on the home tab.
/// Extracted from `firebase_member_dashboard.dart`.
class CircleSummary extends StatelessWidget {
  const CircleSummary({required this.groupId, required this.onOpen, super.key});

  final String groupId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.doc(
        FirebaseFirestore.instance.collection('groups').doc(groupId),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final data = snapshot.data?.data();
        if (snapshot.hasError || data == null) {
          return const WatmCard(child: Text('تعذر تحميل ملخص الدائرة.'));
        }
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
        return WatmCard(
          color: AppColors.seaSoft,
          borderColor: AppColors.sea,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.groups_2_outlined, color: AppColors.sea, size: 38),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.universe,
                ),
              ),
              const SizedBox(height: 14),
              WatmButton(label: 'عرض دائرتي', onPressed: onOpen, secondary: true),
            ],
          ),
        );
      },
    );
  }
}
