import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/services/reminder_service.dart';
import 'core/utils/live_query.dart';
import 'firebase_options.dart';

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
  // مهلة حتى لا يمنع إضافة معطّلة ظهور أول إطار.
  await reminderService
      .initialize()
      .timeout(const Duration(seconds: 3), onTimeout: () {});

  // مستمعو Firestore المخزّنون يخصّون حساباً بعينه. عند تبديل الحساب
  // تصبح قواعد الأمان ترفضهم، فيجب إسقاطهم لا إبقاؤهم يدورون.
  String? signedInUid;
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user?.uid == signedInUid) return;
    signedInUid = user?.uid;
    LiveQuery.reset();
  });

  runApp(const WatmApp());
}
