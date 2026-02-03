// lib/features/nfc_tag/presentation/di/injection.dart

import 'package:get_it/get_it.dart';
import 'package:cards/features/nfc_tag/data/datasources/nfc_remote_data_source.dart';
import 'package:cards/features/nfc_tag/data/repositories/nfc_repository_impl.dart';
import 'package:cards/features/nfc_tag/domain/repositories/nfc_repository.dart';
import 'package:cards/features/nfc_tag/domain/usecases/write_url.dart';
import 'package:cards/features/nfc_tag/domain/usecases/clear_tag.dart';
import 'package:cards/features/nfc_tag/domain/usecases/validate_url.dart';
import 'package:cards/features/nfc_tag/presentation/viewmodels/home_view_model.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Data sources & repositories
  sl.registerLazySingleton<NfcRemoteDataSource>(
      () => NfcRemoteDataSourceImpl());
  sl.registerLazySingleton<NfcRepository>(() => NfcRepositoryImpl(sl()));

  // Use-cases
  sl.registerLazySingleton(() => WriteUrl(sl()));
  sl.registerLazySingleton(() => ClearTag(sl()));
  sl.registerLazySingleton(() => ValidateUrl(sl()));

  // ViewModel
  sl.registerFactory(() => HomeViewModel(
        writeUrl: sl(),
        clearTag: sl(),
        validateUrl: sl(),
      ));
}
