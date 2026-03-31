import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  // Singleton pattern (aby existovala jen jedna instance)
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Inicializace časových zón
    tz.initializeTimeZones();

    // Nastavení pro Android (použijeme ikonu aplikace, která se jmenuje 'ic_launcher')
    // Ujisti se, že máš vygenerovanou ikonu z předchozích kroků
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Nastavení pro iOS (vyžádá si povolení při prvním spuštění)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Na Androidu 13+ si musíme vyžádat práva ručně (zjednodušená verze)
    final androidImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      androidImplementation.requestNotificationsPermission();
    }
  }

  // Funkce pro okamžité zobrazení notifikace (pro test)
  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'channel_id_1', // Unikátní ID kanálu
      'Obecné notifikace', // Jméno kanálu pro uživatele
      channelDescription: 'Notifikace o objednávkách',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // ID notifikace
      title,
      body,
      notificationDetails,
    );
  }
}