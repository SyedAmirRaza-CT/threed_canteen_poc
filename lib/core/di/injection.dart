import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt di = GetIt.instance;

/// Registers everything annotated with @injectable / @lazySingleton.
/// Regenerate with: dart run build_runner build --delete-conflicting-outputs
@InjectableInit()
void configureDependencies() => di.init();
