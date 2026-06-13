import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис статистики дисциплины.
/// Отвечает за:
/// - хранение totalFired / totalCompleted для каждого напоминания
/// - подсчёт дневного процента выполнения
/// - расчёт streak (кол-во дней подряд с >= 80%)
/// - ежедневный сброс счётчиков
/// - ограничение: не более 6 подтверждений в час для одного напоминания
class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  // ─── Ключи SharedPreferences ───────────────────────────────────────────────
  static const _keyFired     = 'stats_fired';      // Map<String, int> (JSON)
  static const _keyCompleted = 'stats_completed';  // Map<String, int> (JSON)
  static const _keyStreak    = 'stats_streak';     // int
  static const _keyLastReset = 'stats_last_reset'; // String (yyyy-MM-dd)

  // Для ограничения накрутки: хранит список timestamp'ов (int, ms) подтверждений
  // за текущую сессию. Очищается при ежедневном сбросе.
  // Ключ: 'stats_completions_timestamps_<reminderId>'
  static String _keyTimestamps(String id) => 'stats_completions_ts_$id';

  // ─── Вспомогательные методы ────────────────────────────────────────────────

  Future<Map<String, int>> _getMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _setMap(String key, Map<String, int> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(map));
  }

  Future<List<int>> _getTimestamps(String reminderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTimestamps(reminderId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _setTimestamps(String reminderId, List<int> ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimestamps(reminderId), jsonEncode(ts));
  }

  // ─── Проверка лимита 6 выполнений в час ────────────────────────────────────

  /// Возвращает true, если лимит НЕ превышен и статистику можно увеличивать.
  Future<bool> _checkAndRegisterCompletion(String reminderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneHourAgo = now - const Duration(hours: 1).inMilliseconds;

    var timestamps = await _getTimestamps(reminderId);
    // Оставляем только те, что были за последний час
    timestamps = timestamps.where((ts) => ts > oneHourAgo).toList();

    if (timestamps.length >= 6) {
      // Лимит исчерпан — не добавляем, но сохраняем актуальный список
      await _setTimestamps(reminderId, timestamps);
      return false;
    }

    // Всё ок — регистрируем новое подтверждение
    timestamps.add(now);
    await _setTimestamps(reminderId, timestamps);
    return true;
  }

  // ─── Публичный API ─────────────────────────────────────────────────────────

  /// Увеличить счётчик фактических срабатываний уведомления.
  Future<void> incrementFired(String reminderId) async {
    final map = await _getMap(_keyFired);
    map[reminderId] = (map[reminderId] ?? 0) + 1;
    await _setMap(_keyFired, map);
  }

  /// Увеличить счётчик подтверждённых выполнений.
  /// Соблюдает ограничение 6 подтверждений в час — если лимит превышен,
  /// счётчик не увеличивается (но визуально ничего не меняется для пользователя).
  Future<void> incrementCompleted(String reminderId) async {
    final withinLimit = await _checkAndRegisterCompletion(reminderId);
    if (!withinLimit) return;

    final map = await _getMap(_keyCompleted);
    map[reminderId] = (map[reminderId] ?? 0) + 1;
    await _setMap(_keyCompleted, map);
  }

  /// Процент выполнения для конкретного напоминания (0..100).
  Future<double> getReminderPercent(String reminderId) async {
    final fired     = await _getMap(_keyFired);
    final completed = await _getMap(_keyCompleted);
    final f = fired[reminderId] ?? 0;
    final c = completed[reminderId] ?? 0;
    if (f == 0) return 0.0;
    return (c / f * 100).clamp(0.0, 100.0);
  }

  /// Суммарный процент выполнения за день по всем напоминаниям (0..100).
  Future<double> getOverallPercent() async {
    final fired     = await _getMap(_keyFired);
    final completed = await _getMap(_keyCompleted);

    int totalFired     = 0;
    int totalCompleted = 0;

    for (final id in fired.keys) {
      totalFired     += fired[id]!;
      totalCompleted += completed[id] ?? 0;
    }

    if (totalFired == 0) return 0.0;
    return (totalCompleted / totalFired * 100).clamp(0.0, 100.0);
  }

  /// Текущий streak (дней подряд с >= 80% выполнения).
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStreak) ?? 0;
  }

  /// Получить все ID напоминаний, по которым есть статистика.
  Future<Set<String>> getTrackedIds() async {
    final fired = await _getMap(_keyFired);
    return fired.keys.toSet();
  }

  /// Ежедневная проверка: если день изменился — сохраняет итог, пересчитывает streak,
  /// сбрасывает дневные счётчики. Вызывать при запуске приложения.
  Future<void> checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final lastReset = prefs.getString(_keyLastReset);

    if (lastReset == today) return; // Ничего не изменилось

    // День изменился — подводим итог
    if (lastReset != null) {
      // Считаем процент за истёкший день
      final overallPercent = await getOverallPercent();

      // Пересчитываем streak
      int streak = prefs.getInt(_keyStreak) ?? 0;
      if (overallPercent >= 80.0) {
        streak += 1;
      } else {
        streak = 0;
      }
      await prefs.setInt(_keyStreak, streak);
    }

    // Сбрасываем дневные счётчики
    await _setMap(_keyFired, {});
    await _setMap(_keyCompleted, {});

    // Очищаем все timestamp'ы подтверждений
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('stats_completions_ts_')) {
        await prefs.remove(key);
      }
    }

    // Сохраняем дату последнего сброса
    await prefs.setString(_keyLastReset, today);
  }

  /// Полная статистика по напоминанию: [fired, completed].
  Future<(int fired, int completed)> getReminderRaw(String reminderId) async {
    final fired     = await _getMap(_keyFired);
    final completed = await _getMap(_keyCompleted);
    return (fired[reminderId] ?? 0, completed[reminderId] ?? 0);
  }

  // ─── Утилиты ───────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
