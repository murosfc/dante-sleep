import 'package:flutter/material.dart';

import '../l10n/localized_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocalizedStrings(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF100818), Color(0xFF1B1030), Color(0xFF0D0715)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0x33281A44),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x66C7B0FF)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    Icon(
                      Icons.nightlight_round,
                      size: 100,
                      color: Color(0xFFE3D5FF),
                    ),
                    Positioned(
                      top: 10,
                      child: Icon(Icons.star, size: 20, color: Color(0xFFF6EEFF)),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 20,
                      child: Icon(Icons.star, size: 15, color: Color(0xFFEADFFF)),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 20,
                      child: Icon(Icons.star, size: 15, color: Color(0xFFEADFFF)),
                    ),
                    Positioned(
                      top: 30,
                      right: 10,
                      child: Icon(
                        Icons.child_care,
                        size: 30,
                        color: Color(0xFFF6EEFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                strings.appTitle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF7F2FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
