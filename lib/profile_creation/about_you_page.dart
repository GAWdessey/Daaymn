
import 'package:daaymn/profile_creation/profile_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutYouPage extends StatefulWidget {
  final VoidCallback onNext;
  final ProfileData profileData;

  const AboutYouPage({super.key, required this.onNext, required this.profileData});

  @override
  State<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends State<AboutYouPage> {
  final Map<String, TextEditingController> _bioControllers = {
    'Two truths and a lie': TextEditingController(),
    'My simple pleasures': TextEditingController(),
    'A hill I\'m willing to die on': TextEditingController(),
    'I\'m looking for...': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    for (var topic in _bioControllers.keys) {
      if (widget.profileData.bioTopics.containsKey(topic)) {
        _bioControllers[topic]!.text = widget.profileData.bioTopics[topic]!;
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _bioControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('About Me (Optional)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: _bioControllers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextFormField(
                        controller: entry.value,
                        decoration: InputDecoration(labelText: entry.key, border: const OutlineInputBorder()),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        maxLength: 280,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onNext,
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    for (var topic in _bioControllers.keys) {
                      if (_bioControllers[topic]!.text.trim().isNotEmpty) {
                        widget.profileData.bioTopics[topic] = _bioControllers[topic]!.text.trim();
                      }
                    }
                    widget.onNext();
                  },
                  child: const Text('Next'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
