import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/widgets/watm_components.dart';

class FirebaseReturnAfterAbsenceScreen extends StatefulWidget {
  const FirebaseReturnAfterAbsenceScreen({
    required this.userId,
    required this.absenceDays,
    super.key,
  });

  final String userId;
  final int absenceDays;

  @override
  State<FirebaseReturnAfterAbsenceScreen> createState() =>
      _FirebaseReturnAfterAbsenceScreenState();
}

class _FirebaseReturnAfterAbsenceScreenState
    extends State<FirebaseReturnAfterAbsenceScreen> {
  static const _actions = [
    'أسجل حضوري اليوم فقط.',
    'أمشي 10 دقائق بهدوء.',
    'أشرب الماء وأرتب يومي.',
    'أرسل رسالة قصيرة لدائرتي.',
  ];

  int? _selectedIndex;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final selectedIndex = _selectedIndex;
    if (selectedIndex == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = dailyDocId(DateTime.now());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('returns')
          .doc(id)
          .set({
        'absenceDays': widget.absenceDays,
        'selectedAction': _actions[selectedIndex],
        'returnedAt': FieldValue.serverTimestamp(),
        'status': 'returned',
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أهلاً بعودتك. خطوتك محفوظة.')),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حفظ خطوة العودة (${error.code}).');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.absenceDays.clamp(1, 30);
    return WatmPage(
      onBack: () => Navigator.of(context).pop(),
      eyebrow: 'مكانك محفوظ',
      title: 'أهلاً بعودتك',
      subtitle: 'غياب $days أيام لا يلغي ما بنيته. نبدأ بخطوة صغيرة اليوم.',
      children: [
        WatmCard(
          color: AppColors.seaSoft,
          borderColor: AppColors.sea,
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 38,
                  color: AppColors.sea,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'لا تحتاج إلى تعويض الأيام الماضية.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.universe,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'العودة نفسها انتصار. اختر ما تستطيع فعله الآن.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.earth, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'ما خطوة عودتك اليوم؟',
          style: TextStyle(
            color: AppColors.universe,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _actions.length; index++)
          WatmChoice(
            label: _actions[index],
            selected: _selectedIndex == index,
            onTap: () => setState(() => _selectedIndex = index),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          WatmErrorCard(_error!),
        ],
        const SizedBox(height: 14),
        WatmButton(
          label: _saving ? 'جارٍ الحفظ…' : 'أبدأ من جديد اليوم',
          onPressed: !_saving && _selectedIndex != null ? _save : null,
        ),
      ],
    );
  }
}
