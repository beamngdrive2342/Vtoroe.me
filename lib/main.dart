import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';
import 'profile_screen.dart';
import 'stats_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await StatsService().checkDailyReset();
  runApp(const SecondSelfApp());
}

class AppTheme {
  static const Color background = Color(0xFF0E0E0E);
  static const Color surface = Color(0xFF131313);
  static const Color accent = Color(0xFFD4FF4A);
  static const Color border = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textMuted = Color(
    0xFF656464,
  ); // Adjusted for better visibility
  static const Color darkText = Color(0xFF0E0E0E);

  static TextStyle get newsreader => GoogleFonts.newsreader(color: textPrimary);
  static TextStyle get inter => GoogleFonts.inter(color: textPrimary);
  static TextStyle get spaceGrotesk =>
      GoogleFonts.spaceGrotesk(color: textPrimary);
}

// ==========================================
// APP SETTINGS
// ==========================================
class AppSettings {
  static bool vibroEnabled = true;
  static bool soundEnabled = true;

  static void vibrateLight() {
    if (vibroEnabled) HapticFeedback.lightImpact();
  }
  static void vibrateMedium() {
    if (vibroEnabled) HapticFeedback.mediumImpact();
  }
  static void vibrateSelection() {
    if (vibroEnabled) HapticFeedback.selectionClick();
  }
}

class SecondSelfApp extends StatelessWidget {
  const SecondSelfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Второе Я',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accent,
          surface: AppTheme.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.background,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ==========================================
// MAIN SCREEN
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isModeActive = false;
  DateTime? activationTime;
  Timer? _timer;
  Timer? _statsTimer;
  int _currentTab = 0;

  /// Accumulated seconds per reminder index
  final Map<int, int> habitStats = {};

  // ── Оверлей подтверждения ──────────────────────────────────────────────────
  int?    activeReminderId;
  String? activeReminderTitle;
  DateTime? activeReminderStartedAt;
  int     _overlaySecondsLeft = 30;
  Timer?  _overlayTimer;

