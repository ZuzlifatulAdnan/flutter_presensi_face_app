part of 'attendance_precheck_bloc.dart';

@freezed
abstract class AttendancePrecheckEvent with _$AttendancePrecheckEvent {
  const factory AttendancePrecheckEvent.fetch({
    double? latitude,
    double? longitude,

    /// Pertahankan data lama di layar selama request berjalan.
    @Default(false) bool silent,
  }) = _Fetch;
}
