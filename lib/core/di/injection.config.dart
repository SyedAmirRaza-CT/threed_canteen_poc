// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:threed_canteen_poc/features/store/data/datasources/product_local_data_source.dart'
    as _i251;
import 'package:threed_canteen_poc/features/store/data/repositories/product_repository_impl.dart'
    as _i353;
import 'package:threed_canteen_poc/features/store/domain/repositories/product_repository.dart'
    as _i98;
import 'package:threed_canteen_poc/features/store/domain/usecases/get_categories.dart'
    as _i995;
import 'package:threed_canteen_poc/features/store/domain/usecases/get_products.dart'
    as _i632;
import 'package:threed_canteen_poc/features/store/domain/usecases/place_order.dart'
    as _i448;
import 'package:threed_canteen_poc/features/store/presentation/providers/basket_provider.dart'
    as _i288;
import 'package:threed_canteen_poc/features/store/presentation/providers/store_provider.dart'
    as _i959;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i251.ProductDataSource>(
      () => _i251.ProductLocalDataSource(),
    );
    gh.lazySingleton<_i98.ProductRepository>(
      () => _i353.ProductRepositoryImpl(gh<_i251.ProductDataSource>()),
    );
    gh.lazySingleton<_i995.GetCategories>(
      () => _i995.GetCategories(gh<_i98.ProductRepository>()),
    );
    gh.lazySingleton<_i632.GetProducts>(
      () => _i632.GetProducts(gh<_i98.ProductRepository>()),
    );
    gh.lazySingleton<_i448.PlaceOrder>(
      () => _i448.PlaceOrder(gh<_i98.ProductRepository>()),
    );
    gh.factory<_i288.BasketProvider>(
      () => _i288.BasketProvider(gh<_i448.PlaceOrder>()),
    );
    gh.factory<_i959.StoreProvider>(
      () => _i959.StoreProvider(
        gh<_i995.GetCategories>(),
        gh<_i632.GetProducts>(),
      ),
    );
    return this;
  }
}