  final List<Map<String, dynamic>> reminders = [
    {
      'title': 'Выровняй спину',
      'subtitle': '30 М',
      'icon': Icons.accessibility_new,
      'isActive': true,
    },
    {
      'title': 'Попей воду',
      'subtitle': '60 М',
      'icon': Icons.water_drop,
      'isActive': true,
    },
    {
      'title': 'Не закуривай',
      'subtitle': '120 М',
      'icon': Icons.smoke_free,
      'isActive': true,
    },
    {
      'title': 'Разомнись',
      'subtitle': '60 М',
      'icon': Icons.self_improvement,
      'isActive': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Регистрируем callback: при каждом срабатывании уведомления
    NotificationService().onReminderFired = _onReminderFired;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statsTimer?.cancel();
    _overlayTimer?.cancel();
    NotificationService().onReminderFired = null;
    NotificationService().stopAll();
    super.dispose();
  }

  // ── Логика оверлея ─────────────────────────────────────────────────────────

  /// Вызывается из NotificationService при каждом фактическом срабатывании таймера.
  void _onReminderFired(int reminderId, String reminderTitle, DateTime fireTime) {
    // Увеличиваем totalFired в статистике
    StatsService().incrementFired(reminderTitle);

    // Если оверлей уже показывается — закрываем предыдущий (пропущен) и открываем новый
    _closeOverlay(confirmed: false);

    setState(() {
      activeReminderId       = reminderId;
      activeReminderTitle    = reminderTitle;
      activeReminderStartedAt = fireTime;
      _overlaySecondsLeft    = 30 - DateTime.now().difference(fireTime).inSeconds;
    });

    _overlayTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final secondsLeft = 30 - DateTime.now().difference(activeReminderStartedAt!).inSeconds;
      if (secondsLeft != _overlaySecondsLeft) {
        setState(() {
          _overlaySecondsLeft = secondsLeft;
        });
      }
      if (_overlaySecondsLeft <= 0) {
        timer.cancel();
        _closeOverlay(confirmed: false);
      }
    });
  }

  void _closeOverlay({required bool confirmed}) {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    if (activeReminderId != null) {
      NotificationService().dismissNotification(activeReminderId!);
    }
    if (mounted) {
      setState(() {
        activeReminderId      = null;
        activeReminderTitle   = null;
        activeReminderStartedAt = null;
        _overlaySecondsLeft   = 30;
      });
    }
  }

  void _confirmAction() {
    AppSettings.vibrateMedium();
    if (activeReminderTitle != null) {
      StatsService().incrementCompleted(activeReminderTitle!);
    }
    _closeOverlay(confirmed: true);
  }

  void _startNotifications() {
    final ns = NotificationService();
    ns.requestPermission();
    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i]['isActive'] == true) {
        final dur = ns.parseFrequency(reminders[i]['subtitle']);
        if (dur != null) {
          ns.startPeriodicReminder(i, reminders[i]['title'], dur);
        }
      }
    }
  }

  void _stopNotifications() {
    NotificationService().stopAll();
  }

  void _startStatsAccumulator() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (int i = 0; i < reminders.length; i++) {
        if (reminders[i]['isActive'] == true) {
          habitStats[i] = (habitStats[i] ?? 0) + 1;
        }
      }
    });
  }

  void _stopStatsAccumulator() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hoursч $minutesм $secondsс';
    } else if (minutes > 0) {
      return '$minutesм $secondsс';
    } else {
      return '$secondsс';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOverlay = activeReminderId != null;

    return Stack(
      children: [
        Scaffold(
          appBar: _currentTab == 0
              ? AppBar(
                  title: Text(
                    'ВТОРОЕ-Я',
                    style: AppTheme.newsreader.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  centerTitle: true,
                )
              : null,
          body: _currentTab == 0
              ? _buildHomeBody()
              : ProfileScreen(
                  reminders: reminders,
                  isModeActive: isModeActive,
                  activationTime: activationTime,
                  habitStats: habitStats,
                ),
          bottomNavigationBar: Container(
            height: 60,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                _buildNavItem(0, Icons.home, 'ГЛАВНАЯ'),
                _buildNavItem(1, Icons.person_outline, 'ПРОФИЛЬ'),
              ],
            ),
          ),
        ),
        if (showOverlay) _buildConfirmationOverlay(),
      ],
    );
  }

  Widget _buildConfirmationOverlay() {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: AppTheme.background.withOpacity(0.93),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Название напоминания
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  activeReminderTitle ?? '',
                  textAlign: TextAlign.center,
                  style: AppTheme.newsreader.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ВЫПОЛНИ СЕЙЧАС',
                textAlign: TextAlign.center,
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 11,
                  letterSpacing: 2.5,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 56),

              // Большой обратный отсчёт
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _overlaySecondsLeft <= 10
                          ? AppTheme.accent.withOpacity(0.6)
                          : AppTheme.border,
                      width: _overlaySecondsLeft <= 10 ? 2 : 1,
                    ),
                    boxShadow: _overlaySecondsLeft <= 10
                        ? [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.12),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_overlaySecondsLeft',
                    style: AppTheme.spaceGrotesk.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: _overlaySecondsLeft <= 10
                          ? AppTheme.accent
                          : AppTheme.textPrimary,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'секунд',
                textAlign: TextAlign.center,
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 64),

              // Кнопка СДЕЛАЛ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GestureDetector(
                  onTap: _confirmAction,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'СДЕЛАЛ  ✓',
                      style: AppTheme.spaceGrotesk.copyWith(
                        color: AppTheme.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Пропустить
              GestureDetector(
                onTap: () => _closeOverlay(confirmed: false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'ПРОПУСТИТЬ',
                    textAlign: TextAlign.center,
                    style: AppTheme.spaceGrotesk.copyWith(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: AppTheme.textMuted,
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppSettings.vibrateLight();
          setState(() => _currentTab = index);
        },
        child: Container(
          color: isSelected ? AppTheme.surface : AppTheme.background,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTheme.spaceGrotesk.copyWith(
                    fontSize: 12,
                    color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Mode Banner
          GestureDetector(
            onTap: () {
              AppSettings.vibrateMedium();
              setState(() {
                isModeActive = !isModeActive;
                if (isModeActive) {
                  activationTime = DateTime.now();
                  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                    setState(() {});
                  });
                  _startNotifications();
                  _startStatsAccumulator();
                } else {
                  _timer?.cancel();
                  _timer = null;
                  _stopNotifications();
                  _stopStatsAccumulator();
                }
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  decoration: BoxDecoration(
                    color: isModeActive
                        ? AppTheme.accent.withOpacity(0.92)
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isModeActive
                          ? AppTheme.accent
                          : Colors.white.withOpacity(0.14),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isModeActive ? 'РЕЖИМ АКТИВЕН' : 'ВТОРОЕ Я',
                                style: AppTheme.newsreader.copyWith(
                                  color: isModeActive
                                      ? AppTheme.darkText
                                      : AppTheme.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isModeActive
                                  ? '${_formatDuration(DateTime.now().difference(activationTime!))} • В НОРМЕ'
                                  : 'НАЖМИТЕ ДЛЯ СТАРТА',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.spaceGrotesk.copyWith(
                                color: isModeActive
                                    ? AppTheme.darkText.withOpacity(0.7)
                                    : AppTheme.textMuted,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isModeActive
                              ? AppTheme.darkText.withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isModeActive
                                ? AppTheme.darkText.withOpacity(0.35)
                                : Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Icon(
                          isModeActive ? Icons.stop : Icons.play_arrow,
                          color: isModeActive
                              ? AppTheme.darkText
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Reminders Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'НАПОМИНАНИЯ',
                style: AppTheme.spaceGrotesk.copyWith(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: AppTheme.textMuted,
                ),
              ),
              GestureDetector(
                onTap: () {
                  AppSettings.vibrateMedium();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SettingsScreen(title: '', isNew: true),
                    ),
                  ).then((newReminder) {
                    if (newReminder != null) {
                      setState(() {
                        reminders.add(newReminder);
                      });
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: AppTheme.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'ДОБАВИТЬ',
                        style: AppTheme.spaceGrotesk.copyWith(
                          color: AppTheme.accent,
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reminders List
          ...reminders.asMap().entries.map((entry) {
            final index = entry.key;
            final r = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ReminderCard(
                title: r['title'],
                subtitle: r['subtitle'],
                icon: r['icon'],
                isActive: r['isActive'],
                onTap: () {
                  AppSettings.vibrateLight();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        title: r['title'],
                        subtitle: r['subtitle'],
                        isNew: false,
                      ),
                    ),
                  ).then((updated) {
                    if (updated != null) {
                      setState(() {
                        reminders[index]['subtitle'] = updated['subtitle'];
                      });
                    }
                  });
                },
                onToggle: (val) {
                  AppSettings.vibrateLight();
                  setState(() {
                    reminders[index]['isActive'] = val;
                  });
                  // Live toggle: start/stop notification if mode is on
                  if (isModeActive) {
                    final ns = NotificationService();
                    if (val) {
                      final dur = ns.parseFrequency(reminders[index]['subtitle']);
                      if (dur != null) {
                        ns.startPeriodicReminder(index, reminders[index]['title'], dur);
                      }
                    } else {
                      ns.stopReminder(index);
                    }
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const ReminderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.surface
            : AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive
              ? AppTheme.border
              : AppTheme.border.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 24, bottom: 24, right: 8),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                      size: 28,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTheme.newsreader.copyWith(
                              fontSize: 22,
                              color: isActive
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTheme.spaceGrotesk.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppToggle(value: isActive, onChanged: onToggle),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatefulWidget {
  final String title;
  final String subtitle; // current subtitle to pre-fill
  final bool isNew;
  const SettingsScreen({
    super.key,
    required this.title,
    this.subtitle = '',
    this.isNew = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _titleController;
  late int selectedMinutes;  // 10..480

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);

    selectedMinutes = 30;

    if (widget.subtitle.isNotEmpty) {
      final parts = widget.subtitle.split('•');
      final dur = NotificationService().parseFrequency(parts[0].trim());
      if (dur != null) {
        // Snap to nearest valid value
        final target = dur.inMinutes;
        selectedMinutes = FrequencyRoulette.values.reduce(
          (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            widget.isNew
                ? TextField(
                    controller: _titleController,
                    style: AppTheme.newsreader.copyWith(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    cursorColor: AppTheme.accent,
                    decoration: InputDecoration(
                      hintText: 'НАЗВАНИЕ',
                      hintStyle: AppTheme.newsreader.copyWith(
                        fontSize: 36,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    widget.title.toUpperCase(),
                    style: AppTheme.newsreader.copyWith(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            const SizedBox(height: 40),

            // Frequency Section — drum roulette
            Text(
              'ЧАСТОТА НАПОМИНАНИЙ',
              style: AppTheme.spaceGrotesk.copyWith(
                fontSize: 10,
                letterSpacing: 2,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            FrequencyRoulette(
              selectedMinutes: selectedMinutes,
              onChanged: (m) => setState(() => selectedMinutes = m),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: const Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            final subtitle = '$selectedMinutes М';
            if (widget.isNew) {
              if (_titleController.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'title': _titleController.text.trim(),
                'subtitle': subtitle,
                'icon': Icons.notifications_active,
                'isActive': true,
              });
            } else {
              Navigator.pop(context, {
                'title': widget.title,
                'subtitle': subtitle,
              });
            }
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              'СОХРАНИТЬ  ✓',
              style: AppTheme.spaceGrotesk.copyWith(
                color: AppTheme.darkText,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// APP TOGGLE (единый тумблер везде)
// ==========================================
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppSettings.vibrateLight();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
          border: Border.all(
            color: value ? AppTheme.accent : AppTheme.border,
            width: value ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: value ? AppTheme.accent : AppTheme.textMuted.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// FREQUENCY ROULETTE (горизонтальная)
// ==========================================
class FrequencyRoulette extends StatefulWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  const FrequencyRoulette({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
  });

  // Фиксированный список значений (минимум 10 минут)
  static const List<int> values = [
    10, 15, 20, 30, 45, 60,
    90, 120, 150, 180, 210, 240, 270, 300,
  ];

  static String label(int m) {
    if (m < 60) return '$m мин';
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) return '$h ч';
    return '$h ч\n$rem м';
  }

  @override
  State<FrequencyRoulette> createState() => _FrequencyRouletteState();
}

class _FrequencyRouletteState extends State<FrequencyRoulette> {
  late final FixedExtentScrollController _controller;
  static const double _itemW = 80.0;
  static const double _itemH = 72.0;

  @override
  void initState() {
    super.initState();
    final idx = FrequencyRoulette.values.indexOf(widget.selectedMinutes);
    _controller = FixedExtentScrollController(initialItem: idx >= 0 ? idx : 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _itemH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotatedBox(
            quarterTurns: -1,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: _itemW,
              diameterRatio: 2.5,
              perspective: 0.005,
              useMagnifier: true,
              magnification: 1.25,
              squeeze: 1.15,
              overAndUnderCenterOpacity: 0.35,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (idx) {
                AppSettings.vibrateSelection();
                widget.onChanged(FrequencyRoulette.values[idx]);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: FrequencyRoulette.values.length,
                builder: (context, index) {
                  final m = FrequencyRoulette.values[index];
                  final isSelected = m == widget.selectedMinutes;
                  return RotatedBox(
                    quarterTurns: 1,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        child: Text(FrequencyRoulette.label(m)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Centre selector highlight
          IgnorePointer(
            child: Container(
              width: _itemW - 4,
              height: _itemH - 12,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.04),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.accent.withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.08),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
