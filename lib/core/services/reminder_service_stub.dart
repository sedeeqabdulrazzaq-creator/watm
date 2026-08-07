import 'reminder_types.dart';

ReminderService createReminderService() => _StubReminderService();

class _StubReminderService implements ReminderService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(ReminderRequest request) async {}

  @override
  Future<void> cancel(int id) async {}
}
