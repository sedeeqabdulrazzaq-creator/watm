import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/firebase_member_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/circle_settings.dart';
import '../../../core/utils/firestore_helpers.dart';
import '../../../core/utils/weight_loss_helpers.dart';
import '../../../core/widgets/watm_components.dart';
import '../../auth/presentation/firebase_email_gate.dart';
import '../../home/presentation/firebase_member_dashboard.dart';
import 'mvp_flow_helpers.dart';
import 'mvp_flow_widgets.dart';
import '../../../core/utils/live_query.dart';

/// Mirrors the flag in main.dart (same --dart-define, read independently —
/// bool.fromEnvironment is a compile-time constant available anywhere).
/// Shows the exact matching key on the matching screen so two test accounts
/// can be compared by eye, with no DevTools console needed.
const bool _debugMatchingInfoEnabled =
    bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);

class MvpFlow extends StatefulWidget {
  const MvpFlow({super.key});

  @override
  State<MvpFlow> createState() => _MvpFlowState();
}

class _MvpFlowState extends State<MvpFlow> {
  int _step = 0;
  final Map<int, Set<int>> _answers = {};
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _checkInNoteController = TextEditingController();
  Timer? _splashTimer;
  bool _splashDelayDone = false;
  bool _restoreDone = false;
  StreamSubscription<User?>? _authSubscription;
  SharedPreferences? _preferences;
  int _streak = 0;
  DateTime? _trialStartedAt;
  String? _membershipStatus;
  FirebaseMemberService? _firebase;
  bool _matchingRequested = false;
  bool _matchingBusy = false;
  String? _matchingError;
  String? _matchedGroupId;
  bool _authForExistingUser = false;
  bool _checkInBusy = false;
  String? _checkInError;

  String? get _normalizedMembershipStatus =>
      _membershipStatus?.trim().toLowerCase();

  bool get _hasMemberAccess {
    const memberStatuses = {'trial', 'active', 'member', 'paid'};
    const blockedStatuses = {'expired', 'cancelled', 'canceled', 'suspended'};
    final status = _normalizedMembershipStatus;
    return (status != null && memberStatuses.contains(status)) ||
        (_trialStartedAt != null && !blockedStatuses.contains(status));
  }

  bool get _isTrial {
    final status = _normalizedMembershipStatus;
    const paidStatuses = {'active', 'member', 'paid'};
    return status == 'trial' ||
        (_trialStartedAt != null && !paidStatuses.contains(status));
  }

  int get _trialDaysLeft {
    final startedAt = _trialStartedAt;
    if (startedAt == null) return 7;
    final elapsed = DateTime.now().difference(startedAt).inDays;
    final remaining = 7 - elapsed;
    if (remaining < 0) return 0;
    if (remaining > 7) return 7;
    return remaining;
  }

  int get _trialDay {
    final day = 8 - _trialDaysLeft;
    if (day < 1) return 1;
    if (day > 7) return 7;
    return day;
  }

  static const _coreQuestions = <QuestionData>[
    QuestionData(
      eyebrow: 'دافعك — السؤال 1 من 8',
      title: 'ما الشيء الذي تريد أن تستعيده بخسارة الوزن؟',
      subtitle:
          'لا توجد إجابة مثالية. اختر السبب الذي يستحق أن نحميه معك عندما تصبح الرحلة صعبة.',
      options: [
        'صحتي وطاقتي في يومي',
        'راحتي وثقتي بجسمي وملابسي',
        'قدرتي على الحركة والعيش بحرية أكبر',
        'ثقتي بأنني أستطيع الوفاء بوعد قطعته لنفسي',
      ],
    ),
    QuestionData(
      eyebrow: 'المدة — السؤال 2 من 8',
      title: 'متى تريد أن تنظر إلى نفسك وتقول: أنا فعلاً تغيّرت؟',
      subtitle:
          'سنستخدم هذه المدة لبناء رحلة واقعية، لا وعد سريع ينتهي بمحاولة أخرى.',
      options: ['21 يوماً', '90 يوماً', '6 أشهر', 'سنة كاملة'],
    ),
    QuestionData(
      eyebrow: 'الجدية — السؤال 3 من 8',
      title: 'في أصعب يوم، ما الوعد الذي تستطيع ألا تتركه؟',
      subtitle:
          'القوة ليست في اليوم المثالي؛ بل في الخطوة الصغيرة التي تحافظ عليها عندما يقل حماسك.',
      options: [
        'أسجل حضوري بصدق حتى إن لم أنجز',
        'أنفذ خطوة بسيطة لعشر دقائق',
        'أطلب الدعم بدلاً من أن أختفي',
        'أحتاج أن أبني التزامي تدريجياً مع المتابعة',
      ],
    ),
    QuestionData(
      eyebrow: 'المحاولات — السؤال 4 من 8',
      title: 'أي جملة تصف قصتك السابقة بصدق؟',
      subtitle:
          'لن نحكم على الماضي؛ سنستخدمه حتى لا نعيد معك الدائرة نفسها.',
      options: [
        'هذه أول تجربة منظمة لي',
        'أبدأ بحماس، ثم يتراجع التزامي تدريجياً',
        'أتعثر مرة واحدة فأتعامل مع الأسبوع كله كأنه ضاع',
        'أعرف ما يجب فعله، لكن تنقصني المتابعة والمحاسبة',
      ],
    ),
    QuestionData(
      eyebrow: 'التعثر — السؤال 5 من 8',
      title: 'عندما تتعثر، ما الذي يحدث قبل أن تتوقف غالباً؟',
      subtitle:
          'إجابتك تساعد دائرتك على التدخل في اللحظة الصحيحة، قبل أن يتحول يوم صعب إلى انسحاب.',
      options: [
        'ألجأ إلى الطعام عندما أتوتر أو أتعب',
        'فوضى يومي تربك وجباتي وحركتي',
        'يوم غير ملتزم يتحول عندي إلى أسبوع كامل',
        'أغيب لأنني أشعر أن أحداً لن يلاحظ أو يسأل',
      ],
    ),
    QuestionData(
      eyebrow: 'وقت التفاعل — السؤال 6 من 8',
      title: 'متى تكون قادراً فعلاً على الحضور لدائرتك؟',
      subtitle:
          'لا نريد الوقت المثالي على الورق؛ نريد وقتاً تستطيع أن تظهر فيه حتى خلال أسبوع مزدحم.',
      options: [
        'الصباح قبل أن يبدأ انشغالي',
        'الظهر خلال استراحة يومي',
        'المساء بعد انتهاء مسؤولياتي',
        'وقتي يتغير وأحتاج دائرة مرنة',
      ],
    ),
    QuestionData(
      eyebrow: 'الدعم — السؤال 7 من 8',
      title: 'عندما تفقد دافعك، كيف تريد من دائرتك أن تقف معك؟',
      subtitle:
          'الدعم الفعّال يختلف من شخص لآخر. اختر الأسلوب الذي يعيدك من دون ضغط أو إحراج.',
      options: [
        'سؤال مباشر وصادق عندما أغيب',
        'تشجيع لطيف من دون لوم أو محاكمة',
        'شخص يشاركني تجربته ويشعر بما أمر به',
        'متابعة يومية واضحة تذكرني بوعدي',
      ],
    ),
    QuestionData(
      eyebrow: 'الخصوصية — السؤال 8 من 8',
      title: 'ما الحد الذي يجعلك تشارك بصدق وتشعر بالأمان؟',
      subtitle:
          'قيمتك ليست في رقم وزنك. أنت تقرر ما يظهر، ويمكنك تغيير مستوى الخصوصية لاحقاً.',
      options: [
        'اسمي الأول والتزامي اليومي فقط',
        'تقدمي وأيام التزامي من دون إظهار وزني',
        'أشارك تحدياتي داخل دائرتي الخاصة فقط',
        'أفضل أقل معلومات ممكنة وتذكيرات خاصة',
      ],
    ),
  ];

