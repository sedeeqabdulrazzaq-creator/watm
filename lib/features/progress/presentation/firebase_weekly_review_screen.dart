import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/widgets/watm_components.dart';
import '../../../core/utils/live_query.dart';

class FirebaseWeeklyReviewScreen extends StatefulWidget {
  const FirebaseWeeklyReviewScreen({required this.userId, super.key});

  final String userId;

  @override
  State<FirebaseWeeklyReviewScreen> createState() =>
      _FirebaseWeeklyReviewScreenState();
}

class _FirebaseWeeklyReviewScreenState
    extends State<FirebaseWeeklyReviewScreen> {
  static const _wins = [
    'حافظت على تسجيل حضوري.',
    'عدت بعد غياب ولم أستسلم.',
    'شجعت عضواً في دائرتي.',
    'أنجزت خطوة صحية مهمة.',
  ];

  static const _focuses = [
    'الاستمرار بهدوء كل يوم.',
    'تحسين النوم والراحة.',
    'زيادة الحركة اليومية.',
    'الاهتمام بالماء والغذاء.',
  ];

  int? _rating;
  int? _winIndex;
  int? _focusIndex;
  bool _loadingSavedReview = true;
  bool _saving = false;
  String? _error;

  late final DateTime _weekStart;

  DocumentReference<Map<String, dynamic>> get _reviewReference =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('weeklyReviews')
          .doc(_weekId);

  @override
  void initState() {
    super.initState();
    _weekStart = startOfLocalWeek(DateTime.now());
    _loadSavedReview();
  }

  Future<void> _loadSavedReview() async {
    try {
      final snapshot = await _reviewReference.get();
      final data = snapshot.data();
      if (data == null || !mounted) return;
      final rating = data['selfRating'];
      final win = data['biggestWin']?.toString();
      final focus = data['nextFocus']?.toString();
      final winIndex = win == null ? -1 : _wins.indexOf(win);
      final focusIndex = focus == null ? -1 : _focuses.indexOf(focus);
      setState(() {
        _rating = rating is int && rating >= 1 && rating <= 5 ? rating : null;
        _winIndex = winIndex >= 0 ? winIndex : null;
        _focusIndex = focusIndex >= 0 ? focusIndex : null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المراجعة السابقة (${error.code}).';
      });
    } finally {
      if (mounted) setState(() => _loadingSavedReview = false);
    }
  }

  String get _weekId => dailyDocId(_weekStart);

  Future<void> _save(int attendanceCount) async {
    if (_rating == null || _winIndex == null || _focusIndex == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _reviewReference.set({
        'weekId': _weekId,
        'weekStart': Timestamp.fromDate(_weekStart),
        'weekEnd': Timestamp.fromDate(
          _weekStart.add(const Duration(days: 6)),
        ),
        'attendanceCount': attendanceCount,
        'selfRating': _rating,
        'biggestWin': _wins[_winIndex!],
        'nextFocus': _focuses[_focusIndex!],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ مراجعتك الأسبوعية')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حفظ المراجعة (${error.code}).');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر حفظ المراجعة الآن. تحقق من الإنترنت وحاول مجدداً.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSavedReview) {
      return WatmPage(
        onBack: () => Navigator.of(context).pop(),
        eyebrow: 'التقدم',
        title: 'مراجعتك الأسبوعية',
        subtitle: 'نستعيد إجابات هذا الأسبوع…',
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.sea)),
        ],
      );
    }
    // هذه الشاشة تعرض الأسبوع الحالي فقط، فقراءة كامل السجل كانت هدراً.
    // معرّفات الوثائق بصيغة YYYY-MM-DD فترتيبها الأبجدي هو ترتيبها الزمني،
    // وأحدث 31 وثيقة تغطي أي أسبوع حالي مهما كان.
    final checkIns = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('checkIns')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(31);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query('checkIns:recent:${widget.userId}', checkIns),
      builder: (context, checkInSnapshot) {
        if (checkInSnapshot.hasError) {
          return WatmPage(
            onBack: () => Navigator.of(context).pop(),
            eyebrow: 'التقدم',
            title: 'مراجعتك الأسبوعية',
            subtitle: 'تعذر تحميل حضور هذا الأسبوع.',
            children: const [
              Icon(Icons.cloud_off_outlined, size: 58, color: AppColors.sea),
            ],
          );
        }
        if (!checkInSnapshot.hasData) {
          return WatmPage(
            onBack: () => Navigator.of(context).pop(),
            eyebrow: 'التقدم',
            title: 'مراجعتك الأسبوعية',
            subtitle: 'جارٍ احتساب حضور هذا الأسبوع…',
            children: const [
              SizedBox(height: 100),
              Center(child: CircularProgressIndicator(color: AppColors.sea)),
            ],
          );
        }
        final attendanceCount = (checkInSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((document) {
          final value = document.data()['day'] ?? document.data()['createdAt'];
          if (value is! Timestamp) return false;
          final date = value.toDate();
          return isDateInLocalWeek(date, _weekStart);
        }).length;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: LiveQuery.doc(_reviewReference),
          builder: (context, reviewSnapshot) {
            if (reviewSnapshot.hasError) {
              return WatmPage(
                onBack: () => Navigator.of(context).pop(),
                eyebrow: 'التقدم',
                title: 'مراجعتك الأسبوعية',
                subtitle: 'تعذر تحميل حالة المراجعة.',
                children: const [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 58,
                    color: AppColors.sea,
                  ),
                ],
              );
            }
            if (!reviewSnapshot.hasData) {
              return WatmPage(
                onBack: () => Navigator.of(context).pop(),
                eyebrow: 'التقدم',
                title: 'مراجعتك الأسبوعية',
                subtitle: 'جارٍ تحميل المراجعة…',
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: CircularProgressIndicator(color: AppColors.sea),
                  ),
                ],
              );
            }
            final saved = reviewSnapshot.data?.data();
            return WatmPage(
              onBack: () => Navigator.of(context).pop(),
              eyebrow: 'التقدم',
              title: saved == null
                  ? 'مراجعتك الأسبوعية'
                  : 'تمت مراجعة هذا الأسبوع',
              subtitle: saved == null
                  ? 'دقيقتان لفهم أسبوعك وتحديد خطوة الأسبوع القادم.'
                  : 'يمكنك تحديث إجاباتك قبل بداية الأسبوع الجديد.',
              children: [
                WatmCard(
                  color: AppColors.natureSoft,
                  borderColor: AppColors.nature,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$attendanceCount من 7 أيام حضور',
                        style: const TextStyle(
                          color: AppColors.universe,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      WatmProgress(value: attendanceCount / 7),
                      const SizedBox(height: 8),
                      const Text(
                        'لا نبحث عن أسبوع كامل؛ نبحث عن عودة مستمرة.',
                        style: TextStyle(color: AppColors.earth, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _QuestionTitle(
                  number: '1',
                  title: 'كيف تقيّم التزامك هذا الأسبوع؟',
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var value = 1; value <= 5; value++)
                        ChoiceChip(
                          label: Text('$value'),
                          selected: _rating == value,
                          onSelected: (_) => setState(() => _rating = value),
                          selectedColor: AppColors.sea,
                          labelStyle: TextStyle(
                            color: _rating == value
                                ? AppColors.white
                                : AppColors.universe,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _QuestionTitle(
                  number: '2',
                  title: 'ما أهم انتصار صغير حققته؟',
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < _wins.length; index++)
                  WatmChoice(
                    label: _wins[index],
                    selected: _winIndex == index,
                    onTap: () => setState(() => _winIndex = index),
                  ),
                const SizedBox(height: 14),
                const WatmCard(
                  color: AppColors.seaSoft,
                  borderColor: AppColors.sea,
                  child: Text(
                    'كل عودة تُحسب. فهمنا ما ساعدك هذا الأسبوع، وسنبني عليه.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.earth, height: 1.55),
                  ),
                ),
                const SizedBox(height: 24),
                const _QuestionTitle(
                  number: '3',
                  title: 'ما تركيزك للأسبوع القادم؟',
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < _focuses.length; index++)
                  WatmChoice(
                    label: _focuses[index],
                    selected: _focusIndex == index,
                    onTap: () => setState(() => _focusIndex = index),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  WatmErrorCard(_error!),
                ],
                const SizedBox(height: 14),
                WatmButton(
                  label: _saving
                      ? 'جارٍ الحفظ…'
                      : saved == null
                          ? 'حفظ المراجعة'
                          : 'تحديث المراجعة',
                  onPressed: !_saving &&
                          _rating != null &&
                          _winIndex != null &&
                          _focusIndex != null
                      ? () => _save(attendanceCount)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  const _QuestionTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.nature,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.universe,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.universe,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
}
