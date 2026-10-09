import 'dart:convert';
import 'dart:io';
import 'package:daaymn/globals.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

class FaceVerificationScreen extends StatefulWidget {
  final Profile profile; // Expect the full user profile

  const FaceVerificationScreen({super.key, required this.profile});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  File? _selfieImage;
  String _verificationResult = '';
  bool _isVerifying = false;

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  Future<void> _takeSelfie() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      // Keeps the upload well under the server's 5 MB limit
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _selfieImage = File(pickedFile.path);
        _verificationResult = ''; 
      });
    }
  }

  Future<void> _verifyFaces() async {
    if (_selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a selfie first.')),
      );
      return;
    }

    if (widget.profile.imageUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one profile picture uploaded.')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationResult = 'Checking your selfie...';
    });

    try {
      // Catch a missing face here so it doesn't use up a server attempt
      final selfieFaces = await _faceDetector.processImage(InputImage.fromFile(_selfieImage!));
      if (selfieFaces.isEmpty) {
        setState(() => _verificationResult = '❌ Not Verified\n(Could not detect a face in your selfie.)');
        return;
      }

      setState(() => _verificationResult = 'Comparing with your profile photos...');

      // The server compares the faces and sets the verified badge itself
      final selfieBase64 = base64Encode(await _selfieImage!.readAsBytes());
      final response = await supabase.functions.invoke('verify-face', body: {'selfie': selfieBase64});
      final data = response.data as Map<String, dynamic>?;

      if (data?['verified'] == true) {
        setState(() => _verificationResult = '✅ Verified');
        await Future.delayed(const Duration(seconds: 2));
        if(mounted) Navigator.of(context).pop();
      } else {
        setState(() => _verificationResult = '❌ Not Verified\n(${data?['reason'] ?? 'Faces do not match.'})');
      }

    } on FunctionException catch (e) {
      final details = e.details is Map ? e.details as Map : null;
      setState(() => _verificationResult = details?['error'] ?? 'An error occurred during verification.');
      debugPrint('Error during face verification: $e');
    } catch (e) {
      setState(() => _verificationResult = 'An error occurred during verification.');
      debugPrint('Error during face verification: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Verification')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Take a selfie to verify your profile.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildImageViews(),
              const SizedBox(height: 30),
              if (_isVerifying)
                Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(_verificationResult, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _selfieImage == null ? _takeSelfie : _verifyFaces,
                  child: Text(_selfieImage == null ? 'Take Selfie' : 'Verify', style: const TextStyle(fontSize: 18)),
                ),
              const SizedBox(height: 30),
              if (!_isVerifying && _verificationResult.isNotEmpty)
                Text(
                  _verificationResult,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _verificationResult.contains('✅') ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageViews() {
    return Center(
      child: _buildImageCard(_selfieImage, 'Your Selfie'),
    );
  }

  Widget _buildImageCard(File? image, String label) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 200,
            height: 200,
            color: Colors.grey.shade200,
            child: image != null
                ? Image.file(image, fit: BoxFit.cover)
                : const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