  static const _detailQuestions = <QuestionData>[
    QuestionData(
      eyebrow: 'إكمال ملف العضوية • الشخصية 1 من 6',
      title: 'ما الشيء الذي يستطيع أعضاء دائرتك الاعتماد عليك فيه؟',
      subtitle:
          'الدائرة القوية لا تسأل فقط عما تحتاجه؛ بل تعرف أيضاً القيمة التي تحملها لها.',
      options: [
        'أستمع باهتمام وأمنح الآخرين مساحة آمنة',
        'أبادر بالتشجيع وأحتفل بالتقدم الصغير',
        'أسأل بوضوح وأساعد على العودة إلى الخطة',
        'أكون صادقاً في تعثري حتى يشعر الآخرون أنهم ليسوا وحدهم',
      ],
    ),
    QuestionData(
      eyebrow: 'إكمال ملف العضوية • السيناريوهات 2 من 6',
      title: 'إذا ابتعدت يومين، ما الذي يساعدك على العودة من دون شعور بالذنب؟',
      subtitle:
          'نريد أن نصمم لك طريق عودة واضحاً قبل أن تحتاجه، لأن التعثر جزء طبيعي من أي رحلة.',
      options: [
        'أسجل ما حدث بصدق وأبدأ من الوجبة أو الخطوة التالية',
        'رسالة خاصة ولطيفة تسأل عني',
        'مهمة صغيرة تعيدني للحركة فوراً',
        'عضو يشاركني تعثره وكيف عاد',
      ],
    ),
    QuestionData(
      eyebrow: 'إكمال ملف العضوية • حدود التذكير 3 من 6',
      title: 'أي متابعة تجعلك مسؤولاً من دون أن تشعرك بأنك مراقَب؟',
      subtitle:
          'حدودك مهمة. سنوضحها لدائرتك حتى يكون الدعم مفيداً ومحترماً.',
      options: [
        'اسألوني مباشرة إذا غبت؛ هذا سبب وجودي هنا',
        'ذكّروني بلطف ومن دون تكرار أو ضغط',
        'أفضل تنبيهات خاصة من النظام فقط',
      ],
    ),
    QuestionData(
      eyebrow: 'إكمال ملف العضوية • التفاصيل الصحية 4 من 6',
      title: 'هل توجد تفاصيل صحية يجب مراعاتها؟',
      subtitle: 'هذه المعلومات خاصة، وتستخدم لتجنب اقتراحات غير مناسبة.',
      options: ['لا توجد', 'إصابة أو ألم حركي', 'حالة صحية مزمنة', 'أفضل مناقشتها لاحقاً'],
    ),
    QuestionData(
      eyebrow: 'إكمال ملف العضوية • ميثاق الدائرة 5 من 6',
      title: 'ما الوعد الذي ستقدمه لأعضاء دائرتك؟',
      subtitle:
          'اختر البنود التي تلتزم بها. العضوية هنا مسؤولية متبادلة وليست مجرد متابعة صامتة.',
      options: [
        'أحمي خصوصية ما يشاركه الأعضاء',
        'لا أستخدم اللوم أو المقارنة أو السخرية',
        'أشجع العودة بعد التعثر ولا أطلب الكمال',
        'أحترم حدود التواصل ووقت كل عضو',
      ],
    ),
    QuestionData(
      eyebrow: 'إكمال ملف العضوية • الالتزامات 6 من 6',
      title: 'اختر ثلاثة وعود يمكنك تنفيذها حتى في أسبوع صعب',
      subtitle:
          'لا نبحث عن خطة مثالية؛ نبحث عن وعود واضحة تستطيع دائرتك أن تساعدك على الوفاء بها.',
      options: [
        'أتحرك أو أمشي لمدة عشر دقائق على الأقل',
        'ألتزم بثلاث حصص تدريب أسبوعياً',
        'أحقق هدف الماء اليومي الذي حددته',
        'ألتزم بوجباتي المخططة أو أسجل خروجي عنها بصدق',
        'أحمي وقت نوم ثابت قدر الإمكان',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (FirebaseMemberService.isAvailable) {
      _firebase = FirebaseMemberService();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        if (mounted) setState(() {});
      });
    }
    // المؤقّت يعمل بالتوازي مع استعادة الملف الشخصي، لا بعدها. سابقاً كانت
    // مدة شاشة البداية = زمن الشبكة + 1500 مللي، فكانت تعلق على اتصال بطيء.
    _splashTimer = Timer(const Duration(milliseconds: 1500), () {
      _splashDelayDone = true;
      _leaveSplashWhenReady();
    });
    _restoreProgress().whenComplete(() {
      _restoreDone = true;
      _leaveSplashWhenReady();
    });
  }

  /// ينتقل من شاشة البداية حين ينتهي الأمران: مرور الحد الأدنى للعرض،
  /// واكتمال الاستعادة. الاستعادة نفسها محدودة بمهلة داخل [loadProfile]
  /// فلا يمكن أن تبقى معلّقة إلى الأبد.
  void _leaveSplashWhenReady() {
    if (!mounted || _step != 0) return;
    if (!_splashDelayDone || !_restoreDone) return;
    setState(() => _step = 1);
    _saveProgress();
  }

