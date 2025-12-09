import 'package:cached_network_image/cached_network_image.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/widgets/online_indicator.dart';
import 'package:daaymn/widgets/verified_badge.dart';
import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback? onDislike;
  final VoidCallback? onLike;
  final VoidCallback? onTap;
  final int? dislikeCount;
  final GlobalKey? likeKey;
  final GlobalKey? dislikeKey;
  final GlobalKey? dislikeCounterKey;
  final GlobalKey? verifiedBadgeKey;

  const ProfileCard({
    super.key,
    required this.profile,
    this.onDislike,
    this.onLike,
    this.onTap,
    this.dislikeCount,
    this.likeKey,
    this.dislikeKey,
    this.dislikeCounterKey,
    this.verifiedBadgeKey,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOnline = profile.lastSeen != null && DateTime.now().difference(profile.lastSeen!).inMinutes < 5;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 4 / 5, // This gives the card a fixed size, preventing the crash.
          child: Stack(
            children: [
              // Full-card background image
              Positioned.fill(
                child: (profile.imageUrl != null && profile.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: profile.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[800]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.person, size: 80, color: Colors.white30),
                        ),
                      )
                    : Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.person, size: 80, color: Colors.white30),
                ),
              ),
              // Protective gradient for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Profile information overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isOnline) const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: OnlineIndicator(size: 12),
                          ),
                          Flexible(
                            child: Text(
                              '${profile.name}, ${profile.age}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [const Shadow(blurRadius: 2, color: Colors.black54)],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          KeyedSubtree(
                            key: verifiedBadgeKey,
                            child: VerifiedBadge(profile: profile),
                          ),
                        ],
                      ),
                      if (profile.jobTitle != null && profile.jobTitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.work_outline, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  profile.jobTitle!,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, shadows: [const Shadow(blurRadius: 1, color: Colors.black87)]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (profile.interests.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: profile.interests.take(3).map((interest) => _buildInterestPill(interest)).toList(),
                          ),
                        ),
                      const SizedBox(height: 50), // Space for action buttons
                    ],
                  ),
                ),
              ),

              // Dislike/Like action buttons
              if (onLike != null && onDislike != null)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Row(
                    children: [
                      KeyedSubtree(
                        key: dislikeKey,
                        child: _buildActionButton(
                          icon: Icons.close,
                          color: Colors.white,
                          backgroundColor: Colors.red.withOpacity(0.9),
                          onPressed: onDislike!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      KeyedSubtree(
                        key: likeKey,
                        child: _buildActionButton(
                          icon: Icons.favorite,
                          color: Colors.white,
                          backgroundColor: Colors.pinkAccent.withOpacity(0.9),
                          onPressed: onLike!,
                        ),
                      ),
                    ],
                  ),
                ),

              // Dislike counter (if applicable)
              if (dislikeCount != null && dislikeCount! > 0)
                Positioned(
                  top: 16,
                  left: 16,
                  child: KeyedSubtree(
                    key: dislikeCounterKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.thumb_down, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            dislikeCount.toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestPill(String interest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: Text(
        interest,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: color.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }
}
