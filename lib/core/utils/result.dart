import 'app_failure.dart';

/// `Result<T>` — hasil operasi yang mungkin gagal, tanpa melempar exception liar
/// (Bab 3.2).
///
/// Repository **selalu** mengembalikan `Result`. ViewModel yang ingin memakai
/// `AsyncValue` Riverpod boleh melempar ulang lewat [unwrap].
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppFailure failure) onErr,
  }) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Result<R>.ok(transform(value)),
        Err<T>(:final failure) => Result<R>.err(failure),
      };

  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async =>
      switch (this) {
        Ok<T>(:final value) => Result<R>.ok(await transform(value)),
        Err<T>(:final failure) => Result<R>.err(failure),
      };

  T getOrElse(T Function(AppFailure failure) orElse) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => orElse(failure),
      };

  /// Lempar [AppFailure] bila gagal. Dipakai di ViewModel agar `AsyncValue`
  /// menangkap error dan layar bisa menampilkan kondisi `error`.
  T unwrap() => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => throw failure,
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;

  @override
  String toString() => 'Err($failure)';
}

/// `Result<void>` yang ringkas untuk operasi tanpa nilai kembali.
typedef VoidResult = Result<void>;

const VoidResult okVoid = Ok<void>(null);
