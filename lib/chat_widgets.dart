import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final bool isMine;
  final String text;
  final String? audioUrl;
  final int? audioDuration;
  final String createdAt;
  final bool isRead;
  final bool isSent;
  final Widget? child;

  const MessageBubble({
    super.key,
    required this.isMine,
    required this.text,
    this.audioUrl,
    this.audioDuration,
    required this.createdAt,
    this.isRead = false,
    this.isSent = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implement MessageBubble UI
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isMine ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: child ?? Text(text, style: TextStyle(color: isMine ? Colors.white : Colors.black)),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement TypingIndicator UI
    return const Text('Typing...');
  }
}

class RecordingIndicator extends StatelessWidget {
  final double? dbLevel;
  final Duration? duration;

  const RecordingIndicator({
    super.key,
    this.dbLevel,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implement RecordingIndicator UI
    return Row(
      children: [
        const Icon(Icons.mic, color: Colors.red),
        const SizedBox(width: 8),
        Text(duration != null ? duration.toString().substring(2, 7) : '0:00.00'),
      ],
    );
  }
}
