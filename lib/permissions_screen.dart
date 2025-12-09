import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onDone;

  const PermissionsScreen({super.key, required this.onDone});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isProcessing = false;
  int _currentStep = 0;

  final List<Map<String, dynamic>> _permissionSteps = [
    {
      'title': 'Location Access',
      'description': 'We use your approximate location to show you potential matches in your area. We only need your location while you\'re using the app.',
      'icon': Icons.location_on,
      'permissions': [Permission.locationWhenInUse],
    },
    {
      'title': 'Notifications',
      'description': 'Get notified when you receive new likes, messages, and matches. We\'ll never spam you.',
      'icon': Icons.notifications,
      'permissions': [Permission.notification],
    },
  ];

  Future<void> _requestCurrentPermission() async {
    if (_isProcessing || _currentStep >= _permissionSteps.length) return;

    setState(() => _isProcessing = true);

    try {
      final permissions = _permissionSteps[_currentStep]['permissions'] as List<Permission>;

      for (final permission in permissions) {
        await permission.request();
      }

      if (mounted) {
        if (_currentStep < _permissionSteps.length - 1) {
          setState(() {
            _currentStep++;
            _isProcessing = false;
          });
        } else {
          _completePermissionsFlow();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _skipPermission() {
    if (_currentStep < _permissionSteps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completePermissionsFlow();
    }
  }

  Future<void> _completePermissionsFlow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);
    if (mounted) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStepData = _permissionSteps[_currentStep];

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _permissionSteps.length,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentStepData['icon'] as IconData,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 40),
                          Text(
                            currentStepData['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            currentStepData['description'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(230),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _requestCurrentPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Allow',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isProcessing ? null : _skipPermission,
                      child: Text(
                        _currentStep < _permissionSteps.length - 1
                            ? 'Skip for now'
                            : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
