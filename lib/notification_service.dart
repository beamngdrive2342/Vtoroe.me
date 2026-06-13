import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final Map<int, Timer> _activeTimers = {};

  /// Callback, вызываемый каждый раз при фактическом срабатывании напоминания.
  /// Аргументы: reminderId (int), reminderTitle (String).
  void Function(int reminderId, String reminderTitle)? onReminderFired;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Create Android notification channel explicitly
    const channel = AndroidNotificationChannel(
      'vtoroe_ya_channel',
      'Второе Я',
      description: 'Напоминания для дисциплины',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> showNow(int id, String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vtoroe_ya_channel',
        'Второе Я',
        channelDescription: 'Напоминания для дисциплины',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Parse frequency from subtitle like "30 М • ВИБРО" or "30 М" or "1 Ч"
  Duration? parseFrequency(String subtitle) {
    // Take only the part before bullet if present
    final raw = subtitle.contains('•') ? subtitle.split('•').first : subtitle;
    final upper = raw.trim().toUpperCase();

    // Match digits followed by optional space then Ч (hour)
    final regHour = RegExp(r'(\d+(?:\.\d+)?)\s*Ч');
    // Match digits followed by optional space then М (minute)
    final regMin = RegExp(r'(\d+)\s*М');

    final hourMatch = regHour.firstMatch(upper);
    if (hourMatch != null) {
      final val = double.tryParse(hourMatch.group(1)!) ?? 0;
      return Duration(minutes: (val * 60).round());
    }
    final minMatch = regMin.firstMatch(upper);
    if (minMatch != null) {
      return Duration(minutes: int.parse(minMatch.group(1)!));
    }
    return null;
  }

  void startPeriodicReminder(int id, String title, Duration interval) {
    stopReminder(id);
    // Fire first notification immediately, then repeat
    _fireReminder(id, title);
    _activeTimers[id] = Timer.periodic(interval, (_) {
      _fireReminder(id, title);
    });
  }

  /// Внутренний метод: показывает уведомление и вызывает callback.
  void _fireReminder(int id, String title) {
    showNow(id, '🔔 $title', 'Время для дисциплины!');
    onReminderFired?.call(id, title);
  }

  void stopReminder(int id) {
    _activeTimers[id]?.cancel();
    _activeTimers.remove(id);
  }

  void stopAll() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _plugin.cancelAll();
  }
}
