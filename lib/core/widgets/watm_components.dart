import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WatmPage extends StatelessWidget {
  const WatmPage({
    required this.children,
    super.key,
    this.eyebrow,
    this.title,
    this.subtitle,
    this.onBack,
    this.bottom,
    this.scrollable = true,
    this.pinBottom = false,
  });

  final List<Widget> children;
  final String? eyebrow;
  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool scrollable;
  final bool pinBottom;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filledTonal(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              ),
            ),
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: const TextStyle(
                color: AppColors.sea,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.universe,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.earth,
                fontSize: 14,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 22),
          ],
          ...children,
          if (!pinBottom && bottom != null) ...[
            const SizedBox(height: 24),
            bottom!,
          ],
        ],
      ),
    );

    final pageContent = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: content,
          )
        : content;

    return ColoredBox(
      color: AppColors.warmBackground,
      child: SafeArea(
        child: pinBottom && bottom != null
            ? Column(
                children: [
                  Expanded(child: pageContent),
                  bottom!,
                ],
              )
            : pageContent,
      ),
    );
  }
}

class WatmButton extends StatelessWidget {
  const WatmButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final style = secondary
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.universe,
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.border),
          )
        : FilledButton.styleFrom(
            foregroundColor: AppColors.white,
            backgroundColor: AppColors.sea,
            disabledBackgroundColor: AppColors.muted,
            disabledForegroundColor: AppColors.earth,
          );
    final button = secondary
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : FilledButton(onPressed: onPressed, style: style, child: Text(label));

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: button,
    );
  }
}

class WatmChoice extends StatelessWidget {
  const WatmChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.caption,
  });

  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.seaSoft : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.sea : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.sea : AppColors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: selected ? AppColors.sea : AppColors.border,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: AppColors.white, size: 17)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.universe,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                      if (caption != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          caption!,
                          style: const TextStyle(
                            color: AppColors.earth,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WatmCard extends StatelessWidget {
  const WatmCard({
    required this.child,
    super.key,
    this.color = AppColors.white,
    this.borderColor = AppColors.border,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F2E47),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class WatmErrorCard extends StatelessWidget {
  const WatmErrorCard(this.message, {super.key, this.height});

  final String message;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return WatmCard(
      color: AppColors.errorSoft,
      borderColor: AppColors.errorBorder,
      child: Text(
        message,
        style: TextStyle(color: AppColors.errorText, height: height),
      ),
    );
  }
}

class WatmProgress extends StatelessWidget {
  const WatmProgress({required this.value, super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: value.clamp(0.0, 1.0).toDouble(),
        backgroundColor: AppColors.muted,
        valueColor: const AlwaysStoppedAnimation(AppColors.sky),
      ),
    );
  }
}

class WatmAvatar extends StatelessWidget {
  const WatmAvatar({
    required this.initial,
    super.key,
    this.needsSupport = false,
  });

  final String initial;
  final bool needsSupport;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFD),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F2E47),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.seaAccent,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        Positioned(
          left: -2,
          bottom: 1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: needsSupport ? AppColors.nature : AppColors.sky,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class WatmBottomNavigation extends StatelessWidget {
  const WatmBottomNavigation({
    required this.onCheckIn,
    super.key,
    this.activeIndex = 4,
    this.onAccount,
    this.onProgress,
    this.onSchedule,
    this.onCircle,
    this.onHome,
  });

  final VoidCallback onCheckIn;
  final int activeIndex;
  final VoidCallback? onAccount;
  final VoidCallback? onProgress;
  final VoidCallback? onSchedule;
  final VoidCallback? onCircle;
  final VoidCallback? onHome;

  VoidCallback? _callbackFor(int index) {
    return switch (index) {
      0 => onAccount,
      1 => onProgress,
      2 => onSchedule ?? onCheckIn,
      3 => onCircle,
      4 => onHome,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasSchedule = onSchedule != null;
    final labels = [
      'حسابي',
      'التقدم',
      hasSchedule ? 'جدولي' : 'تسجيل اليوم',
      'دائرتي',
      'الرئيسية',
    ];
    final icons = [
      Icons.person_outline,
      Icons.trending_up,
      hasSchedule ? Icons.calendar_month_outlined : Icons.add,
      Icons.groups_outlined,
      Icons.home_outlined,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(labels.length, (index) {
          final isPrimary = index == 2;
          final active = index == activeIndex || isPrimary;
          return Expanded(
            child: InkWell(
              onTap: _callbackFor(index),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? AppColors.sea
                      : active
                          ? AppColors.seaSoft
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(isPrimary ? 31 : 16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index],
                      size: isPrimary ? 23 : 20,
                      color: isPrimary
                          ? AppColors.white
                          : active
                              ? AppColors.seaAccent
                              : AppColors.earth,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPrimary
                            ? AppColors.white
                            : active
                                ? AppColors.seaAccent
                                : AppColors.earth,
                        fontSize: 9,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
