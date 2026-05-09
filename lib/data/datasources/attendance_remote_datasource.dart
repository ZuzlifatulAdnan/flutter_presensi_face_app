import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_absensi_app/core/constants/variables.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/models/request/checkinout_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/checkinout_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/company_response_model.dart';
import 'package:http/http.dart' as http;

class AttendanceRemoteDatasource {
  Future<Either<String, CompanyResponseModel>> getCompanyProfile() async {
    final authData = await AuthLocalDatasource().getAuthData();
    final url = Uri.parse('${Variables.baseUrl}/api/company');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authData?.token}',
      },
    );

    if (response.statusCode == 200) {
      return Right(CompanyResponseModel.fromJson(response.body));
    } else {
      return const Left('Failed to get company profile');
    }
  }

  Future<Either<String, (bool, bool)>> isCheckedin() async {
    final authData = await AuthLocalDatasource().getAuthData();
    final url = Uri.parse('${Variables.baseUrl}/api/is-checkin');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authData?.token}',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return Right((
        responseData['checkedin'] as bool,
        responseData['checkedout'] as bool
      ));
    } else {
      return const Left('Failed to get checkedin status');
    }
  }

  Future<Either<String, CheckInOutResponseModel>> checkin(
      CheckInOutRequestModel data) async {
    final authData = await AuthLocalDatasource().getAuthData();
    final url = Uri.parse('${Variables.baseUrl}/api/checkin');
    try {
      final body = <String, String>{
        'latitude': data.latitude ?? '0',
        'longitude': data.longitude ?? '0',
        if (data.workMode != null) 'work_mode': data.workMode!,
      };
      debugPrint('[CHECKIN] URL: $url');
      debugPrint('[CHECKIN] Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${authData?.token}',
        },
        body: body,
      );

      debugPrint('[CHECKIN] Status: ${response.statusCode}');
      debugPrint('[CHECKIN] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(CheckInOutResponseModel.fromJson(response.body));
      } else {
        return Left(_parseErrorMessage(response.body, response.statusCode,
            'Gagal melakukan absen masuk'));
      }
    } catch (e) {
      debugPrint('[CHECKIN] Exception: $e');
      return Left('Gagal terhubung ke server: $e');
    }
  }

  Future<Either<String, CheckInOutResponseModel>> checkout(
      CheckInOutRequestModel data) async {
    final authData = await AuthLocalDatasource().getAuthData();
    final url = Uri.parse('${Variables.baseUrl}/api/checkout');
    try {
      final body = <String, String>{
        'latitude': data.latitude ?? '0',
        'longitude': data.longitude ?? '0',
        if (data.workMode != null) 'work_mode': data.workMode!,
      };
      debugPrint('[CHECKOUT] URL: $url');
      debugPrint('[CHECKOUT] Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${authData?.token}',
        },
        body: body,
      );

      debugPrint('[CHECKOUT] Status: ${response.statusCode}');
      debugPrint('[CHECKOUT] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(CheckInOutResponseModel.fromJson(response.body));
      } else {
        return Left(_parseErrorMessage(response.body, response.statusCode,
            'Gagal melakukan absen pulang'));
      }
    } catch (e) {
      debugPrint('[CHECKOUT] Exception: $e');
      return Left('Gagal terhubung ke server: $e');
    }
  }

  String _parseErrorMessage(String body, int statusCode, String fallback) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final msg = decoded['message'] ??
          decoded['error'] ??
          decoded['msg'];
      if (msg != null) return msg.toString();
      // Laravel validation errors
      final errors = decoded['errors'];
      if (errors is Map) {
        final firstField = errors.values.first;
        if (firstField is List && firstField.isNotEmpty) {
          return firstField.first.toString();
        }
      }
    } catch (_) {}
    return '$fallback (kode: $statusCode)';
  }

  Future<Either<String, AttendanceResponseModel>> getAttendance(
      String date) async {
    final authData = await AuthLocalDatasource().getAuthData();
    final url =
        Uri.parse('${Variables.baseUrl}/api/api-attendances?date=$date');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authData?.token}',
      },
    );

    if (response.statusCode == 200) {
      return Right(AttendanceResponseModel.fromJson(response.body));
    } else {
      return const Left('Failed to get attendance');
    }
  }

  Future<Either<String, AttendanceResponseModel>> getAllAttendances() async {
    final authData = await AuthLocalDatasource().getAuthData();
    final url = Uri.parse('${Variables.baseUrl}/api/api-attendances');
    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authData?.token}',
        },
      );

      debugPrint('[ATTENDANCES] Status: ${response.statusCode}');
      debugPrint('[ATTENDANCES] Response: ${response.body}');

      if (response.statusCode == 200) {
        final model = AttendanceResponseModel.fromJson(response.body);
        debugPrint('[ATTENDANCES] Total data: ${model.data?.length ?? 0}');
        return Right(model);
      } else {
        return Left(_parseErrorMessage(
            response.body, response.statusCode, 'Gagal mengambil riwayat'));
      }
    } catch (e) {
      debugPrint('[ATTENDANCES] Exception: $e');
      return Left('Gagal terhubung ke server: $e');
    }
  }
}
