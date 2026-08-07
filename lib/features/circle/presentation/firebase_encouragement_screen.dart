import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/circle_settings.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/widgets/watm_components.dart';
import '../../../core/utils/live_query.dart';

class FirebaseEncouragementScreen extends StatefulWidget {
  const FirebaseEncouragementScreen({
    required this.groupId,
    super.key,
  });

  final String groupId;

  @override
  State<FirebaseEncouragementScreen> createState() =>
      _FirebaseEncouragementScreenState();
}

class _FirebaseEncouragementScreenState
    extends State<FirebaseEncouragementScreen> {
  static const _messages = [
    'خطوة واحدة اليوم تكفي. أنا معك.',
    'عودتك أهم من الكمال. مكانك محفوظ.',
    'تقدّمك واضح، استمر بهدوء.',
    'شكراً لأنك تلهم دائرتنا بالاستمرار.',
  ];

  String? _recipientId;
  String? _recipientName;
  int? _messageIndex;
  bool _saving = false;
  String? _error;

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    final recipientId = _recipientId;
    final recipientName = _recipientName;
    final messageIndex = _messageIndex;
    if (user == null ||
        recipientId == null ||
        recipientName == null ||
        messageIndex == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final senderSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(user.uid)
          .get();
      final senderName = firstNonEmptyString(
        senderSnapshot.data() ?? <String, dynamic>{},
        const ['firstName', 'displayName', 'name'],
      );
      if (!senderSnapshot.exists || senderName.isEmpty) {
        throw StateError('تعذر التحقق من عضوية المرسل في الدائرة.');
      }
      final payload = <String, dynamic>{
        'senderId': user.uid,
        'senderName': senderName,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'message': _messages[messageIndex],
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'support',
      };
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('encouragements')
          .add(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('وصل تشجيعك إلى $recipientName')),
      );
      setState(() {
        _recipientId = null;
        _recipientName = null;
        _messageIndex = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'permission-denied'
            ? 'تعذر التحقق من عضويتك في الدائرة. أعد فتح التطبيق ثم حاول مجدداً.'
            : 'تعذر إرسال التشجيع (${error.code}). تحقق من الإنترنت وحاول مجدداً.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'لم يُرسل التشجيع بعد. تحقق من اتصالك وعضويتك في الدائرة ثم حاول مجدداً.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WatmPage(
      onBack: () => Navigator.of(context).pop(),
      eyebrow: 'دائرتي',
      title: 'من يحتاج دفعة صغيرة اليوم؟',
      subtitle: 'اختر عضواً ورسالة قصيرة ومحترمة. لا لوم ولا ضغط.',
      children: [
        _MemberSelector(
          groupId: widget.groupId,
          selectedId: _recipientId,
          onSelected: (id, name) => setState(() {
            _recipientId = id;
            _recipientName = name;
          }),
        ),
        const SizedBox(height: 20),
        const Text(
          'اختر الرسالة',
          style: TextStyle(
            color: AppColors.universe,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < _messages.length; index++)
          WatmChoice(
            label: _messages[index],
            selected: _messageIndex == index,
            onTap: () => setState(() => _messageIndex = index),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          WatmErrorCard(_error!, height: 1.5),
        ],
      ],
      bottom: WatmButton(
        label: _saving ? 'جارٍ الإرسال…' : 'إرسال التشجيع',
        onPressed: !_saving && _recipientId != null && _messageIndex != null
            ? _send
            : null,
      ),
    );
  }
}

class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
    required this.groupId,
    required this.selectedId,
    required this.onSelected,
  });

  final String groupId;
  final String? selectedId;
  final void Function(String id, String name) onSelected;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
        'members:$groupId',
        FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .limit(kCircleMaxMembers),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const WatmCard(child: Text('تعذر تحميل أعضاء الدائرة.'));
        }
        if (!snapshot.hasData) {
          return const WatmCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sea),
            ),
          );
        }
        final members = (snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((document) {
          final userId = document.data()['userId']?.toString() ?? document.id;
          return userId != currentUserId;
        }).toList();
        if (members.isEmpty) {
          return const WatmCard(
            color: AppColors.seaSoft,
            borderColor: AppColors.sea,
            child: Text(
              'لا يوجد عضو آخر في الدائرة حالياً. سيصبح التشجيع متاحاً عند انضمام عضو جديد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.earth, height: 1.6),
            ),
          );
        }
        return Column(
          children: members.map((document) {
            final data = document.data();
            final id = data['userId']?.toString() ?? document.id;
            final name = _nameOf(data);
            final streak = _numberOf(data['personalStreak']);
            return WatmChoice(
              label: name,
              caption: streak > 0 ? '$streak أيام التزام' : 'بدأ رحلته',
              selected: selectedId == id,
              onTap: () => onSelected(id, name),
            );
          }).toList(),
        );
      },
    );
  }
}

// Thin forwarders to lib/core/utils/firestore_helpers.dart, kept under the
// original local names so every call site below is unaffected.
String _nameOf(Map<String, dynamic> data) => firstNonEmptyString(
      data,
      const ['firstName', 'displayName', 'name'],
      fallback: 'عضو',
    );

int _numberOf(dynamic value) => parseIntOrZero(value);
