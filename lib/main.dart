import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/services/firebase_member_service.dart';
import 'core/services/reminder_service.dart';
import 'core/utils/live_query.dart';
import 'firebase_options.dart';

/// Runs in a separate isolate for messages that arrive while the app is
/// backgrounded or killed. FCM already shows a system notification on its
/// own for the `notification` payload our scripts/send-circle-notifications.js
/// worker sends — nothing else to do — but some platforms only deliver
/// background messages at all when a handler is registered, so this must
/// exist even as a no-op. The isolate starts fresh, so Firebase needs its
/// own initializeApp call here.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Opt-in only, off by default. Run with:
///   flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
/// (or use start-dev.ps1 -Emulator) to point the app at the local Firebase
/// emulators — see start-emulators.ps1 — instead of production. Test
/// sign-ups, joins, and deletions during development then never touch real
/// data, so cleaning up after a test session is just restarting the
/// emulators instead of deleting anything from the Firebase console.
const bool _useFirebaseEmulator =
    bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (_useFirebaseEmulator) {
    // 127.0.0.1 وليس localhost — مقصود.
    //
    // محاكيات Firebase تستمع على IPv4 فقط، بينما يحلّ المتصفح على ويندوز
    // اسم localhost إلى ::1 (IPv6) أولاً. النتيجة اتصال لا يصل أبداً:
    // تدخل Firestore وضع «غير متصل» فتصطف الكتابات محلياً، ولا تُرجع
    // set() ولا runTransaction أي نتيجة ولا خطأ — تعليق صامت تماماً،
    // بلا أي سطر رفض في سجل المحاكي.
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }

  // Crashlytics has no Flutter Web implementation at all — calling
  // FirebaseCrashlytics.instance there throws, so every call here must stay
  // behind this guard rather than relying on setCrashlyticsCollectionEnabled
  // to make it a no-op.
  if (!kIsWeb) {
    // Debug runs (this machine, emulators, `flutter run`) never have
    // anything to do with real users, so keep them out of the production
    // Crashlytics dashboard — only release builds report.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // مهلة حتى لا يمنع إضافة معطّلة ظهور أول إطار.
  await reminderService
      .initialize()
      .timeout(const Duration(seconds: 3), onTimeout: () {});

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    // A token can rotate at any time (reinstall, restore, OS-level
    // refresh) — without this listener, scripts/send-circle-notifications.js
    // would keep pushing to a dead token until the user's next sign-in.
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(FirebaseMemberService().syncPushTokenIfAuthorized());
    });
  }

  // مستمعو Firestore المخزّنون يخصّون حساباً بعينه. عند تبديل الحساب
  // تصبح قواعد الأمان ترفضهم، فيجب إسقاطهم لا إبقاؤهم يدورون.
  String? signedInUid;
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user?.uid == signedInUid) return;
    signedInUid = user?.uid;
    LiveQuery.reset();
    if (user != null) {
      unawaited(FirebaseMemberService().syncPushTokenIfAuthorized());
    }
  });

  runApp(const WatmApp());
}
