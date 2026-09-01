part of 'get_all_attendances_bloc.dart';

@freezed
class GetAllAttendancesEvent with _$GetAllAttendancesEvent {
  const factory GetAllAttendancesEvent.started() = _Started;
  const factory GetAllAttendancesEvent.getAllAttendances() = _GetAllAttendances;

  /// Riwayat dengan filter server: tanggal, bulan/tahun, status, mode kerja.
  const factory GetAllAttendancesEvent.filter({
    String? date,
    int? month,
    int? year,
    String? status,
    String? workMode,
  }) = _Filter;
}