  Future<void> _restoreProgress() async {
    final preferences = await SharedPreferences.getInstance();
    final savedStep = preferences.getInt('watm_mvp_step');
    final savedAnswers = preferences.getString('watm_mvp_answers');
    Map<String, dynamic>? cloudProfile;
    try {
      cloudProfile = await _firebase?.loadProfile();
    } catch (_) {
      // The local journey still works while the cloud is temporarily offline.
    }
    if (!mounted) return;

    _preferences = preferences;
    setState(() {
      // A newly authenticated account must never inherit questionnaire data
      // that was still held in memory for a different local user.
      _answers.clear();
      _nameController.text = preferences.getString('watm_name') ??
          cloudProfile?['firstName']?.toString() ??
          '';
      _ageController.text = preferences.getString('watm_age') ??
          cloudProfile?['age']?.toString() ??
          '';
      _cityController.text = preferences.getString('watm_city') ??
          cloudProfile?['city']?.toString() ??
          '';
      _currentWeightController.text =
          preferences.getString('watm_current_weight_kg') ??
              cloudProfile?['currentWeightKg']?.toString() ??
              '';
      _targetWeightController.text =
          preferences.getString('watm_target_weight_kg') ??
              cloudProfile?['targetWeightKg']?.toString() ??
              '';
      _matchedGroupId = firstNonEmptyString(
        cloudProfile ?? <String, dynamic>{},
        ['groupId', 'circleId'],
      );
      _streak = preferences.getInt('watm_streak') ?? 0;
      final localMembershipStatus =
          preferences.getString('watm_membership_status');
      _membershipStatus = localMembershipStatus;
      final cloudMembershipStatus =
          cloudProfile?['membershipStatus']?.toString().trim().toLowerCase();
      if (cloudMembershipStatus != null &&
          cloudMembershipStatus.isNotEmpty) {
        // Trial activation is local-first. Do not let an older cloud-side
        // applicant value undo a trial that is still waiting to synchronize.
        final localTrialPendingSync =
            localMembershipStatus?.trim().toLowerCase() == 'trial' &&
                cloudMembershipStatus == 'applicant';
        if (!localTrialPendingSync) {
          _membershipStatus = cloudMembershipStatus;
        }
      }
      final trialValue = preferences.getString('watm_trial_started_at');
      _trialStartedAt =
          trialValue == null ? null : DateTime.tryParse(trialValue);
      final cloudTrial = cloudProfile?['trialStartedAt'];
      if (cloudTrial is Timestamp) {
        _trialStartedAt = cloudTrial.toDate();
      }
      final cloudStep = cloudProfile?['onboardingStep'];
      final restoredStep = cloudStep is int && cloudStep > (savedStep ?? -1)
          ? cloudStep
          : savedStep;
      if (restoredStep != null) {
        _step = restoredStep.clamp(0, 34).toInt();
      }
      dynamic restoredAnswers = cloudProfile?['onboardingAnswers'];
      if (savedAnswers != null) {
        try {
          restoredAnswers = jsonDecode(savedAnswers);
        } on FormatException {
          // Ignore damaged local data and use the cloud copy when available.
        }
      }
      if (restoredAnswers is Map) {
        for (final entry in restoredAnswers.entries) {
          if (entry.value is! List) continue;
          final answerStep = int.tryParse(entry.key.toString());
          if (answerStep == null) continue;
          _answers[answerStep] =
              (entry.value as List<dynamic>).whereType<int>().toSet();
        }
      }
      _step = normalizeMvpRestoredStep(
        step: _step,
        hasMemberAccess: _hasMemberAccess,
        isTrial: _isTrial,
        trialDaysLeft: _trialDaysLeft,
      );
      if (_step >= 7 && _step <= 27 && !_weightGoalValid) {
        _step = 6;
      }
    });
    // Also repairs stale steps created by older builds in local storage and
    // Firestore, so the wrong activity does not return on the next launch.
    await _saveProgress();
    final firebase = _firebase;
    final cloudTrialStarted = cloudProfile?['trialStartedAt'] is Timestamp;
    if (firebase != null &&
        firebase.currentUser != null &&
        _normalizedMembershipStatus == 'trial' &&
        !cloudTrialStarted) {
      unawaited(_syncTrialActivation(firebase, preferences));
    }
  }

  Future<void> _saveProgress() async {
    final preferences =
        _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    final answers = _answers.map(
      (step, values) => MapEntry(step.toString(), values.toList()),
    );
    final persistedStep = normalizeMvpRestoredStep(
      step: _step,
      hasMemberAccess: _hasMemberAccess,
      isTrial: _isTrial,
      trialDaysLeft: _trialDaysLeft,
    );
    await preferences.setInt('watm_mvp_step', persistedStep);
    await preferences.setString('watm_mvp_answers', jsonEncode(answers));
    final membershipStatus = _membershipStatus;
    if (membershipStatus != null && membershipStatus.isNotEmpty) {
      await preferences.setString(
        'watm_membership_status',
        membershipStatus,
      );
    }
    final firebase = _firebase;
    if (firebase?.currentUser != null) {
      try {
        await firebase!.saveProgress(step: persistedStep, answers: answers);
      } catch (_) {
        // Local progress stays available until the next cloud sync.
      }
    }
  }

  Future<void> _saveMemberProfile() async {
    final preferences =
        _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setString('watm_name', _nameController.text.trim());
    await preferences.setString('watm_age', _ageController.text.trim());
    await preferences.setString('watm_city', _cityController.text.trim());
    await preferences.setString(
      'watm_current_weight_kg',
      _currentWeightController.text.trim(),
    );
    await preferences.setString(
      'watm_target_weight_kg',
      _targetWeightController.text.trim(),
    );
    final firebase = _firebase;
    if (firebase?.currentUser != null) {
      try {
        await firebase!.saveProfile(
          name: _nameController.text.trim(),
          age: _ageController.text.trim(),
          city: _cityController.text.trim(),
          phone: '',
          currentWeightKg: _currentWeightKg,
          targetWeightKg: _targetWeightKg,
        );
      } catch (_) {
        // The profile remains available locally until the next cloud sync.
      }
    }
  }

