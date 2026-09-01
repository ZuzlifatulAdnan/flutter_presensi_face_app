import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_absensi_app/data/datasources/attendance_remote_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';

part 'attendance_precheck_bloc.freezed.dart';
part 'attendance_precheck_event.dart';
part 'attendance_precheck_state.dart';

/// Menjaga status kelayakan presensi (`GET /api/attendance/pre-check`).
///
/// Dipanggil saat halaman presensi dibuka dan setiap kali posisi GPS berubah,
/// karena satu respons menentukan label tombol, aktif/tidaknya tombol, mode
/// kerja yang boleh dipilih, dan syarat foto/catatan.
class AttendancePrecheckBloc
    extends Bloc<AttendancePrecheckEvent, AttendancePrecheckState> {
  final AttendanceRemoteDatasource datasource;

  AttendancePrecheckBloc(this.datasource) : super(const _Initial()) {
    on<_Fetch>((event, emit) async {
      // Saat refresh diam-diam, data lama tetap tampil supaya peta tidak
      // berkedip setiap kali posisi GPS bergeser.
      final previous = state;
      if (event.silent && previous is _Loaded) {
        emit(_Loaded(previous.data, refreshing: true));
      } else {
        emit(const _Loading());
      }

      final result = await datasource.preCheck(
        latitude: event.latitude,
        longitude: event.longitude,
      );

      result.fold(
        (message) => emit(_Error(message)),
        (data) => emit(_Loaded(data)),
      );
    });
  }
}
