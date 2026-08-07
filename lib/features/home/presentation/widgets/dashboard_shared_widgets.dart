import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/watm_components.dart';

/// Shown wherever the member has no circle assigned yet (home tab and
/// circle tab). Extracted from `firebase_member_dashboard.dart`.
class NoCirclePanel extends StatelessWidget {
  const NoCirclePanel({super.key});

  @override
  Widget build(BuildContext context) => const WatmCard(
        color: AppColors.seaSoft,
        borderColor: AppColors.sea,
        child: Column(
          children: [
            Icon(Icons.groups_2_outlined, color: AppColors.sea, size: 40),
            SizedBox(height: 12),
            Text(
              'مطابقة دائرتك قيد الإعداد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 7),
            Text(
              'عند تعيين دائرتك ستظهر بياناتها وأعضاؤها الحقيقيون هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.earth, height: 1.6),
            ),
          ],
        ),
      );
}

/// Privacy reassurance card shown on the home tab and the account tab.
/// Extracted from `firebase_member_dashboard.dart`.
class PrivacyPanel extends StatelessWidget {
  const PrivacyPanel({super.key});

  @override
  Widget build(BuildContext context) => const WatmCard(
        color: AppColors.natureSoft,
        borderColor: AppColors.nature,
        child: Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.sky),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'وزنك وأرقام تقدمك خاصة بك. ترى الدائرة اسمك الأول والتزامك فقط.',
                style: TextStyle(color: AppColors.universe, height: 1.5),
              ),
            ),
          ],
        ),
      );
}

/// A single label/value row used inside the account panel.
/// Extracted from `firebase_member_dashboard.dart`.
class ProfileRow extends StatelessWidget {
  const ProfileRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.earth))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
