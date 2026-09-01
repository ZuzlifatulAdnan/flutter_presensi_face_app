import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_absensi_app/data/datasources/attendance_remote_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_summary_model.dart';

part 'attendance_summary_bloc.freezed.dart';
part 'attendance_summary_event.dart';
part 'attendance_summary_state.dart';

/// Rekap presensi bulanan (`GET /api/attendance/summary`) untuk kartu
/// statistik di beranda dan halaman riwayat.
class AttendanceSummaryBloc
    extends Bloc<AttendanceSummaryEvent, AttendanceSummaryState> {
  final AttendanceRemoteDatasource datasource;

  AttendanceSummaryBloc(this.datasource) : super(const _Initial()) {
    on<_Fetch>((event, emit) async {
      emit(const _Loading());
      final result = await datasource.getSummary(
        month: event.month,
        year: event.year,
      );
      result.fold(
        (message) => emit(_Error(message)),
        (summary) => emit(_Loaded(summary)),
      );
    });
  }
}
