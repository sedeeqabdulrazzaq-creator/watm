import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firestore_helpers.dart';
import '../../../../core/widgets/watm_components.dart';
import '../../../progress/presentation/firebase_weekly_review_screen.dart';
import '../../../returning/presentation/firebase_return_after_absence_screen.dart';
import '../../../../core/utils/live_query.dart';

/// Weekly progress summary, attendance log, and shortcuts to the weekly
/// review / return-after-absence flows. Extracted from
/// `firebase_member_dashboard.dart`.
class ProgressPanel extends StatelessWidget {
  const ProgressPanel({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // ملاحظة: هذا الاستعلام يبقى بلا حد لأن الشاشة تعرض «إجمالي تسجيلاتك».
      // التخزين أدناه يجعله يُقرأ مرة واحدة في الجلسة بدل كل إعادة بناء.
      stream: LiveQuery.query(
        'checkIns:all:$userId',
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('checkIns'),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmCard(child: Text('تعذر تحميل سجل التقدم.'));
        }
        if (!snapshot.hasData) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final documents = [...?snapshot.data?.docs];
        documents.sort((a, b) => firstTimestamp(b.data(), const ['day', 'createdAt'])
            .compareTo(firstTimestamp(a.data(), const ['day', 'createdAt'])));
        final weekStart = startOfLocalWeek(DateTime.now());
        final weeklyDocuments = documents
            .where((document) => isDateInLocalWeek(
                  firstTimestamp(
                    document.data(),
                    const ['day', 'createdAt'],
                  ),
                  weekStart,
                ))
            .toList();
        final weeklyCount = weeklyDocuments.length;
        final progress = weeklyCount / 7;
        final scoredDays = weeklyDocuments
            .where((document) => document.data()['commitmentScore'] is int)
            .toList();
        final completedCommitments = scoredDays.fold<int>(
          0,
          (total, document) =>
              total + parseIntOrZero(document.data()['commitmentScore']),
        );
        final possibleCommitments = scoredDays.length * 3;
        return Column(
          children: [
            WatmCard(
              color: AppColors.natureSoft,
              borderColor: AppColors.nature,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$weeklyCount من 7 أيام هذا الأسبوع',
                    style: const TextStyle(
                      color: AppColors.universe,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WatmProgress(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    documents.isEmpty ? 'ابدأ بأول تسجيل يومي.' : 'إجمالي تسجيلاتك: ${documents.length}',
                    style: const TextStyle(color: AppColors.earth),
                  ),
                  if (possibleCommitments > 0) ...[
                    const Divider(height: 28),
                    Text(
                      '$completedCommitments من $possibleCommitments التزامات مكتملة',
                      style: const TextStyle(
                        color: AppColors.universe,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    WatmProgress(
                      value: completedCommitments / possibleCommitments,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الحركة • خطة الطعام • الماء',
                      style: TextStyle(color: AppColors.earth, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            WatmButton(
              label: 'بدء المراجعة الأسبوعية',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FirebaseWeeklyReviewScreen(userId: userId),
                ),
              ),
            ),
            const SizedBox(height: 14),
            WatmButton(
              label: 'معاينة العودة بعد الغياب',
              secondary: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FirebaseReturnAfterAbsenceScreen(
                    userId: userId,
                    absenceDays: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            WatmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('سجل الحضور', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (documents.isEmpty)
                    const Text('لا توجد تسجيلات بعد.', style: TextStyle(color: AppColors.earth))
                  else
                    ...documents.take(14).map((document) {
                      final data = document.data();
                      final date = firstTimestamp(data, const ['day', 'createdAt']);
                      final note = firstNonEmptyString(data, const ['note'], fallback: 'تم الحضور');
                      final score = data['commitmentScore'] is int
                          ? parseIntOrZero(data['commitmentScore'])
                          : null;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.nature,
                          child: Icon(Icons.check, color: AppColors.universe),
                        ),
                        title: Text('${date.day}/${date.month}/${date.year}'),
                        subtitle: Text(
                          score == null
                              ? note
                              : '$score من 3 التزامات${note == 'تم الحضور' ? '' : ' • $note'}',
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
