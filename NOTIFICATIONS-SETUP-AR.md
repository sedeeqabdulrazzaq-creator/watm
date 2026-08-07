# إعداد منبّهات الهاتف

ميزة الجدول تعمل على Chrome ما دام التطبيق مفتوحاً. وقد تم تطبيق إعدادات
الإشعارات الأصلية التالية داخل المشروع على Android وiOS، لذلك لا تعدّلها أو
تستبدل ملفات المنصات بأمر `flutter create .` عند كل تشغيل.

## Android

الإذن التالي موجود قبل application في android/app/src/main/AndroidManifest.xml:

~~~xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
~~~

والمستقبلات التالية موجودة داخل application:

~~~xml
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
~~~

كما أن desugaring مفعّل داخل android/app/build.gradle.kts:

~~~kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
~~~

## iOS

تمت إضافة الاستيراد التالي إلى ios/Runner/AppDelegate.swift:

~~~swift
import UserNotifications
~~~

وتم ضبط delegate داخل didFinishLaunchingWithOptions:

~~~swift
UNUserNotificationCenter.current().delegate =
    self as? UNUserNotificationCenterDelegate
~~~

إذن الإشعارات يُطلب من المستخدم تلقائياً عندما يفعّل أول منبّه من تبويب
«جدولي».

## اختبار Android قبل التسليم

1. أضف موعداً بعد خمس دقائق وفعّل التذكير.
2. أغلق التطبيق تماماً وانتظر وصول الإشعار.
3. أعد تشغيل الهاتف واختبر موعداً يومياً جديداً.
4. عطّل التذكير من التطبيق وتأكد أن الإشعار لا يصل.

على Chrome يجب إبقاء الصفحة مفتوحة، لأن تنبيه الويب في هذه النسخة يعتمد على
المتصفح وليس خدمة دفع خلفية.
