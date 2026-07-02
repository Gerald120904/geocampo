import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class AppLoadingState extends StatefulWidget {
  const AppLoadingState({
    super.key,
    this.title = 'Preparando datos',
    this.steps = const ['Conectando', 'Validando capas', 'Armando vista'],
  });

  final String title;
  final List<String> steps;

  @override
  State<AppLoadingState> createState() => _AppLoadingStateState();
}

class _AppLoadingStateState extends State<AppLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5DF)),
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final active = (controller.value * widget.steps.length)
                  .floor()
                  .clamp(0, widget.steps.length - 1);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: controller.value,
                      minHeight: 7,
                      backgroundColor: AppColors.paleGreen,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < widget.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            i < active
                                ? Icons.check_circle_rounded
                                : i == active
                                ? Icons.sync_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: i <= active
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.steps[i],
                            style: TextStyle(
                              color: i <= active
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
