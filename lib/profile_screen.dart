import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'stats_service.dart';
import 'auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final List<Map<String, dynamic>> reminders;
  final bool isModeActive;
  final DateTime? activationTime;
  final Map<int, int> habitStats;

  const ProfileScreen({
    super.key,
    required this.reminders,
    required this.isModeActive,
    required this.activationTime,
    required this.habitStats,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _overallPercent = 0;
  int _streak = 0;
  final List<_ReminderStat> _reminderStats = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = StatsService();
    final overall = await stats.getOverallPercent();
    final streak = await stats.getCurrentStreak();

    final List<_ReminderStat> entries = [];
    for (final r in widget.reminders) {
      final title = r['title'] as String;
      final pct = await stats.getReminderPercent(title);
      final (fired, completed) = await stats.getReminderRaw(title);
      entries.add(_ReminderStat(
        title: title,
        icon: r['icon'] as IconData,
        percent: pct,
        fired: fired,
        completed: completed,
      ));
    }

    if (mounted) {
      setState(() {
        _overallPercent = overall;
        _streak = streak;
        _reminderStats
          ..clear()
          ..addAll(entries);
      });
    }
  }

  // _editName removed — name comes from Google account

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'ВТОРОЕ-Я',
          style: AppTheme.newsreader.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Header ────────────────────────────────────────────────
                _buildHeader(context),

                // ── 2. Divider ───────────────────────────────────────────────
                const Divider(color: AppTheme.border, height: 24),

                // ── 3. Карточки статистики ───────────────────────────────────
                _buildStatCards(),

                // ── 4. Напоминания ───────────────────────────────────────────
                const SizedBox(height: 24),
                Text(
                  'НАПОМИНАНИЯ',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildRemindersList(),

                const SizedBox(height: 32),

                // ── 5. Sign Out ─────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () {
                      AppSettings.vibrateLight();
                      _showLogoutDialog(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'ВЫЙТИ',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Диалог выхода ─────────────────────────────────────────────────────────

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Выйти из аккаунта?',
          style: GoogleFonts.newsreader(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы всегда сможете войти снова.',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textMuted,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'ОТМЕНА',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              AppSettings.vibrateLight();
              // Очищаем флаги обучения при выходе
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('onboarding_done');
              await prefs.remove('profile_onboarding_done');
              await AuthService().signOut();
            },
            child: Text(
              'ВЫЙТИ',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final name = AuthService().displayName;
    final photoUrl = AuthService().photoUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.accent, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: photoUrl != null
              ? Image.network(photoUrl, fit: BoxFit.cover)
              : const Icon(Icons.person, color: AppTheme.accent, size: 22),
        ),
        const SizedBox(width: 12),

        // Имя + статус
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                widget.isModeActive ? '● РЕЖИМ АКТИВЕН' : '○ РЕЖИМ ВЫКЛЮЧЕН',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: widget.isModeActive
                      ? AppTheme.accent
                      : AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Карточки статистики ───────────────────────────────────────────────────

  Widget _buildStatCards() {
    final pctInt = _overallPercent.round();
    final streakStr = _streak.toString();
    final daysSuffix = _pluralDays(_streak);

    return Row(
      children: [
        // Левая: процент
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pctInt%',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'СЕГОДНЯ',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Правая: streak
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: streakStr,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: ' $daysSuffix',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STREAK',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Список напоминаний ────────────────────────────────────────────────────

  Widget _buildRemindersList() {
    if (_reminderStats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Пока нет данных. Включите режим активности!',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: _reminderStats.asMap().entries.map((entry) {
        final i = entry.key;
        final stat = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: i < _reminderStats.length - 1 ? 8 : 0),
          child: _buildReminderRow(stat),
        );
      }).toList(),
    );
  }

  Widget _buildReminderRow(_ReminderStat stat) {
    final pctInt = stat.percent.round();
    final iconColor = stat.percent >= 50 ? AppTheme.textPrimary : AppTheme.textMuted;
    final pctColor = stat.percent >= 50 ? AppTheme.accent : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(stat.icon, color: iconColor, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stat.title,
              style: GoogleFonts.newsreader(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pctInt%',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pctColor,
            ),
          ),
        ],
      ),
    );
  }



  // ── Утилиты ───────────────────────────────────────────────────────────────

  String _pluralDays(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }
}

// ── Модель данных ─────────────────────────────────────────────────────────

class _ReminderStat {
  final String title;
  final IconData icon;
  final double percent;
  final int fired;
  final int completed;

  const _ReminderStat({
    required this.title,
    required this.icon,
    required this.percent,
    required this.fired,
    required this.completed,
  });
}
