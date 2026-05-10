part of 'update_password_bloc.dart';

@freezed
class UpdatePasswordEvent with _$UpdatePasswordEvent {
  const factory UpdatePasswordEvent.started() = _Started;
  const factory UpdatePasswordEvent.updatePassword(
          String oldPassword, String newPassword, String confirmPassword) =
      _UpdatePassword;
}
