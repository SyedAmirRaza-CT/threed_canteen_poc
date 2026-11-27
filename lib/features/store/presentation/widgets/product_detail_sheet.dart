import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_bottom_sheet.dart';
import '../../../../core/widgets/custom_elevated_button.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../providers/basket_provider.dart';

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
    Category category,
  ) {
    return CustomBottomSheet.show<void>(
      context,
      maxHeightFactor: 0.52,
      barrierColor: Colors.black12,
      builder: (_) => ProductDetailSheet(product: product, category: category),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // the 3D product spinning above the sheet is the hero image
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: _Details(
              product: p,
              remaining: remaining,
              inBasket: basket.quantityOf(p),
              qty: qty,
              onQty: (v) => setState(() => _qty = v),
            ),
          ),
        ),
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
