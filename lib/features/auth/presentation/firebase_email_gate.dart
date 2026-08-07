import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/firebase_member_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/watm_components.dart';

class FirebaseEmailGate extends StatefulWidget {
  const FirebaseEmailGate({
    required this.child,
    this.initialCreateAccount = true,
    this.onAuthenticated,
    this.onBack,
    super.key,
  });

  final Widget child;
  final bool initialCreateAccount;
  final Future<void> Function()? onAuthenticated;
  final VoidCallback? onBack;

  @override
  State<FirebaseEmailGate> createState() => _FirebaseEmailGateState();
}

class _FirebaseEmailGateState extends State<FirebaseEmailGate> {
  static const _journeyPreferenceKeys = <String>[
    'watm_mvp_step',
    'watm_mvp_answers',
    'watm_phone',
    'watm_name',
    'watm_age',
    'watm_city',
    'watm_current_weight_kg',
    'watm_target_weight_kg',
    'watm_last_check_in',
    'watm_last_check_in_note',
    'watm_streak',
    'watm_encouragements_sent',
    'watm_trial_started_at',
    'watm_membership_status',
  ];

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  FirebaseMemberService? _service;
  late bool _createAccount;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _createAccount = widget.initialCreateAccount;
    if (FirebaseMemberService.isAvailable) {
      _service = FirebaseMemberService();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      late UserCredential credential;
      if (_createAccount) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      final user = credential.user;
      if (user == null) {
        throw StateError('لم يكتمل تسجيل الدخول.');
      }
      await _prepareLocalJourney(user.uid);
      await service.ensureUserDocument();
      final preferences = await SharedPreferences.getInstance();
      if ((preferences.getInt('watm_mvp_step') ?? 0) <= 5) {
        await preferences.setInt('watm_mvp_step', 6);
      }
      await widget.onAuthenticated?.call();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'اكتب بريدك الإلكتروني أولاً لإرسال رابط الاستعادة.';
        _message = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _message =
            'أرسلنا رابط استعادة كلمة المرور إلى بريدك. تحقق أيضاً من مجلد الرسائل غير المرغوب فيها.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareLocalJourney(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final previousUserId = preferences.getString('watm_last_user_id');
    if (previousUserId == userId) return;
    for (final key in _journeyPreferenceKeys) {
      await preferences.remove(key);
    }
    await preferences.setString('watm_last_user_id', userId);
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'عنوان البريد الإلكتروني غير صحيح.';
        case 'weak-password':
          return 'استخدم كلمة مرور من 6 أحرف على الأقل.';
        case 'email-already-in-use':
          return 'يوجد حساب بهذا البريد. اختر «لدي حساب» ثم سجّل الدخول.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        case 'too-many-requests':
          return 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.';
      }
    }
    return 'تعذر إكمال العملية. تحقق من الإنترنت وحاول مجدداً.';
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) return widget.child;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: service.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return KeyedSubtree(
            key: ValueKey(user.uid),
            child: widget.child,
          );
        }
        return _buildAuthScreen();
      },
    );
  }

  Widget _buildAuthScreen() {
    final emailValid = _emailController.text.contains('@');
    final passwordValid = _passwordController.text.length >= 6;

    return Scaffold(
      backgroundColor: AppColors.muted,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: WatmPage(
            onBack: widget.onBack,
            eyebrow: 'تجربة WATM المجانية',
            title: _createAccount ? 'أنشئ حسابك بالبريد' : 'مرحباً بعودتك',
            subtitle: _createAccount
                ? 'ابدأ تجربتك لمدة 7 أيام بلا دفع أو بطاقة.'
                : 'سجّل الدخول للعودة إلى تجربتك وبياناتك المحفوظة.',
            children: [
              TextField(
                controller: _emailController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'name@example.com',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                onChanged: (_) => setState(() {}),
                obscureText: !_showPassword,
                textDirection: TextDirection.ltr,
                autofillHints: _createAccount
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  helperText: '6 أحرف على الأقل',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                WatmErrorCard(_error!, height: 1.5),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                WatmCard(
                  color: AppColors.natureSoft,
                  borderColor: AppColors.nature,
                  child: Text(
                    _message!,
                    style: const TextStyle(
                      color: AppColors.universe,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const WatmCard(
                color: AppColors.natureSoft,
                borderColor: AppColors.nature,
                child: Text(
                  'لا يوجد خصم أو تجديد تلقائي. بعد اليوم السابع تختار أنت إن كنت تريد الاستمرار.',
                  style: TextStyle(color: AppColors.universe, height: 1.6),
                ),
              ),
            ],
            bottom: Column(
              children: [
                WatmButton(
                  label: _busy
                      ? 'جارٍ المتابعة…'
                      : _createAccount
                          ? 'إنشاء الحساب وبدء الطلب'
                          : 'تسجيل الدخول',
                  onPressed: !_busy && emailValid && passwordValid
                      ? _submit
                      : null,
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _createAccount = !_createAccount;
                            _error = null;
                            _message = null;
                          }),
                  child: Text(
                    _createAccount
                        ? 'لدي حساب بالفعل'
                        : 'إنشاء حساب جديد',
                  ),
                ),
                if (!_createAccount)
                  TextButton(
                    onPressed: _busy ? null : _sendPasswordReset,
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
