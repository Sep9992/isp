import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;

// ─── WorkManager callback (musí být top-level funkce) ───────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'dailyMealCheck') {
      await _checkAndNotify();
    }
    return Future.value(true);
  });
}

// Parsuje objednané jídlo z HTML jídelníčku
Future<String?> _parseTodayMeal(String html) async {
  try {
    // Hledáme třídu menuGridRowOrdered
    final RegExp mealRegex = RegExp(
      r'menuGridRowOrdered[^>]*>.*?menuGridRowMeal[^>]*>.*?openDetail\([^)]+\)[^>]*>([^<]+)<',
      dotAll: true,
    );
    final match = mealRegex.firstMatch(html);
    if (match != null) {
      return match.group(1)?.trim();
    }
  } catch (_) {}
  return null;
}

// Zjistí jestli je den pracovní (Po-Pá)
bool _isWeekday(DateTime date) {
  return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
}

// Vrátí datum zítřka nebo pondělí (pokud je pátek/víkend)
DateTime _getNextWorkday(DateTime from) {
  DateTime next = from.add(const Duration(days: 1));
  while (!_isWeekday(next)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

// Formátuje datum pro URL: d.M.yyyy
String _formatDateForUrl(DateTime date) {
  return '${date.day}.${date.month}.${date.year}';
}

// Hlavní logika kontroly a odeslání notifikace
Future<void> _checkAndNotify() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) return;

    // Inicializace notifikací
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final now = DateTime.now();
    final tomorrow = _getNextWorkday(now);

    // Stáhneme jídelníček pro dnešek
    String? todayMeal;
    String? tomorrowMeal;

    try {
      final todayUrl = 'https://isp.mlsoft.cz/web/cateringmenu.htm';
      final todayResp = await http.get(Uri.parse(todayUrl))
          .timeout(const Duration(seconds: 10));
      if (todayResp.statusCode == 200) {
        todayMeal = await _parseTodayMeal(todayResp.body);
      }
    } catch (_) {}

    try {
      // Pro zítřek použijeme datum v URL přes POST filterTargetDate
      final tomorrowResp = await http.post(
        Uri.parse('https://isp.mlsoft.cz/web/cateringmenu.htm'),
        body: {'filterTargetDate': _formatDateForUrl(tomorrow)},
      ).timeout(const Duration(seconds: 10));
      if (tomorrowResp.statusCode == 200) {
        tomorrowMeal = await _parseTodayMeal(tomorrowResp.body);
      }
    } catch (_) {}

    // Sestavíme text notifikace
    String title;
    String body;

    if (todayMeal != null && todayMeal.isNotEmpty) {
      title = '🍽️ Dnes máš oběd';
      body = todayMeal;
    } else {
      title = '⚠️ Dnes nemáš objednáno!';
      body = 'Nezapomeň si objednat oběd.';
    }

    // Přidáme upozornění na zítřek pokud není objednáno
    if (tomorrowMeal == null || tomorrowMeal.isEmpty) {
      final nextLabel = tomorrow.weekday == DateTime.monday ? 'Pondělí' : 'Zítra';
      body += '\n⚠️ $nextLabel nemáš objednáno!';
    }

    // Odešleme notifikaci
    const androidDetails = AndroidNotificationDetails(
      'meal_reminder',
      'Připomenutí oběda',
      channelDescription: 'Denní připomenutí objednaného oběda',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await plugin.show(42, title, body, details);
  } catch (e) {
    debugPrint('Notification error: $e');
  }
}

// ─── NotificationService ─────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Vyžádáme oprávnění na Android 13+
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    // Inicializujeme WorkManager
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // Naplánujeme denní kontrolu
    await scheduleDailyCheck();
  }

  // Naplánuje každodenní kontrolu v nastaveném čase
  Future<void> scheduleDailyCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;

    // Nejdřív zrušíme existující task
    await Workmanager().cancelByUniqueName('dailyMealCheck');

    if (!enabled) return;

    final hour = prefs.getInt('notification_hour') ?? 10;
    final minute = prefs.getInt('notification_minute') ?? 0;

    // Spočítáme zpoždění do příštího spuštění
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    final delay = next.difference(now);

    await Workmanager().registerOneOffTask(
      'dailyMealCheck',
      'dailyMealCheck',
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  // Okamžité zobrazení notifikace (pro test)
  Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id_1',
      'Obecné notifikace',
      channelDescription: 'Notifikace o objednávkách',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _plugin.show(
      0, title, body,
      const NotificationDetails(android: androidDetails),
    );
  }

  // Test notifikace — odešle okamžitě
  Future<void> sendTestNotification() async {
    await showNotification(
      '🍽️ Test notifikace',
      'Notifikace fungují správně!',
    );
  }
}