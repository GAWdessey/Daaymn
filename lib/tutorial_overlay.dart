import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ShowcaseItem {
  final GlobalKey key;
  final String description;
  final ShapeBorder? shape;

  ShowcaseItem({
    required this.key,
    required this.description,
    this.shape,
  });
}

class TutorialOverlay extends StatefulWidget {
  final List<ShowcaseItem> items;
  final int currentStep;
  final VoidCallback onNext;

  const TutorialOverlay({
    super.key,
    required this.items,
    required this.currentStep,
    required this.onNext,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _calculateRect();
  }

  @override
  void didUpdateWidget(covariant TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _calculateRect();
    }
  }

  void _calculateRect() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.currentStep < 0 || widget.currentStep >= widget.items.length) {
        return;
      }

      final item = widget.items[widget.currentStep];
      final RenderBox? targetRenderBox = item.key.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? overlayRenderBox = context.findRenderObject() as RenderBox?;

      if (targetRenderBox == null || !targetRenderBox.hasSize || overlayRenderBox == null) {
        if (mounted && _targetRect != null) {
          setState(() => _targetRect = null);
        }
        return;
      }

      final targetSize = targetRenderBox.size;
      final globalTargetOffset = targetRenderBox.localToGlobal(Offset.zero);
      final overlayTopLeft = overlayRenderBox.localToGlobal(Offset.zero);
      final localTargetOffset = globalTargetOffset - overlayTopLeft;
      
      final newRect = Rect.fromLTWH(localTargetOffset.dx, localTargetOffset.dy, targetSize.width, targetSize.height);
      
      if (mounted && _targetRect != newRect) {
        setState(() {
          _targetRect = newRect;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onNext,
        child: CustomPaint(
          painter: _OverlayPainter(
            context: context,
            targetRect: _targetRect,
            targetShape: (widget.currentStep >= 0 && widget.currentStep < widget.items.length) ? widget.items[widget.currentStep].shape : null,
            text: (widget.currentStep >= 0 && widget.currentStep < widget.items.length) ? widget.items[widget.currentStep].description : '',
          ),
          size: MediaQuery.of(context).size,
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final BuildContext context;
  final Rect? targetRect;
  final ShapeBorder? targetShape;
  final String text;

  _OverlayPainter({
    required this.context,
    required this.targetRect,
    this.targetShape,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withAlpha(200);

    if (targetRect == null || text.isEmpty || !targetRect!.isFinite) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
      return;
    }
    
    // --- PERFORMANCE OPTIMIZATION: Use BlendMode.dstOut for efficient cutout ---
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw the semi-transparent overlay over the whole screen.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // 2. Define the shape to be cut out.
    final shapeToPaint = targetShape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)));
    final inflatedRect = targetRect!.inflate(6.0);
    final cutOutPath = shapeToPaint.getOuterPath(inflatedRect);
    
    // 3. Use BlendMode.dstOut to erase the cutout area from the overlay.
    final erasePaint = Paint()..blendMode = BlendMode.dstOut;
    canvas.drawPath(cutOutPath, erasePaint);

    canvas.restore();
    // --- End Optimization ---

    // Paint the description text, which is not affected by the cutout.
    _paintDescription(canvas, size, inflatedRect);
  }

  void _paintDescription(Canvas canvas, Size screenSize, Rect target) {
    const double textPadding = 32.0;
    const double screenPadding = 16.0;
    final safeArea = Rect.fromLTRB(screenPadding, screenPadding, screenSize.width - screenPadding, screenSize.height - screenPadding);

    final bool placeAbove = target.center.dy > screenSize.height / 2;

    final textSpan = TextSpan(
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4, shadows: [Shadow(color: Colors.black54, blurRadius: 4.0)]),
      children: _buildTextSpans(text),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: screenSize.width - (screenPadding * 2));

    double textY;
    if (placeAbove) {
      textY = target.top - textPainter.height - textPadding;
    } else {
      textY = target.bottom + textPadding;
    }

    if (textY < safeArea.top) textY = safeArea.top;
    if (textY + textPainter.height > safeArea.bottom) textY = safeArea.bottom - textPainter.height;

    final textX = (screenSize.width - textPainter.width) / 2;

    textPainter.paint(canvas, Offset(textX, textY));
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'daaymn', caseSensitive: false);
    final matches = pattern.allMatches(text);

    if (matches.isEmpty) {
      spans.add(TextSpan(text: text));
      return spans;
    }

    int lastIndex = 0;
    for (final Match match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontFamily: 'Pacifico'),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
           oldDelegate.text != text ||
           oldDelegate.targetShape != targetShape;
  }
}
