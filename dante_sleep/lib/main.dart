import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          return MaterialApp(
            title: 'Dante Sleep',
            theme: ThemeData.dark().copyWith(
              primaryColor: provider.isDay ? Colors.blue : Colors.purple,
              scaffoldBackgroundColor: Colors.grey[900],
              textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: provider.isDay ? Colors.blue : Colors.purple,
                titleTextStyle: const TextStyle(color: Colors.black),
              ),
              iconTheme: const IconThemeData(color: Colors.black),
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
