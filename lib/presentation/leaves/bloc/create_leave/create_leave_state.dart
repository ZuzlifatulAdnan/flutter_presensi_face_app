part of 'create_leave_bloc.dart';

@freezed
class CreateLeaveState with _$CreateLeaveState {
  const factory CreateLeaveState.initial() = _Initial;
  const factory CreateLeaveState.loading() = _Loading;
  const factory CreateLeaveState.success(Leave leave) = _Success;
  const factory CreateLeaveState.error(String message) = _Error;
}
