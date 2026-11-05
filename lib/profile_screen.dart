import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _currentPassword = TextEditingController();

  bool _busy = false;
  bool _needsReauthentication = false;
  bool _success = false;
  String? _message;

  @override
  void dispose() {
    _newPassword.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Could not verify your password. Please try again.';
      case 'weak-password':
        return 'Choose a stronger password that meets the project rules.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait before trying again.';
      case 'no-current-user':
      case 'user-token-expired':
        return 'Please sign out and sign in again.';
      default:
        return 'The action could not finish. Please try again.';
    }
  }

  Future<void> _changePassword() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _message = null;
      _success = false;
    });

    try {
      if (_needsReauthentication) {
        await widget.auth.reauthenticate(_currentPassword.text);
      }

      await widget.auth.updatePassword(_newPassword.text);

      if (!mounted) return;

      _newPassword.clear();
      _currentPassword.clear();

      setState(() {
        _needsReauthentication = false;
        _success = true;
        _message = 'Password updated. Use your new password next time.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        if (error.code == 'requires-recent-login') {
          _needsReauthentication = true;
          _message =
              'Enter your current password below, then retry the update.';
        } else {
          _message = _friendlyError(error.code);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
      _success = false;
    });

    try {
      await widget.auth.signOut();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not sign out. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 80,
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Signed in as',
                  textAlign: TextAlign.center,
                ),
                Text(
                  widget.auth.currentUser?.email ?? 'Email unavailable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                Text(
                  'Update password',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPassword,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Use at least 6 characters.';
                    }
                    if (_needsReauthentication &&
                        value == _currentPassword.text) {
                      return 'Choose a different new password.';
                    }
                    return null;
                  },
                ),
                if (_needsReauthentication) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _currentPassword,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Enter your current password.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (_message != null) ...[
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _success
                          ? Colors.green.shade800
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _busy ? null : _changePassword,
                  child: Text(
                    _needsReauthentication
                        ? 'Verify and update password'
                        : 'Update password',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}