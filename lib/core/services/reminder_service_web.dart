// This implementation is selected only for Flutter Web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import '../utils/schedule_helpers.dart';
import 'reminder_types.dart';

ReminderService createReminderService() => _WebReminderService();

class _WebReminderService implements ReminderService {
  final Map<int, Timer> _timers = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission == 'granted') return true;
    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  }

  @override
  Future<void> schedule(ReminderRequest request) async {
    await cancel(request.id);
    if (!html.Notification.supported ||
        html.Notification.permission != 'granted') {
      return;
    }
    _arm(request);
  }

  void _arm(ReminderRequest request) {
    final now = DateTime.now();
    final next = nextReminderDate(
      now: now,
      hour: request.hour,
      minute: request.minute,
      weekday: request.weekday,
    );
    _timers[request.id] = Timer(next.difference(now), () {
      html.Notification(
        'موعد WATM',
        body: request.title,
        tag: 'watm-${request.id}',
      );
      _arm(request);
    });
  }

  @override
  Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
  }
}
