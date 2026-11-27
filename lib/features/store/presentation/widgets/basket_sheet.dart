import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/api_state.dart';
import '../../../../core/widgets/custom_bottom_sheet.dart';
import '../../../../core/widgets/custom_elevated_button.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../domain/entities/basket.dart';
import '../../domain/entities/order.dart';
import '../providers/basket_provider.dart';
import 'product_detail_sheet.dart' show QuantityStepper;

class BasketSheet extends StatelessWidget {
  const BasketSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await CustomBottomSheet.show<void>(
      context,
      builder: (_) => const BasketSheet(),
    );
    if (context.mounted) context.read<BasketProvider>().resetOrder();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BasketProvider>();
    return switch (provider.order) {
      ApiLoading() => const _Busy(),
      ApiSuccess(:final data) => _Success(order: data),
      _ => _BasketView(provider: provider),
    };
  }
}

String _money(int v) => '${AppConstants.currencySymbol}$v';

class _BasketView extends StatelessWidget {
  const _BasketView({required this.provider});
  final BasketProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final basket = provider.basket;
    if (basket.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧺', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              AppStrings.basketEmpty,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.basketEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            CustomElevatedButton(
              label: AppStrings.continueShopping,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
    final error = provider.order is ApiError<Order>;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${AppStrings.yourBasket} (${basket.itemCount})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              CustomTextButton(
                label: AppStrings.clearBasket,
                color: AppColors.danger,
                onPressed: provider.clear,
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: basket.lines.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _LineTile(line: basket.lines[i], provider: provider),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              _Row(AppStrings.items, '${basket.itemCount}'),
              _Row(AppStrings.totalCalories, '${basket.totalCalories} kcal'),
              _Row(AppStrings.subtotal, _money(basket.subtotal)),
              _Row(AppStrings.tax, _money(basket.tax)),
              _Row(AppStrings.total, _money(basket.total), bold: true),
              if (error)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    AppStrings.tryAgain,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 12),
              CustomElevatedButton(
                label: '${AppStrings.checkout} · ${_money(basket.total)}',
                icon: Icons.lock_outline_rounded,
                onPressed: provider.checkout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.provider});
  final BasketLine line;
  final BasketProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = line.product;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(p.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_money(p.price)} × ${line.quantity} = ${_money(line.total)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          QuantityStepper(
            value: line.quantity,
            min: 0,
            max: p.stock,
            onChanged: (v) =>
                v < line.quantity ? provider.decrement(p) : provider.add(p),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppStrings.placingOrder,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 72,
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.orderPlaced,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppStrings.orderNumber} ${order.id}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${order.itemCount} ${AppStrings.items.toLowerCase()} · ${_money(order.total)}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.orderThanks,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          CustomElevatedButton(
            label: AppStrings.done,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
