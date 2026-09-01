import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:flutter_absensi_app/core/constants/variables.dart';
import 'package:flutter_absensi_app/core/network/api_exception.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';

/// Berkas yang diunggah lewat `multipart/form-data`.
///
/// Menyimpan bytes (bukan path) supaya jalur unggah yang sama dipakai di
/// Android, iOS, maupun web — `dart:io` tidak tersedia di web.
class UploadFile {
  final String field;
  final String filename;
  final Uint8List bytes;
  final MediaType? contentType;

  const UploadFile({
    required this.field,
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  factory UploadFile.bytes(
    String field,
    Uint8List bytes, {
    required String filename,
  }) =>
      UploadFile(
        field: field,
        filename: filename,
        bytes: bytes,
        contentType: mediaTypeFor(filename),
      );

  static MediaType? mediaTypeFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return null;
    }
  }
}

/// Envelope respons sukses: `{success, message, data, meta}`.
///
/// Endpoint lama masih mengirim key lamanya (`attendance`, `user`, `company`,
/// `checkedin`, ...) di level atas, jadi [raw] tetap disimpan utuh dan
/// [dataMap] jatuh kembali ke [raw] bila `data` tidak ada.
class ApiEnvelope {
  final int statusCode;
  final String message;
  final dynamic data;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> raw;

  const ApiEnvelope({
    required this.statusCode,
    required this.message,
    required this.data,
    required this.meta,
    required this.raw,
  });

  /// `data` sebagai objek. Bila endpoint lama tidak mengirim `data`, seluruh
  /// body dipakai sehingga pembacaan key lama tetap bekerja.
  Map<String, dynamic> get dataMap {
    final value = data;
    if (value is Map<String, dynamic>) return value;
    return raw;
  }

