import 'package:daaymn/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthMode { signIn, signUp, forgotPassword, updatePassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onSignedIn,
    this.showVerificationSuccess = false,
    this.accessToken,
  });

  final VoidCallback onSignedIn;
  final bool showVerificationSuccess;
  final String? accessToken;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthMode _authMode = AuthMode.signIn;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.accessToken != null) {
      _authMode = AuthMode.updatePassword;
    }

    if (widget.showVerificationSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email confirmed successfully! You can now log in.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accessToken != null && oldWidget.accessToken == null) {
      setState(() {
        _authMode = AuthMode.updatePassword;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      switch (_authMode) {
        case AuthMode.signIn:
          await Supabase.instance.client.auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          break;
        case AuthMode.signUp:
          await Supabase.instance.client.auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            emailRedirectTo: 'com.daaymn.app://auth-callback',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Confirmation link sent! Please check your email.'),
                backgroundColor: Colors.blue,
              ),
            );
            setState(() => _authMode = AuthMode.signIn);
          }
          break;
        case AuthMode.forgotPassword:
          final email = _emailController.text.trim();
          await Supabase.instance.client.auth.resetPasswordForEmail(
            email,
            redirectTo: 'com.daaymn.app://reset-password',
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('password_recovery_email', email);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset link sent! Check your email.'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() => _authMode = AuthMode.signIn);
          }
          break;
        case AuthMode.updatePassword:
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: _passwordController.text.trim()),
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('password_recovery_email');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password updated successfully! You can now log in.'),
                backgroundColor: Colors.green,
              ),
            );
            widget.onSignedIn();
          }
          break;
      }

      if (_authMode == AuthMode.signIn && mounted) {
        widget.onSignedIn();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An unexpected error occurred.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty || !value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty || value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final logo = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: const Text(
        'Daaymn',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.bold,
          fontFamily: 'Pacifico',
          height: 2.5, // Increased to prevent clipping
        ),
      ),
    );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NEW: Conditionally wrap the logo
                if (themeProvider.isDaaymnbow)
                  Card(
                    elevation: 4.0,
                    shadowColor: Colors.black.withValues(alpha: 0.5),
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: logo,
                    ),
                  )
                else
                  logo,
                const SizedBox(height: 48),

                if (_authMode != AuthMode.updatePassword)
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                  ),

                if (_authMode == AuthMode.signIn || _authMode == AuthMode.signUp || _authMode == AuthMode.updatePassword)
                  const SizedBox(height: 16),

                if (_authMode == AuthMode.signIn || _authMode == AuthMode.signUp || _authMode == AuthMode.updatePassword)
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: _authMode == AuthMode.updatePassword ? 'New Password' : 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                  ),

                if (_authMode == AuthMode.signUp || _authMode == AuthMode.updatePassword)
                  const SizedBox(height: 16),

                if (_authMode == AuthMode.signUp || _authMode == AuthMode.updatePassword)
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(labelText: 'Confirm Password'),
                    obscureText: !_isPasswordVisible,
                    validator: _validateConfirmPassword,
                  ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_getButtonText()),
                ),

                const SizedBox(height: 16),

                if (_authMode == AuthMode.signIn)
                  TextButton(
                    onPressed: () => setState(() => _authMode = AuthMode.forgotPassword),
                    child: const Text('Forgot Password?'),
                  ),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _formKey.currentState?.reset();
                      if (_authMode == AuthMode.signIn) {
                        _authMode = AuthMode.signUp;
                      } else {
                        _authMode = AuthMode.signIn;
                      }
                    });
                  },
                  child: Text(_getSwitchText()),
                ),

                if (_authMode == AuthMode.signIn) ...[
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '"Tired of the swipe-right desert? Your oasis awaits."',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Pacifico',
                          ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    switch (_authMode) {
      case AuthMode.signIn:
        return 'Sign In';
      case AuthMode.signUp:
        return 'Sign Up';
      case AuthMode.forgotPassword:
        return 'Send Reset Link';
      case AuthMode.updatePassword:
        return 'Update Password';
    }
  }

  String _getSwitchText() {
    switch (_authMode) {
      case AuthMode.signIn:
        return "Don't have an account? Sign Up";
      case AuthMode.signUp:
        return 'Already have an account? Sign In';
      case AuthMode.forgotPassword:
      case AuthMode.updatePassword:
        return 'Back to Sign In';
    }
  }
}
