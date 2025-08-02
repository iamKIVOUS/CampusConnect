import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _enrollmentController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _handleLogin(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus(); // Dismiss keyboard

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _enrollmentController.text.trim(),
      _passwordController.text.trim(),
      _selectedRole,
    );

    if (success) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else {
      setState(() {
        _error = 'Login failed. Please check your credentials.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _enrollmentController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Connect Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _enrollmentController,
                    decoration: const InputDecoration(
                      labelText: 'Enrollment Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    keyboardType: TextInputType.text,
                    autofillHints: const [AutofillHints.username],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enrollment number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
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
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(
                        value: 'employee',
                        child: Text('Employee'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleLogin(context),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
