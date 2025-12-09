import 'dart:io';
import 'dart:math';
import 'package:daaymn/globals.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

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
  double _progress = 0.0;

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableLandmarks: true,
    ),
  );

  Future<void> _takeSelfie() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
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

    final profileImageUrls = widget.profile.imageUrls;
    if (profileImageUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one profile picture uploaded.')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationResult = 'Starting verification...';
      _progress = 0.0;
    });

    try {
      final selfieInputImage = InputImage.fromFile(_selfieImage!);
      final selfieFaces = await _faceDetector.processImage(selfieInputImage);

      if (selfieFaces.isEmpty) {
        setState(() => _verificationResult = '❌ Not Verified\n(Could not detect a face in your selfie.)');
        return;
      }

      final selfieLandmarks = _extractLandmarks(selfieFaces.first);

      bool matchFound = false;

      for (int i = 0; i < profileImageUrls.length; i++) {
        final url = profileImageUrls[i];
        setState(() {
           _verificationResult = 'Checking profile photo ${i + 1} of ${profileImageUrls.length}...';
           _progress = (i + 1) / profileImageUrls.length;
        });

        final profileImageFile = await _downloadImage(url);
        if(profileImageFile == null) continue;

        final profileInputImage = InputImage.fromFile(profileImageFile);
        final profileFaces = await _faceDetector.processImage(profileInputImage);

        if (profileFaces.isEmpty) continue;

        final profileLandmarks = _extractLandmarks(profileFaces.first);
        
        final areFacesSimilar = _compareFaces(selfieLandmarks, profileLandmarks);

        if (areFacesSimilar) {
          matchFound = true;
          break; 
        }
      }

      if (matchFound) {
        await _updateVerificationStatus(true);
        setState(() => _verificationResult = '✅ Verified');
        await Future.delayed(const Duration(seconds: 2));
        if(mounted) Navigator.of(context).pop();
      } else {
        setState(() => _verificationResult = '❌ Not Verified\n(Faces do not match.)');
      }

    } catch (e) {
      setState(() => _verificationResult = 'An error occurred during verification.');
      debugPrint('Error during face verification: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Map<FaceLandmarkType, Point<int>> _extractLandmarks(Face face) {
    final Map<FaceLandmarkType, Point<int>> landmarks = {};
    face.landmarks.forEach((type, landmark) {
      if (landmark != null) {
        landmarks[type] = Point(landmark.position.x, landmark.position.y);
      }
    });
    return landmarks;
  }

  bool _compareFaces(Map<FaceLandmarkType, Point<int>> landmarks1, Map<FaceLandmarkType, Point<int>> landmarks2) {
    if (landmarks1.isEmpty || landmarks2.isEmpty) return false;

    final landmarkTypes = landmarks1.keys.toSet().intersection(landmarks2.keys.toSet());
    if (landmarkTypes.length < 5) return false; // Need a minimum number of common landmarks

    final distances1 = _calculatePairwiseDistances(landmarks1, landmarkTypes);
    final distances2 = _calculatePairwiseDistances(landmarks2, landmarkTypes);
    
    // Normalize distances by the nose-to-mouth distance to make it scale-invariant
    final normalizer1 = landmarks1[FaceLandmarkType.noseBase]?.distanceTo(landmarks1[FaceLandmarkType.leftMouth] ?? landmarks1[FaceLandmarkType.rightMouth]!) ?? 1.0;
    final normalizer2 = landmarks2[FaceLandmarkType.noseBase]?.distanceTo(landmarks2[FaceLandmarkType.leftMouth] ?? landmarks2[FaceLandmarkType.rightMouth]!) ?? 1.0;

    double totalDifference = 0;
    int comparisonCount = 0;

    for (int i = 0; i < distances1.length; i++) {
        final normalizedDist1 = distances1[i] / normalizer1;
        final normalizedDist2 = distances2[i] / normalizer2;
        totalDifference += (normalizedDist1 - normalizedDist2).abs();
        comparisonCount++;
    }
    
    if (comparisonCount == 0) return false;

    final averageDifference = totalDifference / comparisonCount;
    const similarityThreshold = 0.5; 

    debugPrint('Face similarity difference: $averageDifference');
    return averageDifference < similarityThreshold;
  }

  List<double> _calculatePairwiseDistances(Map<FaceLandmarkType, Point<int>> landmarks, Set<FaceLandmarkType> types) {
      final List<double> distances = [];
      final landmarkPoints = types.map((type) => landmarks[type]!).toList();

      for (int i = 0; i < landmarkPoints.length; i++) {
          for (int j = i + 1; j < landmarkPoints.length; j++) {
              distances.add(landmarkPoints[i].distanceTo(landmarkPoints[j]));
          }
      }
      return distances;
  }


  Future<File?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final documentDirectory = await getApplicationDocumentsDirectory();
      final file = File('${documentDirectory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      debugPrint("Failed to download image: $e");
      return null;
    }
  }

  Future<void> _updateVerificationStatus(bool isVerified) async {
    try {
      await supabase.from('profiles').update({'is_verified': isVerified}).eq('id', widget.profile.id);
    } catch (e) {
      debugPrint("Failed to update verification status: $e");
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
                    LinearProgressIndicator(value: _progress),
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
