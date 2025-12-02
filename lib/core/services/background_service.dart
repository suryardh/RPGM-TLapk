import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../translator_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'rpgm_channel', 'Translation Service',
    description: 'Background Translation',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'rpgm_channel',
      initialNotificationTitle: 'RPGM Translator',
      initialNotificationContent: 'Ready...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final notifPlugin = FlutterLocalNotificationsPlugin();

  service.on('startTranslation').listen((event) async {
    if (event == null) return;
    String path = event['path'];
    List<String> keys = List<String>.from(event['apiKeys']);
    
    // Map<String, dynamic> jadi Map<String, bool>
    Map<String, dynamic> rawScope = event['scope'];
    Map<String, bool> scope = rawScope.map((k, v) => MapEntry(k, v as bool));

    final translator = TranslatorService(keys);
    
    await for (final status in translator.processGame(path, scope)) {
      // Update UI
      service.invoke('update', status);
      
      // Update Notif
      if (status['progress'] != null) {
        int p = ((status['progress'] as double) * 100).toInt();
        notifPlugin.show(
          888, 'Translating...', 'Progress: $p% | ${status['log']}',
          NotificationDetails(android: AndroidNotificationDetails(
            'rpgm_channel', 'Translation Service',
            showProgress: true, maxProgress: 100, progress: p,
            ongoing: true, icon: 'ic_bg_service_small',
          )),
        );
      }
      
      if (status['status'] == 'completed') {
        service.invoke('completed', status);
        notifPlugin.show(888, 'Selesai!', 'File tersimpan: ${status['path']}',
            NotificationDetails(android: AndroidNotificationDetails('rpgm_channel', 'Translation Service')));
        service.stopSelf();
      }
    }
  });
}
