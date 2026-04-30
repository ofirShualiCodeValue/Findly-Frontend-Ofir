import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash.dart';
import 'store/auth_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required for any DateFormat(... 'he') call — without this, Hebrew locale
  // data is missing and DateFormat throws "Unexpected null value".
  await initializeDateFormatting('he', null);
  await authStore.init();
  runApp(const FindlyApp());
}

class FindlyApp extends StatelessWidget {
  const FindlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Findly',
      debugShowCheckedModeBanner: false,
      theme: buildFindlyTheme(),
      locale: const Locale('he'),
      supportedLocales: const [Locale('he'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
