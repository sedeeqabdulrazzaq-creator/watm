# WATM Flutter

نسخة MVP من WATM لخسارة الوزن عبر دوائر التزام صغيرة، مبنية بـFlutter.

## ما تم تنفيذه

- رحلة من 35 شاشة تبدأ بـSplash وتنتهي بالتجديد.
- رحلة مخصصة لخسارة الوزن تبدأ بالوزن الحالي والوزن المستهدف مع خصوصية كاملة.
- 8 أسئلة للمطابقة و6 مجموعات تفصيلية لبناء أسلوب الدعم والالتزامات.
- تجربة كاملة لمدة 7 أيام بلا دفع أو بطاقة، ثم شاشة اختيار العضوية.
- مطابقة تلقائية حسب مقدار خسارة الوزن والمدة ووقت التفاعل عبر Firestore.
- تسجيل يومي لثلاثة التزامات: الحركة وخطة الطعام والماء.
- الشاشة الرئيسية والتشجيع وتتبع الالتزامات والمراجعة الأسبوعية.
- جدول يومي وأسبوعي بأوقات قابلة للتعديل وتذكيرات اختيارية.
- RTL كامل، تمرير للشاشات الطويلة، واستجابة للهواتف القصيرة.
- حفظ مرحلة الرحلة والإجابات محلياً عند تحديث الصفحة أو إغلاقها.

الدفع فقط ما زال محاكاة واجهة. المطابقة مرتبطة فعلياً بـFirestore، ولا يوجد
تجديد تلقائي في النسخة التجريبية.

## تفعيل قواعد Firestore

استخدم ملف `firestore.rules` كاملاً باعتباره المصدر الوحيد للقواعد، ثم نفّذ
Publish من Firebase Console. لا تستخدم المقاطع القديمة المنفصلة. توجد خطوات
النشر والحماية في `FIRESTORE-RULES-SETUP-AR.md`، وإعداد إشعارات الهاتف في
`NOTIFICATIONS-SETUP-AR.md`.

## التشغيل في Antigravity على Windows

افتح PowerShell داخل هذا المجلد ونفّذ:

```powershell
flutter create . --platforms=android,ios,web
flutter pub get
flutter run -d chrome
```

أو شغّل ملف الإعداد الجاهز:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-watm.ps1
```

بعد ظهور التطبيق افتح المجلد نفسه في Antigravity.

## المصدر البصري

- Figma file: https://www.figma.com/design/fYbsRKeL0dFEkeaFRf4KlW
- MVP page node: `155:2`
- Flutter flow: `lib/features/mvp/presentation/mvp_flow.dart`

## الهوية الرسمية

- Sea: `#5FA9D3`
- Nature: `#D7DB62`
- Sky: `#A8AD32`
- Earth: `#75644A`
- Universe: `#101820`
- Warm background: `#FBFAF6`
