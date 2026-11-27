import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/api_state.dart';
import '../../../../core/widgets/custom_elevated_button.dart';
import '../../domain/entities/product.dart';
import '../providers/basket_provider.dart';
import '../providers/store_provider.dart';
import '../scene/store_scene.dart';
import '../widgets/basket_sheet.dart';
import '../widgets/gesture_controls.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/store_hud.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  StoreScene? _scene;
  final ValueNotifier<bool> _ready = ValueNotifier(false);
  late final BasketProvider _basket = context.read<BasketProvider>();
  int _seenAdds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StoreProvider>().loadCatalog();
    });
    _basket.addListener(_onBasketChanged);
  }

  void _onBasketChanged() {
    final added = _basket.addCounter != _seenAdds;
    _seenAdds = _basket.addCounter;
    _scene?.syncShelf({
      for (final l in _basket.basket.lines) l.product.id: l.quantity,
    });
    _scene?.syncBasket(
      _basket.basket.lines,
      justAdded: added ? _basket.lastAdded?.id : null,
    );
  }

  @override
  void dispose() {
    _basket.removeListener(_onBasketChanged);
    _scene?.dispose();
    _ready.dispose();
    super.dispose();
  }

  StoreScene _sceneFor(StoreCatalog catalog) {
    return _scene ??= StoreScene(
      catalog: catalog,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      onBasketTapped: () {
        if (mounted) BasketSheet.show(context);
      },
      onReady: () {
        if (!mounted) return;
        // ThreeJS only swaps its spinner for the 3D texture when its widget is
        // rebuilt after setup, so rebuild the page here.
        setState(() {});
        _ready.value = true;
        // Dev conveniences: flutter run --dart-define=AUTO_ENTER=true --dart-define=AUTO_ADD=true
        if (const bool.fromEnvironment('AUTO_ADD')) {
          _autoAdd(catalog);
        }
        // Dev only: DEMO="x,z,yaw;x,z,yaw" visits each view for 6 seconds.
        const demo = String.fromEnvironment('DEMO');
        if (demo.isNotEmpty) {
          final views = demo.split(';');
          for (var i = 0; i < views.length; i++) {
            final v = views[i].split(',').map(double.parse).toList();
            Future.delayed(
              Duration(milliseconds: 500 + i * 6000),
              () => _scene?.debugPlace(v[0], v[1], v[2]),
            );
          }
        }
        if (const bool.fromEnvironment('AUTO_ENTER')) {
          Future.delayed(
            const Duration(seconds: 1),
            () => _scene?.enterStore(),
          );
        }
      },
      onAisleChanged: (a) {
        if (mounted) context.read<StoreProvider>().aisle = a;
      },
      onPhaseChanged: (p) {
        if (mounted) context.read<StoreProvider>().phase = p;
      },
      onProductTapped: (p) => _openProduct(catalog, p),
    );
  }

  /// Dev only: add one product every 8 seconds so the hand and basket can be checked.
  void _autoAdd(StoreCatalog catalog) {
    var i = 0;
    Timer.periodic(const Duration(seconds: 8), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _basket.add(catalog.products[(i++ * 5) % catalog.products.length]);
    });
  }

  void _openProduct(StoreCatalog catalog, Product p) {
    if (!mounted) return;
    ProductDetailSheet.show(context, p, catalog.categoryOf(p));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select<StoreProvider, ApiState<StoreCatalog>>(
      (s) => s.catalog,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF000000 | AppColors.skyColor),
      body: switch (state) {
        ApiSuccess(:final data) => _world(data),
        ApiError(:final message) => _Message(
          text: message,
          action: AppStrings.tryAgain,
          onAction: context.read<StoreProvider>().loadCatalog,
        ),
        _ => const _Message(text: AppStrings.loadingStore, loading: true),
      },
    );
  }

  KeyEventResult _onKey(StoreScene scene, KeyEvent e) {
    final down = e is! KeyUpEvent;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      scene.setKeys(forward: down ? 1 : 0);
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      scene.setKeys(forward: down ? -1 : 0);
    }
    if (k == LogicalKeyboardKey.keyA) scene.setKeys(strafe: down ? -1 : 0);
    if (k == LogicalKeyboardKey.keyD) scene.setKeys(strafe: down ? 1 : 0);
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyQ) {
      scene.setKeys(turn: down ? -1 : 0);
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyE) {
      scene.setKeys(turn: down ? 1 : 0);
    }
    return KeyEventResult.ignored;
  }

  Widget _world(StoreCatalog catalog) {
    final scene = _sceneFor(catalog);
    return Stack(
      fit: StackFit.expand,
      children: [
        Focus(
          autofocus: true,
          onKeyEvent: (_, e) => _onKey(scene, e),
          child: StoreGestureLayer(
            onMove: scene.setMove,
            onLook: scene.look,
            onZoom: scene.zoomBy,
            onTap: scene.tap,
            onScroll: scene.scroll,
            child: scene.build(),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _ready,
          builder: (context, ready, _) {
            if (!ready) {
              return const _Message(
                text: AppStrings.loadingStore,
                loading: true,
              );
            }
            return StoreHud(
              onEnter: scene.enterStore,
              onBasket: () => BasketSheet.show(context),
            );
          },
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.loading = false,
    this.action,
    this.onAction,
  });
  final String text;
  final bool loading;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const CircularProgressIndicator(),
              if (loading) const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                CustomElevatedButton(
                  label: action!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
