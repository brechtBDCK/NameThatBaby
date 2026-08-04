import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/domain.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.category,
    required this.progress,
    required this.remaining,
  });
  final NameCategory category;
  final double progress;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final girls = category == NameCategory.girls;
    final color = girls ? Palette.terra : Palette.forest;
    final label = girls ? 'Girls' : 'Boys';
    final percent = (progress * 100).round();
    return Semantics(
      label: '$label, $percent percent complete, $remaining names left',
      child: Card(
        elevation: 0,
        color: girls ? const Color(0xffffe8d9) : const Color(0xffe1f0f3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: color.withValues(alpha: 0.16),
                        color: color,
                      ),
                    ),
                    Text('$percent%', style: TextStyle(color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · $percent% complete',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$remaining names left'),
                  ],
                ),
              ),
              Icon(Icons.spa_outlined, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
