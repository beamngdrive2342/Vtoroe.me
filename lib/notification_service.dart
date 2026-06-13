import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback для UI-оверлея (вызывается при тапе на уведомление когда приложение открыто)
  void Function(int reminderId, String reminderTitle, DateTime fireTime)? onReminderFired;

  /// Активные конфиги напоминаний (для отмены)
  final Map<int, _ReminderConfig> _activeConfigs = {};

  Future<void> init() async {
    // Инициализируем timezone
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Когда пользователь тапнул по уведомлению — вызываем callback
        final payload = details.payload;
        if (payload != null) {
          final parts = payload.split('|');
          if (parts.length == 2) {
            final id = int.tryParse(parts[0]);
            final title = parts[1];
            if (id != null) {
              onReminderFired?.call(id, title, DateTime.now());
            }
          }
        }
      },
    );

    // Создаём Android notification channel
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
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> dismissNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Parse frequency from subtitle like "30 М" or "1 Ч"
  Duration? parseFrequency(String subtitle) {
    final raw = subtitle.contains('•') ? subtitle.split('•').first : subtitle;
    final upper = raw.trim().toUpperCase();

    final regHour = RegExp(r'(\d+(?:\.\d+)?)\s*Ч');
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

  /// Запустить периодическое напоминание через системный планировщик Android.
  /// Планирует 48 уведомлений вперёд (≈24ч для 30-мин интервала).
  /// Работает даже когда приложение закрыто.
  Future<void> startPeriodicReminder(
      int id, String title, Duration interval) async {
    stopReminder(id);
    _activeConfigs[id] = _ReminderConfig(id: id, title: title, interval: interval);
    await _scheduleNext48(id, title, interval);
  }

  /// Планирует 48 уведомлений вперёд с шагом [interval].
  Future<void> _scheduleNext48(int id, String title, Duration interval) async {
    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < 48; i++) {
      final scheduledTime = now.add(interval * (i + 1));
      final notifId = id * 1000 + i;

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'vtoroe_ya_channel',
          'Второе Я',
          channelDescription: 'Напоминания для дисциплины',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          showWhen: true,
          when: scheduledTime.millisecondsSinceEpoch + 30000,
          usesChronometer: true,
          chronometerCountDown: true,
          timeoutAfter: 30000,
          styleInformation: const BigTextStyleInformation(''),
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id: notifId,
          scheduledDate: scheduledTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: '🔔 $title',
          body: 'Время для дисциплины!',
          payload: '$id|$title',
        );
      } catch (_) {
        // Если exact alarm недоступен — пробуем inexact
        try {
          await _plugin.zonedSchedule(
            id: notifId,
            scheduledDate: scheduledTime,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: '🔔 $title',
            body: 'Время для дисциплины!',
            payload: '$id|$title',
          );
        } catch (_) {
          // Пропустить это уведомление
        }
      }
    }
  }

  void stopReminder(int id) {
    _activeConfigs.remove(id);
    for (int i = 0; i < 48; i++) {
      _plugin.cancel(id: id * 1000 + i);
    }
  }

  void stopAll() {
    _activeConfigs.clear();
    _plugin.cancelAll();
  }
}

class _ReminderConfig {
  final int id;
  final String title;
  final Duration interval;
  const _ReminderConfig(
      {required this.id, required this.title, required this.interval});
}
