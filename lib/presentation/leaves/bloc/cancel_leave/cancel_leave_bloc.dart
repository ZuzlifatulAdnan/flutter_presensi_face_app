import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter_absensi_app/data/datasources/leave_remote_datasource.dart';

part 'cancel_leave_bloc.freezed.dart';
part 'cancel_leave_event.dart';
part 'cancel_leave_state.dart';

/// Pembatalan pengajuan izin/cuti (`POST /api/leaves/{id}/cancel`).
/// Hanya pengajuan berstatus `pending` yang bisa dibatalkan.
class CancelLeaveBloc extends Bloc<CancelLeaveEvent, CancelLeaveState> {
  final LeaveRemoteDatasource datasource;

  CancelLeaveBloc(this.datasource) : super(const _Initial()) {
    on<_Cancel>((event, emit) async {
      emit(const _Loading());
      final result = await datasource.cancelLeave(event.id);
      result.fold(
        (message) => emit(_Error(message)),
        (message) => emit(_Success(message)),
      );
    });
  }
}
