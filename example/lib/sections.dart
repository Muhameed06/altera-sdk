import 'package:flutter/material.dart';

/// Demo content sections. Each is a plain widget — the SDK needs no special
/// base class, only a stable id supplied via RemoteNode.

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      // Text/icon colors are INHERITED (no hardcoded color) so a per-node style
      // override from the editor (textColor / fontSize / fontWeight) wins.
      child: Row(
        children: [
          Icon(icon, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Opacity(opacity: 0.8, child: Text(subtitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedSection extends StatelessWidget {
  const FeaturedSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Featured',
        subtitle: 'Editor-curated picks of the week',
        color: Color(0xFF5B8CFF),
        icon: Icons.star_rounded,
      );
}

class MusicSection extends StatelessWidget {
  const MusicSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Music',
        subtitle: 'Your daily mixes and new releases',
        color: Color(0xFFEC4899),
        icon: Icons.music_note_rounded,
      );
}

class FavoritesSection extends StatelessWidget {
  const FavoritesSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Favorites',
        subtitle: 'Everything you loved, in one place',
        color: Color(0xFFF59E0B),
        icon: Icons.favorite_rounded,
      );
}

class RecentsSection extends StatelessWidget {
  const RecentsSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Recently Played',
        subtitle: 'Jump back in where you left off',
        color: Color(0xFF34D399),
        icon: Icons.history_rounded,
      );
}

// ── Search screen sections ──
class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Trending',
        subtitle: 'What everyone is listening to now',
        color: Color(0xFF6366F1),
        icon: Icons.trending_up_rounded,
      );
}

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Categories',
        subtitle: 'Browse by genre and mood',
        color: Color(0xFF14B8A6),
        icon: Icons.grid_view_rounded,
      );
}

class RecentSearchesSection extends StatelessWidget {
  const RecentSearchesSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Recent Searches',
        subtitle: 'Pick up where you left off',
        color: Color(0xFF8B5CF6),
        icon: Icons.search_rounded,
      );
}

// ── Profile screen sections ──
class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Alex Morgan',
        subtitle: 'Premium member since 2021',
        color: Color(0xFFF43F5E),
        icon: Icons.person_rounded,
      );
}

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Your Stats',
        subtitle: '1,204 hours · 320 artists this year',
        color: Color(0xFF0EA5E9),
        icon: Icons.bar_chart_rounded,
      );
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Settings',
        subtitle: 'Account, playback, and privacy',
        color: Color(0xFF64748B),
        icon: Icons.settings_rounded,
      );
}

// ── Library screen sections ──
class PlaylistsSection extends StatelessWidget {
  const PlaylistsSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Playlists',
        subtitle: 'Your handcrafted collections',
        color: Color(0xFFF97316),
        icon: Icons.queue_music_rounded,
      );
}

class AlbumsSection extends StatelessWidget {
  const AlbumsSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Albums',
        subtitle: 'Saved albums and EPs',
        color: Color(0xFF06B6D4),
        icon: Icons.album_rounded,
      );
}

class DownloadsSection extends StatelessWidget {
  const DownloadsSection({super.key});
  @override
  Widget build(BuildContext context) => const _SectionCard(
        title: 'Downloads',
        subtitle: 'Available offline',
        color: Color(0xFF22C55E),
        icon: Icons.download_rounded,
      );
}
