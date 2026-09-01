part of 'create_leave_bloc.dart';

@freezed
class CreateLeaveEvent with _$CreateLeaveEvent {
  const factory CreateLeaveEvent.started() = _Started;

  /// Ajukan izin/cuti baru, atau ubah pengajuan bila [leaveId] diisi.
  const factory CreateLeaveEvent.createLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
    UploadFile? attachment,
    @Default(false) bool removeAttachment,
    int? leaveId,
  }) = _CreateLeave;
}
