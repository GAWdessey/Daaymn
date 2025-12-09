
import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a loading dialog that displays a stream of status messages.
///
/// This function is a convenient way to show an asynchronous loading process
/// to the user, providing them with real-time feedback.
Future<T?> showDaaymnLoadingDialog<T>({
  required BuildContext context,
  required Stream<String> statusStream,
  required Future<T> future,
}) {
  final navigator = Navigator.of(context);
  future.then((result) => navigator.pop(result)).catchError((error) => navigator.pop());

  return showDialog<T>(
    context: context,
    barrierDismissible: false, // User cannot dismiss the dialog by tapping outside
    builder: (BuildContext context) {
      return DaaymnLoadingDialog(statusStream: statusStream);
    },
  );
}

class DaaymnLoadingDialog extends StatefulWidget {
  final Stream<String> statusStream;

  const DaaymnLoadingDialog({super.key, required this.statusStream});

  @override
  State<DaaymnLoadingDialog> createState() => _DaaymnLoadingDialogState();
}

class _DaaymnLoadingDialogState extends State<DaaymnLoadingDialog> {
  String _currentStatus = 'Initializing...';
  late final StreamSubscription<String> _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = widget.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withAlpha(217),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.pinkAccent.withAlpha(128), width: 2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'DAAYMN',
            style: TextStyle(
              fontFamily: 'Bungee',
              fontSize: 24,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.pinkAccent.withAlpha(179),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              _currentStatus,
              key: ValueKey<String>(_currentStatus), // Important for AnimatedSwitcher
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
