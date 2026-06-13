import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'main.dart' show AppTheme, AppSettings;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    AppSettings.vibrateMedium();
    setState(() => _isLoading = true);
    await AuthService().signInWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),

              // Название приложения
              Text(
                'ВТОРОЕ-Я',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),

              // Подзаголовок
              Text(
                'ДИСЦИПЛИНА КАЖДЫЙ ДЕНЬ',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              // Кнопка Google Sign In
              GestureDetector(
                onTap: _isLoading ? null : _handleSignIn,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? AppTheme.accent.withOpacity(0.7)
                        : AppTheme.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.darkText,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: AppTheme.darkText,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ВОЙТИ ЧЕРЕЗ GOOGLE',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppTheme.darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Примечание
              Text(
                'Войдя, вы соглашаетесь с условиями использования',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
