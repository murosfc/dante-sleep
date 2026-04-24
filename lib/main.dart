import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_strings.dart';
import 'providers/app_provider.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService().initialize();
  
  final provider = AppProvider();
  await provider.loadData();
  runApp(MyApp(provider: provider));
}

class MyApp extends StatelessWidget {
  final AppProvider provider;

  const MyApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final bool isDay = provider.isDay;
          final ColorScheme colorScheme = isDay
              ? const ColorScheme.light(
                  primary: Color(0xFF2A6CE8),
                  secondary: Color(0xFF5FA7FF),
                  surface: Color(0xFFF4F8FF),
                  onSurface: Color(0xFF14223A),
                )
              : const ColorScheme.dark(
                  primary: Color(0xFF3A235C),
                  secondary: Color(0xFF5B3A88),
                  surface: Color(0xFF130A1E),
                  onSurface: Color(0xFFF2ECFF),
                );

          return MaterialApp(
            title: provider.locale.languageCode == 'pt'
                ? AppStringsPortuguese.appTitle
                : AppStrings.appTitle,
            theme: ThemeData(
              useMaterial3: true,
              brightness: isDay ? Brightness.light : Brightness.dark,
              colorScheme: colorScheme,
              scaffoldBackgroundColor: isDay
                  ? const Color(0xFFEAF2FF)
                  : const Color(0xFF0B0612),
              appBarTheme: AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: isDay
                    ? const Color(0xFF2A6CE8)
                    : const Color(0xFF1A0F2A),
                foregroundColor: isDay
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFFF8F3FF),
                titleTextStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 8,
                shadowColor: isDay
                    ? const Color(0x1F1E3A7A)
                    : const Color(0x4D000000),
                color: isDay ? const Color(0xFFFFFFFF) : const Color(0xFF1A1226),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              dividerTheme: DividerThemeData(
                color: isDay
                    ? const Color(0x663C6BC8)
                    : const Color(0x66A387D4),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: isDay ? const Color(0xFF2A6CE8) : const Color(0xFFDABBF8),
                ),
              ),
            ),
            locale: provider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('pt')],
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/main': (context) => const MainScreen(),
            },
          );
        },
      ),
    );
  }
}
