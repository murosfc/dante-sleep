import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../l10n/localized_strings.dart';
import '../providers/app_provider.dart';
import '../services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const bool _enableGoogleSignIn = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _babyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _babyNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = LocalizedStrings(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isLoginMode) {
        await FirebaseService().signInWithEmail(email, password);
      } else {
        await FirebaseService().signUpWithEmail(email, password);
        final name = _nameController.text.trim();
        final babyName = _babyNameController.text.trim();
        if (name.isNotEmpty || babyName.isNotEmpty) {
           final user = FirebaseService().currentUser;
           if (user != null) {
              await FirebaseService().updateUserProfile(user.uid, {
                if (name.isNotEmpty) 'displayName': name,
                if (babyName.isNotEmpty) 'pendingBabyName': babyName,
              });
           }
        }
      }
      
      // Load settings after successful authentication
      if (mounted) {
        await Provider.of<AppProvider>(context, listen: false)
            .loadSettingsFromCurrentUser();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'invalid-credential':
          case 'user-not-found':
          case 'wrong-password':
            _errorMessage = strings.authInvalidCredentials;
            break;
          case 'email-already-in-use':
            _errorMessage = strings.authEmailInUse;
            break;
          default:
            _errorMessage = strings.authGenericError;
        }
      });
    } catch (_) {
      setState(() {
        _errorMessage = strings.authGenericError;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitWithGoogle() async {
    final strings = LocalizedStrings(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseService().signInWithGoogle();
      
      // Load settings after successful authentication
      if (mounted) {
        await Provider.of<AppProvider>(context, listen: false)
            .loadSettingsFromCurrentUser();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in FirebaseAuthException: ${e.code} ${e.message}');
      setState(() {
        _errorMessage = strings.authGenericError;
      });
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      setState(() {
        _errorMessage = strings.authGenericError;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocalizedStrings(context);
    final title = _isLoginMode ? strings.authTitleLogin : strings.authTitleRegister;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF100818), Color(0xFF1B1030), Color(0xFF0D0715)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: const Color(0xFF231A36), // Mais claro para contraste
                  elevation: 8,
                  shadowColor: Colors.black54,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Dante Sleep',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFF7F2FF),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFCCB7F0),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_isLoginMode) ...[
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: strings.authUserName,
                                labelStyle: const TextStyle(color: Color(0xFF4B2FA6)),
                                filled: true,
                                fillColor: const Color(0xFFF3F0FA),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF4B2FA6), width: 2),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return strings.authRequired;
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _babyNameController,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: strings.authBabyName,
                                labelStyle: const TextStyle(color: Color(0xFF4B2FA6)),
                                filled: true,
                                fillColor: const Color(0xFFF3F0FA),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF4B2FA6), width: 2),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return strings.authRequired;
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: strings.authEmail,
                              labelStyle: const TextStyle(color: Color(0xFF4B2FA6)),
                              filled: true,
                              fillColor: Color(0xFFF3F0FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF4B2FA6), width: 2),
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return strings.authRequired;
                              if (!v.contains('@')) {
                                return strings.authInvalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: strings.authPassword,
                              labelStyle: const TextStyle(color: Color(0xFF4B2FA6)),
                              filled: true,
                              fillColor: Color(0xFFF3F0FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF4B2FA6), width: 2),
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                            ),
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) return strings.authRequired;
                              if (v.length < 6) {
                                return strings.authShortPassword;
                              }
                              return null;
                            },
                          ),
                          if (!_isLoginMode) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: strings.authConfirmPassword,
                                labelStyle: const TextStyle(color: Color(0xFF4B2FA6)),
                                filled: true,
                                fillColor: Color(0xFFF3F0FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF4B2FA6), width: 2),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) {
                                  return strings.authRequired;
                                }
                                if (v != _passwordController.text) {
                                  return strings.authPasswordMismatch;
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4B2FA6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                elevation: 2,
                              ),
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLoginMode
                                          ? strings.authSubmitLogin
                                          : strings.authSubmitRegister,
                                    ),
                            ),
                          ),
                          if (_enableGoogleSignIn && _isLoginMode) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                              ),
                              onPressed: _isLoading ? null : _submitWithGoogle,
                              icon: const Icon(Icons.g_mobiledata),
                              label: Text(strings.authGoogleSignIn),
                            ),
                          ],
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isLoginMode = !_isLoginMode;
                                      _errorMessage = null;
                                    });
                                  },
                            child: Text(
                              _isLoginMode
                                  ? strings.authSwitchToRegister
                                  : strings.authSwitchToLogin,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              strings.authFooterHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF9E8ABF),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
