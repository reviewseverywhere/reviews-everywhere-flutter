// lib/core/usecase/usecase.dart

/// A generic UseCase: takes Params, returns Type.
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Use when there are no parameters.
class NoParams {}
