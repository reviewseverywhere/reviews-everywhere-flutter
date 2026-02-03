// lib/features/nfc_tag/domain/usecases/clear_tag.dart

import 'package:cards/core/usecase/usecase.dart';
import 'package:cards/features/nfc_tag/domain/repositories/nfc_repository.dart';

class ClearTag implements UseCase<void, NoParams> {
  final NfcRepository repository;
  ClearTag(this.repository);

  @override
  Future<void> call(NoParams _) =>
      repository.clearTag();
}
