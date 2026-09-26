import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HeroPill {
  final String label;
  final String value;
  const HeroPill({required this.label, required this.value});
}

/// The glass hero balance card (`.g-teal` in the mockup): frosted teal-glass
/// surface, generous radius, floating stat pills. Soft highlights come from
/// the tinted glass rather than a hard gradient band.
class HeroCard extends StatelessWidget {
  final String eyebrow;
  final String amount;
  final String? chip;
  final List<HeroPill> pills;
  final double amountSize;

  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.amount,
    this.chip,
    this.pills = const [],
    this.amountSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final highlight = Color.alphaBlend(
      isDark ? const Color(0x4D7C83AD) : Colors.white.withValues(alpha: 0.55),
      Colors.transparent,
    );

    final amountColor = isDark ? Colors.white : const Color(0xFF182346);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0x203D5387) : const Color(0xB3E3E7F1),
            isDark ? const Color(0x16182346) : const Color(0x66DEE3F0),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0x2E7C83AD) : const Color(0x993D5387),
        ),
        boxShadow: [
          BoxShadow(
            color: ac.brandSolid.withValues(alpha: isDark ? 0.28 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -60,
            child: SizedBox(
              width: 220,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: amountColor.withValues(alpha: 0.7),
                            letterSpacing: 0.08,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amount,
                          style: AppTheme.display(
                            context,
                            size: amountSize,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: highlight.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: highlight.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.arrow_upward_rounded,
                            size: 11, color: amountColor),
                        const SizedBox(width: 5),
                        Text(chip!,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: amountColor)),
                      ]),
                    ),
                ],
              ),
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(children: [
                  for (var i = 0; i < pills.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: highlight.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: highlight.withValues(alpha: 0.12)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pills[i].label.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: amountColor.withValues(alpha: 0.6),
                                  letterSpacing: 0.05)),
                          const SizedBox(height: 3),
                          Text(pills[i].value,
                              style: AppTheme.display(context, size: 14.5, color: amountColor)),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}