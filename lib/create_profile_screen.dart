
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:daaymn/globals.dart';
import 'package:daaymn/widgets/daaymn_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _VerificationResult {
  final Profile? profile;
  final List<String> rejectedUrls;

  _VerificationResult({this.profile, this.rejectedUrls = const []});
}

class CreateProfileScreen extends StatefulWidget {
  final Function(Profile) onProfileSaved;
  final Profile? profileToEdit;

  const CreateProfileScreen({
    super.key,
    required this.onProfileSaved,
    this.profileToEdit,
  });

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _workController = TextEditingController();
  final _religionController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _selfDescribedEthnicityController = TextEditingController(); // Controller for self-described ethnicity
  final Map<String, TextEditingController> _bioControllers = {
    "Two truths and a lie": TextEditingController(),
    "My simple pleasures": TextEditingController(),
    "A hill I'm willing to die on": TextEditingController(),
    "I'm looking for...": TextEditingController(),
  };

  // Image state
  final _imagePicker = ImagePicker();
  final List<dynamic> _imageSources = List.filled(6, null);
  int _selectedBestPhoto = 1;

  // Checkbox state
  bool _showWork = true;
  bool _showReligion = true;
  bool _showHeight = true;
  bool _showWeight = true;
  bool _showDominantHand = true;
  bool _showDevicePreference = true;

  // --- Valid Dropdown Options ---
  static const List<String> _genders = ['Male', 'Female', 'Non-binary', 'Other'];
  static const List<String> _pronouns = ['he/him', 'she/her', 'they/them', 'Other'];
  static const List<String> _ethnicities = [
    'East Asian', 'South & Southeast Asian', 'African', 'Hispanic / Latinx',
    'Middle Eastern & North African', 'Native American / Indigenous', 'Pacific Islander',
    'Caucasian', 'Multiracial', 'One for All', 'All for One', 'Prefer to self-describe',
    'Prefer not to say'
  ];
  static const List<String> _dominantHands = ['Right', 'Left', 'Ambidextrous'];
  static const List<String> _devicePreferences = ['Apple', 'Android', 'Other'];
  static const List<String> _metricSystems = ['Metric', 'Imperial'];
  // ---------------------------------

  // Dropdown State
  String? _selectedGender;
  String? _selectedEthnicity;
  String? _selectedPronouns;
  String? _selectedDominantHand;
  String? _selectedDevicePreference;
  String _selectedMetricSystem = 'Metric';
  List<String> _interestedIn = [];

  @override
  void initState() {
    super.initState();
    _prefillForm();
  }

