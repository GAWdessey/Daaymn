
import 'dart:async';
import 'package:daaymn/globals.dart';
import 'package:daaymn/profile_creation/profile_data_model.dart';
import 'package:daaymn/widgets/daaymn_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:daaymn/cryptography_service.dart' as crypto_service;

class InterestedInPage extends StatefulWidget {
  final Function(Profile) onProfileCreated;
  final ProfileData profileData;

  const InterestedInPage({
    super.key,
    required this.onProfileCreated,
    required this.profileData,
  });

  @override
  State<InterestedInPage> createState() => _InterestedInPageState();
}

class _InterestedInPageState extends State<InterestedInPage> {
  final List<String> _interestedIn = [];
  final crypto_service.CryptographyService _cryptographyService = crypto_service.CryptographyService();

  Future<void> _saveProfile() async {
    if (_interestedIn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select who you are interested in.')));
      return;
    }

    final statusController = StreamController<String>();

    final saveFuture = () async {
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        
        // Images are already uploaded and verified, just filter them
        final validImageUrls = widget.profileData.imageSources.whereType<String>().toList();

        statusController.add('Generating security keys...');
        final keyPair = await _cryptographyService.createKeyPair();
        await _cryptographyService.storeKeyPair(userId, keyPair);
        final publicKeyPem = _cryptographyService.encodePublicKeyToPem(keyPair.publicKey);

        statusController.add('Finalizing profile...');

        final profileData = <String, dynamic>{
          'name': widget.profileData.name,
          'age': widget.profileData.age,
          'image_urls': validImageUrls,
          'best_photo_index': widget.profileData.selectedBestPhoto,
          'gender': widget.profileData.gender,
          'pronouns': widget.profileData.pronouns,
          'ethnicity': widget.profileData.ethnicity,
          'city': widget.profileData.city,
          'bio_topics': widget.profileData.bioTopics,
          'dominant_hand': {'value': widget.profileData.dominantHand, 'show': widget.profileData.showDominantHand},
          'device_preference': {'value': widget.profileData.devicePreference, 'show': widget.profileData.showDevicePreference},
          'work': {'value': widget.profileData.work, 'show': widget.profileData.showWork},
          'religion': {'value': widget.profileData.religion, 'show': widget.profileData.showReligion},
          'height_cm': {'value': widget.profileData.heightCm, 'show': widget.profileData.showHeight},
          'weight_kg': {'value': widget.profileData.weightKg, 'show': widget.profileData.showWeight},
          'interested_in': _interestedIn,
          'public_key': publicKeyPem,
          'like_count': 6, // Set initial like count to 6
          'updated_at': DateTime.now().toIso8601String(),
        };

        final response = await Supabase.instance.client.rpc('handle_profile_upsert', params: {'profile_data': profileData});

        return Profile.fromJson(response);
      } catch (e) {
        rethrow;
      }
    }();

    showDaaymnLoadingDialog<Profile>(
      context: context,
      statusStream: statusController.stream,
      future: saveFuture,
    );

    try {
      final newProfile = await saveFuture;
      if (mounted) {
        widget.onProfileCreated(newProfile);
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An error occurred. Please check your connection and try again.'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } finally {
      statusController.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('I am interested in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Male'),
                      value: _interestedIn.contains('Male'),
                      onChanged: (value) => setState(() => value! ? _interestedIn.add('Male') : _interestedIn.remove('Male')),
                    ),
                    CheckboxListTile(
                      title: const Text('Female'),
                      value: _interestedIn.contains('Female'),
                      onChanged: (value) => setState(() => value! ? _interestedIn.add('Female') : _interestedIn.remove('Female')),
                    ),
                    CheckboxListTile(
                      title: const Text('Other'),
                      value: _interestedIn.contains('Other'),
                      onChanged: (value) => setState(() => value! ? _interestedIn.add('Other') : _interestedIn.remove('Other')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}