  Future<void> _completeCheckIn() async {
    if (_checkInBusy) return;
    final preferences =
        _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _checkInBusy = true;
      _checkInError = null;
    });
    final firebase = _firebase;
    final commitments = _answers[29] ?? <int>{};
    final commitmentScore = dailyCommitmentScore(commitments);
    try {
      if (firebase == null || firebase.currentUser == null) {
        throw StateError('يجب تسجيل الدخول أولاً.');
      }
      final nextStreak = await firebase.saveCheckIn(
        day: today,
        note: _checkInNoteController.text.trim(),
        moved: commitments.contains(0),
        followedFoodPlan: commitments.contains(1),
        hydrated: commitments.contains(2),
        commitmentScore: commitmentScore,
      );
      await preferences.setString(
        'watm_last_check_in',
        today.toIso8601String(),
      );
      await preferences.setInt('watm_streak', nextStreak);
      await preferences.setString(
        'watm_last_check_in_note',
        _checkInNoteController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _streak = nextStreak);
      _next();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _checkInError = error.code == 'permission-denied'
            ? 'تعذر حفظ تسجيل اليوم بسبب صلاحيات قاعدة البيانات. حدّث القواعد ثم حاول مجدداً.'
            : 'تعذر حفظ تسجيل اليوم (${error.code}). تحقق من الإنترنت وحاول مجدداً.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkInError =
            'لم يُحفظ تسجيل اليوم بعد. تحقق من تسجيل الدخول والإنترنت ثم حاول مجدداً.';
      });
    } finally {
      if (mounted) setState(() => _checkInBusy = false);
    }
  }

  Future<void> _activateFreeTrial() async {
    final preferences =
        _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    final localStartedAt = _trialStartedAt ?? DateTime.now();

    // Activate locally before contacting Firestore so this primary action is
    // never blocked by a slow connection or security-rule configuration.
    await preferences.setString(
      'watm_trial_started_at',
      localStartedAt.toIso8601String(),
    );
    await preferences.setString('watm_membership_status', 'trial');
    if (!mounted) return;
    setState(() {
      _trialStartedAt = localStartedAt;
      _membershipStatus = 'trial';
    });
    _next();

    final firebase = _firebase;
    if (firebase != null && firebase.currentUser != null) {
      unawaited(_syncTrialActivation(firebase, preferences));
    }
  }

  Future<void> _syncTrialActivation(
    FirebaseMemberService firebase,
    SharedPreferences preferences,
  ) async {
    try {
      final serverStartedAt = await firebase.activateTrial();
      await preferences.setString(
        'watm_trial_started_at',
        serverStartedAt.toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _trialStartedAt = serverStartedAt;
        _membershipStatus = 'trial';
      });
      await _saveProgress();
    } catch (_) {
      // Keep the local trial active; cloud progress can synchronize later.
    }
  }

  int _singleAnswerIndex(int step) {
    final values = _answers[step];
    if (values == null || values.isEmpty) return 0;
    return values.first;
  }

  String _answerLabel(int step, QuestionData question) {
    final index = _singleAnswerIndex(step);
    if (index < 0 || index >= question.options.length) {
      return question.options.first;
    }
    return question.options[index];
  }

  Future<void> _startAutomaticMatching() async {
    if (_matchingBusy) return;
    final firebase = _firebase;
    if (firebase == null || firebase.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _matchingError = 'سجّل الدخول أولاً حتى نضيفك إلى دائرتك تلقائياً.';
      });
      return;
    }

    setState(() {
      _matchingBusy = true;
      _matchingError = null;
    });
    debugPrint(
      '[_startAutomaticMatching] calling matchCurrentUser age=$_age '
      'ageCode=${ageBandCode(_age)} goalCode=${weightLossBandCode(_weightLossGoal)} '
      'durationCode=${_singleAnswerIndex(8)}',
    );
    try {
      final result = await firebase.matchCurrentUser(
        goalCode: weightLossBandCode(_weightLossGoal),
        durationCode: _singleAnswerIndex(8),
        ageCode: ageBandCode(_age),
        goal: weightLossBandLabel(_weightLossGoal),
        duration: _answerLabel(8, _coreQuestions[1]),
        ageGroup: ageBandLabel(_age),
        interactionTime: _answerLabel(12, _coreQuestions[5]),
        seriousness: _answerLabel(9, _coreQuestions[2]),
        supportStyle: _answerLabel(13, _coreQuestions[6]),
        firstName: _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _matchedGroupId = result.groupId;
        _matchingBusy = false;
      });
      _go(26);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _matchingBusy = false;
        _matchingError =
            'انتهت مهلة الاتصال بقاعدة البيانات. تحقق من الإنترنت ثم اضغط إعادة المحاولة؛ لن تُنشأ عضوية مكررة.';
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _matchingBusy = false;
        _matchingError = error.code == 'permission-denied'
            ? 'قواعد Firestore لا تسمح بالمطابقة بعد. انشر قواعد المطابقة '
                'المرفقة ثم أعد المحاولة.'
                '${_debugMatchingInfoEnabled ? "\n\n[${error.code}] ${error.message}" : ""}'
            : 'تعذرت المطابقة مؤقتاً (${error.code}). تحقق من الاتصال وأعد المحاولة.'
                '${_debugMatchingInfoEnabled ? "\n\n${error.message}" : ""}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matchingBusy = false;
        _matchingError =
            'تعذرت المطابقة مؤقتاً. تحقق من الاتصال وأعد المحاولة.';
      });
    }
  }

  void _retryAutomaticMatching() {
    setState(() {
      _step = 25;
      _matchingRequested = false;
      _matchingBusy = false;
      _matchingError = null;
    });
    _saveProgress();
  }

  Future<void> _restartJourney() async {
    final preferences =
        _preferences ?? await SharedPreferences.getInstance();
    await preferences.remove('watm_mvp_step');
    await preferences.remove('watm_mvp_answers');
    await preferences.remove('watm_phone');
    await preferences.remove('watm_name');
    await preferences.remove('watm_age');
    await preferences.remove('watm_city');
    await preferences.remove('watm_current_weight_kg');
    await preferences.remove('watm_target_weight_kg');
    await preferences.remove('watm_last_check_in');
    await preferences.remove('watm_last_check_in_note');
    await preferences.remove('watm_streak');
    await preferences.remove('watm_encouragements_sent');
    await preferences.remove('watm_trial_started_at');
    await preferences.remove('watm_membership_status');
    await _firebase?.signOut();
    if (!mounted) return;
    setState(() {
      _answers.clear();
      _nameController.clear();
      _ageController.clear();
      _cityController.clear();
      _currentWeightController.clear();
      _targetWeightController.clear();
      _checkInNoteController.clear();
      _streak = 0;
      _trialStartedAt = null;
      _membershipStatus = null;
      _matchingRequested = false;
      _matchingBusy = false;
      _matchingError = null;
      _matchedGroupId = null;
      _authForExistingUser = false;
      _checkInBusy = false;
      _checkInError = null;
      _step = 1;
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _authSubscription?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    _checkInNoteController.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _step = _step < 34 ? _step + 1 : 34);
    _saveProgress();
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
      _saveProgress();
    }
  }

void _go(int step) {
  debugPrint('[_go] BEFORE current=$_step target=$step');

  setState(() {
    if (step < 0) {
      _step = 0;
    } else if (step > 34) {
      _step = 34;
    } else {
      _step = step;
    }
  });

  debugPrint('[_go] AFTER current=$_step');

  _saveProgress();
}

  void _toggleAnswer(int option, {bool multiple = false}) {
    setState(() {
      final values = _answers.putIfAbsent(_step, () => <int>{});
      if (!multiple) values.clear();
      if (!values.add(option)) values.remove(option);
    });
    _saveProgress();
  }

  void _toggleDailyCommitment(int option) {
    setState(() {
      _checkInError = null;
      final values = _answers.putIfAbsent(29, () => <int>{});
      if (option == 3) {
        values
          ..clear()
          ..add(3);
      } else {
        values.remove(3);
        if (!values.add(option)) values.remove(option);
      }
    });
    _saveProgress();
  }

 @override
