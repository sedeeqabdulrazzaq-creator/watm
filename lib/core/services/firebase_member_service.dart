import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint, kDebugMode;

import '../utils/circle_settings.dart';
import '../utils/firestore_helpers.dart';

class CircleMatchResult {
  const CircleMatchResult({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.status,
    required this.goal,
    required this.duration,
    required this.ageGroup,
  });

  final String groupId;
  final String groupName;
  final int memberCount;
  final String status;
  final String goal;
  final String duration;
  final String ageGroup;

  factory CircleMatchResult.fromDocument(
    String groupId,
    Map<String, dynamic> data,
  ) {
    final storedName = firstNonEmptyString(
      data,
      ['name', 'title'],
      fallback: 'دائرتك',
    );
    final goal = firstNonEmptyString(data, ['goal']);
    final duration = firstNonEmptyString(data, ['duration']);
    final ageGroup = firstNonEmptyString(data, ['ageGroup']);
    return CircleMatchResult(
      groupId: groupId,
      groupName: buildCircleDisplayName(
        goal: goal,
        duration: duration,
        interactionTime: firstNonEmptyString(data, ['interactionTime']),
        fallback: storedName,
      ),
      memberCount: parseIntOrZero(data['memberCount']),
      status: firstNonEmptyString(
        data,
        ['status'],
        fallback: 'forming',
      ),
      goal: goal,
      duration: duration,
      ageGroup: ageGroup,
    );
  }
}

/// سجل خطوات المطابقة الأخيرة.
///
/// نفس ما يُطبع في وحدة تحكم المتصفح، لكن معروضاً داخل التطبيق: عند تعليق
/// المطابقة تكفي لقطة واحدة من الشاشة لمعرفة آخر خطوة اكتملت، بدل فتح
/// أدوات المطوّر. لا يظهر إلا في وضع المحاكي.
final ValueNotifier<List<String>> matchingTrace =
    ValueNotifier<List<String>>(<String>[]);

void _trace(String message) {
  if (kDebugMode) debugPrint('[matchCurrentUser] $message');
  final next = <String>[...matchingTrace.value, message];
  matchingTrace.value =
      next.length > 14 ? next.sublist(next.length - 14) : next;
}

/// الدائرة التي ستعمل عليها المعاملة، مع عدّادها وحالتها مقروءين مسبقاً.
///
/// وجودها يوحّد فرعَي «الانضمام» و«الإنشاء»: كلاهما يُرجع نفس النوع، فتبقى
/// الدالة الرئيسية على مسار واحد بدل متغيّرات `late` تُملأ في فرعين.
class _CircleContext {
  const _CircleContext({
    required this.reference,
    required this.data,
    required this.memberCount,
    required this.status,
  });

  factory _CircleContext.fromDocument(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) {
    return _CircleContext(
      reference: reference,
      data: data,
      memberCount: parseIntOrZero(data['memberCount']),
      status: data['status']?.toString().trim().toLowerCase() ?? '',
    );
  }

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> data;
  final int memberCount;
  final String status;

  /// دائرة تقبل عضواً جديداً: نفس مفتاح المطابقة، وغير ممتلئة، وغير مغلقة.
  bool acceptsNewMember(String matchingKey) =>
      data['matchingKey'] == matchingKey &&
      memberCount < kCircleMaxMembers &&
      status != 'full' &&
      status != 'closed';
}

class FirebaseMemberService {
  FirebaseMemberService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static bool get isAvailable => Firebase.apps.isNotEmpty;

  User? get currentUser => _auth.currentUser;

