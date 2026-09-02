/// Pembacaan nilai JSON yang toleran terhadap perbedaan tipe dari server.
///
/// Respons API menggabungkan bentuk lama dan baru: satu field bisa datang
/// sebagai angka, string, atau objek `{id, name}` tergantung endpoint dan
/// versi backend. Tanpa toleransi ini satu perbedaan tipe saja melempar
/// `TypeError` di tengah `fromMap`, dan pemanggil yang hanya menangkap
/// `ApiException` tidak pernah tahu prosesnya gagal.
library;

String? asString(dynamic value) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  // Relasi yang sudah dimuat penuh, mis. `position: {"id": 1, "name": "Staf"}`.
  if (value is Map) return asString(value['name'] ?? value['title']);
  return null;
}

int? asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (value is Map) return asInt(value['id']);
  return null;
}

double? asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Laravel mengirim boolean sebagai `true`/`false`, `1`/`0`, atau `"1"`/`"0"`
/// tergantung cast pada model.
bool? asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.toLowerCase()) {
      case '1':
      case 'true':
        return true;
      case '0':
      case 'false':
        return false;
    }
  }
  return null;
}

/// Tanggal yang tidak bisa dibaca menjadi `null`, bukan melempar seperti
/// `DateTime.parse`.
DateTime? asDate(dynamic value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

Map<String, dynamic>? asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// Bangun sub-model hanya bila nodenya benar-benar objek.
T? asModel<T>(dynamic value, T Function(Map<String, dynamic>) build) {
  final map = asMap(value);
  return map == null ? null : build(map);
}