Widget build(BuildContext context) {
  debugPrint('[BUILD] step=$_step');

  return Scaffold(
      backgroundColor: AppColors.muted,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClipRRect(
            borderRadius: MediaQuery.sizeOf(context).width > 600
                ? BorderRadius.circular(30)
                : BorderRadius.zero,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(key: ValueKey(_step), child: _screen()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _screen() {
    if (_step == 0) return _splash();
    if (_step == 1) return _welcome();
    if (_step == 2) return _howItWorks();
    // Steps 4 and 5 belonged to the removed prototype phone/OTP flow.
    // Restoring an old local value now returns to the verified email account
    // hand-off instead of exposing a fake verification screen.
    if (_step >= 3 && _step <= 5) {
      return FirebaseEmailGate(
        initialCreateAccount: !_authForExistingUser,
        onAuthenticated: _restoreProgress,
        onBack: _back,
        child: _basicInformation(),
      );
    }
    if (_step == 6) return _basicInformation();
    if (_step >= 7 && _step <= 14) {
      return _question(_coreQuestions[_step - 7]);
    }
    if (_step == 15) return _assessment();
    if (_step == 16) return _trialOffer();
    if (_step == 17) return _trialActivated();
    if (_step == 18) return _trialWelcome();
    if (_step >= 19 && _step <= 24) {
      return _question(
        _detailQuestions[_step - 19],
        multiple: _step == 23 || _step == 24,
      );
    }
    if (_step == 25) return _matching();
    if (_step == 26) return _circleReady();
    if (_step == 27) return _meetMembers();
    if (_step == 28) return _memberDashboardOrSignedOut();
    if (_step == 29) return _dailyCheckIn();
    if (_step == 30) return _checkInSuccess();
    // Legacy transient steps used hard-coded demo people and metrics. They are
    // intentionally redirected to the Firebase-backed member dashboard.
    if (_step >= 31 && _step <= 33) return _memberDashboardOrSignedOut();
    return _renewal();
  }

  Widget _splash() {
    return ColoredBox(
      color: AppColors.warmBackground,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.sea, shape: BoxShape.circle),
              child: const Text('W', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 18),
            const Text('WATM', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            const Text('نحن لا نحقق أهدافنا وحدنا…\nبل نحققها معاً.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.earth, fontSize: 16, height: 1.75)),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Text('Powered by WE ARE THE MESSAGE', textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.earth, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return WatmPage(
      eyebrow: 'رحلة خسارة وزن جماعية',
      title: 'لن تخسر الوزن وحدك مرة أخرى.',
      subtitle:
          'WATM يضعك داخل دائرة صغيرة من أشخاص يريدون خسارة مقدار قريب من الوزن وبمدة وإيقاع يومي مشابهين لك.',
      children: [
        _memberVisual(),
      ],
      bottom: Column(
        children: [
          WatmButton(label: 'اطلب الانضمام', onPressed: _next),
          const SizedBox(height: 10),
          WatmButton(
            label: 'لدي حساب',
            onPressed: () {
              setState(() => _authForExistingUser = true);
              _go(3);
            },
            secondary: true,
          ),
          TextButton(onPressed: _next, child: const Text('كيف تعمل العضوية؟')),
        ],
      ),
    );
  }

  Widget _memberVisual() {
    return WatmCard(
      color: AppColors.seaSoft,
      child: SizedBox(
        height: 210,
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Positioned(top: 12, right: 35, child: WatmAvatar(initial: 'س')),
            Positioned(top: 28, left: 34, child: WatmAvatar(initial: 'أ')),
            Positioned(bottom: 18, right: 30, child: WatmAvatar(initial: 'ع')),
            Positioned(bottom: 24, left: 28, child: WatmAvatar(initial: 'م')),
            WatmAvatar(initial: 'و'),
          ],
        ),
      ),
    );
  }

  Widget _howItWorks() {
    return WatmPage(
      onBack: _back,
      eyebrow: 'كيف تعمل العضوية؟',
      title: 'نحدد هدف وزنك، ثم نختار دائرتك.',
      subtitle:
          'المطابقة الدقيقة تجعل أعضاء الدائرة يمرون بتحديات متقاربة ويمكنهم دعم بعضهم بصدق.',
      children: const [
        StepCard(
          number: '1',
          title: 'نقطة البداية',
          body: 'الوزن الحالي والهدف يبقيان خاصين بك.',
        ),
        StepCard(
          number: '2',
          title: 'خطة التزام بسيطة',
          body: 'ثلاثة التزامات يومية يمكن قياسها خلال دقيقة.',
        ),
        StepCard(
          number: '3',
          title: 'مطابقة دقيقة',
          body: 'حتى 7 أعضاء بهدف وزن ومدة ووقت متقارب.',
        ),
      ],
      bottom: WatmButton(
        label: 'ابدأ الطلب',
        onPressed: () {
          setState(() => _authForExistingUser = false);
          _next();
        },
      ),
    );
  }

  Widget _basicInformation() => WatmPage(
        onBack: () => _go(3),
        eyebrow: 'بداية رحلة خسارة الوزن',
        title: 'لنحدد نقطة البداية والهدف',
        subtitle:
            'يظهر اسمك الأول فقط داخل الدائرة، وتبقى أرقام وزنك خاصة بك.',
        children: [
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'الاسم الأول'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ageController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            maxLength: 3,
            decoration: const InputDecoration(
              labelText: 'العمر',
              counterText: '',
              helperText: 'من 13 إلى 100 سنة',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cityController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'المدينة'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _currentWeightController,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'وزنك الحالي',
              suffixText: 'كغم',
              helperText: 'اكتب وزنك الحالي كما هو، بلا حكم أو إحراج.',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _targetWeightController,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'الوزن الذي تريد الوصول إليه',
              suffixText: 'كغم',
              helperText: _weightGoalValid
                  ? 'هدفك: خسارة ${formatWeightKg(_weightLossGoal)} كغم.'
                  : 'يجب أن يكون الهدف أقل من وزنك الحالي.',
            ),
          ),
          const SizedBox(height: 14),
          const WatmCard(
            color: AppColors.seaSoft,
            borderColor: AppColors.sea,
            child: Text(
              'لن نعرض وزنك لأعضاء الدائرة. سيظهر لهم التزامك وتقدّمك فقط.',
              style: TextStyle(color: AppColors.universe, height: 1.6),
            ),
          ),
        ],
        bottom: WatmButton(
          label: 'ابدأ تقييم خسارة الوزن',
          onPressed: _nameController.text.trim().length >= 2 &&
                  _cityController.text.trim().length >= 2 &&
                  _ageValid &&
                  _weightGoalValid
              ? () async {
                  await _saveMemberProfile();
                  if (!mounted) return;
                  // Use an explicit target instead of _next(): this screen
                  // is also shown immediately after signing in, before the
                  // parent's _step has necessarily caught up to 6, so
                  // incrementing from whatever _step currently holds could
                  // land back on the auth gate instead of the questions.
                  _go(7);
                }
              : null,
        ),
      );

  bool get _ageValid {
    final age = int.tryParse(_ageController.text.trim());
    return age != null && age >= 13 && age <= 100;
  }

  int get _age => int.tryParse(_ageController.text.trim()) ?? 13;

  double? get _currentWeightKg =>
      parseWeightKg(_currentWeightController.text);

  double? get _targetWeightKg =>
      parseWeightKg(_targetWeightController.text);

  bool get _weightGoalValid => isValidTargetWeight(
        currentWeight: _currentWeightKg,
        targetWeight: _targetWeightKg,
      );

  double get _weightLossGoal {
    if (!_weightGoalValid) return 0;
    return weightLossGoalKg(
      currentWeight: _currentWeightKg!,
      targetWeight: _targetWeightKg!,
    );
  }

  Widget _question(QuestionData data, {bool multiple = false}) {
    final selected = _answers[_step] ?? <int>{};
    return WatmPage(
      onBack: _back,
      eyebrow: data.eyebrow,
      title: data.title,
      subtitle: data.subtitle,
      children: [
        WatmProgress(value: _questionProgress()),
        const SizedBox(height: 22),
        for (var i = 0; i < data.options.length; i++)
          WatmChoice(
            label: data.options[i],
            selected: selected.contains(i),
            onTap: () => _toggleAnswer(i, multiple: multiple),
          ),
        if (multiple)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('يمكنك اختيار أكثر من إجابة.', style: TextStyle(color: AppColors.earth, fontSize: 12)),
          ),
      ],
      bottom: WatmButton(
        label: _step == 14 ? 'عرض نتيجة التقييم' : 'التالي',
        onPressed: selected.isEmpty ? null : _next,
      ),
    );
  }

  double _questionProgress() {
    if (_step >= 7 && _step <= 14) return (_step - 6) / 8;
    if (_step >= 19 && _step <= 24) return (_step - 18) / 6;
    return 0;
  }

  Widget _assessment() => WatmPage(
        children: [
          const Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.nature,
              child: Icon(Icons.check_rounded, color: AppColors.universe, size: 42),
            ),
          ),
          const SizedBox(height: 20),
          const Text('خطة البداية أصبحت جاهزة', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.55)),
          const SizedBox(height: 8),
          const Text('ستحصل على تجربة كاملة بلا دفع، داخل دائرة خاصة محدودة بـ7 أعضاء متقاربين في الهدف والجدية.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.earth, fontSize: 14, height: 1.6)),
          const SizedBox(height: 18),
          const Center(child: Chip(backgroundColor: AppColors.universe, label: Text('مستوى الجدية: مرتفع', style: TextStyle(color: Colors.white)))),
          const SizedBox(height: 18),
          WatmCard(
            child: Column(
              children: [
                ResultRow(
                  label: 'وزنك الحالي',
                  value: '${formatWeightKg(_currentWeightKg ?? 0)} كغم',
                ),
                ResultRow(
                  label: 'الوزن المستهدف',
                  value: '${formatWeightKg(_targetWeightKg ?? 0)} كغم',
                ),
                ResultRow(
                  label: 'هدف الخسارة',
                  value: '${formatWeightKg(_weightLossGoal)} كغم',
                ),
                ResultRow(
                  label: 'المدة',
                  value: _answerLabel(8, _coreQuestions[1]),
                ),
                ResultRow(
                  label: 'وقت التفاعل',
                  value: _answerLabel(12, _coreQuestions[5]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const WatmCard(
            color: AppColors.natureSoft,
            borderColor: AppColors.nature,
            child: Text('وزنك رقم خاص بك. أعضاء الدائرة يرون التزامك وتقدمك فقط، وليس رقم الميزان.', style: TextStyle(color: AppColors.universe, height: 1.6)),
          ),
        ],
        bottom: Column(
          children: [
            WatmButton(label: 'ابدأ التجربة المجانية', onPressed: _next),
            TextButton(onPressed: () => _go(7), child: const Text('تعديل إجاباتي')),
          ],
        ),
      );

  Widget _trialOffer() => WatmPage(
        onBack: _back,
        eyebrow: 'تم قبول طلبك',
        title: 'جرّب WATM لمدة أسبوع كامل',
        subtitle:
            'ادخل دائرتك واستخدم تسجيل اليوم والتشجيع والمراجعة الأسبوعية لمدة 7 أيام من دون دفع أو إدخال بطاقة.',
        children: const [
          WatmCard(
            color: AppColors.seaSoft,
            borderColor: AppColors.sea,
            child: Column(
              children: [
                ResultRow(label: 'مدة التجربة', value: '7 أيام كاملة'),
                ResultRow(label: 'الدفع الآن', value: 'لا يوجد'),
                ResultRow(label: 'البطاقة المصرفية', value: 'غير مطلوبة'),
                ResultRow(label: 'الوصول', value: 'جميع خصائص العضو'),
              ],
            ),
          ),
          SizedBox(height: 18),
          WatmCard(
            color: AppColors.natureSoft,
            borderColor: AppColors.nature,
            child: Text(
              'لن يتم تجديد أي شيء تلقائياً. في نهاية الأسبوع تختار أنت إن كنت تريد الاستمرار.',
              style: TextStyle(color: AppColors.universe, height: 1.7),
            ),
          ),
        ],
        bottom: WatmButton(
          label: 'ابدأ تجربتي المجانية',
          onPressed: _activateFreeTrial,
        ),
      );

  Widget _trialActivated() => WatmPage(
        children: [
          const SizedBox(height: 36),
          const Center(
            child: CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.nature,
              child: Icon(
                Icons.celebration_rounded,
                size: 48,
                color: AppColors.universe,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'بدأ أسبوعك المجاني',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'لا يوجد دفع ولا بطاقة. سنجهّز ملفك ثم نطابقك مع دائرة تجريبية مناسبة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.earth, height: 1.7),
          ),
          const SizedBox(height: 22),
          WatmCard(
            child: Column(
              children: [
                const ResultRow(label: 'الحالة', value: 'تجربة فعّالة'),
                ResultRow(
                  label: 'الوقت المتبقي',
                  value: '$_trialDaysLeft أيام',
                ),
                const ResultRow(
                  label: 'التجديد التلقائي',
                  value: 'غير مفعّل',
                ),
              ],
            ),
          ),
        ],
        bottom: WatmButton(label: 'متابعة', onPressed: _next),
      );

  Widget _trialWelcome() => WatmPage(
        eyebrow: 'تجربتك المجانية • اليوم الأول',
        title: 'أسبوعك الأول لبناء زخم خسارة الوزن.',
        subtitle:
            'سجّل التزاماتك الثلاثة، شجّع أعضاء دائرتك، واختبر هل يساعدك هذا النظام على الاستمرار.',
        children: const [
          StepCard(
            number: '1',
            title: 'أكمل ملف العضوية',
            body: 'لنحسّن توافقك مع أعضاء الدائرة.',
          ),
          StepCard(
            number: '2',
            title: 'ادخل دائرتك',
            body: 'تعرّف إلى القائدة والأعضاء الحقيقيين.',
          ),
          StepCard(
            number: '3',
            title: 'سجّل التزاماتك',
            body: 'الحركة والطعام والماء خلال أقل من دقيقة.',
          ),
        ],
        bottom: WatmButton(label: 'أكمل ملفي', onPressed: _next),
      );

  Widget _matching() {
    if (!_matchingRequested) {
      _matchingRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == 25) {
          _startAutomaticMatching();
        }
      });
    }
    final error = _matchingError;
    return WatmPage(
      children: [
        const SizedBox(height: 52),
        if (error == null)
          const Center(
            child: SizedBox(
              width: 110,
              height: 110,
              child: CircularProgressIndicator(
                strokeWidth: 9,
                color: AppColors.sea,
                backgroundColor: AppColors.seaSoft,
              ),
            ),
          )
        else
          const Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.seaSoft,
              child: Icon(
                Icons.sync_problem_rounded,
                color: AppColors.seaAccent,
                size: 44,
              ),
            ),
          ),
        const SizedBox(height: 34),
        Text(
          error == null
              ? 'نضيفك إلى دائرتك المناسبة'
              : 'لم تكتمل المطابقة',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          error ??
              'نطابق مقدار الوزن الذي تريد خسارته مع المدة والفئة العمرية، ثم ننشئ دائرة جديدة أو نضمك إلى دائرة متوافقة.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.earth,
            height: 1.7,
          ),
        ),
        if (error == null) ...[
          const SizedBox(height: 24),
          const WatmProgress(value: .65),
          const SizedBox(height: 12),
          const Text(
            'تتم العملية تلقائياً، ولا تحتاج إلى اختيار مجموعة يدوياً.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.earth, fontSize: 12),
          ),
        ],
        if (_debugMatchingInfoEnabled) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              // يُبنى عبر buildCircleMatchingKey نفسها لا بتركيب نص يدوي:
              // النسخة اليدوية السابقة بقيت على الصيغة الرباعية بعد تبسيط
              // المطابقة، فكانت الشاشة تعرض مفتاحاً غير الذي يُكتب فعلاً.
              'وضع الاختبار — مفتاح المطابقة:\n'
              '${buildCircleMatchingKey(
                goalCode: weightLossBandCode(_weightLossGoal),
                durationCode: _singleAnswerIndex(8),
                ageCode: ageBandCode(_age),
              )}\n'
              '(هدف=${weightLossBandLabel(_weightLossGoal)}، '
              'مدة=${_answerLabel(8, _coreQuestions[1])}، '
              'عمر=$_age → فئة ${ageBandLabel(_age)})\n'
              'قارن هذا النص حرفياً بين حسابين — لازم يتطابق تماماً حتى ينضموا لنفس الدائرة.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.earth,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // آخر خطوة اكتملت داخل معاملة المطابقة. تُعرض هنا حتى تكفي لقطة
          // واحدة من الشاشة لتحديد موضع التوقّف، بلا فتح أدوات المطوّر.
          ValueListenableBuilder<List<String>>(
            valueListenable: matchingTrace,
            builder: (context, steps, _) {
              if (steps.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'تتبّع المطابقة (آخر خطوة هي موضع التوقّف):\n'
                  '${steps.join('\n')}',
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.earth,
                    height: 1.5,
                  ),
                ),
              );
            },
          ),
        ],
      ],
      bottom: error == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WatmButton(
                  label: 'إعادة المحاولة',
                  onPressed: _startAutomaticMatching,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _back,
                  child: const Text('العودة إلى السؤال السابق'),
                ),
              ],
            ),
    );
  }

  Widget _circleReady() {
    final groupId = _matchedGroupId;
    if (groupId == null || groupId.isEmpty) {
      return WatmPage(
        title: 'لم نعثر على دائرتك',
        subtitle: 'أعد المطابقة حتى نربط حسابك بالدائرة الصحيحة.',
        children: const [],
        bottom: WatmButton(
          label: 'إعادة المطابقة',
          onPressed: _retryAutomaticMatching,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.doc(
        FirebaseFirestore.instance.collection('groups').doc(groupId),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return WatmPage(
            title: 'تعذر تحميل دائرتك',
            subtitle: 'تحقق من الاتصال ثم أعد المحاولة.',
            children: const [],
            bottom: WatmButton(
              label: 'إعادة المطابقة',
              onPressed: _retryAutomaticMatching,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const WatmPage(
            title: 'نجهّز دائرتك',
            children: [
              SizedBox(height: 80),
              Center(child: CircularProgressIndicator(color: AppColors.sea)),
            ],
          );
        }
        final data = snapshot.data?.data();
        if (data == null) {
          return WatmPage(
            title: 'تعذر تحميل دائرتك',
            subtitle: 'تحقق من الاتصال ثم أعد المحاولة.',
            children: const [],
            bottom: WatmButton(
              label: 'إعادة المطابقة',
              onPressed: _retryAutomaticMatching,
            ),
          );
        }
        var maxMembers = parseIntOrZero(data['maxMembers']);
        if (maxMembers < 1) maxMembers = kCircleMaxMembers;
        final status = firstNonEmptyString(
          data,
          ['status'],
          fallback: 'forming',
        );
        final storedGroupName = firstNonEmptyString(
          data,
          ['name', 'title'],
          fallback: 'دائرتك',
        );
        final groupName = buildCircleDisplayName(
          goal: firstNonEmptyString(data, ['goal']),
          duration: firstNonEmptyString(data, ['duration']),
          ageGroup: firstNonEmptyString(data, ['ageGroup']),
          fallback: storedGroupName,
        );
        final statusText = status == 'full'
            ? 'اكتملت الدائرة'
            : status == 'active'
                ? 'بدأ نشاط الدائرة'
                : 'قيد التكوين — يبدأ النشاط عند $kCircleMinimumStartMembers أعضاء';
        // Member count is read from the real `members` subcollection (the
        // same source `MembersPanel` and `_meetMembers` use) instead of the
        // group document's `memberCount` field. That field is only a
        // denormalized counter written at join time; some accounts have a
        // `groupId` pointing at a group whose member document is missing or
        // out of sync, which made this screen show a different number than
        // the circle screen shown right after it.
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LiveQuery.query(
            'members:$groupId',
            FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('members')
                .limit(kCircleMaxMembers),
          ),
          builder: (context, membersSnapshot) {
            final memberDocs = membersSnapshot.data?.docs;
            final memberCount =
                memberDocs != null && memberDocs.isNotEmpty
                    ? memberDocs.length
                    : 1;
            return WatmPage(
          children: [
            const SizedBox(height: 36),
            const Center(
              child: CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.nature,
                child: Icon(
                  Icons.groups_rounded,
                  size: 50,
                  color: AppColors.universe,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              status == 'forming'
                  ? 'تم إنشاء دائرتك تلقائياً'
                  : 'دائرتك أصبحت جاهزة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.sea,
                fontSize: 12,
              ),
            ),
            Text(
              groupName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            WatmCard(
              child: Column(
                children: [
                  ResultRow(
                    label: 'الأعضاء',
                    value: '$memberCount من $maxMembers',
                  ),
                  ResultRow(label: 'الحالة', value: statusText),
                  ResultRow(
                    label: 'الهدف',
                    value: firstNonEmptyString(
                      data,
                      ['goal'],
                      fallback: 'هدف مشترك',
                    ),
                  ),
                  ResultRow(
                    label: 'المدة',
                    value: firstNonEmptyString(
                      data,
                      ['duration'],
                      fallback: 'مرنة',
                    ),
                  ),
                  ResultRow(
                    label: 'الفئة العمرية',
                    value: firstNonEmptyString(
                      data,
                      ['ageGroup'],
                      fallback: 'متقاربة',
                    ),
                  ),
                  if (_debugMatchingInfoEnabled)
                    ResultRow(
                      label: 'مفتاح المطابقة (اختبار)',
                      value: firstNonEmptyString(
                        data,
                        ['matchingKey'],
                        fallback: '—',
                      ),
                    ),
                ],
              ),
            ),
          ],
          bottom: WatmButton(
            label: 'تعرف على أعضاء دائرتي',
            onPressed: _next,
          ),
        );
          },
        );
      },
    );
  }

  Widget _meetMembers() {
    final groupId = _matchedGroupId;
    if (groupId == null || groupId.isEmpty) {
      return WatmPage(
        title: 'لم نعثر على أعضاء الدائرة',
        children: const [],
        bottom: WatmButton(
          label: 'إعادة المطابقة',
          onPressed: _retryAutomaticMatching,
        ),
      );
    }
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
          return WatmPage(
            title: 'تعذر تحميل أعضاء الدائرة',
            subtitle: 'تحقق من الإنترنت، ثم حاول مرة أخرى.',
            children: const [
              SizedBox(height: 42),
              Center(
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: AppColors.sea,
                ),
              ),
            ],
            bottom: WatmButton(
              label: 'العودة إلى المطابقة',
              onPressed: _retryAutomaticMatching,
            ),
          );
        }
        final documents = snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final members = documents.map((document) {
          final data = document.data();
          final name = firstNonEmptyString(
            data,
            ['firstName', 'name', 'displayName'],
            fallback: 'عضو',
          );
          final streak = parseIntOrZero(data['personalStreak']);
          return MemberData(
            name.characters.first,
            name,
            streak > 0
                ? '$streak أيام التزام متتالية'
                : 'عضو جديد في الدائرة',
            firstNonEmptyString(
              data,
              ['goal'],
              fallback: 'بدأ رحلة جديدة مع الدائرة.',
            ),
          );
        }).toList();
        return WatmPage(
          eyebrow: 'دائرتك التلقائية',
          title: 'تعرف على أعضاء دائرتك',
          subtitle:
              'يُضاف الأعضاء المتوافقون تلقائياً، حتى يكتمل العدد عند 7.',
          children: [
            if (!snapshot.hasData)
              const Center(
                child: CircularProgressIndicator(color: AppColors.sea),
              )
            else if (members.isEmpty)
              const WatmCard(
                child: Text(
                  'لم يصل أعضاء الدائرة بعد. سنضيفهم تلقائياً عند انضمامهم.',
                  style: TextStyle(color: AppColors.earth, height: 1.7),
                ),
              )
            else
              for (final member in members) ...[
                MemberCard(member: member),
                const SizedBox(height: 12),
              ],
          ],
          bottom: WatmButton(
            label: 'دخول الشاشة الرئيسية',
            onPressed: _next,
          ),
        );
      },
    );
  }

  Widget _memberDashboardOrSignedOut() {
    final dashboard = FirebaseMemberDashboard(onCheckIn: () => _go(29));
    if (_firebase?.currentUser != null) return dashboard;
    return FirebaseEmailGate(
      initialCreateAccount: false,
      onAuthenticated: _restoreProgress,
      onBack: () => _go(1),
      child: dashboard,
    );
  }

  Widget _dailyCheckIn() => WatmPage(
        onBack: () => _go(28),
        eyebrow: 'تسجيل اليوم • اليوم $_trialDay من 7',
        title: 'ماذا أنجزت لخسارة الوزن اليوم؟',
        subtitle: 'اختر ما أنجزته فعلاً. لا نحتاج يوماً مثالياً حتى نستمر.',
        children: [
          WatmChoice(
            label: 'تحركت أو مشيت اليوم',
            selected: _answers[_step]?.contains(0) ?? false,
            onTap: () => _toggleDailyCommitment(0),
          ),
          WatmChoice(
            label: 'التزمت بخطة وجباتي',
            selected: _answers[_step]?.contains(1) ?? false,
            onTap: () => _toggleDailyCommitment(1),
          ),
          WatmChoice(
            label: 'شربت كمية الماء التي حددتها',
            selected: _answers[_step]?.contains(2) ?? false,
            onTap: () => _toggleDailyCommitment(2),
          ),
          WatmChoice(
            label: 'كان يوماً صعباً، لكنني سجلت وسأعود غداً',
            selected: _answers[_step]?.contains(3) ?? false,
            onTap: () => _toggleDailyCommitment(3),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _checkInNoteController,
            onChanged: (_) {
              if (_checkInError != null) {
                setState(() => _checkInError = null);
              }
            },
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظة خاصة بك (اختيارية)',
            ),
          ),
          if (_checkInError != null) ...[
            const SizedBox(height: 12),
            WatmErrorCard(_checkInError!, height: 1.5),
          ],
        ],
      bottom: WatmButton(
        label: _checkInBusy ? 'جارٍ حفظ تسجيلك…' : 'تأكيد تسجيل اليوم',
        onPressed: !_checkInBusy && (_answers[_step]?.isNotEmpty ?? false)
            ? _completeCheckIn
            : null,
      ),
    );

  Widget _checkInSuccess() => WatmPage(
        children: [
          const SizedBox(height: 50),
          const Center(child: CircleAvatar(radius: 48, backgroundColor: AppColors.nature, child: Icon(Icons.done_all_rounded, size: 46, color: AppColors.universe))),
          const SizedBox(height: 26),
          const Text('تم تسجيل حضورك اليوم', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            dailyCommitmentScore(_answers[29] ?? <int>{}) == 0
                ? 'حتى في اليوم الصعب، تسجيلك وعودتك غداً جزء من النجاح.'
                : 'أنجزت ${dailyCommitmentScore(_answers[29] ?? <int>{})} من 3 التزامات اليوم. الاستمرار أهم من الكمال.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.earth, height: 1.7),
          ),
          const SizedBox(height: 24),
          WatmCard(
            color: AppColors.natureSoft,
            borderColor: AppColors.nature,
            child: Center(
              child: Text(
                '🔥 $_streak ${_streak == 1 ? 'يوم متتالٍ' : 'أيام متتالية'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: WatmButton(
          label: 'العودة إلى الرئيسية',
          onPressed: _finishCheckInFlow,
        ),
      );

  void _finishCheckInFlow() {
    setState(() {
      _step = 28;
      _answers.remove(29);
      _checkInNoteController.clear();
      _checkInError = null;
      _checkInBusy = false;
    });
    _saveProgress();
  }

  Widget _renewal() {
    final selected = _answers[_step];
    const plans = [
      (
        '٢١ يوماً',
        'بداية مركزة لبناء الزخم',
        'متابعة يومية • مراجعتان',
        '9,999 د.ع',
      ),
      (
        '٣ أشهر',
        'التغيير الحقيقي المستدام',
        'دائرة مستقرة • مراجعة أسبوعية',
        '24,999 د.ع',
      ),
      (
        'عضوية سنوية',
        'لمن اختبر النظام ويريد الاستمرار',
        'دورات متتابعة • سجل طويل',
        '79,999 د.ع',
      ),
    ];
    return WatmPage(
      eyebrow: _trialDaysLeft == 0
          ? 'انتهى أسبوعك المجاني'
          : 'الاستمرار بعد التجربة',
      title: 'هل تريد الاحتفاظ بمكانك داخل الدائرة؟',
      subtitle:
          'لن يتم خصم أي مبلغ تلقائياً. اختر العضوية المناسبة فقط إذا وجدت أن WATM يساعدك فعلاً على الاستمرار.',
      children: [
        WatmCard(
          color: AppColors.natureSoft,
          borderColor: AppColors.nature,
          child: Text(
            _trialDaysLeft == 0
                ? 'اكتملت أيام التجربة السبعة. بياناتك محفوظة، ويعود الوصول الكامل بعد اختيار العضوية.'
                : 'بقي $_trialDaysLeft أيام في تجربتك. يمكنك الاستمرار في التجربة قبل اتخاذ القرار.',
            style: const TextStyle(
              color: AppColors.universe,
              height: 1.7,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < plans.length; i++) ...[
          PlanCard(
            title: plans[i].$1,
            headline: plans[i].$2,
            details: plans[i].$3,
            price: plans[i].$4,
            recommended: i == 1,
            selected: selected?.contains(i) ?? false,
            onTap: () => _toggleAnswer(i),
          ),
          const SizedBox(height: 14),
        ],
      ],
      bottom: Column(
        children: [
          WatmButton(
            label: 'تأكيد اختيار العضوية',
            onPressed: (selected?.isNotEmpty ?? false)
                ? _showMembershipCheckout
                : null,
          ),
          if (_trialDaysLeft > 0)
            TextButton(
              onPressed: () => _go(28),
              child: Text('أكمل تجربتي ($_trialDaysLeft أيام متبقية)'),
            ),
          TextButton(
            onPressed: _restartJourney,
            child: const Text('إعادة تجربة النموذج من البداية'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMembershipCheckout() async {
    const names = ['عضوية 21 يوماً', 'عضوية 3 أشهر', 'العضوية السنوية'];
    final selectedIndex = _answers[34]?.first ?? 1;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تم اختيار العضوية'),
        content: Text(
          'اخترت ${names[selectedIndex]}. الدفع الإلكتروني غير متاح في هذه النسخة التجريبية، ولن يتم خصم أي مبلغ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
