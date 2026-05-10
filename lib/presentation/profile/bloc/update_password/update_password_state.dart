part of 'update_password_bloc.dart';

@freezed
class UpdatePasswordState with _$UpdatePasswordState {
  const factory UpdatePasswordState.initial() = _Initial;
  const factory UpdatePasswordState.loading() = _Loading;
  const factory UpdatePasswordState.success(String message) = _Success;
  const factory UpdatePasswordState.error(String message) = _Error;
}
