// lib/features/nfc_tag/domain/usecases/validate_url.dart

import 'package:cards/core/usecase/usecase.dart';
import 'package:cards/features/nfc_tag/domain/repositories/nfc_repository.dart';

class ValidateUrl implements UseCase<bool, String> {
  final NfcRepository repository;
  ValidateUrl(this.repository);

  @override
  Future<bool> call(String url) =>
      repository.validateUrl(url);
}
