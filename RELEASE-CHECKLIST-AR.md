# قائمة تجهيز النشر — WATM

## ما طُبِّق فعلاً في هذه النسخة

| التغيير | الملف |
|---|---|
| `namespace` + `applicationId` → `com.watm.app` | `android/app/build.gradle.kts` |
| إعداد توقيع إصدار يقرأ من `key.properties` | `android/app/build.gradle.kts` |
| نقل حزمة Kotlin من `com/example/watm_app` إلى `com/watm/app` | `android/app/src/main/kotlin/com/watm/app/MainActivity.kt` |
| صلاحية `POST_NOTIFICATIONS` | `android/app/src/main/AndroidManifest.xml` |
| `PRODUCT_BUNDLE_IDENTIFIER` → `com.watm.app` (6 مواضع) | `ios/Runner.xcodeproj/project.pbxproj` |
| `iosBundleId` + تنبيه إعادة التوليد | `lib/firebase_options.dart` |
| حماية مفاتيح التوقيع | `.gitignore` |
| نموذج مفاتيح | `android/key.properties.example` |

## ما يتطلّب حسابك أنت

### 1. إنشاء مفتاح التوقيع

```powershell
keytool -genkey -v -keystore C:\keys\watm-release.jks -storetype JKS `
        -keyalg RSA -keysize 2048 -validity 10000 -alias watm
```

ثم انسخ `android/key.properties.example` إلى `android/key.properties` واملأه.

احتفظ بنسخة احتياطية من ملف `.jks` وكلمتَي المرور في مكان آمن **خارج المشروع**.
فقدانه = عجز دائم عن تحديث التطبيق. فعّل **Play App Signing** عند أول رفع
حتى تستطيع جوجل مساعدتك في استرجاع مفتاح الرفع لو ضاع.

### 2. تسجيل التطبيقين في Firebase

معرّف الحزمة غير قابل للتعديل في تطبيق Firebase مسجَّل، لذلك:

1. Firebase Console ← إعدادات المشروع ← **أضف تطبيق Android** بحزمة `com.watm.app`
2. كرّر مع **تطبيق iOS** بنفس المعرّف
3. أعد توليد الإعدادات:
   ```powershell
   flutterfire configure --project=watm-429c3
   ```
4. بعد التأكد من عمل كل شيء، احذف تطبيقَي `com.example.*` القديمين

بيانات المستخدمين و Firestore مرتبطة بالمشروع لا بالتطبيق — لن يضيع شيء.

### 3. التنظيف والبناء

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

### 4. التحقق من التوقيع

```powershell
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

إذا ظهر `CN=Android Debug` فالمفتاح لم يُقرأ — راجع مسار `storeFile` في
`key.properties` (الشرطة المائلة العكسية مضاعفة في Windows).

### 5. اختبار الإشعارات

على جهاز حقيقي بنظام **Android 13 أو أحدث**: افتح «جدولي» وفعّل تذكيراً.
يجب أن يظهر حوار طلب صلاحية الإشعارات. إن لم يظهر فالبناء قديم — أعد
`flutter clean`.

### 6. قبل كل رفعة لاحقة

زد الرقم بعد `+` في `pubspec.yaml` (`version: 0.1.2+3` → `+4`). هو
`versionCode`، ويرفض Google Play أي ملف لا يحمل رقماً أعلى من السابق.

---

## معلّق بعد هذه المرحلة

- **البند ②** — التأخير: مهلة على `loadProfile`، تثبيت تدفقات Firestore،
  تحديد `limit` على استعلامات `checkIns`، تضمين الخطوط محلياً.
- **البند ③** — نقل المطابقة إلى Cloud Function بدل معاملة العميل.
- **البند ④** — دالة الهاش في اسم الدائرة، والمنطقة الزمنية المثبّتة على بغداد.
