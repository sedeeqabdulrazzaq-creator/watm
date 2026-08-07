import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/watm_components.dart';

/// Small, self-contained data models and presentational widgets used
/// throughout the MVP journey (`mvp_flow.dart`). Extracted so the state
/// class only holds the journey/screen logic.

class QuestionData {
  const QuestionData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.options,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> options;
}

class MemberData {
  const MemberData(this.initial, this.name, this.status, this.shared);

  final String initial;
  final String name;
  final String status;
  final String shared;
}

class StepCard extends StatelessWidget {
  const StepCard({required this.number, required this.title, required this.body, super.key});
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WatmCard(
        child: Row(
          children: [
            CircleAvatar(backgroundColor: AppColors.nature, child: Text(number, style: const TextStyle(color: AppColors.universe, fontWeight: FontWeight.w700))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(body, style: const TextStyle(color: AppColors.earth, height: 1.5))])),
          ],
        ),
      ),
    );
  }
}

class ResultRow extends StatelessWidget {
  const ResultRow({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.universe, fontSize: 13, fontWeight: FontWeight.w500))),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.earth, fontSize: 12)),
        ],
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({required this.title, required this.headline, required this.details, required this.price, required this.recommended, required this.selected, required this.onTap, super.key});
  final String title;
  final String headline;
  final String details;
  final String price;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: WatmCard(
        color: selected ? AppColors.seaSoft : AppColors.white,
        borderColor: selected ? AppColors.sea : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))), if (recommended) const Chip(backgroundColor: AppColors.nature, label: Text('موصى به', style: TextStyle(fontSize: 11)))]),
            const SizedBox(height: 12),
            Text(headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(details, style: const TextStyle(color: AppColors.earth, fontSize: 14)),
            const Divider(height: 28),
            Text(price, style: const TextStyle(color: AppColors.seaAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  const MemberCard({required this.member, super.key});
  final MemberData member;

  @override
  Widget build(BuildContext context) {
    return WatmCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          WatmAvatar(initial: member.initial),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.6)),
                Text(member.status, style: const TextStyle(color: AppColors.earth, fontSize: 12, height: 1.5)),
                Text('شارك: ${member.shared}', style: const TextStyle(color: AppColors.seaAccent, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CircleActivity extends StatelessWidget {
  const CircleActivity({required this.initial, required this.title, required this.subtitle, this.button, this.onPressed, super.key});
  final String initial;
  final String title;
  final String subtitle;
  final String? button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return WatmCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          WatmAvatar(initial: initial, needsSupport: button != null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.5)), Text(subtitle, style: const TextStyle(color: AppColors.earth, fontSize: 11, height: 1.5))])),
          if (button != null) TextButton(onPressed: onPressed, child: Text(button!)),
        ],
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({required this.value, required this.label, super.key});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700)), Text(label, style: const TextStyle(color: AppColors.earth))]);
}

class MiniMetric extends StatelessWidget {
  const MiniMetric({required this.value, required this.label, super.key});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(16)), child: Column(children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.earth, fontSize: 11))]));
}
