import 'package:material_ui/material_ui.dart';

import '../utils/responsive.dart';

/// The one overlay used for details, the basket and order results. Look and
/// behaviour are changed here only. Scrolls, so it never overflows in
/// landscape or on small phones.
class CustomBottomSheet {
  CustomBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: Responsive.isMobile(context) ? double.infinity : 640,
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final maxH =
            MediaQuery.sizeOf(ctx).height *
            (Responsive.isShort(ctx) ? 0.98 : 0.9);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
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
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        );
      },
    );
  }
}
