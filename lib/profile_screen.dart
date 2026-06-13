import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';
import 'stats_service.dart';

class ProfileScreen extends StatefulWidget {
  final List<Map<String, dynamic>> reminders;
  final bool isModeActive;
  final DateTime? activationTime;

  /// Map of reminder index -> accumulated seconds (legacy, kept for compat)
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
    // Обновляем каждые 5 секунд, пока экран открыт
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
    final streak  = await stats.getCurrentStreak();

    final List<_ReminderStat> entries = [];
    for (final r in widget.reminders) {
      final title = r['title'] as String;
      final pct   = await stats.getReminderPercent(title);
      final (fired, completed) = await stats.getReminderRaw(title);
      entries.add(_ReminderStat(
        title:     title,
        icon:      r['icon'] as IconData,
        percent:   pct,
        fired:     fired,
        completed: completed,
      ));
    }

    if (mounted) {
      setState(() {
        _overallPercent = overall;
        _streak         = streak;
        _reminderStats
          ..clear()
          ..addAll(entries);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Вкладка «Сегодня» ──────────────────────────────────────────
              Text(
                'СЕГОДНЯ',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // ── Блок 1: Большой процент ─────────────────────────────────────
              _buildOverallBlock(),
              const SizedBox(height: 24),

              // ── Блок 2: Streak ──────────────────────────────────────────────
              _buildStreakBlock(),
              const SizedBox(height: 32),

              // ── Настройки ───────────────────────────────────────────────────
              Text(
                'НАСТРОЙКИ',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingToggle(
                'Звуковые уведомления',
                Icons.volume_up,
                AppSettings.soundEnabled,
                (v) => setState(() => AppSettings.soundEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildSettingToggle(
                'Вибрация',
                Icons.vibration,
                AppSettings.vibroEnabled,
                (v) => setState(() => AppSettings.vibroEnabled = v),
              ),
              const SizedBox(height: 32),

              // ── Блок 3: Список напоминаний ──────────────────────────────────
              Text(
                'НАПОМИНАНИЯ',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Выполнение за сегодня',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 10,
                  color: AppTheme.textMuted.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),

              if (_reminderStats.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Пока нет данных.\nВключите режим активности!',
                      textAlign: TextAlign.center,
                      style: AppTheme.spaceGrotesk.copyWith(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                )
              else
                ..._reminderStats.map((stat) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildReminderRow(stat),
                    )),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Блок 1: Общий процент ─────────────────────────────────────────────────

  Widget _buildOverallBlock() {
    final pct = _overallPercent;
    final pctInt = pct.round();

    // Цвет процента: красноватый при низком, акцент при высоком
    final Color pctColor = pct >= 80
        ? AppTheme.accent
        : pct >= 50
            ? AppTheme.textPrimary
            : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: pct >= 80 ? AppTheme.accent.withOpacity(0.4) : AppTheme.border,
          width: pct >= 80 ? 1.5 : 1,
        ),
        boxShadow: pct >= 80
            ? [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            '$pctInt%',
            textAlign: TextAlign.center,
            style: AppTheme.newsreader.copyWith(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: pctColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ВЫПОЛНЕНО СЕГОДНЯ',
            textAlign: TextAlign.center,
            style: AppTheme.spaceGrotesk.copyWith(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Прогресс-бар
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: pctColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Блок 2: Streak ─────────────────────────────────────────────────────────

  Widget _buildStreakBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Text(
            '🔥',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_streak ${_pluralDays(_streak)}',
                style: AppTheme.newsreader.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _streak > 0 ? AppTheme.accent : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'STREAK · ПОДРЯД ≥ 80%',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pluralDays(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
    return 'дней';
  }

  // ── Строка напоминания ─────────────────────────────────────────────────────

  Widget _buildReminderRow(_ReminderStat stat) {
    final pctInt = stat.percent.round();
    final Color pctColor = stat.percent >= 80
        ? AppTheme.accent
        : stat.percent >= 50
            ? AppTheme.textPrimary
            : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stat.icon, color: AppTheme.textPrimary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stat.title,
                  style: AppTheme.newsreader.copyWith(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '$pctInt%',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pctColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Прогресс-бар
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (stat.percent / 100).clamp(0.02, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: pctColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          if (stat.fired > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${stat.completed} из ${stat.fired} подтверждено',
              style: AppTheme.spaceGrotesk.copyWith(
                fontSize: 10,
                color: AppTheme.textMuted.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Настройки (сохранены из старого ProfileScreen) ─────────────────────────

  Widget _buildSettingToggle(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTheme.spaceGrotesk
                  .copyWith(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Модель данных одной строки статистики ──────────────────────────────────

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
