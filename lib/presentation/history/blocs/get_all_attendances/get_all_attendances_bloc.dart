import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_absensi_app/data/datasources/attendance_remote_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';

part 'get_all_attendances_bloc.freezed.dart';
part 'get_all_attendances_event.dart';
part 'get_all_attendances_state.dart';

class GetAllAttendancesBloc
    extends Bloc<GetAllAttendancesEvent, GetAllAttendancesState> {
  final AttendanceRemoteDatasource datasource;

  GetAllAttendancesBloc(this.datasource) : super(const _Initial()) {
    on<_GetAllAttendances>((event, emit) async {
      emit(const _Loading());
      await _load(emit);
    });

    // Filter dijalankan di server (`GET /api/attendance/history`) supaya
    // aplikasi tidak perlu mengunduh seluruh riwayat lalu menyaringnya.
    on<_Filter>((event, emit) async {
      emit(const _Loading());
      await _load(
        emit,
        date: event.date,
        month: event.month,
        year: event.year,
        status: event.status,
        workMode: event.workMode,
      );
    });
  }

  Future<void> _load(
    Emitter<GetAllAttendancesState> emit, {
    String? date,
    int? month,
    int? year,
    String? status,
    String? workMode,
  }) async {
    final result = await datasource.getAttendances(
      date: date,
      month: month,
      year: year,
      status: status,
      workMode: workMode,
    );

    result.fold(
      (message) => emit(_Error(message)),
      (response) {
        final data = response.data;
        if (data == null || data.isEmpty) {
          emit(const _Empty());
        } else {
          emit(_Loaded(data));
        }
      },
    );
  }
}
