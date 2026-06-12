import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  final List<Map<String, dynamic>> reminders;
  final bool isModeActive;
  final DateTime? activationTime;
  /// Map of reminder index -> accumulated seconds
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
  String userName = 'Пользователь';
  bool darkMode = true;

  String _formatStatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '$hч $mм';
    if (m > 0) return '$mм';
    return '<1м';
  }

  @override
  Widget build(BuildContext context) {
    // Build sorted habit stats list
    final statEntries = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.reminders.length; i++) {
      final secs = widget.habitStats[i] ?? 0;
      statEntries.add({
        'title': widget.reminders[i]['title'],
        'icon': widget.reminders[i]['icon'],
        'seconds': secs,
      });
    }
    statEntries.sort((a, b) => (b['seconds'] as int).compareTo(a['seconds'] as int));
    final maxSeconds = statEntries.isNotEmpty
        ? (statEntries.first['seconds'] as int)
        : 1;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar + Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.accent, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.person, color: AppTheme.accent, size: 40),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _editName(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: AppTheme.newsreader.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit, color: AppTheme.textMuted, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isModeActive ? '● РЕЖИМ АКТИВЕН' : '○ РЕЖИМ ВЫКЛЮЧЕН',
                    style: AppTheme.spaceGrotesk.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: widget.isModeActive ? AppTheme.accent : AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Settings Section
            Text(
              'НАСТРОЙКИ',
              style: AppTheme.spaceGrotesk.copyWith(
                fontSize: 10,
                letterSpacing: 2,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingToggle('Звуковые уведомления', Icons.volume_up, AppSettings.soundEnabled, (v) {
              setState(() => AppSettings.soundEnabled = v);
            }),
            const SizedBox(height: 8),
            _buildSettingToggle('Вибрация', Icons.vibration, AppSettings.vibroEnabled, (v) {
              setState(() => AppSettings.vibroEnabled = v);
            }),
            const SizedBox(height: 36),

            // Stats Section
            Text(
              'МОНИТОРИНГ ДИСЦИПЛИНЫ',
              style: AppTheme.spaceGrotesk.copyWith(
                fontSize: 10,
                letterSpacing: 2,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Общее время выполнения привычек',
              style: AppTheme.spaceGrotesk.copyWith(
                fontSize: 10,
                color: AppTheme.textMuted.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),

            if (statEntries.isEmpty)
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
              ...statEntries.map((stat) {
                final secs = stat['seconds'] as int;
                final fraction = maxSeconds > 0 ? secs / maxSeconds : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildStatBar(
                    stat['title'] as String,
                    stat['icon'] as IconData,
                    _formatStatTime(secs),
                    fraction,
                  ),
                );
              }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
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
              style: AppTheme.spaceGrotesk.copyWith(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildStatBar(String title, IconData icon, String time, double fraction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTheme.newsreader.copyWith(fontSize: 16, color: AppTheme.textPrimary),
              ),
            ),
            Text(
              time,
              style: AppTheme.spaceGrotesk.copyWith(
                fontSize: 12,
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.02, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editName(BuildContext context) {
    final controller = TextEditingController(text: userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Имя', style: AppTheme.newsreader.copyWith(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTheme.spaceGrotesk.copyWith(color: AppTheme.textPrimary),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.border),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ОТМЕНА', style: AppTheme.spaceGrotesk.copyWith(color: AppTheme.textMuted, fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => userName = controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text('OK', style: AppTheme.spaceGrotesk.copyWith(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
