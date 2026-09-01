part of 'attendance_summary_bloc.dart';

@freezed
abstract class AttendanceSummaryEvent with _$AttendanceSummaryEvent {
  /// Tanpa argumen, server memakai bulan dan tahun berjalan.
  const factory AttendanceSummaryEvent.fetch({int? month, int? year}) = _Fetch;
}
