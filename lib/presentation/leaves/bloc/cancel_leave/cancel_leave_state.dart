part of 'cancel_leave_bloc.dart';

@freezed
class CancelLeaveState with _$CancelLeaveState {
  const factory CancelLeaveState.initial() = _Initial;
  const factory CancelLeaveState.loading() = _Loading;
  const factory CancelLeaveState.success(String message) = _Success;
  const factory CancelLeaveState.error(String message) = _Error;
}
