import 'package:masrouf/core/error/failure.dart';
import 'package:meta/meta.dart';

/// Success-or-[Failure], used at repository boundaries.
///
/// A sealed class rather than dartz's `Either` so that switch expressions are
/// exhaustively checked by the analyser and call sites read as Dart instead of
/// as category theory.
@immutable
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  T getOrElse(T Function(Failure failure) orElse) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => orElse(failure),
      };
}

@immutable
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok($value)';
}

@immutable
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash(Err<T>, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Runs [body], converting a thrown exception into an [Err].
///
/// Only for the outermost repository call: swallowing exceptions deeper down
/// hides the stack trace that makes a sync bug diagnosable.
Future<Result<T>> guard<T>(
  Future<T> Function() body,
  Failure Function(Object error, StackTrace stackTrace) onError,
) async {
  try {
    return Ok<T>(await body());
  } catch (error, stackTrace) {
    return Err<T>(onError(error, stackTrace));
  }
}
