import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_absensi_app/data/datasources/attendance_remote_datasource.dart';
import 'package:flutter_absensi_app/data/models/request/checkinout_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/checkinout_response_model.dart';

part 'checkout_attendance_bloc.freezed.dart';
part 'checkout_attendance_event.dart';
part 'checkout_attendance_state.dart';

class CheckoutAttendanceBloc
    extends Bloc<CheckoutAttendanceEvent, CheckoutAttendanceState> {
  final AttendanceRemoteDatasource datasource;

  CheckoutAttendanceBloc(this.datasource) : super(const _Initial()) {
    // Absen pulang tidak mengirim `work_mode`: server memakai mode yang
    // tercatat saat absen masuk.
    on<_Checkout>((event, emit) async {
      emit(const _Loading());
      await _submit(
        CheckInOutRequestModel(
          latitude: event.latitute,
          longitude: event.longitude,
        ),
        emit,
      );
    });

    on<_Submit>((event, emit) async {
      emit(const _Loading());
      await _submit(event.request, emit);
    });
  }

  Future<void> _submit(
    CheckInOutRequestModel request,
    Emitter<CheckoutAttendanceState> emit,
  ) async {
    final result = await datasource.checkout(request);
    result.fold(
      (message) => emit(_Error(message)),
      (response) => emit(_Loaded(response)),
    );
  }
}
