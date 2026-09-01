import 'dart:convert';

/// Kesalahan terstruktur dari API.
///
/// Backend mengirim envelope `{success, message, data, errors}` dengan
/// `message` yang sudah berbahasa Indonesia dan aman ditampilkan langsung ke
/// pengguna, jadi [message] dipakai apa adanya di UI.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Error validasi 422, dipetakan ke field form.
  final Map<String, List<String>> errors;

  /// Konteks tambahan pada respons gagal (mis. `distance_meters`).
  final Map<String, dynamic> data;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errors = const {},
    this.data = const {},
  });

  factory ApiException.network(Object error) => ApiException(
        statusCode: 0,
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet '
            'Anda lalu coba lagi.',
        data: {'detail': error.toString()},
      );

  factory ApiException.parse(String body) {
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(body);
      decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    return ApiException(
      statusCode: -1,
      message: decoded['message']?.toString() ??
          'Respons server tidak dapat dibaca. Coba lagi beberapa saat.',
    );
  }

  /// Sesi berakhir — token harus dihapus dan pengguna diarahkan ke login.
  bool get isUnauthenticated => statusCode == 401;

  /// Konflik keadaan: sudah absen, sedang cuti, sudah diproses.
  /// UI cukup menampilkan [message] dan me-refresh pre-check.
  bool get isConflict => statusCode == 409;

  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  /// Validasi atau aturan bisnis gagal.
  bool get isValidation => statusCode == 422;

  bool get isRateLimited => statusCode == 429;

  /// Mode pemeliharaan aktif.
  bool get isMaintenance => statusCode == 503;

  bool get isNetwork => statusCode == 0;

  /// Pesan validasi pertama untuk [field], bila ada.
  String? errorFor(String field) {
    final list = errors[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  /// Angka dari [data] (server bisa mengirim string maupun number).
  double? numberFrom(String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  String toString() => message;
}
