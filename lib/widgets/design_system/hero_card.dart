import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HeroPill {
  final String label;
  final String value;
  const HeroPill({required this.label, required this.value});
}

/// The gradient hero balance card (`.hero-card`) — always filled with the
/// fixed `brandSolid` gradient so white content stays legible in BOTH themes.
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
    this.amountSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ac.brandSolid, ac.brandSolidStrong],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: ac.brandSolid.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
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
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.06,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amount,
                          style: TextStyle(
                            fontFamily: 'Fraunces',
                            fontFamilyFallback: const ['serif'],
                            fontSize: amountSize,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.01,
                            color: Colors.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.arrow_upward_rounded, size: 11, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(chip!,
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                ],
              ),
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(children: [
                  for (var i = 0; i < pills.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pills[i].label.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                  letterSpacing: 0.04)),
                          const SizedBox(height: 2),
                          Text(pills[i].value,
                              style: const TextStyle(
                                fontFamily: 'Fraunces',
                                fontFamilyFallback: ['serif'],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
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
