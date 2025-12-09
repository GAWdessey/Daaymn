
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// --- Models ---

class Message {
  final int id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final String messageType;
  final bool isOtm;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.isRead,
    required this.messageType,
    required this.isOtm,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'].toString(),
      receiverId: json['receiver_id'].toString(),
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
      messageType: json['message_type'] ?? 'text',
      isOtm: json['is_otm'] ?? false,
    );
  }

  Message copyWith({
    int? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? createdAt,
    bool? isRead,
    String? messageType,
    bool? isOtm,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      isOtm: isOtm ?? this.isOtm,
    );
  }
}


// A generic class to hold optional profile details and their visibility.
class OptionalDetail<T> {
  final T value;
  final bool show;

  OptionalDetail({required this.value, required this.show});
}

class Profile {
  final String id;
  final String name;
  final int age;
  final DateTime? purchasedInfiniteScrollUntil;
  final DateTime? purchasedGhostModeUntil;
  final String? bio;
  final String? imageUrl;
  final List<String> imageUrls;
  final int? bestPhotoIndex;
  final String? gender;
  final String? pronouns;
  final String? ethnicity;
  final Map<String, String> bioTopics;
  final int likeCount;
  final DateTime? lastLikeGrantedAt;
  final String? publicKey;
  final List<String>? interestedIn;
  final bool isVerified;
  final bool isSubscribed;
  final String? metricSystem;
  final DateTime? lastSeen;
  final String? jobTitle;
  final List<String> interests;

  final OptionalDetail<String>? work;
  final OptionalDetail<String>? religion;
  final OptionalDetail<double>? heightCm;
  final OptionalDetail<double>? weightKg;
  final OptionalDetail<String>? dominantHand;
  final OptionalDetail<String>? devicePreference;

  // Fields for permanent and temporary rewards
  final bool hasPurchasedGhostMode;
  final bool isGhostModeEnabled;
  final DateTime? infiniteScrollUntil;
  final DateTime? ghostModeUntil;
  final DateTime? lastAdLikeAt;
  final DateTime? lastAdScrollAt;
  final DateTime? lastAdGhostAt;

  // New fields for subscriptions and reports
  final DateTime? subscriptionExpiresAt;
  final bool hasClaimedMonthlyReport;
  final String? monthlyReportCreditTier;
  final String? subscriptionTier;
  final DateTime? lastFreeReportClaimedAt;
  final double? lastClaimedScore;

