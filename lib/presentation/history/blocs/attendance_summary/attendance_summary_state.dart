part of 'attendance_summary_bloc.dart';

@freezed
class AttendanceSummaryState with _$AttendanceSummaryState {
  const factory AttendanceSummaryState.initial() = _Initial;
  const factory AttendanceSummaryState.loading() = _Loading;
  const factory AttendanceSummaryState.loaded(AttendanceSummary summary) =
      _Loaded;
  const factory AttendanceSummaryState.error(String message) = _Error;
}
