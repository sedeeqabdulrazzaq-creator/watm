class ReminderRequest {
  const ReminderRequest({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.weekday,
  });

  final int id;
  final String title;
  final int hour;
  final int minute;
  final int? weekday;
}

abstract class ReminderService {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> schedule(ReminderRequest request);

  Future<void> cancel(int id);
}