  Profile({
    required this.id,
    required this.name,
    required this.age,
    this.bio,
    this.imageUrl,
    this.imageUrls = const [],
    this.bestPhotoIndex,
    this.gender,
    this.pronouns,
    this.ethnicity,
    this.bioTopics = const {},
    required this.likeCount,
    this.lastLikeGrantedAt,
    this.publicKey,
    this.interestedIn,
    this.isVerified = false,
    this.isSubscribed = false,
    this.metricSystem,
    this.lastSeen,
    this.jobTitle,
    this.interests = const [],
    this.work,
    this.religion,
    this.heightCm,
    this.weightKg,
    this.dominantHand,
    this.devicePreference,
    this.hasPurchasedGhostMode = false,
    this.isGhostModeEnabled = false,
    this.infiniteScrollUntil,
    this.ghostModeUntil,
    this.lastAdLikeAt,
    this.lastAdScrollAt,
    this.lastAdGhostAt,
    this.subscriptionExpiresAt,
    this.hasClaimedMonthlyReport = false,
    this.monthlyReportCreditTier,
    this.subscriptionTier,
    this.lastFreeReportClaimedAt,
    this.lastClaimedScore,
    this.purchasedInfiniteScrollUntil, // Added
    this.purchasedGhostModeUntil,      // Added
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    OptionalDetail<T>? parseOptionalDetail<T>(dynamic data) {
      if (data == null || data['value'] == null) return null;
      T value;
      if (T == int && data['value'] is num) {
        value = (data['value'] as num).toInt() as T;
      } else if (T == double && data['value'] is num) {
        value = (data['value'] as num).toDouble() as T;
      } else {
        value = data['value'] as T;
      }
      return OptionalDetail<T>(value: value, show: data['show'] ?? true);
    }

    Map<String, String> parseBioTopics(dynamic data) {
      if (data == null) return {};
      return Map<String, String>.from(data);
    }

    List<String> originalImageUrls = List<String>.from(json['image_urls'] ?? []);
    int? bestPhotoIndex = json['best_photo_index'];

    String? mainImageUrl;
    List<String> sortedImageUrls = List.from(originalImageUrls);

    if (bestPhotoIndex != null && bestPhotoIndex > 0 && bestPhotoIndex <= sortedImageUrls.length) {
      final bestPhotoUrl = sortedImageUrls.removeAt(bestPhotoIndex - 1);
      sortedImageUrls.insert(0, bestPhotoUrl);
      mainImageUrl = bestPhotoUrl;
    } else if (sortedImageUrls.isNotEmpty) {
      mainImageUrl = sortedImageUrls.first;
    }

    List<String>? interestedInList;
    final interestedInData = json['interested_in'];
    if (interestedInData is List) {
      interestedInList = List<String>.from(interestedInData.map((e) => e.toString()));
    }

    return Profile(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      bio: json['bio'],
      imageUrl: mainImageUrl,
      imageUrls: sortedImageUrls,
      bestPhotoIndex: bestPhotoIndex,
      gender: json['gender'],
      pronouns: json['pronouns'],
      ethnicity: json['ethnicity'],
      bioTopics: parseBioTopics(json['bio_topics']),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 6,
      lastLikeGrantedAt: json['last_like_granted_at'] != null ? DateTime.parse(json['last_like_granted_at']) : null,
      publicKey: json['public_key'],
      interestedIn: interestedInList,
      isVerified: json['is_verified'] ?? false,
      isSubscribed: json['is_subscribed'] ?? false,
      metricSystem: json['metric_system'],
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      jobTitle: json['job_title'],
      interests: List<String>.from(json['interests'] ?? []),
      work: parseOptionalDetail<String>(json['work']),
      religion: parseOptionalDetail<String>(json['religion']),
      heightCm: parseOptionalDetail<double>(json['height_cm']),
      weightKg: parseOptionalDetail<double>(json['weight_kg']),
      dominantHand: parseOptionalDetail<String>(json['dominant_hand']),
      devicePreference: parseOptionalDetail<String>(json['device_preference']),
      hasPurchasedGhostMode: json['has_purchased_ghost_mode'] ?? false,
      isGhostModeEnabled: json['is_ghost_mode_enabled'] ?? false,
      infiniteScrollUntil: json['infinite_scroll_until'] != null ? DateTime.parse(json['infinite_scroll_until']) : null,
      ghostModeUntil: json['ghost_mode_until'] != null ? DateTime.parse(json['ghost_mode_until']) : null,
      lastAdLikeAt: json['last_ad_like_at'] != null ? DateTime.parse(json['last_ad_like_at']) : null,
      lastAdScrollAt: json['last_ad_scroll_at'] != null ? DateTime.parse(json['last_ad_scroll_at']) : null,
      lastAdGhostAt: json['last_ad_ghost_at'] != null ? DateTime.parse(json['last_ad_ghost_at']) : null,
      subscriptionExpiresAt: json['subscription_expires_at'] != null ? DateTime.parse(json['subscription_expires_at']) : null,
      hasClaimedMonthlyReport: json['has_claimed_monthly_report'] ?? false,
      monthlyReportCreditTier: json['monthly_report_credit_tier'],
      subscriptionTier: json['subscription_tier'],
      lastFreeReportClaimedAt: json['last_free_report_claimed_at'] != null ? DateTime.parse(json['last_free_report_claimed_at']) : null,
      lastClaimedScore: (json['last_claimed_score'] as num?)?.toDouble(),
      // Added
      purchasedInfiniteScrollUntil: json['purchased_infinite_scroll_until'] != null ? DateTime.parse(json['purchased_infinite_scroll_until']) : null,
      purchasedGhostModeUntil: json['purchased_ghost_mode_until'] != null ? DateTime.parse(json['purchased_ghost_mode_until']) : null,
    );
  }

  Profile copyWith({
    String? id,
    String? name,
    int? age,
    String? bio,
    String? imageUrl,
    List<String>? imageUrls,
    int? bestPhotoIndex,
    String? gender,
    String? pronouns,
    String? ethnicity,
    Map<String, String>? bioTopics,
    int? likeCount,
    DateTime? lastLikeGrantedAt,
    String? publicKey,
    List<String>? interestedIn,
    bool? isVerified,
    bool? isSubscribed,
    String? metricSystem,
    DateTime? lastSeen,
    String? jobTitle,
    List<String>? interests,
    OptionalDetail<String>? work,
    OptionalDetail<String>? religion,
    OptionalDetail<double>? heightCm,
    OptionalDetail<double>? weightKg,
    OptionalDetail<String>? dominantHand,
    OptionalDetail<String>? devicePreference,
    bool? hasPurchasedGhostMode,
    bool? isGhostModeEnabled,
    DateTime? infiniteScrollUntil,
    DateTime? ghostModeUntil,
    DateTime? lastAdLikeAt,
    DateTime? lastAdScrollAt,
    DateTime? lastAdGhostAt,
    DateTime? subscriptionExpiresAt,
    bool? hasClaimedMonthlyReport,
    String? monthlyReportCreditTier,
    String? subscriptionTier,
    DateTime? lastFreeReportClaimedAt,
    double? lastClaimedScore,
    DateTime? purchasedInfiniteScrollUntil,
    DateTime? purchasedGhostModeUntil,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      bestPhotoIndex: bestPhotoIndex ?? this.bestPhotoIndex,
      gender: gender ?? this.gender,
      pronouns: pronouns ?? this.pronouns,
      ethnicity: ethnicity ?? this.ethnicity,
      bioTopics: bioTopics ?? this.bioTopics,
      likeCount: likeCount ?? this.likeCount,
      lastLikeGrantedAt: lastLikeGrantedAt ?? this.lastLikeGrantedAt,
      publicKey: publicKey ?? this.publicKey,
      interestedIn: interestedIn ?? this.interestedIn,
      isVerified: isVerified ?? this.isVerified,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      metricSystem: metricSystem ?? this.metricSystem,
      lastSeen: lastSeen ?? this.lastSeen,
      jobTitle: jobTitle ?? this.jobTitle,
      interests: interests ?? this.interests,
      work: work ?? this.work,
      religion: religion ?? this.religion,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      dominantHand: dominantHand ?? this.dominantHand,
      devicePreference: devicePreference ?? this.devicePreference,
      hasPurchasedGhostMode: hasPurchasedGhostMode ?? this.hasPurchasedGhostMode,
      isGhostModeEnabled: isGhostModeEnabled ?? this.isGhostModeEnabled,
      infiniteScrollUntil: infiniteScrollUntil ?? this.infiniteScrollUntil,
      ghostModeUntil: ghostModeUntil ?? this.ghostModeUntil,
      lastAdLikeAt: lastAdLikeAt ?? this.lastAdLikeAt,
      lastAdScrollAt: lastAdScrollAt ?? this.lastAdScrollAt,
      lastAdGhostAt: lastAdGhostAt ?? this.lastAdGhostAt,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      hasClaimedMonthlyReport: hasClaimedMonthlyReport ?? this.hasClaimedMonthlyReport,
      monthlyReportCreditTier: monthlyReportCreditTier ?? this.monthlyReportCreditTier,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      lastFreeReportClaimedAt: lastFreeReportClaimedAt ?? this.lastFreeReportClaimedAt,
      lastClaimedScore: lastClaimedScore ?? this.lastClaimedScore,
      purchasedInfiniteScrollUntil: purchasedInfiniteScrollUntil ?? this.purchasedInfiniteScrollUntil,
      purchasedGhostModeUntil: purchasedGhostModeUntil ?? this.purchasedGhostModeUntil,
    );
  }

  factory Profile.empty() => Profile(
    id: '',
    name: 'User',
    age: 0,
    likeCount: 6,
  );
}
