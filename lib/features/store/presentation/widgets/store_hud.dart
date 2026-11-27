import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_elevated_button.dart';
import '../providers/basket_provider.dart';
import '../providers/store_provider.dart';

/// Size of the basket button; the fly-in animation lands on it.
const double kBasketButtonSize = 64;
const double kHudMargin = 16;

/// Everything drawn over the 3D view: gate card, aisle pill, hint, basket.
class StoreHud extends StatelessWidget {
  const StoreHud({super.key, required this.onEnter, required this.onBasket});

  final VoidCallback onEnter;
  final VoidCallback onBasket;

  @override
  Widget build(BuildContext context) {
    final phase = context.select<StoreProvider, StorePhase>((s) => s.phase);
    return SafeArea(
      minimum: const EdgeInsets.all(kHudMargin),
      child: switch (phase) {
        StorePhase.inside => _InsideHud(onBasket: onBasket),
        _ => _GateCard(
          entering: phase == StorePhase.entering,
          onEnter: onEnter,
        ),
      },
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({required this.entering, required this.onEnter});
  final bool entering;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = Responsive.isShort(context);
    final card = Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.hudGlass,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.welcomeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.hudText,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              AppStrings.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.hudText.withValues(alpha: 0.8),
              ),
            ),
          ],
          SizedBox(height: compact ? 10 : 16),
          CustomElevatedButton(
            label: entering ? AppStrings.entering : AppStrings.enterStore,
            icon: entering ? null : Icons.storefront_rounded,
            onPressed: entering ? null : onEnter,
          ),
        ],
      ),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Responsive.constrained(
        card,
        maxWidth: 440,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

class _InsideHud extends StatelessWidget {
  const _InsideHud({required this.onBasket});
  final VoidCallback onBasket;

  @override
  Widget build(BuildContext context) {
    final aisle = context.select<StoreProvider, String>((s) => s.aisle);
    final count = context.select<BasketProvider, int>(
      (b) => b.basket.itemCount,
    );
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(right: kBasketButtonSize + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aisle.isNotEmpty)
                  _Pill(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${AppStrings.nowViewing}  ',
                            style: TextStyle(
                              color: AppColors.hudText.withValues(alpha: 0.7),
                            ),
                          ),
                          TextSpan(
                            text: aisle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.hudText),
                    ),
                  ),
                const SizedBox(height: 8),
                const _FadingHint(),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: _BasketButton(count: count, onTap: onBasket),
        ),
      ],
    );
  }
}

/// The controls hint, shown for a few seconds after entering, then fades away.
class _FadingHint extends StatefulWidget {
  const _FadingHint();

  @override
  State<_FadingHint> createState() => _FadingHintState();
}

class _FadingHintState extends State<_FadingHint> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: _Pill(
        child: Text(
          AppStrings.hintWalk,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.hudText.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.hudGlass,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    ),
  );
}

class _BasketButton extends StatelessWidget {
  const _BasketButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.basket,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: kBasketButtonSize,
          height: kBasketButtonSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      color: Color(0x55000000),
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_basket_rounded,
                  color: AppColors.hudText,
                  size: 30,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.hudText, width: 2),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.hudText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
