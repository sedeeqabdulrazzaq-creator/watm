import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/firebase_member_service.dart';
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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب نهائياً'),
        content: const Text(
          'سيُحذف حسابك وكل بياناتك — تقدمك، تسجيلاتك اليومية، وجدولك — نهائياً '
          'ولا يمكن التراجع عن ذلك. ستُزال أيضاً من دائرتك الحالية. '
          'هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('متابعة الحذف'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = firstNonEmptyString(profile, const ['city'], fallback: 'غير محددة');
    // Membership/trial flags are ignored in the free build.
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
              ProfileRow(label: 'حالة العضوية', value: 'الوصول مجاني دائمًا'),

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
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmDeleteAccount(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            icon: const Icon(Icons.delete_forever_outlined, size: 19),
            label: const Text('حذف الحساب نهائياً'),
          ),
        ),
      ],
    );
  }
}

/// Re-authenticates with the account's password, purges the user's
/// Firestore data, then deletes the Firebase Auth user.
///
/// `User.delete()` requires a "recent" sign-in — it throws
/// `requires-recent-login` otherwise — so we always reauthenticate first
/// instead of trying `delete()` and only falling back on that error; it
/// keeps this one dialog handling the whole flow instead of two.
///
/// The Firestore purge (`FirebaseMemberService.deleteAccountData`) has to
/// run here, before `delete()`, and not in a Cloud Functions trigger like
/// `cleanupUserOnDelete` in `functions/index.js`: that function needs the
/// Blaze plan, which this project isn't on. Doing it client-side means it
/// must run while the user can still satisfy `isOwner` security-rule
/// checks — once `delete()` succeeds, the account can never sign in again
/// to clean up anything left behind.
class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() => _error = 'تعذر التحقق من الحساب. أعد تسجيل الدخول وحاول مجدداً.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await FirebaseMemberService().deleteAccountData();
      await user.delete();
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'wrong-password' ||
          'invalid-credential' =>
            'كلمة المرور غير صحيحة.',
          'too-many-requests' => 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.',
          'network-request-failed' =>
            'تعذّر الاتصال بالإنترنت. تحقق من اتصالك وحاول مجدداً.',
          _ => 'تعذر حذف الحساب (${error.code}). حاول مجدداً.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حذف الحساب. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد كلمة المرور'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('لحماية حسابك، أدخل كلمة المرور لإتمام الحذف نهائياً.'),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            autofocus: true,
            obscureText: !_showPassword,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: !_busy && _passwordController.text.isNotEmpty
              ? _submit
              : null,
          child: Text(_busy ? 'جارٍ الحذف…' : 'حذف نهائياً'),
        ),
      ],
    );
  }
}
