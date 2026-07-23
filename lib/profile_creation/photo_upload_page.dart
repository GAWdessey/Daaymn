
import 'dart:io';
import 'dart:math';
import 'package:daaymn/profile_creation/profile_data_model.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoUploadPage extends StatefulWidget {
  final VoidCallback onNext;
  final ProfileData profileData;

  const PhotoUploadPage({super.key, required this.onNext, required this.profileData});

  @override
  State<PhotoUploadPage> createState() => _PhotoUploadPageState();
}

class _PhotoUploadPageState extends State<PhotoUploadPage> {
  final _imagePicker = ImagePicker();
  bool _isPickingImage = false;

  Future<void> _pickImage(int index) async {
    if (_isPickingImage) return;

    try {
      setState(() {
        _isPickingImage = true;
      });
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile != null && mounted) {
        setState(() {
          widget.profileData.imageSources[index] = pickedFile;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _setBestPhoto(int index) {
    setState(() {
      final selectedImage = widget.profileData.imageSources[index];
      if (selectedImage == null) return;

      final newImageSources = List<dynamic>.filled(6, null);
      newImageSources[0] = selectedImage;

      int newIndex = 1;
      for (int i = 0; i < widget.profileData.imageSources.length; i++) {
        if (i != index && widget.profileData.imageSources[i] != null) {
          newImageSources[newIndex++] = widget.profileData.imageSources[i];
        }
      }

      widget.profileData.imageSources = newImageSources;
      widget.profileData.selectedBestPhoto = 1;
    });
  }

  Widget _buildCircularPhotoUploader() {
    int uploadedCount = widget.profileData.imageSources.where((i) => i != null).length;
    double progress = uploadedCount / 6.0;

    return SizedBox(
      width: 250, height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 250, height: 250, child: CustomPaint(painter: GradientProgressPainter(progress))),
          const Text('D', style: TextStyle(fontFamily: 'Pacifico', fontSize: 60, color: Colors.white70)),
          ...List.generate(6, (index) {
            final angle = (index / 6.0) * 2 * pi - (pi / 2);
            final x = 95 * cos(angle);
            final y = 95 * sin(angle);
            return Positioned(left: 125 - 30 + x, top: 125 - 30 + y, child: _buildPhotoSlot(index));
          }),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index) {
    final source = widget.profileData.imageSources[index];
    final isBestPhoto = (widget.profileData.selectedBestPhoto - 1) == index;

    Widget imageContent;
    if (source is XFile) {
      imageContent = Image.file(
        File(source.path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
      );
    } else if (source is String) {
      imageContent = Image.network(
        source,
        cacheWidth: 720,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
      );
    } else {
      imageContent = const Icon(Icons.add, color: Colors.grey, size: 24);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _pickImage(index),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[300],
            child: ClipOval(
              child: SizedBox.fromSize(
                size: const Size.fromRadius(30),
                child: imageContent,
              ),
            ),
          ),
        ),
        if (source != null)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => _setBestPhoto(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isBestPhoto ? Colors.amber : Colors.black.withAlpha(128),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star, color: isBestPhoto ? Colors.white : Colors.white.withAlpha(178), size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStarOfTheShow() {
    final bestPhotoIndex = widget.profileData.selectedBestPhoto - 1;
    if (bestPhotoIndex < 0 || bestPhotoIndex >= widget.profileData.imageSources.length) return const SizedBox.shrink();

    final source = widget.profileData.imageSources[bestPhotoIndex];
    if (source == null) return const SizedBox.shrink();

    Widget imageContent;
    if (source is XFile) {
      imageContent = Image.file(File(source.path), fit: BoxFit.cover);
    } else if (source is String) {
      imageContent = Image.network(
        source,
        cacheWidth: 720,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 48),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: SizedBox(
                width: 80,
                height: 80,
                child: imageContent,
              ),
            ),
            const SizedBox(width: 16),
            const Text('Star of the show', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Pacifico')),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(204),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All photos are scanned upon upload. Nudity, weapons, and offensive content are not permitted and will be automatically rejected.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Add Your Best Photos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Add at least 3 photos to continue.', style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Center(child: _buildCircularPhotoUploader()),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                        children: <TextSpan>[
                          TextSpan(text: 'Tap the '),
                          TextSpan(text: 'star', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: ' to choose your best photo!'),
                        ],
                      ),
                    ),
                    _buildStarOfTheShow(),
                  ],
                ),
              ),
            ),
            _buildWarningWidget(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (widget.profileData.imageSources.where((s) => s != null).length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 3 photos.')));
                  return;
                }
                widget.onNext();
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

class GradientProgressPainter extends CustomPainter {
  final double progress;
  GradientProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    final paint = Paint()..shader = const SweepGradient(colors: [Color(0xFF00DBDE), Color(0xFFFC00FF)], startAngle: -pi / 2, endAngle: 3 * pi / 2, tileMode: TileMode.repeated).createShader(rect)..style = PaintingStyle.fill;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, true, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
