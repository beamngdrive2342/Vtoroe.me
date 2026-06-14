import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show AppTheme, AppSettings;
import 'notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.add_circle_outline,
      title: 'ДОБАВЬ НАПОМИНАНИЕ',
      subtitle:
          'Нажми + чтобы добавить. Нажми на карточку чтобы настроить частоту',
    ),
    _OnboardingPage(
      icon: Icons.play_circle_outline,
      title: 'ВКЛЮЧИ РЕЖИМ',
      subtitle:
          'Нажми на большую кнопку на главном экране — напоминания начнут работать',
    ),
    _OnboardingPage(
      icon: Icons.timer_outlined,
      title: 'УСПЕЙ ЗА 15 СЕКУНД',
      subtitle:
          'Когда придёт уведомление — открой приложение и нажми «Сделал». Это засчитается',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    AppSettings.vibrateLight();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    AppSettings.vibrateMedium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    // Запрашиваем разрешения на уведомления и точные будильники
    await NotificationService().requestPermission();
    await NotificationService().requestExactAlarmPermission();
    // Запрашиваем исключение из оптимизации батареи (критично для фона)
    await NotificationService().requestBatteryOptimizationExemption();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.accent : AppTheme.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: GestureDetector(
                onTap: _nextPage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 56,
                  decoration: BoxDecoration(
                    color: isLast ? AppTheme.accent : AppTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: isLast
                        ? null
                        : Border.all(
                            color: AppTheme.accent.withOpacity(0.5),
                            width: 1,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isLast ? 'НАЧАТЬ' : 'ДАЛЕЕ →',
                    style: GoogleFonts.spaceGrotesk(
                      color: isLast ? AppTheme.darkText : AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            page.icon,
            size: 64,
            color: AppTheme.accent,
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// ==========================================
// PROFILE ONBOARDING SCREEN
// ==========================================
class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.percent,
      title: 'ЧТО ТАКОЕ %',
      subtitle:
          'Это процент выполнения: сколько раз ты нажал «Сделал» из всех уведомлений за сегодня. Сбрасывается каждый день',
    ),
    _OnboardingPage(
      icon: Icons.local_fire_department_outlined,
      title: 'ЧТО ТАКОЕ STREAK',
      subtitle:
          'Streak растёт, если каждый день выполняешь ≥ 80% напоминаний. Пропустишь день — streak обнулится',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart,
      title: 'СЛЕДИ ЗА ПРОГРЕССОМ',
      subtitle:
          'По каждому напоминанию виден отдельный %. Стремись держать всё выше 50% — это значит ты не забываешь',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    AppSettings.vibrateLight();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      AppSettings.vibrateMedium();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.accent : AppTheme.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: GestureDetector(
                onTap: _nextPage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 56,
                  decoration: BoxDecoration(
                    color: isLast ? AppTheme.accent : AppTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: isLast
                        ? null
                        : Border.all(
                            color: AppTheme.accent.withOpacity(0.5),
                            width: 1,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isLast ? 'ПОНЯЛ' : 'ДАЛЕЕ →',
                    style: GoogleFonts.spaceGrotesk(
                      color: isLast ? AppTheme.darkText : AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            page.icon,
            size: 64,
            color: AppTheme.accent,
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
