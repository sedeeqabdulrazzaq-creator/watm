import 'reminder_service_stub.dart'
    if (dart.library.html) 'reminder_service_web.dart'
    if (dart.library.io) 'reminder_service_native.dart';
import 'reminder_types.dart';

export 'reminder_types.dart';

final ReminderService reminderService = createReminderService();
