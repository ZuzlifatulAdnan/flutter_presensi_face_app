part of 'attendance_precheck_bloc.dart';

@freezed
class AttendancePrecheckState with _$AttendancePrecheckState {
  const factory AttendancePrecheckState.initial() = _Initial;
  const factory AttendancePrecheckState.loading() = _Loading;
  const factory AttendancePrecheckState.loaded(
    AttendancePreCheck data, {
    @Default(false) bool refreshing,
  }) = _Loaded;
  const factory AttendancePrecheckState.error(String message) = _Error;
}
