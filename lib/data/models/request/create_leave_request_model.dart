import 'dart:convert';

import 'package:flutter_absensi_app/core/network/api_client.dart';

/// Payload pengajuan / perubahan izin & cuti.
///
/// Lampiran disimpan sebagai [UploadFile] (bytes, bukan path) supaya alur
/// unggah yang sama berjalan di Android, iOS, dan web.
class CreateLeaveRequestModel {
  final int leaveTypeId;
  final String startDate;
  final String endDate;
  final String? reason;

  /// JPG, PNG, WEBP, atau PDF — maks 5 MB.
  final UploadFile? attachment;

  /// Hapus lampiran lama tanpa menggantinya (hanya saat mengubah pengajuan).
  final bool removeAttachment;

  CreateLeaveRequestModel({
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.attachment,
    this.removeAttachment = false,
  });

  factory CreateLeaveRequestModel.fromJson(String str) =>
      CreateLeaveRequestModel.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory CreateLeaveRequestModel.fromMap(Map<String, dynamic> json) =>
      CreateLeaveRequestModel(
        leaveTypeId: (json['leave_type_id'] as num).toInt(),
        startDate: json['start_date'].toString(),
        endDate: json['end_date'].toString(),
        reason: json['reason']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'leave_type_id': leaveTypeId.toString(),
        'start_date': startDate,
        'end_date': endDate,
        if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
        if (removeAttachment) 'remove_attachment': true,
      };

  /// Batas ukuran lampiran yang diterima server.
  static const int maxAttachmentBytes = 5 * 1024 * 1024;

  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

  /// Validasi lampiran di sisi aplikasi supaya pengguna tidak perlu menunggu
  /// respons 422 dari server. Mengembalikan pesan error, atau null bila lolos.
  static String? validateAttachment(UploadFile? file) {
    if (file == null) return null;
    final ext = file.filename.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      return 'Lampiran harus berformat JPG, PNG, WEBP, atau PDF.';
    }
    if (file.bytes.length > maxAttachmentBytes) {
      return 'Ukuran lampiran maksimal 5 MB.';
    }
    return null;
  }
}
