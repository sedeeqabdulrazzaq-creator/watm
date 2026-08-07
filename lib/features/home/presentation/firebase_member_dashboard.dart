import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/widgets/watm_components.dart';
import '../../circle/presentation/firebase_encouragement_screen.dart';
import '../../notifications/presentation/firebase_notifications_screen.dart';
import '../../returning/presentation/firebase_return_after_absence_screen.dart';
import 'widgets/account_tab_widgets.dart';
import 'widgets/circle_tab_widgets.dart';
import 'widgets/dashboard_shared_widgets.dart';
import 'widgets/home_tab_widgets.dart';
import 'widgets/progress_tab_widgets.dart';
import 'widgets/schedule_tab_widgets.dart';
import '../../../core/utils/live_query.dart';

class FirebaseMemberDashboard extends StatefulWidget {
  const FirebaseMemberDashboard({
    required this.onCheckIn,
    super.key,
  });

  final VoidCallback onCheckIn;

  @override
  State<FirebaseMemberDashboard> createState() =>
      _FirebaseMemberDashboardState();
}

class _FirebaseMemberDashboardState extends State<FirebaseMemberDashboard> {
  int _activeIndex = 4;

  void _select(int index) => setState(() => _activeIndex = index);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const WatmPage(
        title: 'يجب تسجيل الدخول أولاً',
        subtitle: 'سجّل الدخول بالبريد الإلكتروني لعرض بيانات رحلتك.',
        children: [Icon(Icons.lock_outline, size: 60, color: AppColors.sea)],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.doc(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmPage(
            title: 'تعذر تحميل بياناتك',
            subtitle: 'تحقق من الإنترنت ثم أعد فتح التطبيق.',
            children: [
              Icon(Icons.cloud_off_outlined, size: 60, color: AppColors.sea),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const WatmPage(
            children: [
              SizedBox(height: 220),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }

        final profile = snapshot.data?.data() ?? <String, dynamic>{};
        return _DashboardPage(
          user: user,
          profile: profile,
          activeIndex: _activeIndex,
          onCheckIn: widget.onCheckIn,
          onSelect: _select,
        );
      },
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.user,
    required this.profile,
    required this.activeIndex,
    required this.onCheckIn,
    required this.onSelect,
  });

  final User user;
  final Map<String, dynamic> profile;
  final int activeIndex;
  final VoidCallback onCheckIn;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstName = firstNonEmptyString(profile, const ['firstName', 'displayName'], fallback: 'عضو WATM');
    final groupId = firstNonEmptyString(profile, const ['groupId', 'circleId']);
    final daysLeft = _daysLeft(profile['trialStartedAt']);
    final heading = switch (activeIndex) {
      0 => ('حسابي', 'بيانات عضويتك وخصوصيتك.'),
      1 => ('تقدمي', 'شاهد التزامك وخطواتك في رحلة خسارة الوزن.'),
      2 => ('جدولي', 'نظّم مواعيدك اليومية والأسبوعية وفعّل التذكير.'),
      3 => ('دائرتي', 'أشخاص يخسرون الوزن معك، بلا مقارنة أو أحكام.'),
      _ => ('أهلاً $firstName',
          daysLeft > 0
              ? 'متبقي $daysLeft أيام من تجربتك. لا توجد بطاقة أو دفعة تلقائية.'
              : 'انتهت التجربة المجانية. بيانات رحلتك محفوظة.'),
    };

    return WatmPage(
      pinBottom: true,
      eyebrow: activeIndex == 4 ? 'تجربتك المجانية' : 'WATM',
      title: heading.$1,
      subtitle: heading.$2,
      bottom: WatmBottomNavigation(
        activeIndex: activeIndex,
        onCheckIn: onCheckIn,
        onAccount: () => onSelect(0),
        onProgress: () => onSelect(1),
        onSchedule: () => onSelect(2),
        onCircle: () => onSelect(3),
        onHome: () => onSelect(4),
      ),
      children: [
        ScheduleReminderSync(userId: user.uid),
        ..._content(
          context: context,
          userId: user.uid,
          email: user.email ?? '',
          firstName: firstName,
          groupId: groupId,
          daysLeft: daysLeft,
        ),
      ],
    );
  }

  List<Widget> _content({
    required BuildContext context,
    required String userId,
    required String email,
    required String firstName,
    required String groupId,
    required int daysLeft,
  }) {
    return switch (activeIndex) {
      0 => [
          AccountPanel(
            email: email,
            firstName: firstName,
            profile: profile,
            daysLeft: daysLeft,
            onSignOut: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      1 => [ProgressPanel(userId: userId)],
      2 => [SchedulePanel(userId: userId)],
      3 => [
          if (groupId.isEmpty)
            const NoCirclePanel()
          else
            CirclePanel(
              groupId: groupId,
              onEncourage: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FirebaseEncouragementScreen(
                    groupId: groupId,
                  ),
                ),
              ),
            ),
        ],
      _ => [
          ScheduleSummary(
            userId: userId,
            onOpen: () => onSelect(2),
          ),
          ReturnAfterAbsencePrompt(
            userId: userId,
            onOpen: (absenceDays) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FirebaseReturnAfterAbsenceScreen(
                  userId: userId,
                  absenceDays: absenceDays,
                ),
              ),
            ),
          ),
          if (groupId.isNotEmpty) ...[
            NotificationsSummary(
              groupId: groupId,
              userId: userId,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FirebaseNotificationsScreen(
                    groupId: groupId,
                    userId: userId,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TodayPanel(userId: userId, onCheckIn: onCheckIn),
          const SizedBox(height: 14),
          if (groupId.isEmpty)
            const NoCirclePanel()
          else
            CircleSummary(groupId: groupId, onOpen: () => onSelect(3)),
          const SizedBox(height: 14),
          const PrivacyPanel(),
        ],
    };
  }
}

int _daysLeft(dynamic value) {
  if (value is! Timestamp) return 7;
  final elapsed = DateTime.now().difference(value.toDate()).inDays;
  return (7 - elapsed).clamp(0, 7).toInt();
}
