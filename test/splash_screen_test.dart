import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watm_app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash screen shows the WATM identity', (tester) async {
    await tester.pumpWidget(const WatmApp());

    expect(find.text('WATM'), findsOneWidget);
    expect(find.textContaining('نحن لا نحقق أهدافنا وحدنا'), findsOneWidget);
    expect(find.text('Powered by WE ARE THE MESSAGE'), findsOneWidget);
  });

  testWidgets('Splash continues to the membership welcome screen', (tester) async {
    await tester.pumpWidget(const WatmApp());

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('لن تخسر الوزن وحدك مرة أخرى.'), findsOneWidget);
    expect(find.text('اطلب الانضمام'), findsOneWidget);
    expect(find.text('لدي حساب'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsNothing);
  });
}
