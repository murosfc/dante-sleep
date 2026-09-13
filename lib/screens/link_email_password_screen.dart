import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/localized_strings.dart';
import '../services/firebase_service.dart';

/// Lets a user who is currently signed in with Google add an email/password
/// credential to the same account, so it can be accessed with either method.
class LinkEmailPasswordScreen extends StatefulWidget {
  const LinkEmailPasswordScreen({super.key});

  @override
  State<LinkEmailPasswordScreen> createState() =>
      _LinkEmailPasswordScreenState();
}

class _LinkEmailPasswordScreenState extends State<LinkEmailPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasNumber = RegExp(r'[0-9]');
  static final RegExp _hasUppercase = RegExp(r'[A-Z]');
  static final RegExp _hasSpecialChar = RegExp(r'[^A-Za-z0-9]');

  @override
  void initState() {
    super.initState();
    _emailController.text = FirebaseService().currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String value) =>
      value.length >= 6 &&
      _hasLetter.hasMatch(value) &&
      _hasNumber.hasMatch(value) &&
      _hasUppercase.hasMatch(value) &&
      _hasSpecialChar.hasMatch(value);

  Future<void> _submit() async {
    final strings = LocalizedStrings(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseService().linkEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.linkEmailSuccess)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
          case 'credential-already-in-use':
          case 'provider-already-linked':
            _errorMessage = strings.linkErrorEmailInUse;
            break;
          case 'requires-recent-login':
            _errorMessage = strings.linkErrorRequiresRecentLogin;
            break;
          case 'weak-password':
            _errorMessage = strings.passwordWeak;
            break;
          default:
            _errorMessage = strings.linkErrorGeneric;
        }
      });
    } catch (_) {
      setState(() => _errorMessage = strings.linkErrorGeneric);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocalizedStrings(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.linkEmailScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.passwordStrengthHint,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: strings.authEmail,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return strings.authRequired;
                    if (!v.contains('@')) return strings.authInvalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: strings.authPassword,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return strings.authRequired;
                    if (!_isStrongPassword(v)) return strings.passwordWeak;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: strings.authConfirmPassword,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirmPassword =
                            !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return strings.authRequired;
                    if (v != _passwordController.text) {
                      return strings.authPasswordMismatch;
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(strings.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
