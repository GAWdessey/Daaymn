
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final TextEditingController _reportController = TextEditingController();

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    final text = _reportController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the problem before submitting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSubmitting) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final focusScope = FocusScope.of(context);
    setState(() => _isSubmitting = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      // 1) Persist the report in Supabase.
      await Supabase.instance.client.from('problem_reports').insert({
        'user_id': userId,
        'message': text,
      });

      // 2) Email the report to daaymnco@gmail.com via FormSubmit.
      await http.post(
        Uri.parse('https://formsubmit.co/ajax/daaymnco@gmail.com'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // FormSubmit rejects requests with no web origin; native clients
          // send none, so present the app's site as origin/referer.
          'Origin': 'https://daaymn.co',
          'Referer': 'https://daaymn.co/',
        },
        body: jsonEncode({
          'subject': 'Daaymn problem report',
          'message': text,
          'user': userId ?? 'anon',
        }),
      );

      _reportController.clear();
      focusScope.unfocus();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you for your report!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not submit your report. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Report a Problem", style: TextStyle(fontFamily: 'Pacifico', color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))])),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              children: [
                const SizedBox(height: 60), // Spacer for aesthetics
                Text(
                  'Help us improve Daaymn!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please describe the issue you encountered in detail.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextField(
                      controller: _reportController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Describe the bug, payment issue, or other problem here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: Text(_isSubmitting ? 'Submitting...' : 'Submit Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
