import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/firebase_member_service.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firestore_helpers.dart';
import '../../../../core/utils/schedule_helpers.dart';
import '../../../../core/widgets/watm_components.dart';
import '../../../../core/utils/live_query.dart';

class ScheduleReminderSync extends StatefulWidget {
  const ScheduleReminderSync({required this.userId, super.key});

  final String userId;

  @override
  State<ScheduleReminderSync> createState() => _ScheduleReminderSyncState();
}

class _ScheduleReminderSyncState extends State<ScheduleReminderSync> {
  Set<int> _knownIds = <int>{};
  String _lastSignature = '';

  Future<void> _sync(List<_ScheduleItem> items) async {
    final currentIds = items.map((item) => item.notificationId).toSet();
    for (final removedId in _knownIds.difference(currentIds)) {
      await reminderService.cancel(removedId);
    }
    for (final item in items) {
      if (item.reminderEnabled) {
        await reminderService.schedule(item.reminderRequest);
      } else {
        await reminderService.cancel(item.notificationId);
      }
    }
    _knownIds = currentIds;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
        'scheduleItems:${widget.userId}',
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('scheduleItems')
            .limit(50),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final items = snapshot.data!.docs
              .map(_ScheduleItem.fromDocument)
              .toList();
          final signature = items
              .map(
                (item) => [
                  item.id,
                  item.reminderEnabled,
                  item.frequency,
                  item.weekday,
                  item.hour,
                  item.minute,
                  item.title,
                ].join(':'),
              )
              .join('|');
          if (signature != _lastSignature) {
            _lastSignature = signature;
            WidgetsBinding.instance.addPostFrameCallback((_) => _sync(items));
          }
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class ScheduleSummary extends StatelessWidget {
  const ScheduleSummary({
    required this.userId,
    required this.onOpen,
    super.key,
  });

  final String userId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: LiveQuery.query(
        'scheduleItems:$userId',
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('scheduleItems')
            .limit(50),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: WatmCard(child: Text('تعذر تحميل الجدول الآن.')),
          );
        }
        final items = (snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map(_ScheduleItem.fromDocument)
            .toList();
        _ScheduleItem? nextItem;
        DateTime? nextDate;
        final now = DateTime.now();
        for (final item in items) {
          final candidate = nextReminderDate(
            now: now,
            hour: item.hour,
            minute: item.minute,
            weekday: item.frequency == 'weekly' ? item.weekday : null,
          );
          if (nextDate == null || candidate.isBefore(nextDate)) {
            nextDate = candidate;
            nextItem = item;
          }
        }

        final item = nextItem;
        final repeatText = item == null
            ? 'أضف مواعيدك اليومية والأسبوعية'
            : item.frequency == 'daily'
                ? 'يومياً'
                : 'كل ${arabicWeekdayName(item.weekday)}';
        final subtitle = item == null
            ? repeatText
            : '$repeatText • ${formatScheduleTime(item.hour, item.minute)}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(22),
              child: WatmCard(
                color: AppColors.seaSoft,
                borderColor: AppColors.sea,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.sea,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item == null ? 'نظّم جدولك' : 'موعدك القادم',
                            style: const TextStyle(
                              color: AppColors.universe,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item != null)
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: AppColors.universe,
                                fontSize: 13,
                              ),
                            ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.earth,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 17,
                      color: AppColors.seaAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SchedulePanel extends StatefulWidget {
  const SchedulePanel({required this.userId, super.key});

  final String userId;

  @override
  State<SchedulePanel> createState() => _SchedulePanelState();
}

class _SchedulePanelState extends State<SchedulePanel> {
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('scheduleItems');

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEditor({_ScheduleItem? item}) async {
    final draft = await showDialog<_ScheduleDraft>(
      context: context,
      builder: (_) => _ScheduleEditorDialog(item: item),
    );
    if (draft == null || !mounted) return;

    var reminderEnabled = draft.reminderEnabled;
    var permissionDenied = false;
    if (reminderEnabled) {
      reminderEnabled = await reminderService.requestPermission();
      permissionDenied = !reminderEnabled;
      // Same OS permission as local reminders, so this never shows a
      // second dialog — just registers this device for circle push
      // notifications (new member, encouragement) now that we know
      // notifications are wanted.
      if (reminderEnabled) {
        unawaited(FirebaseMemberService().requestPushPermissionAndSyncToken());
      }
    }
    if (!mounted) return;

    try {
      final reference = item?.reference ?? _collection.doc();
      final values = <String, Object?>{
        'title': draft.title,
        'frequency': draft.frequency,
        'hour': draft.time.hour,
        'minute': draft.time.minute,
        'weekday': draft.frequency == 'weekly'
            ? draft.weekday
            : FieldValue.delete(),
        'reminderEnabled': reminderEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (item == null) {
        values['createdAt'] = FieldValue.serverTimestamp();
      }
      await reference.set(values, SetOptions(merge: true));

      final request = ReminderRequest(
        id: stableNotificationId(reference.id),
        title: draft.title,
        hour: draft.time.hour,
        minute: draft.time.minute,
        weekday: draft.frequency == 'weekly' ? draft.weekday : null,
      );
      if (reminderEnabled) {
        await reminderService.schedule(request);
      } else {
        await reminderService.cancel(request.id);
      }
      if (!mounted) return;
      if (permissionDenied) {
        _showMessage(
          'تم حفظ الموعد، لكن التذكير متوقف لأن إذن الإشعارات لم يُمنح.',
        );
      } else {
        _showMessage(item == null ? 'تمت إضافة الموعد.' : 'تم تحديث الموعد.');
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage('تعذر حفظ الموعد (${error.code}).');
      }
    }
  }

  Future<void> _toggleReminder(_ScheduleItem item, bool enabled) async {
    if (enabled) {
      final granted = await reminderService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        _showMessage('فعّل إذن الإشعارات من إعدادات المتصفح أو الهاتف.');
        return;
      }
      unawaited(FirebaseMemberService().requestPushPermissionAndSyncToken());
    }
    try {
      await item.reference.update({
        'reminderEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (enabled) {
        await reminderService.schedule(item.reminderRequest);
      } else {
        await reminderService.cancel(item.notificationId);
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage('تعذر تحديث التذكير (${error.code}).');
      }
    }
  }

  Future<void> _deleteItem(_ScheduleItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الموعد'),
        content: Text('هل تريد حذف «${item.title}» من جدولك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await reminderService.cancel(item.notificationId);
      await item.reference.delete();
      if (mounted) _showMessage('تم حذف الموعد.');
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage('تعذر حذف الموعد (${error.code}).');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WatmCard(
          color: AppColors.seaSoft,
          borderColor: AppColors.sea,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.alarm_rounded, color: AppColors.seaAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'أضف مواعيدك وحدد وقت التذكير. على الهاتف يعمل التنبيه بعد إغلاق التطبيق، وعلى Chrome يجب إبقاء التطبيق مفتوحاً.',
                  style: TextStyle(color: AppColors.universe, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        WatmButton(
          label: 'إضافة موعد جديد',
          onPressed: () => _openEditor(),
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LiveQuery.query(
            'scheduleItems:${widget.userId}',
            _collection.limit(50),
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const WatmErrorCard(
                'تعذر تحميل الجدول. تحقق من الإنترنت.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: AppColors.sea),
                ),
              );
            }
            final items = snapshot.data!.docs
                .map(_ScheduleItem.fromDocument)
                .toList()
              ..sort(_compareScheduleItems);
            if (items.isEmpty) {
              return const WatmCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.sea,
                      size: 42,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'جدولك فارغ حالياً',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'أضف أول موعد يومي أو أسبوعي وحدد الوقت المناسب.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.earth, height: 1.6),
                    ),
                  ],
                ),
              );
            }

            final daily =
                items.where((item) => item.frequency == 'daily').toList();
            final weekly =
                items.where((item) => item.frequency == 'weekly').toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (daily.isNotEmpty) ...[
                  _ScheduleSectionTitle(
                    title: 'الجدول اليومي',
                    count: daily.length,
                  ),
                  const SizedBox(height: 10),
                  for (final item in daily) ...[
                    _ScheduleItemCard(
                      item: item,
                      onEdit: () => _openEditor(item: item),
                      onDelete: () => _deleteItem(item),
                      onToggleReminder: (value) =>
                          _toggleReminder(item, value),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (weekly.isNotEmpty) ...[
                  if (daily.isNotEmpty) const SizedBox(height: 10),
                  _ScheduleSectionTitle(
                    title: 'الجدول الأسبوعي',
                    count: weekly.length,
                  ),
                  const SizedBox(height: 10),
                  for (final item in weekly) ...[
                    _ScheduleItemCard(
                      item: item,
                      onEdit: () => _openEditor(item: item),
                      onDelete: () => _deleteItem(item),
                      onToggleReminder: (value) =>
                          _toggleReminder(item, value),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ScheduleSectionTitle extends StatelessWidget {
  const _ScheduleSectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Chip(
          backgroundColor: AppColors.natureSoft,
          label: Text('$count'),
        ),
      ],
    );
  }
}

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleReminder,
  });

  final _ScheduleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleReminder;

  @override
  Widget build(BuildContext context) {
    final repeatText = item.frequency == 'daily'
        ? 'يومياً'
        : 'كل ${arabicWeekdayName(item.weekday)}';
    return WatmCard(
      color: item.reminderEnabled ? AppColors.natureSoft : AppColors.white,
      borderColor:
          item.reminderEnabled ? AppColors.nature : AppColors.border,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.frequency == 'daily'
                  ? AppColors.seaSoft
                  : AppColors.nature,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              item.frequency == 'daily'
                  ? Icons.today_rounded
                  : Icons.date_range_rounded,
              color: AppColors.universe,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$repeatText • ${formatScheduleTime(item.hour, item.minute)}',
                  style: const TextStyle(
                    color: AppColors.earth,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch.adaptive(
                value: item.reminderEnabled,
                onChanged: onToggleReminder,
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الموعد',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditorDialog extends StatefulWidget {
  const _ScheduleEditorDialog({this.item});

  final _ScheduleItem? item;

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  late final TextEditingController _titleController;
  late String _frequency;
  late TimeOfDay _time;
  late int _weekday;
  late bool _reminderEnabled;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _frequency = item?.frequency ?? 'daily';
    _time = TimeOfDay(hour: item?.hour ?? 8, minute: item?.minute ?? 0);
    _weekday = item?.weekday ?? DateTime.sunday;
    _reminderEnabled = item?.reminderEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'إضافة موعد' : 'تعديل الموعد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المهمة أو الموعد',
                hintText: 'مثال: المشي لمدة 20 دقيقة',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'نوع التكرار',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('يومي'),
                  selected: _frequency == 'daily',
                  onSelected: (_) => setState(() => _frequency = 'daily'),
                ),
                ChoiceChip(
                  label: const Text('أسبوعي'),
                  selected: _frequency == 'weekly',
                  onSelected: (_) => setState(() => _frequency = 'weekly'),
                ),
              ],
            ),
            if (_frequency == 'weekly') ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'يوم الأسبوع'),
                items: [
                  for (var day = DateTime.monday;
                      day <= DateTime.sunday;
                      day++)
                    DropdownMenuItem(
                      value: day,
                      child: Text(arabicWeekdayName(day)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _weekday = value);
                },
              ),
            ],
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_rounded),
              title: const Text('وقت الموعد'),
              subtitle: Text(formatScheduleTime(_time.hour, _time.minute)),
              trailing: TextButton(
                onPressed: _pickTime,
                child: const Text('اختيار'),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _reminderEnabled,
              onChanged: (value) =>
                  setState(() => _reminderEnabled = value),
              title: const Text('منبّه للتذكير'),
              subtitle: const Text('إشعار عند حلول الموعد'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _ScheduleDraft(
                      title: _titleController.text.trim(),
                      frequency: _frequency,
                      time: _time,
                      weekday: _weekday,
                      reminderEnabled: _reminderEnabled,
                    ),
                  ),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _ScheduleDraft {
  const _ScheduleDraft({
    required this.title,
    required this.frequency,
    required this.time,
    required this.weekday,
    required this.reminderEnabled,
  });

  final String title;
  final String frequency;
  final TimeOfDay time;
  final int weekday;
  final bool reminderEnabled;
}

class _ScheduleItem {
  const _ScheduleItem({
    required this.id,
    required this.reference,
    required this.title,
    required this.frequency,
    required this.hour,
    required this.minute,
    required this.weekday,
    required this.reminderEnabled,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final String title;
  final String frequency;
  final int hour;
  final int minute;
  final int weekday;
  final bool reminderEnabled;

  int get notificationId => stableNotificationId(id);

  ReminderRequest get reminderRequest => ReminderRequest(
        id: notificationId,
        title: title,
        hour: hour,
        minute: minute,
        weekday: frequency == 'weekly' ? weekday : null,
      );

  factory _ScheduleItem.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final frequency =
        data['frequency']?.toString() == 'weekly' ? 'weekly' : 'daily';
    var weekday = parseIntOrZero(data['weekday']);
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      weekday = DateTime.sunday;
    }
    return _ScheduleItem(
      id: document.id,
      reference: document.reference,
      title: firstNonEmptyString(
        data,
        const ['title'],
        fallback: 'موعد صحي',
      ),
      frequency: frequency,
      hour: parseIntOrZero(data['hour']).clamp(0, 23).toInt(),
      minute: parseIntOrZero(data['minute']).clamp(0, 59).toInt(),
      weekday: weekday,
      reminderEnabled: data['reminderEnabled'] == true,
    );
  }
}

int _compareScheduleItems(_ScheduleItem first, _ScheduleItem second) {
  if (first.frequency != second.frequency) {
    return first.frequency == 'daily' ? -1 : 1;
  }
  if (first.frequency == 'weekly' && first.weekday != second.weekday) {
    return first.weekday.compareTo(second.weekday);
  }
  final firstMinutes = first.hour * 60 + first.minute;
  final secondMinutes = second.hour * 60 + second.minute;
  return firstMinutes.compareTo(secondMinutes);
}
