import 'package:flutter/foundation.dart';
import 'package:daaymn/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  Profile? _profile;
  bool _isLoading = true;
  String? _error;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProfileProvider() {
    // Initial fetch when the provider is first created
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _error = "User not logged in.";
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _profile = Profile.fromJson(response);
        _error = null;
      } else {
        _profile = null; // Explicitly set to null if no profile found
        _error = "No profile found for the current user.";
      }
    } catch (e) {
      _error = "An error occurred while fetching the profile: $e";
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
