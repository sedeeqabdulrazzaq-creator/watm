import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firestore_helpers.dart';
import '../../../../core/utils/weight_loss_helpers.dart';
import '../../../../core/widgets/watm_components.dart';
import 'dashboard_shared_widgets.dart';

/// Account tab content: identity card, membership/trial status, privacy
/// note. Extracted from `firebase_member_dashboard.dart`.
class AccountPanel extends StatelessWidget {
  const AccountPanel({
    required this.email,
    required this.firstName,
    required this.profile,
    required this.daysLeft,
    required this.onSignOut,
    super.key,
  });

  final String email;
  final String firstName;
  final Map<String, dynamic> profile;
  final int daysLeft;
  final Future<void> Function() onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'هل تريد تسجيل الخروج من التطبيق؟ ستبقى دائرتك وتقدمك محفوظين لحين تسجيل الدخول مرة أخرى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('البقاء في التطبيق'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onSignOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = firstNonEmptyString(profile, const ['city'], fallback: 'غير محددة');
    final status = firstNonEmptyString(profile, const ['membershipStatus'], fallback: 'trial');
    final currentWeight = parseWeightKg(profile['currentWeightKg']?.toString() ?? '');
    final targetWeight = parseWeightKg(profile['targetWeightKg']?.toString() ?? '');
    return Column(
      children: [
        WatmCard(
          child: Column(
            children: [
              WatmAvatar(initial: firstName.characters.first),
              const SizedBox(height: 12),
              Text(firstName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(email, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.earth)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        WatmCard(
          color: AppColors.seaSoft,
          borderColor: AppColors.sea,
          child: Column(
            children: [
              ProfileRow(label: 'حالة العضوية', value: status == 'trial' ? 'تجربة مجانية' : status),
              ProfileRow(label: 'الأيام المتبقية', value: '$daysLeft'),
              ProfileRow(label: 'المدينة', value: city),
              ProfileRow(
                label: 'وزنك الحالي • خاص',
                value: currentWeight == null
                    ? 'غير محدد'
                    : '${formatWeightKg(currentWeight)} كغم',
              ),
              ProfileRow(
                label: 'هدفك • خاص',
                value: targetWeight == null
                    ? 'غير محدد'
                    : '${formatWeightKg(targetWeight)} كغم',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const PrivacyPanel(),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'تسجيل الخروج من التطبيق',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
