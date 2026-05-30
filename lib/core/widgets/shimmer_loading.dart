import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerListCard extends StatelessWidget {
  const ShimmerListCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(isDark, 160, 14),
                  const SizedBox(height: 8),
                  _bar(isDark, 110, 12),
                  const SizedBox(height: 8),
                  _bar(isDark, 200, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(bool isDark, double width, double height) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class ShimmerStatRow extends StatelessWidget {
  const ShimmerStatRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5),
      child: Row(
        children: List.generate(3, (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        )),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const ShimmerListCard(),
    );
  }
}