import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const bool _enableGoogleSignIn = bool.fromEnvironment(
    'ENABLE_GOOGLE_SIGN_IN',
    defaultValue: false,
  );

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _text(BuildContext context, String key) {
    final isPt = Localizations.localeOf(context).languageCode == 'pt';

    const pt = {
      'titleLogin': 'Entrar',
      'titleRegister': 'Criar conta',
      'email': 'E-mail',
      'password': 'Senha',
      'confirmPassword': 'Confirmar senha',
      'submitLogin': 'Entrar',
      'submitRegister': 'Cadastrar',
      'switchToRegister': 'Nao tem conta? Cadastre-se',
      'switchToLogin': 'Ja tem conta? Entrar',
      'googleSignIn': 'Entrar com Google',
      'required': 'Campo obrigatorio',
      'invalidEmail': 'E-mail invalido',
      'shortPassword': 'Senha deve ter pelo menos 6 caracteres',
      'passwordMismatch': 'As senhas nao coincidem',
      'invalidCredentials': 'E-mail ou senha invalidos',
      'emailInUse': 'Este e-mail ja esta em uso',
      'genericError': 'Nao foi possivel autenticar. Tente novamente.',
    };

    const en = {
      'titleLogin': 'Sign in',
      'titleRegister': 'Create account',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm password',
      'submitLogin': 'Sign in',
      'submitRegister': 'Sign up',
      'switchToRegister': 'No account yet? Create one',
      'switchToLogin': 'Already have an account? Sign in',
      'googleSignIn': 'Continue with Google',
      'required': 'Required field',
      'invalidEmail': 'Invalid email',
      'shortPassword': 'Password must have at least 6 characters',
      'passwordMismatch': 'Passwords do not match',
      'invalidCredentials': 'Invalid email or password',
      'emailInUse': 'This email is already in use',
      'genericError': 'Could not authenticate. Please try again.',
    };

    return (isPt ? pt : en)[key] ?? key;
  }

  Future<void> _submit() async {
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
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'invalid-credential':
          case 'user-not-found':
          case 'wrong-password':
            _errorMessage = _text(context, 'invalidCredentials');
            break;
          case 'email-already-in-use':
            _errorMessage = _text(context, 'emailInUse');
            break;
          default:
            _errorMessage = _text(context, 'genericError');
        }
      });
    } catch (_) {
      setState(() {
        _errorMessage = _text(context, 'genericError');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseService().signInWithGoogle();
    } on FirebaseAuthException {
      setState(() {
        _errorMessage = _text(context, 'genericError');
      });
    } catch (_) {
      setState(() {
        _errorMessage = _text(context, 'genericError');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final title = _isLoginMode
        ? _text(context, 'titleLogin')
        : _text(context, 'titleRegister');

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
                  color: const Color(0xFF1A1226),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
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
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: _text(context, 'email'),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return _text(context, 'required');
                              if (!v.contains('@')) {
                                return _text(context, 'invalidEmail');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: _text(context, 'password'),
                            ),
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) return _text(context, 'required');
                              if (v.length < 6) {
                                return _text(context, 'shortPassword');
                              }
                              return null;
                            },
                          ),
                          if (!_isLoginMode) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: _text(context, 'confirmPassword'),
                              ),
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) {
                                  return _text(context, 'required');
                                }
                                if (v != _passwordController.text) {
                                  return _text(context, 'passwordMismatch');
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
                          FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLoginMode
                                        ? _text(context, 'submitLogin')
                                        : _text(context, 'submitRegister'),
                                  ),
                          ),
                          if (_enableGoogleSignIn && _isLoginMode) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _submitWithGoogle,
                              icon: const Icon(Icons.g_mobiledata),
                              label: Text(_text(context, 'googleSignIn')),
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
                                  ? _text(context, 'switchToRegister')
                                  : _text(context, 'switchToLogin'),
                            ),
                          ),
                          if (isPt)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Use e-mail e senha para acessar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF9E8ABF),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Use email and password to continue.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
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