  String normalizeIraqiPhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00964')) digits = digits.substring(2);
    if (digits.startsWith('964')) return '+$digits';
    if (digits.startsWith('07')) digits = digits.substring(1);
    if (digits.startsWith('7')) return '+964$digits';
    return '+$digits';
  }

  Future<void> ensureUserDocument() async {
    final user = _requireUser();
    final reference = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final values = <String, Object?>{
        'uid': user.uid,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (user.phoneNumber != null) {
        values['phone'] = user.phoneNumber;
      } else if (snapshot.data()?['phone'] == '+') {
        values['phone'] = FieldValue.delete();
      }
      if (!snapshot.exists) {
        values['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(reference, values, SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = currentUser;
    if (user == null) return null;
    // بلا مهلة، كان إقلاع التطبيق يعلق كلياً على اتصال بطيء أو متقطّع.
    // المستدعي يلتقط الاستثناء ويكمل بالبيانات المحفوظة محلياً.
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 6));
    return snapshot.data();
  }

  Future<void> saveProfile({
    required String name,
    required String age,
    required String city,
    required String phone,
    double? currentWeightKg,
    double? targetWeightKg,
  }) async {
    final user = _requireUser();
    final values = <String, Object?>{
      'firstName': name,
      'age': int.tryParse(age),
      'city': city,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (currentWeightKg != null && targetWeightKg != null) {
      values.addAll({
        'currentWeightKg': currentWeightKg,
        'targetWeightKg': targetWeightKg,
        'weightLossGoalKg': currentWeightKg - targetWeightKg,
      });
    }
    if (phone.trim().isNotEmpty) {
      values['phone'] = normalizeIraqiPhone(phone);
    }
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(values, SetOptions(merge: true));
  }

  Future<void> saveProgress({
    required int step,
    required Map<String, List<int>> answers,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'onboardingStep': step,
      'onboardingAnswers': answers,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DateTime> activateTrial() async {
    // Trial/membership fields are deprecated in the free build.
    // Keep this method as a safe no-op for older callers.
    return DateTime.now();
  }

  Future<CircleMatchResult> matchCurrentUser({
    required int goalCode,
    required int durationCode,
    required int ageCode,
    required int interactionTimeCode,
    required String goal,
    required String duration,
    required String ageGroup,
    required String interactionTime,
    required String seriousness,
    required String supportStyle,
    required String firstName,
  }) async {
    matchingTrace.value = <String>[];
    final user = _requireUser();
    final matchingKey = buildCircleMatchingKey(
      goalCode: goalCode,
      durationCode: durationCode,
      ageCode: ageCode,
      interactionTimeCode: interactionTimeCode,
    );
    final userReference = _firestore.collection('users').doc(user.uid);
    final groupCollection = _firestore.collection('groups');
    final bucketReference =
        _firestore.collection('matchingBuckets').doc(matchingKey);
    final queueReference =
        _firestore.collection('matchingQueue').doc(user.uid);

    // مسار سريع قبل أي كتابة: من طُوبق سلفاً ودائرته موجودة يعود فوراً،
    // بلا مفتاح مؤقّت ولا معاملة ولا كتابة تنظيف بعدها. أثره أن إعادة فتح
    // شاشة المطابقة — أو إعادة المحاولة بعد فشل سابق — محصّنة ضد أي خلل
    // داخل مسار المطابقة نفسه. أي فشل هنا يسقط بصمت إلى المعاملة أدناه.
    final existing = await _existingCircleFromProfile(
      userReference: userReference,
      groupCollection: groupCollection,
    );
    if (existing != null) return existing;

    // Limit group/bucket reads to the exact matching key being processed.
    // Security rules remove this short-lived field after the attempt.
    try {
      _trace('step=pendingKey:start key=$matchingKey');
      await userReference.set({
        'pendingMatchingKey': matchingKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(kCircleMatchingTimeout);
      _trace('step=pendingKey:done');

      var attempt = 0;
      return await _firestore
          .runTransaction<CircleMatchResult>(
        (transaction) async {
          attempt++;
          _trace('step=txn:start attempt=$attempt');

          // ── القراءات أولاً. Firestore يرفض أي قراءة بعد أول كتابة داخل
          //    المعاملة، فكل ما يحتاجه الفرعان يُقرأ هنا.
          final userSnapshot = await transaction.get(userReference);
          _trace('step=txn:readUser:done');
          final userData = userSnapshot.data() ?? <String, dynamic>{};

          final alreadyMatched = await _existingCircleResult(
            transaction: transaction,
            groupCollection: groupCollection,
            userData: userData,
          );
          if (alreadyMatched != null) return alreadyMatched;

          final bucketSnapshot = await transaction.get(bucketReference);
          _trace('step=txn:readBucket:done');
          final bucketData = bucketSnapshot.data() ?? <String, dynamic>{};
          final circleNumber = parseIntOrZero(bucketData['nextCircleNumber']);

          final circle = await _findReusableCircle(
            transaction: transaction,
            groupCollection: groupCollection,
            bucketData: bucketData,
            matchingKey: matchingKey,
          );

          // ── ثم الكتابات.
          final timestamp = FieldValue.serverTimestamp();
          final memberData = _newMemberData(
            userId: user.uid,
            firstName: firstName.trim().isNotEmpty
                ? firstName.trim()
                : firstNonEmptyString(
                    userData,
                    ['firstName', 'displayName'],
                    fallback: 'عضو',
                  ),
            goal: goal,
            duration: duration,
            ageGroup: ageGroup,
            interactionTime: interactionTime,
            seriousness: seriousness,
            supportStyle: supportStyle,
            joinedAt: timestamp,
          );

          final joined = circle != null
              ? await _joinCircle(
                  transaction: transaction,
                  circle: circle,
                  memberId: user.uid,
                  memberData: memberData,
                  timestamp: timestamp,
                )
              : _createCircle(
                  transaction: transaction,
                  groupCollection: groupCollection,
                  memberId: user.uid,
                  memberData: memberData,
                  matchingKey: matchingKey,
                  goal: goal,
                  duration: duration,
                  ageGroup: ageGroup,
                  interactionTime: interactionTime,
                  timestamp: timestamp,
                );

          _finalizeBucket(
            transaction: transaction,
            bucketReference: bucketReference,
            matchingKey: matchingKey,
            circle: joined,
            // الانضمام لا يستهلك رقماً جديداً؛ الإنشاء يحجز التالي.
            nextCircleNumber: circle != null
                ? (circleNumber < 1 ? 1 : circleNumber)
                : circleNumber + 1,
            timestamp: timestamp,
          );
          _updateUserMatch(
            transaction: transaction,
            userReference: userReference,
            groupId: joined.reference.id,
            matchingKey: matchingKey,
            timestamp: timestamp,
          );
          _updateQueue(
            transaction: transaction,
            queueReference: queueReference,
            userId: user.uid,
            groupId: joined.reference.id,
            matchingKey: matchingKey,
            criteria: <String, Object?>{
              'goal': goal,
              'duration': duration,
              'ageGroup': ageGroup,
              'interactionTime': interactionTime,
              'seriousness': seriousness,
              'supportStyle': supportStyle,
            },
            timestamp: timestamp,
          );

          _trace(
            'step=txn:beforeCommitReturn attempt=$attempt '
            'group=${joined.reference.id}',
          );
          return CircleMatchResult.fromDocument(
            joined.reference.id,
            joined.data,
          );
        },
        timeout: kCircleMatchingTimeout,
        maxAttempts: 5,
      )
          // Safety net: the Firestore SDK's own `timeout:`/`maxAttempts`
          // above should always resolve or throw well before this. This
          // outer timeout exists purely so a stalled transaction (seen
          // against the Firestore emulator, and possible in production
          // under rare SDK/network conditions) can never leave the person
          // stuck on the matching screen forever with no way to recover
          // except an unprompted page refresh — it always surfaces the
          // retry screen instead.
          .timeout(kCircleMatchingSafetyTimeout)
          .then((result) {
        _trace('step=DONE group=${result.groupId}');
        return result;
      });
    } on TimeoutException {
      _trace('step=TIMEOUT');
      rethrow;
    } on FirebaseException catch (error) {
      _trace(
        'step=FIREBASE_ERROR code=${error.code} message=${error.message}',
      );
      rethrow;
    } catch (error) {
      _trace('step=UNKNOWN_ERROR error=$error');
      rethrow;
    } finally {
      // تنظيف غير حاجز.
      //
      // كان هذا التحديث مُنتظَراً (await) داخل finally، أي أنه يقع بعد
      // تسجيل step=DONE وقبل أن تعود النتيجة إلى الشاشة. فكانت المطابقة
      // تنجح بالكامل ثم يبقى المستخدم أمام مؤشر دوّار حتى ينتهي التنظيف
      // أو تنقضي مهلته — وهو ما جعل إعادة تحميل الصفحة تبدو كأنها الحل.
      //
      // `pendingMatchingKey` قيمة عابرة تستبدلها أي مطابقة لاحقة، فلا
      // يصحّ أن يحجز مسحُها انتقال المستخدم إلى دائرته.
      unawaited(
        userReference
            .update({
              'pendingMatchingKey': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(kCircleMatchingCleanupTimeout)
            .catchError((Object _) {
              // فشل التنظيف لا يعني شيئاً للمستخدم: القيمة قصيرة العمر
              // وتُستبدل في المحاولة التالية.
            }),
      );
    }
  }

  /// نظير `_existingCircleResult` خارج المعاملة، للمسار السريع.
  ///
  /// قراءتان فقط: وثيقة المستخدم ثم دائرته. قاعدة `hasGroupAccess` تسمح
  /// بقراءة المجموعة لأن وثيقة المستخدم تشير إليها، فلا حاجة إلى
  /// `pendingMatchingKey` هنا. تُرجع `null` عند أي فشل — فتكمل المطابقة
  /// طريقها المعتاد بدل أن يرث المستخدم خطأً من تحسين.
  Future<CircleMatchResult?> _existingCircleFromProfile({
    required DocumentReference<Map<String, dynamic>> userReference,
    required CollectionReference<Map<String, dynamic>> groupCollection,
  }) async {
    try {
      final userSnapshot =
          await userReference.get().timeout(kCircleMatchingTimeout);
      final groupId = firstNonEmptyString(
        userSnapshot.data() ?? <String, dynamic>{},
        ['groupId', 'circleId'],
      );
      if (groupId.isEmpty) return null;

      final groupSnapshot = await groupCollection
          .doc(groupId)
          .get()
          .timeout(kCircleMatchingTimeout);
      final data = groupSnapshot.data();
      if (!groupSnapshot.exists || data == null) return null;

      _trace('step=fastPath:returnExisting group=$groupId');
      return CircleMatchResult.fromDocument(groupId, data);
    } on FirebaseException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// العضو مطابَق سلفاً ودائرته ما زالت موجودة: تُعاد كما هي بلا أي كتابة.
  /// تُرجع `null` إذا لم يكن له دائرة، أو كانت دائرته المسجّلة محذوفة.
  Future<CircleMatchResult?> _existingCircleResult({
    required Transaction transaction,
    required CollectionReference<Map<String, dynamic>> groupCollection,
    required Map<String, dynamic> userData,
  }) async {
    final existingGroupId = firstNonEmptyString(
      userData,
      ['groupId', 'circleId'],
    );
    if (existingGroupId.isEmpty) return null;

    _trace('step=txn:hasExistingGroup id=$existingGroupId');
    final snapshot =
        await transaction.get(groupCollection.doc(existingGroupId));
    _trace('step=txn:readExistingGroup:done');
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;

    _trace('step=txn:returnExisting');
    return CircleMatchResult.fromDocument(existingGroupId, data);
  }

  /// تبحث عن دائرة صالحة لإعادة الاستخدام لنفس مفتاح المطابقة.
  ///
  /// قراءة محضة: لا كتابة ولا أي منطق انضمام بداخلها، حتى يبقى قرار
  /// «أي دائرة؟» منفصلاً تماماً عن «ماذا نكتب فيها؟».
  ///
  /// المصدر الوحيد للمرشّحين اليوم هو `openGroupId` داخل حاوية المطابقة،
  /// لأن قواعد الأمان تمنع سرد مجموعة `groups` (`allow list: if false`)،
  /// و`Transaction.get` في SDK العميل لا يقبل استعلاماً أصلاً — يقبل مرجع
  /// وثيقة واحدة فقط. أي بحث أوسع يحتاج فهرساً داخل الحاوية نفسها.
  Future<_CircleContext?> _findReusableCircle({
    required Transaction transaction,
    required CollectionReference<Map<String, dynamic>> groupCollection,
    required Map<String, dynamic> bucketData,
    required String matchingKey,
  }) async {
    final openGroupId = firstNonEmptyString(bucketData, ['openGroupId']);
    if (openGroupId.isEmpty) {
      _trace('step=txn:reuse:none reason=emptyBucket');
      return null;
    }

    final snapshot = await transaction.get(groupCollection.doc(openGroupId));
    _trace('step=txn:readOpenGroup:done');
    final data = snapshot.data();
   if (!snapshot.exists || data == null) {
  _trace('step=txn:reuse:cleanupBucket id=$openGroupId');

  transaction.set(
    _firestore.collection('matchingBuckets').doc(matchingKey),
    {
      'matchingKey': matchingKey,
      'openGroupId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  return null;
}

    final circle = _CircleContext.fromDocument(snapshot.reference, data);
   if (!circle.acceptsNewMember(matchingKey)) {
  if (circle.status == 'full' ||
      circle.status == 'closed' ||
      circle.memberCount >= kCircleMaxMembers) {

    transaction.set(
      _firestore.collection('matchingBuckets').doc(matchingKey),
      {
        'matchingKey': matchingKey,
        'openGroupId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  _trace(
    'step=txn:reuse:none reason=notJoinable id=$openGroupId '
    'count=${circle.memberCount} status=${circle.status}',
  );

return null;
}

return circle;
}

  Future<_CircleContext> _joinCircle({
    required Transaction transaction,
    required _CircleContext circle,
    required String memberId,
    required Map<String, Object?> memberData,
    required Object timestamp,
  }) async {
    final memberReference =
        circle.reference.collection('members').doc(memberId);
    final memberSnapshot = await transaction.get(memberReference);
    if (memberSnapshot.exists) {
      _trace(
        'step=txn:branch=alreadyMember group=${circle.reference.id} '
        'count=${circle.memberCount}',
      );
      return circle;
    }

    // حارس دفاعي. `_findReusableCircle` تستبعد الممتلئة أصلاً، وقاعدة
    // الأمان ترفض عدّاداً فوق السبعة، لكن هذا يمنع أي تعديل مستقبلي من
    // تسريب دائرة ممتلئة إلى هذا المسار فتُكتب `memberCount: 8` بصمت.
    // موضعه بعد فحص العضوية عمداً: العضو الموجود في دائرة مكتملة يجب أن
    // تُعاد له دائرته، لا أن يُرمى له استثناء.
    if (circle.memberCount >= kCircleMaxMembers) {
      _trace('step=txn:joinRejected reason=full group=${circle.reference.id}');
      throw StateError('الدائرة اكتملت قبل إتمام الانضمام.');
    }

    final memberCount = circle.memberCount + 1;
    final status = circleStatusForMemberCount(memberCount);
    _trace(
      'step=txn:branch=joinExisting group=${circle.reference.id} '
      'count=$memberCount',
    );

    transaction.update(circle.reference, {
      'memberCount': memberCount,
      'status': status,
      'updatedAt': timestamp,
    });
    transaction.set(memberReference, memberData);

    return _CircleContext(
      reference: circle.reference,
      data: <String, dynamic>{
        ...circle.data,
        'memberCount': memberCount,
        'status': status,
      },
      memberCount: memberCount,
      status: status,
    );
  }

  /// تنشئ دائرة جديدة بعضو واحد وتُرجعها.
  _CircleContext _createCircle({
    required Transaction transaction,
    required CollectionReference<Map<String, dynamic>> groupCollection,
    required String memberId,
    required Map<String, Object?> memberData,
    required String matchingKey,
    required String goal,
    required String duration,
    required String ageGroup,
    required String interactionTime,
    required Object timestamp,
  }) {
    final reference = groupCollection.doc();
    const memberCount = 1;
    final status = circleStatusForMemberCount(memberCount);
    _trace('step=txn:branch=createNew group=${reference.id}');

    final data = <String, dynamic>{
      'name': buildCircleDisplayName(
        goal: goal,
        duration: duration,
        interactionTime: interactionTime,
      ),
      'matchingKey': matchingKey,
      'goal': goal,
      'duration': duration,
      'ageGroup': ageGroup,
      'interactionTime': interactionTime,
      'memberCount': memberCount,
      'maxMembers': kCircleMaxMembers,
      'minimumStartMembers': kCircleMinimumStartMembers,
      'status': status,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    };
    transaction.set(reference, data);
    transaction.set(
      reference.collection('members').doc(memberId),
      memberData,
    );

    return _CircleContext(
      reference: reference,
      data: data,
      memberCount: memberCount,
      status: status,
    );
  }

  /// تكتب حاوية المطابقة مرة واحدة للفرعين.
  ///
  /// الدائرة الممتلئة تُسحب من الحاوية، فيبدأ العضو التالي دائرة جديدة.
  /// `matchingKey` و`nextCircleNumber` يُكتبان دائماً لأن قاعدة `validBucket`
  /// تشترط وجودهما في الوثيقة الناتجة عن الدمج.
  void _finalizeBucket({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> bucketReference,
    required String matchingKey,
    required _CircleContext circle,
    required int nextCircleNumber,
    required Object timestamp,
  }) {
    transaction.set(
      bucketReference,
      {
        'matchingKey': matchingKey,
        'openGroupId': circle.memberCount >= kCircleMaxMembers
            ? FieldValue.delete()
            : circle.reference.id,
        'nextCircleNumber': nextCircleNumber,
        'updatedAt': timestamp,
      },
      SetOptions(merge: true),
    );
  }

  /// تربط وثيقة المستخدم بدائرته.
  void _updateUserMatch({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> userReference,
    required String groupId,
    required String matchingKey,
    required Object timestamp,
  }) {
    transaction.set(
      userReference,
      {
        'groupId': groupId,
        'circleId': groupId,
        'matchingKey': matchingKey,
        'matchingStatus': 'matched',
        'matchedAt': timestamp,
        'updatedAt': timestamp,
      },
      SetOptions(merge: true),
    );
  }

  /// تُغلق طلب المستخدم في طابور المطابقة.
  void _updateQueue({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> queueReference,
    required String userId,
    required String groupId,
    required String matchingKey,
    required Map<String, Object?> criteria,
    required Object timestamp,
  }) {
    transaction.set(
      queueReference,
      {
        'userId': userId,
        'status': 'matched',
        'groupId': groupId,
        'matchingKey': matchingKey,
        'criteria': criteria,
        'matchedAt': timestamp,
        'updatedAt': timestamp,
      },
      SetOptions(merge: true),
    );
  }

  Map<String, Object?> _newMemberData({
    required String userId,
    required String firstName,
    required String goal,
    required String duration,
    required String ageGroup,
    required String interactionTime,
    required String seriousness,
    required String supportStyle,
    required Object joinedAt,
  }) {
    return <String, Object?>{
      'userId': userId,
      'uid': userId,
      'firstName': firstName,
      'goal': goal,
      'duration': duration,
      'ageGroup': ageGroup,
      'interactionTime': interactionTime,
      'seriousness': seriousness,
      'supportStyle': supportStyle,
      'personalStreak': 0,
      'joinedAt': joinedAt,
      'updatedAt': joinedAt,
    };
  }

  Future<int> saveCheckIn({
    required DateTime day,
    required String note,
    required bool moved,
    required bool followedFoodPlan,
    required bool hydrated,
    required int commitmentScore,
  }) async {
    final user = _requireUser();
    final userReference = _firestore.collection('users').doc(user.uid);
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final checkInReference = userReference
        .collection('checkIns')
        .doc(dailyDocId(normalizedDay));
    final previousReference = userReference
        .collection('checkIns')
        .doc(dailyDocId(normalizedDay.subtract(const Duration(days: 1))));

    return _firestore.runTransaction<int>((transaction) async {
      final userSnapshot = await transaction.get(userReference);
      final userData = userSnapshot.data() ?? <String, dynamic>{};
      final groupId = firstNonEmptyString(
        userData,
        ['groupId', 'circleId'],
      );
      final checkInSnapshot = await transaction.get(checkInReference);
      final previousSnapshot = await transaction.get(previousReference);
      DocumentSnapshot<Map<String, dynamic>>? memberSnapshot;
      DocumentReference<Map<String, dynamic>>? memberReference;
      if (groupId.isNotEmpty) {
        memberReference = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(user.uid);
        memberSnapshot = await transaction.get(memberReference);
      }

      final existingStreak = parseIntOrZero(checkInSnapshot.data()?['streak']);
      final previousStreak = parseIntOrZero(previousSnapshot.data()?['streak']);
      final streak = nextDailyStreak(
        todayExists: checkInSnapshot.exists,
        todayStreak: existingStreak,
        previousDayExists: previousSnapshot.exists,
        previousDayStreak: previousStreak,
      );
      final existingCreatedAt = checkInSnapshot.data()?['createdAt'];

      transaction.set(
        checkInReference,
        {
          'day': Timestamp.fromDate(normalizedDay),
          'note': note,
          'streak': streak,
          'moved': moved,
          'followedFoodPlan': followedFoodPlan,
          'hydrated': hydrated,
          'commitmentScore': commitmentScore,
          'createdAt': existingCreatedAt is Timestamp
              ? existingCreatedAt
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Older accounts may point to a group without a member document. Do not
      // let that legacy inconsistency block the user's private daily check-in.
      if (memberReference != null && memberSnapshot?.exists == true) {
        transaction.set(
          memberReference,
          {
            'userId': user.uid,
            'uid': user.uid,
            'firstName': firstNonEmptyString(
              userData,
              ['firstName', 'displayName'],
              fallback: 'عضو',
            ),
            'personalStreak': streak,
            'lastCheckInAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      return streak;
    });
  }

  Future<void> signOut() => _auth.signOut();

  User _requireUser() {
    final user = currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول أولاً.');
    return user;
  }
}