  /// `data` sebagai list. Mendukung bentuk lama `{"data": [...]}` maupun
  /// paginasi Laravel `{"data": {"data": [...]}}`.
  List<Map<String, dynamic>> get dataList {
    final value = data;
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    if (value is Map<String, dynamic> && value['data'] is List) {
      return (value['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// Ambil objek dari `data`, atau dari key lama di level atas.
  Map<String, dynamic>? object(String key) {
    final fromData = data;
    if (fromData is Map<String, dynamic> && fromData[key] is Map) {
      return Map<String, dynamic>.from(fromData[key] as Map);
    }
    if (raw[key] is Map) return Map<String, dynamic>.from(raw[key] as Map);
    return null;
  }

  /// Ambil nilai skalar dari `data`, atau dari key lama di level atas.
  T? value<T>(String key) {
    final fromData = data;
    if (fromData is Map<String, dynamic> && fromData[key] is T) {
      return fromData[key] as T;
    }
    if (raw[key] is T) return raw[key] as T;
    return null;
  }

  int? get currentPage => _metaInt('current_page');

  int? get lastPage => _metaInt('last_page');

  int? get total => _metaInt('total');

  /// Masih ada halaman berikutnya yang bisa dimuat.
  bool get hasMorePages {
    final current = currentPage;
    final last = lastPage;
    if (current == null || last == null) return false;
    return current < last;
  }

  int? _metaInt(String key) {
    final value = meta[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Klien HTTP tunggal untuk seluruh API.
///
/// Menyatukan header, envelope `{success, message, data, meta}`, dan pemetaan
/// kode status ke [ApiException] supaya setiap datasource tidak mengulang
/// logika yang sama.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 30);

  /// Dipanggil saat server menjawab 401 supaya sesi lokal dibersihkan dan
  /// pengguna diarahkan kembali ke halaman login.
  static VoidCallback? onUnauthenticated;

  final http.Client _client = http.Client();

  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    return _send(
      () async => _client.get(uri, headers: await _headers(auth: auth)),
      uri,
      'GET',
      auth,
    );
  }

  Future<ApiEnvelope> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    return _send(
      () async => _client.post(
        uri,
        headers: await _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
      uri,
      'POST',
      auth,
    );
  }

  Future<ApiEnvelope> delete(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    return _send(
      () async => _client.delete(uri, headers: await _headers(auth: auth)),
      uri,
      'DELETE',
      auth,
    );
  }

  /// Kirim `multipart/form-data`. Dipakai untuk presensi berfoto, lampiran
  /// izin, dan perubahan foto profil.
  ///
  /// PHP tidak mem-parse multipart pada PUT, jadi endpoint ubah data pun
  /// memakai POST — sesuai catatan di dokumentasi API.
  Future<ApiEnvelope> multipart(
    String path, {
    Map<String, dynamic> fields = const {},
    List<UploadFile> files = const [],
    bool auth = true,
  }) async {
    final uri = _uri(path);
    return _send(
      () async {
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(await _headers(auth: auth, json: false));

        fields.forEach((key, value) {
          if (value == null) return;
          // Laravel memvalidasi boolean dari string '1'/'0'.
          request.fields[key] = value is bool
              ? (value ? '1' : '0')
              : value.toString();
        });

        for (final file in files) {
          request.files.add(
            http.MultipartFile.fromBytes(
              file.field,
              file.bytes,
              filename: file.filename,
              contentType: file.contentType,
            ),
          );
        }

        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      },
      uri,
      'POST(multipart)',
      auth,
    );
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('${Variables.baseUrl}$normalized');
    if (query == null || query.isEmpty) return uri;

    final params = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      params[key] = text;
    });
    if (params.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  Future<Map<String, String>> _headers({
    required bool auth,
    bool json = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = (await AuthLocalDatasource().getAuthData())?.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<ApiEnvelope> _send(
    Future<http.Response> Function() run,
    Uri uri,
    String method,
    bool authenticated,
  ) async {
    late http.Response response;
    try {
      response = await run().timeout(_timeout);
    } catch (e) {
      debugPrint('[API] $method $uri -> $e');
      throw ApiException.network(e);
    }

    debugPrint('[API] $method $uri -> ${response.statusCode}');

    Map<String, dynamic> body;
    try {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is List) {
        body = <String, dynamic>{'data': decoded};
      } else {
        body = <String, dynamic>{};
      }
    } catch (_) {
      body = <String, dynamic>{};
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && body['success'] != false) {
      return ApiEnvelope(
        statusCode: response.statusCode,
        message: body['message']?.toString() ?? '',
        data: body.containsKey('data') ? body['data'] : body,
        meta: body['meta'] is Map
            ? Map<String, dynamic>.from(body['meta'] as Map)
            : const {},
        raw: body,
      );
    }

    throw _failureFrom(response.statusCode, body, authenticated);
  }

  ApiException _failureFrom(
    int statusCode,
    Map<String, dynamic> body,
    bool authenticated,
  ) {
    final errors = <String, List<String>>{};
    final rawErrors = body['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((key, value) {
        if (value is List) {
          errors[key.toString()] = value.map((e) => e.toString()).toList();
        } else if (value != null) {
          errors[key.toString()] = [value.toString()];
        }
      });
    }

    var message = body['message']?.toString() ??
        body['error']?.toString() ??
        body['msg']?.toString() ??
        '';
    if (message.isEmpty && errors.isNotEmpty) {
      message = errors.values.first.first;
    }
    if (message.isEmpty) message = _defaultMessage(statusCode);

    // 401 hanya berarti sesi berakhir bila request memang membawa token.
    // Pada `/api/login` kode yang sama berarti kredensial salah, dan itu tidak
    // boleh memaksa navigasi keluar dari halaman masuk.
    if (statusCode == 401 && authenticated) {
      onUnauthenticated?.call();
    }

    return ApiException(
      statusCode: statusCode,
      message: message,
      errors: errors,
      data: body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : const {},
    );
  }

  String _defaultMessage(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
      case 403:
        return 'Anda tidak berhak melakukan tindakan ini.';
      case 404:
        return 'Data yang diminta tidak ditemukan.';
      case 409:
        return 'Tindakan ini bentrok dengan data yang sudah ada.';
      case 422:
        return 'Data yang dikirim tidak valid.';
      case 429:
        return 'Terlalu banyak permintaan. Coba lagi beberapa saat.';
      case 503:
        return 'Aplikasi sedang dalam pemeliharaan. Coba lagi nanti.';
      default:
        if (statusCode >= 500) {
          return 'Terjadi gangguan pada server. Coba lagi beberapa saat.';
        }
        return 'Permintaan gagal diproses (kode: $statusCode).';
    }
  }
}
