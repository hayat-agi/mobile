import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// Import flutter_local_notifications with a prefix to avoid the
// NotificationVisibility name clash with flutter_foreground_task.
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;

/// Manages the Android foreground service that keeps the Flutter engine —
/// and therefore the BLE connection + earthquake detection pipeline — alive
/// while the app is in the background or "closed" by the user.
///
/// This class is Android-only and is a no-op on any other platform.
///
/// Architecture note:
///   The TaskHandler isolate pattern from flutter_foreground_task is NOT used
///   here because BLE (flutter_blue_plus) and the entire detection pipeline
///   run exclusively in the main isolate. All we need is the persistent
///   foreground Service declaration so Android does not kill the process.
///   The `callback` parameter of startService is omitted intentionally so
///   no separate isolate is spawned.
class EarthquakeForegroundService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final EarthquakeForegroundService _instance =
      EarthquakeForegroundService._internal();
  factory EarthquakeForegroundService() => _instance;
  EarthquakeForegroundService._internal();

  // ── Notification IDs / channel IDs ──────────────────────────────────────
  static const int _earthquakeAlertNotificationId = 9001;
  static const String _alertChannelId = 'eq_alert';
  static const String _alertChannelName = 'Deprem Uyarısı';

  // ── Internal state ───────────────────────────────────────────────────────
  final fln.FlutterLocalNotificationsPlugin _localNotifications =
      fln.FlutterLocalNotificationsPlugin();

  bool _localNotificationsInitialized = false;

  // ── Initialization ───────────────────────────────────────────────────────

  /// Call once from main() before runApp().
  /// Initialises flutter_foreground_task and flutter_local_notifications.
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    // Configure flutter_foreground_task.
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'eq_detection_service',
        channelName: 'Deprem Algılama Servisi',
        channelDescription:
            'ESP32 sensöründen deprem algılama devam ediyor.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
      ),
    );

    // Initialise flutter_local_notifications for high-priority earthquake alerts.
    const fln.AndroidInitializationSettings androidInit =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const fln.InitializationSettings initSettings =
        fln.InitializationSettings(android: androidInit);

    await _localNotifications.initialize(initSettings);

    // Create the high-importance alert channel up front.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const fln.AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        importance: fln.Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    );

    _localNotificationsInitialized = true;
    debugPrint('[EarthquakeForegroundService] initialized');
  }

  // ── Service lifecycle ────────────────────────────────────────────────────

  /// Start the foreground service.
  /// Safe to call multiple times — ignored if already running.
  Future<void> startService() async {
    if (!Platform.isAndroid) return;

    final alreadyRunning = await FlutterForegroundTask.isRunningService;
    if (alreadyRunning) {
      debugPrint('[EarthquakeForegroundService] already running — skip start');
      return;
    }

    // Request notification permission (Android 13+).
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.connectedDevice],
      notificationTitle: 'Hayat Ağı',
      notificationText: 'Deprem algılama aktif',
    );

    if (result is ServiceRequestSuccess) {
      debugPrint('[EarthquakeForegroundService] foreground service started');
    } else {
      debugPrint(
          '[EarthquakeForegroundService] start failed: '
          '${(result as ServiceRequestFailure).error}');
    }
  }

  /// Update the persistent notification text without restarting the service.
  Future<void> updateNotification(String title, String text) async {
    if (!Platform.isAndroid) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Stop the foreground service.
  /// Only call this when the user explicitly turns off background detection.
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;

    final running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      debugPrint('[EarthquakeForegroundService] not running — skip stop');
      return;
    }

    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestSuccess) {
      debugPrint('[EarthquakeForegroundService] foreground service stopped');
    } else {
      debugPrint(
          '[EarthquakeForegroundService] stop failed: '
          '${(result as ServiceRequestFailure).error}');
    }
  }

  // ── Earthquake alert notification ────────────────────────────────────────

  /// Show a high-priority "heads-up" notification when an earthquake is
  /// detected. Works whether the app is in foreground, background, or
  /// screen-off.
  Future<void> showEarthquakeAlert({
    required double peakAcceleration,
    required DateTime timestamp,
  }) async {
    if (!Platform.isAndroid) return;
    if (!_localNotificationsInitialized) return;

    final String body =
        'Sarsıntı algılandı — zirve ivme: '
        '${peakAcceleration.toStringAsFixed(2)} m/s²';

    const fln.AndroidNotificationDetails androidDetails =
        fln.AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: 'Deprem uyarısı bildirimleri',
      importance: fln.Importance.max,
      priority: fln.Priority.high,
      ticker: 'DEPREM UYARISI',
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      visibility: fln.NotificationVisibility.public,
      autoCancel: true,
    );

    const fln.NotificationDetails details =
        fln.NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      _earthquakeAlertNotificationId,
      'DEPREM UYARISI',
      body,
      details,
    );

    debugPrint(
        '[EarthquakeForegroundService] earthquake alert notification shown');
  }
}
