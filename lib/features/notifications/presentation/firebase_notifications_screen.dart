import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/widgets/watm_components.dart';
import '../../../core/utils/live_query.dart';

class FirebaseNotificationsScreen extends StatelessWidget {
  const FirebaseNotificationsScreen({
    required this.groupId,
    required this.userId,
    super.key,
  });

  final String groupId;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _reads => FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId)
      .collection('notificationReads');

  Future<void> _markRead(String encouragementId) =>
      _reads.doc(encouragementId).set({
        'encouragementId': encouragementId,
        'groupId': groupId,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> _markAllRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    // Each write is validated against the related encouragement and group
    // membership. Small batches stay within Firestore Security Rules access
    // limits as well as the normal write-batch limit.
    const batchSize = 10;
    for (var start = 0; start < documents.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, documents.length).toInt();
      final batch = FirebaseFirestore.instance.batch();
      for (final document in documents.sublist(start, end)) {
        batch.set(
          _reads.doc(document.id),
          {
            'encouragementId': document.id,
            'groupId': groupId,
            'readAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _markReadWithFeedback(
    BuildContext context,
    String encouragementId,
  ) async {
    try {
      await _markRead(encouragementId);
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الإشعار (${error.code}).')),
      );
    }
  }

  Future<void> _markAllReadWithFeedback(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    try {
      await _markAllRead(documents);
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الإشعارات (${error.code}).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final encouragements = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('encouragements')
        .where('recipientId', isEqualTo: userId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
          'encouragements:for:$groupId:$userId', encouragements),
      builder: (context, encouragementSnapshot) {
        if (encouragementSnapshot.hasError) {
          return WatmPage(
            onBack: () => Navigator.of(context).pop(),
            eyebrow: 'دائرتي',
            title: 'الإشعارات',
            subtitle: 'تعذر تحميل التشجيعات الآن.',
            children: const [
              Icon(Icons.cloud_off_outlined, size: 58, color: AppColors.sea),
            ],
          );
        }
        if (!encouragementSnapshot.hasData) {
          return WatmPage(
            onBack: () => Navigator.of(context).pop(),
            eyebrow: 'دائرتي',
            title: 'تشجيعاتك',
            subtitle: 'جارٍ تحميل التشجيعات…',
            children: const [
              SizedBox(height: 100),
              Center(child: CircularProgressIndicator(color: AppColors.sea)),
            ],
          );
        }

        final received = [...?encouragementSnapshot.data?.docs]
          ..sort(
            (a, b) => _dateOf(b.data()).compareTo(_dateOf(a.data())),
          );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LiveQuery.query('notificationReads:$userId', _reads),
          builder: (context, readSnapshot) {
            if (readSnapshot.hasError) {
              return WatmPage(
                onBack: () => Navigator.of(context).pop(),
                eyebrow: 'دائرتي',
                title: 'تشجيعاتك',
                subtitle: 'تعذر تحميل حالة قراءة الإشعارات.',
                children: const [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 58,
                    color: AppColors.sea,
                  ),
                ],
              );
            }
            if (!readSnapshot.hasData) {
              return WatmPage(
                onBack: () => Navigator.of(context).pop(),
                eyebrow: 'دائرتي',
                title: 'تشجيعاتك',
                subtitle: 'جارٍ تحميل حالة القراءة…',
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: CircularProgressIndicator(color: AppColors.sea),
                  ),
                ],
              );
            }
            final readIds = {
              for (final document in readSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                document.id,
            };
            final unread = received
                .where((document) => !readIds.contains(document.id))
                .toList();

            return WatmPage(
              onBack: () => Navigator.of(context).pop(),
              eyebrow: 'دائرتي',
              title: 'تشجيعاتك',
              subtitle: unread.isNotEmpty
                  ? 'لديك ${unread.length} تشجيعات جديدة.'
                  : 'كل التشجيعات مقروءة. استمر بهدوء.',
              children: [
                if (unread.isNotEmpty) ...[
                  WatmButton(
                    label: 'تحديد الكل كمقروء',
                    secondary: true,
                    onPressed: () =>
                        _markAllReadWithFeedback(context, unread),
                  ),
                  const SizedBox(height: 14),
                ],
                if (received.isEmpty)
                  const WatmCard(
                    color: AppColors.seaSoft,
                    borderColor: AppColors.sea,
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 46,
                          color: AppColors.sea,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد تشجيعات مستلمة بعد.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...received.map((document) {
                    final data = document.data();
                    final isRead = readIds.contains(document.id);
                    final sender =
                        data['senderName']?.toString().trim().isNotEmpty == true
                            ? data['senderName'].toString()
                            : 'عضو من دائرتك';
                    final message = data['message']?.toString() ?? 'أنا معك.';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: isRead
                              ? null
                              : () => _markReadWithFeedback(
                                    context,
                                    document.id,
                                  ),
                          child: WatmCard(
                            color: isRead
                                ? AppColors.white
                                : AppColors.natureSoft,
                            borderColor: isRead
                                ? AppColors.border
                                : AppColors.nature,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isRead
                                        ? AppColors.seaSoft
                                        : AppColors.nature,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isRead
                                        ? Icons.mark_email_read_outlined
                                        : Icons.favorite_outline_rounded,
                                    color: AppColors.universe,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              sender,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.universe,
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: AppColors.sea,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          color: AppColors.earth,
                                          height: 1.55,
                                        ),
                                      ),
                                      if (!isRead) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          'اضغط لتحديده كمقروء',
                                          style: TextStyle(
                                            color: AppColors.sea,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}

// Thin forwarder to lib/core/utils/firestore_helpers.dart, kept under the
// original local name so every call site above is unaffected.
DateTime _dateOf(Map<String, dynamic> data) =>
    firstTimestamp(data, const ['createdAt']);
