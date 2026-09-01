import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_absensi_app/data/datasources/attendance_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/models/request/checkinout_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/checkinout_response_model.dart';

part 'checkin_attendance_bloc.freezed.dart';
part 'checkin_attendance_event.dart';
part 'checkin_attendance_state.dart';

class CheckinAttendanceBloc
    extends Bloc<CheckinAttendanceEvent, CheckinAttendanceState> {
  final AttendanceRemoteDatasource datasource;

  CheckinAttendanceBloc(this.datasource) : super(const _Initial()) {
    // Jalur lama: hanya koordinat, mode kerja diambil dari profil tersimpan.
    on<_Checkin>((event, emit) async {
      emit(const _Loading());
      final authData = await AuthLocalDatasource().getAuthData();
      await _submit(
        CheckInOutRequestModel(
          latitude: event.latitute,
          longitude: event.longitude,
          workMode: authData?.user?.workMode ?? authData?.workMode,
        ),
        emit,
      );
    });

    // Jalur baru: payload lengkap (mode kerja, foto, catatan, alamat,
    // deteksi fake GPS, info perangkat, akurasi) dari halaman presensi.
    on<_Submit>((event, emit) async {
      emit(const _Loading());
      await _submit(event.request, emit);
    });
  }

  Future<void> _submit(
    CheckInOutRequestModel request,
    Emitter<CheckinAttendanceState> emit,
  ) async {
    final result = await datasource.checkin(request);
    result.fold(
      (message) => emit(_Error(message)),
      (response) => emit(_Loaded(response)),
    );
  }
}
