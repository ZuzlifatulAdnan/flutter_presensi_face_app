part of 'cancel_leave_bloc.dart';

@freezed
abstract class CancelLeaveEvent with _$CancelLeaveEvent {
  const factory CancelLeaveEvent.cancel(int id) = _Cancel;
}
