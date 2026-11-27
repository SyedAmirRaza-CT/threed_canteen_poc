import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_elevated_button.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../providers/basket_provider.dart';

/// What the product sheet can ask the 3D scene to do with the showcased item.
class ShowcaseControls {
  const ShowcaseControls({required this.onRotate, required this.onZoom});
  final ValueChanged<Offset> onRotate;
  final ValueChanged<double> onZoom;
}

/// Full-screen layer for the product sheet: the 3D item above/left of the panel
/// can be dragged to turn it (including tilting to see its top) and pinched to
/// zoom; the details panel sits at the bottom (portrait) or right (landscape).
class _ShowcaseOverlay extends StatefulWidget {
  const _ShowcaseOverlay({
    required this.animation,
    required this.landscape,
    required this.controls,
    required this.child,
  });
  final Animation<double> animation;
  final bool landscape;
  final ShowcaseControls? controls;
  final Widget child;

  @override
  State<_ShowcaseOverlay> createState() => _ShowcaseOverlayState();
}

class _ShowcaseOverlayState extends State<_ShowcaseOverlay> {
  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final c = widget.controls;
    final land = widget.landscape;
    final panel = land
        ? SizedBox(
            width: (size.width * 0.44).clamp(300.0, 460.0),
            height: double.infinity,
            child: Material(
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
              child: SafeArea(left: false, child: widget.child),
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height * 0.52,
              maxWidth: Responsive.isMobile(context) ? double.infinity : 640,
            ),
            child: Material(
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Flexible(child: widget.child),
                ],
              ),
            ),
          );
    final slide = SlideTransition(
      position:
          Tween(
            begin: land ? const Offset(1, 0) : const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: widget.animation,
              curve: Curves.easeOutCubic,
            ),
          ),
      child: panel,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // drag to rotate, pinch to zoom the showcased item
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _lastScale = 1,
          onScaleUpdate: (d) {
            c?.onRotate(d.focalPointDelta);
            if (d.pointerCount > 1 && d.scale > 0) {
              c?.onZoom(d.scale / _lastScale);
              _lastScale = d.scale;
            }
          },
          child: const SizedBox.expand(),
        ),
        Align(
          alignment: land ? Alignment.centerRight : Alignment.bottomCenter,
          child: slide,
        ),
      ],
    );
  }
}

class ProductDetailSheet extends StatefulWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.category,
  });

  final Product product;
  final Category category;

  static Future<void> show(
    BuildContext context,
    Product product,
    Category category, {
    ShowcaseControls? controls,
  }) {
    final size = MediaQuery.sizeOf(context);
    return showGeneralDialog<void>(
      context: context,
      // the 3D view stays touchable (drag to rotate), so a tap outside does
      // not close it: use Cancel, the close button or the back button
      barrierDismissible: false,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) => _ShowcaseOverlay(
        animation: anim,
        landscape: size.width > size.height,
        controls: controls,
        child: ProductDetailSheet(product: product, category: category),
      ),
    );
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _qty = 1;

  void _add(BuildContext context) {
    final basket = context.read<BasketProvider>();
    basket.add(widget.product, _qty);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final basket = context.watch<BasketProvider>();
    final remaining = basket.remaining(p);
    final qty = remaining == 0 ? 0 : _qty.clamp(1, remaining);
    final out = p.stock == 0;
    final allTaken = !out && remaining == 0;
    final side =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final scroller = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: _Details(
        product: p,
        remaining: remaining,
        inBasket: basket.quantityOf(p),
        qty: qty,
        onQty: (v) => setState(() => _qty = v),
      ),
    );
    return Column(
      mainAxisSize: side ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // the 3D product spinning next to the sheet is the hero image
        if (side) Expanded(child: scroller) else Flexible(child: scroller),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: Responsive.scale(context, 52),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomElevatedButton(
                  label: out
                      ? AppStrings.outOfStock
                      : (allTaken
                            ? AppStrings.allInBasket
                            : '${AppStrings.addToBasket} · ${AppConstants.currencySymbol}${p.price * qty}'),
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: remaining > 0 ? () => _add(context) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.product,
    required this.remaining,
    required this.inBasket,
    required this.qty,
    required this.onQty,
  });

  final Product product;
  final int remaining;
  final int inBasket;
  final int qty;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _VegBadge(isVeg: product.isVeg),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${AppConstants.currencySymbol}${product.price}',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          product.description,
          style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Stat(
              label: AppStrings.calories,
              value: '${product.calories} kcal',
            ),
            _Stat(label: AppStrings.inStock, value: '$remaining'),
            if (inBasket > 0)
              _Stat(label: AppStrings.inYourBasket, value: '$inBasket'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.ingredients,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final i in product.ingredients)
              Chip(label: Text(i), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 14),
        if (remaining > 0)
          Row(
            children: [
              Text(
                AppStrings.quantity,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              QuantityStepper(value: qty, max: remaining, onChanged: onQty),
            ],
          ),
      ],
    );
  }
}

class _VegBadge extends StatelessWidget {
  const _VegBadge({required this.isVeg});
  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final c = isVeg ? AppColors.veg : AppColors.nonVeg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: c),
          const SizedBox(width: 5),
          Text(
            isVeg ? AppStrings.veg : AppStrings.nonVeg,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// − 1 + control with 48px tap targets.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
