

class ProfileData {
  // Photo Upload Page
  List<dynamic> imageSources = List.filled(6, null);
  int selectedBestPhoto = 1;

  // Essentials Page
  String name = '';
  int? age;
  String? gender;
  String? pronouns;
  String? ethnicity;
  String? city;

  // About You Page
  Map<String, String> bioTopics = {};

  // Get Attention Page
  String work = '';
  bool showWork = true;
  String religion = '';
  bool showReligion = true;
  double? heightCm;
  bool showHeight = true;
  double? weightKg;
  bool showWeight = true;
  String? dominantHand;
  bool showDominantHand = true;
  String? devicePreference;
  bool showDevicePreference = true;

  // Interested In Page
  String? interestedIn;
}
