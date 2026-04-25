import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import 'auth_screen.dart';
import 'baby_onboarding_screen.dart';
import 'main_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseService().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasData) {
          return Consumer<AppProvider>(
            builder: (ctx, provider, _) {
              final user = snapshot.data!;

              if (provider.isLoadingAuthUserData) {
                return const _AuthLoadingScreen();
              }

              if (provider.loadedUserId != user.uid || !provider.babyProfileLoaded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!ctx.mounted) return;
                  Provider.of<AppProvider>(
                    ctx,
                    listen: false,
                  ).ensureUserDataLoadedFor(user);
                });
                return const _AuthLoadingScreen();
              }

              if (provider.babyProfile == null) {
                return const BabyOnboardingScreen();
              }
              return const MainScreen();
            },
          );
        }

        return const AuthScreen();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
