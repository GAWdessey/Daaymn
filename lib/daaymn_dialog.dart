import 'package:flutter/material.dart';

class DaaymnDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final String? secondButtonText; // New optional parameter
  final VoidCallback? onSecondButtonPressed; // New optional parameter

  const DaaymnDialog({
    super.key,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onButtonPressed,
    this.secondButtonText,
    this.onSecondButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Daaymn', style: TextStyle(fontFamily: 'Pacifico', fontSize: 40, color: Colors.pinkAccent)),
            const SizedBox(height: 24),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: onButtonPressed,
              child: Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            // Conditionally add the second button if the text for it is provided
            if (secondButtonText != null)
              TextButton(
                onPressed: onSecondButtonPressed ?? () => Navigator.of(context).pop(),
                child: Text(secondButtonText!, style: const TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
  }
}