  void _prefillForm() {
    if (widget.profileToEdit == null) return;
    final profile = widget.profileToEdit!;
    _nameController.text = profile.name;
    _ageController.text = profile.age.toString();

    // --- Graceful Dropdown Handling ---
    _selectedGender = _genders.contains(profile.gender) ? profile.gender : null;
    _selectedPronouns = _pronouns.contains(profile.pronouns) ? profile.pronouns : null;

    if (profile.ethnicity != null) {
      if (_ethnicities.contains(profile.ethnicity)) {
        _selectedEthnicity = profile.ethnicity;
      } else {
        _selectedEthnicity = 'Prefer to self-describe';
        _selfDescribedEthnicityController.text = profile.ethnicity!;
      }
    } else {
      _selectedEthnicity = null;
    }

    _selectedDominantHand = _dominantHands.contains(profile.dominantHand?.value) ? profile.dominantHand?.value : null;
    _selectedDevicePreference = _devicePreferences.contains(profile.devicePreference?.value) ? profile.devicePreference?.value : null;
    _selectedMetricSystem = _metricSystems.contains(profile.metricSystem) ? profile.metricSystem! : 'Metric';
    // ------------------------------------

    _showDominantHand = profile.dominantHand?.show ?? true;
    _showDevicePreference = profile.devicePreference?.show ?? true;
    _selectedBestPhoto = profile.bestPhotoIndex ?? 1;
    _interestedIn = profile.interestedIn ?? [];

    for (int i = 0; i < profile.imageUrls.length && i < _imageSources.length; i++) {
      _imageSources[i] = profile.imageUrls[i];
    }

    for (var topic in _bioControllers.keys) {
      if (profile.bioTopics.containsKey(topic)) {
        _bioControllers[topic]!.text = profile.bioTopics[topic]!;
      }
    }

    _workController.text = profile.work?.value ?? '';
    _showWork = profile.work?.show ?? true;
    _religionController.text = profile.religion?.value ?? '';
    _showReligion = profile.religion?.show ?? true;

    if (profile.heightCm != null) {
      if (_selectedMetricSystem == 'Imperial') {
        final inches = profile.heightCm!.value / 2.54;
        _heightController.text = inches.round().toString();
      } else {
        _heightController.text = profile.heightCm!.value.toStringAsFixed(0);
      }
    }
    _showHeight = profile.heightCm?.show ?? true;

    if (profile.weightKg != null) {
      if (_selectedMetricSystem == 'Imperial') {
        final lbs = profile.weightKg!.value * 2.20462;
        _weightController.text = lbs.round().toString();
      } else {
        _weightController.text = profile.weightKg!.value.toStringAsFixed(0);
      }
    }
    _showWeight = profile.weightKg?.show ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _workController.dispose();
    _religionController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _selfDescribedEthnicityController.dispose();
    for (var controller in _bioControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

    void _showMultipleImageRejectionDialog(List<String> rejectedUrls) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black.withAlpha(217),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.pinkAccent.withAlpha(128), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Daaymn, a problem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Bungee',
                    fontSize: 24,
                    color: Colors.white,
                     shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.pinkAccent.withAlpha(178),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Our robot overlords rejected one or more of your photos. Please swap them out and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("I'll fix it.", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleImageRejections(List<String> rejectedUrls) {
    setState(() {
      for (var rejectedUrl in rejectedUrls) {
        final rejectedIndex = _imageSources.indexOf(rejectedUrl);
        if (rejectedIndex != -1) {
          _imageSources[rejectedIndex] = null;
          if ((_selectedBestPhoto - 1) == rejectedIndex) {
            final firstAvailable = _imageSources.indexWhere((s) => s != null);
             _selectedBestPhoto = firstAvailable != -1 ? firstAvailable + 1 : 1;
          }
        }
      }
    });
  }

  Future<void> _pickImage(int index) async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null && mounted) {
      setState(() {
        _imageSources[index] = pickedFile;
      });
    }
  }

  void _setBestPhoto(int index) {
    setState(() {
      final selectedImage = _imageSources[index];
      if (selectedImage == null) return;

      final newImageSources = List<dynamic>.filled(6, null);
      newImageSources[0] = selectedImage;

      int newIndex = 1;
      for (int i = 0; i < _imageSources.length; i++) {
        if (i != index && _imageSources[i] != null) {
          newImageSources[newIndex++] = _imageSources[i];
        }
      }

      _imageSources.setAll(0, newImageSources);
      _selectedBestPhoto = 1;
    });
  }
  
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled. Please enable them in your settings.')));
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(forceAndroidLocationManager: true);
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to get location: $e")));
       return null;
    }
  }

  Future<void> _updateLocationInBackground() async {
    final position = await _determinePosition();
    if (position != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'location': 'POINT(${position.longitude} ${position.latitude})'
        }).eq('id', Supabase.instance.client.auth.currentUser!.id);
      } catch (e) {
        // Silently fail. The user does not need to know about this background task.
        debugPrint("Error updating location in background: $e");
      }
    }
  }


  Future<_VerificationResult> _runVerification(StreamController<String> statusController) async {
    try {
      statusController.add('Uploading images...');
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final Map<String, String> uploadedUrlMap = {};

      for (int i = 0; i < _imageSources.length; i++) {
        final source = _imageSources[i];
        if (source is XFile) {
          final fileBytes = await source.readAsBytes();
          final image = img.decodeImage(fileBytes);
          if (image == null) {
            continue;
          }

          image.exif.clear();
          final sanitizedBytes = img.encodeJpg(image, quality: 85);

          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final filePath = '$userId/$fileName';
          await Supabase.instance.client.storage.from('profile-images').uploadBinary(filePath, sanitizedBytes);
          final publicUrl = Supabase.instance.client.storage.from('profile-images').getPublicUrl(filePath);
          _imageSources[i] = publicUrl;
          uploadedUrlMap[publicUrl] = filePath;
        }
      }

      if (uploadedUrlMap.isEmpty) {
          statusController.add('No new images to verify.');
          await Future.delayed(const Duration(milliseconds: 500));
      } else {
        statusController.add('Verifying images, this can take a moment...');
        List<String> rejectedUrls = [];
        const maxAttempts = 10;
        int attempt = 0;
        
        while (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          List<String> stillPresentUrls = [];

          for (var url in uploadedUrlMap.keys) {
              final response = await http.head(Uri.parse(url));
              if (response.statusCode == 200) {
                  stillPresentUrls.add(url);
              }
          }

          if(stillPresentUrls.length < uploadedUrlMap.length) {
              rejectedUrls = uploadedUrlMap.keys.where((url) => !stillPresentUrls.contains(url)).toList();
              return _VerificationResult(rejectedUrls: rejectedUrls);
          }
          
          if (attempt == 0 && stillPresentUrls.length == uploadedUrlMap.length) {
              break;
          }

          attempt++;
        }
      }

      statusController.add('Finalizing profile...');

      final bioTopicsData = <String, String>{};
      for (var topic in _bioControllers.keys) {
        if (_bioControllers[topic]!.text.trim().isNotEmpty) {
          bioTopicsData[topic] = _bioControllers[topic]!.text.trim();
        }
      }

      final validImageUrls = _imageSources.whereType<String>().toList();

      double? heightCm;
      if (_heightController.text.isNotEmpty) {
        final height = double.parse(_heightController.text);
        heightCm = _selectedMetricSystem == 'Imperial' ? height * 2.54 : height;
      }

      double? weightKg;
      if (_weightController.text.isNotEmpty) {
        final weight = double.parse(_weightController.text);
        weightKg = _selectedMetricSystem == 'Imperial' ? weight / 2.20462 : weight;
      }

      String? ethnicityValue;
      if (_selectedEthnicity == 'Prefer to self-describe') {
        ethnicityValue = _selfDescribedEthnicityController.text.trim();
      } else {
        ethnicityValue = _selectedEthnicity;
      }

      final profileData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text),
        'image_urls': validImageUrls,
        'best_photo_index': _selectedBestPhoto,
        'gender': _selectedGender,
        'pronouns': _selectedPronouns,
        'ethnicity': ethnicityValue,
        'bio_topics': bioTopicsData,
        'dominant_hand': {'value': _selectedDominantHand, 'show': _showDominantHand},
        'device_preference': {'value': _selectedDevicePreference, 'show': _showDevicePreference},
        'work': {'value': _workController.text.trim(), 'show': _showWork},
        'religion': {'value': _religionController.text.trim(), 'show': _showReligion},
        'height_cm': {'value': heightCm, 'show': _showHeight},
        'weight_kg': {'value': weightKg, 'show': _showWeight},
        'interested_in': _interestedIn,
        'metric_system': _selectedMetricSystem,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // THE FIX: Remove is_verified from the payload
      profileData.remove('is_verified');

      final response = await Supabase.instance.client.rpc('handle_profile_upsert', params: {'profile_data': profileData});

      return _VerificationResult(profile: Profile.fromJson(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
      rethrow;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields.')),
      );
      return;
    }
    if (_imageSources.where((s) => s != null).length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least 3 photos.')),
      );
      return;
    }

    final statusController = StreamController<String>();
    
    _VerificationResult? result;
    try {
        result = await showDaaymnLoadingDialog<_VerificationResult>(
        context: context,
        statusStream: statusController.stream,
        future: _runVerification(statusController),
      );
    } catch (e) {
       // Error is already handled and shown in _runVerification
    }
    
    if (mounted && result != null) {
      final nonNullResult = result;
      if (nonNullResult.profile != null) {
        // This is the fix: Call the location update in the background
        _updateLocationInBackground(); 
        widget.onProfileSaved(nonNullResult.profile!);
      } else if (nonNullResult.rejectedUrls.isNotEmpty) {
        _handleImageRejections(nonNullResult.rejectedUrls);
        Future.delayed(Duration.zero, () {
          if(mounted) {
            _showMultipleImageRejectionDialog(nonNullResult.rejectedUrls);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An unknown error occurred while saving.')),
        );
      }
    }

    if (!statusController.isClosed) {
      statusController.close();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCircularPhotoUploader() {
    int uploadedCount = _imageSources.where((i) => i != null).length;
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
    final source = _imageSources[index];
    final isBestPhoto = (_selectedBestPhoto - 1) == index;

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
    final bestPhotoIndex = _selectedBestPhoto - 1;
    if (bestPhotoIndex < 0 || bestPhotoIndex >= _imageSources.length) {
      return const SizedBox.shrink();
    }

    final source = _imageSources[bestPhotoIndex];
    if (source == null) {
      return const SizedBox.shrink();
    }

    Widget imageContent;
    if (source is XFile) {
      imageContent = Image.file(File(source.path), fit: BoxFit.cover);
    } else if (source is String) {
      imageContent = Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 48, color: Colors.white70),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(height: 48, thickness: 1, color: Colors.black26),
        Text(
          'Your Star Photo',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontFamily: 'Pacifico',
              ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageContent,
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Star of the Show',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  String? _validateNotOnlyNumbers(String? value) {
    if (value != null && value.trim().isNotEmpty && RegExp(r'^[0-9\s]+$').hasMatch(value)) {
      return 'Please enter text, not just numbers.';
    }
    return null;
  }

  Widget _buildOptionalTextField({
    required TextEditingController controller,
    required String labelText,
    required bool value,
    required ValueChanged<bool?> onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: '$labelText (Optional)', border: const OutlineInputBorder()),
          inputFormatters: inputFormatters,
          validator: validator,
          keyboardType: inputFormatters?.contains(FilteringTextInputFormatter.digitsOnly) ?? false
              ? TextInputType.number
              : TextInputType.text,
        ),
        CheckboxListTile(
          title: const Text('Display on profile'),
          value: value,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildOptionalDropdownField<T>({
    required T? value,
    required String labelText,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool showValue,
    required ValueChanged<bool?> onShowChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          isExpanded: true, 
          value: value,
          decoration: InputDecoration(labelText: '$labelText (Optional)', border: const OutlineInputBorder()),
          items: items.map((T item) => DropdownMenuItem<T>(value: item, child: Text(item.toString()))).toList(),
          onChanged: onChanged,
        ),
        CheckboxListTile(
          title: const Text('Display on profile'),
          value: showValue,
          onChanged: onShowChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final heightLabel = _selectedMetricSystem == 'Imperial' ? 'Height (in)' : 'Height (cm)';
    final weightLabel = _selectedMetricSystem == 'Imperial' ? 'Weight (lbs)' : 'Weight (kg)';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(fontFamily: 'Pacifico', color: Colors.white, fontSize: 30)),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 80),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Photos'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildWarningWidget(),
                        const SizedBox(height: 16),
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

                _buildSectionHeader('The Essentials'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Please enter your name';
                              if (RegExp(r'^[0-9\s]+$').hasMatch(value)) return 'Name cannot be only numbers';
                              return null;
                            }),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: _ageController,
                            decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your age';
                              if (int.tryParse(value) == null || int.parse(value) < 18) return 'You must be at least 18';
                              return null;
                            }),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(isExpanded: true, value: _selectedGender, decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()), items: _genders.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() => _selectedGender = newValue), validator: (value) => value == null ? 'Please select a gender' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(isExpanded: true, value: _selectedPronouns, decoration: const InputDecoration(labelText: 'Pronouns', border: OutlineInputBorder()), items: _pronouns.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() => _selectedPronouns = newValue), validator: (value) => value == null ? 'Please select pronouns' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedEthnicity,
                          decoration: const InputDecoration(labelText: 'Ethnicity', border: OutlineInputBorder()),
                          items: _ethnicities.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedEthnicity = newValue;
                              if (_selectedEthnicity != 'Prefer to self-describe') {
                                _selfDescribedEthnicityController.clear();
                              }
                            });
                          },
                          validator: (value) => value == null ? 'Please select an ethnicity' : null,
                        ),
                        if (_selectedEthnicity == 'Prefer to self-describe') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _selfDescribedEthnicityController,
                            decoration: const InputDecoration(labelText: 'Please describe', border: OutlineInputBorder()),
                            validator: (value) {
                              if (_selectedEthnicity == 'Prefer to self-describe' && (value == null || value.trim().isEmpty)) {
                                return 'Please enter your ethnicity';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedMetricSystem,
                          decoration: const InputDecoration(labelText: 'Measurement System', border: OutlineInputBorder()),
                          items: _metricSystems.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                          onChanged: (newValue) => setState(() => _selectedMetricSystem = newValue!),
                          validator: (value) => value == null ? 'Please select a measurement system' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                _buildSectionHeader('About Me (Optional)'),
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
                            validator: _validateNotOnlyNumbers,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                _buildSectionHeader('More About You (Optional)'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildOptionalTextField(
                          controller: _workController,
                          labelText: 'Work',
                          value: _showWork,
                          onChanged: (newValue) => setState(() => _showWork = newValue!),
                          validator: _validateNotOnlyNumbers,
                        ),
                        const SizedBox(height: 16),
                        _buildOptionalTextField(
                          controller: _religionController,
                          labelText: 'Religion',
                          value: _showReligion,
                          onChanged: (newValue) => setState(() => _showReligion = newValue!),
                          validator: _validateNotOnlyNumbers,
                        ),
                        const SizedBox(height: 16),
                        _buildOptionalTextField(
                          controller: _heightController,
                          labelText: heightLabel,
                          value: _showHeight,
                          onChanged: (newValue) => setState(() => _showHeight = newValue!),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 16),
                        _buildOptionalTextField(
                          controller: _weightController,
                          labelText: weightLabel,
                          value: _showWeight,
                          onChanged: (newValue) => setState(() => _showWeight = newValue!),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 16),
                        _buildOptionalDropdownField<String>(
                          value: _selectedDominantHand,
                          labelText: 'Dominant Hand',
                          items: _dominantHands,
                          onChanged: (newValue) => setState(() => _selectedDominantHand = newValue),
                          showValue: _showDominantHand,
                          onShowChanged: (newValue) => setState(() => _showDominantHand = newValue!),
                        ),
                        const SizedBox(height: 16),
                        _buildOptionalDropdownField<String>(
                          value: _selectedDevicePreference,
                          labelText: 'Device Preference',
                          items: _devicePreferences,
                          onChanged: (newValue) => setState(() => _selectedDevicePreference = newValue),
                          showValue: _showDevicePreference,
                          onShowChanged: (newValue) => setState(() => _showDevicePreference = newValue!),
                        ),
                      ],
                    ),
                  ),
                ),

                _buildSectionHeader('Core Preference'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Interested In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ...['Male', 'Female', 'Other'].map((gender) => CheckboxListTile(
                              title: Text(gender),
                              value: _interestedIn.contains(gender),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _interestedIn.add(gender);
                                  } else {
                                    _interestedIn.remove(gender);
                                  }
                                });
                              },
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveProfile,
        icon: const Icon(Icons.save),
        label: const Text('Save Changes'),
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
    final paint = Paint()..shader = const SweepGradient(colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)], startAngle: -pi / 2, endAngle: 3 * pi / 2, tileMode: TileMode.repeated).createShader(rect)..style = PaintingStyle.fill;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, true, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Small helper extension used by dropdown label formatting.
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
