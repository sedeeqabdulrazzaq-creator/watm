import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/mvp/presentation/mvp_flow.dart';

class WatmApp extends StatelessWidget {
  const WatmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WATM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      // Let visitors understand WATM before asking them to create an account.
      // Authentication is requested inside the journey, immediately before
      // private profile data is collected.
      home: const MvpFlow(),
    );
  }
}
