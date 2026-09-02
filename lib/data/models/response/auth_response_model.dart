import 'dart:convert';

import 'package:flutter_absensi_app/data/models/response/company_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/json_value.dart';

class AuthResponseModel {
    final User? user;
    final String? token;
    final String? role;
    final String? workMode;
    final Company? company;
    final Position? position;
    final DefaultShift? defaultShift;
    final DefaultShiftDetail? defaultShiftDetail;
    final Department? department;

    AuthResponseModel({
        this.user,
        this.token,
        this.role,
        this.workMode,
        this.company,
        this.position,
        this.defaultShift,
        this.defaultShiftDetail,
        this.department,
    });

    factory AuthResponseModel.fromJson(String str) => AuthResponseModel.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory AuthResponseModel.fromMap(Map<String, dynamic> json) => AuthResponseModel(
        user: asModel(json["user"], User.fromMap),
        token: asString(json["token"]),
        role: asString(json["role"]),
        workMode: asString(json["work_mode"]),
        company: asModel(json["company"], Company.fromMap),
        position: asModel(json["position"], Position.fromMap),
        defaultShift: asModel(json["default_shift"], DefaultShift.fromMap),
        defaultShiftDetail: asModel(json["default_shift_detail"], DefaultShiftDetail.fromMap),
        department: asModel(json["department"], Department.fromMap),
    );

    Map<String, dynamic> toMap() => {
        "user": user?.toMap(),
        "token": token,
        "role": role,
        "work_mode": workMode,
        "company": company?.toMap(),
        "position": position?.toMap(),
        "default_shift": defaultShift?.toMap(),
        "default_shift_detail": defaultShiftDetail?.toMap(),
        "department": department?.toMap(),
    };

  AuthResponseModel copyWith({
    User? user,
    String? token,
    String? role,
    String? workMode,
    Company? company,
    Position? position,
    DefaultShift? defaultShift,
    DefaultShiftDetail? defaultShiftDetail,
    Department? department,
  }) {
    return AuthResponseModel(
      user: user ?? this.user,
      token: token ?? this.token,
      role: role ?? this.role,
      workMode: workMode ?? this.workMode,
      company: company ?? this.company,
      position: position ?? this.position,
      defaultShift: defaultShift ?? this.defaultShift,
      defaultShiftDetail: defaultShiftDetail ?? this.defaultShiftDetail,
      department: department ?? this.department,
    );
  }
}

class User {
    final int? id;
    final String? name;
    final String? email;
    final String? workMode;
    final int? companyId;
    final DateTime? emailVerifiedAt;
    final dynamic twoFactorSecret;
    final dynamic twoFactorRecoveryCodes;
    final dynamic twoFactorConfirmedAt;
    final dynamic fcmToken;
    final DateTime? createdAt;
    final DateTime? updatedAt;
    final String? phone;
    final String? role;
    final String? position;
    final String? department;
    final int? jabatanId;
    final int? departemenId;
    final int? shiftKerjaId;
    final dynamic faceEmbedding;
    final dynamic imageUrl;
    final ShiftKerja? shiftKerja;
    final Departemen? departemen;

    User({
        this.id,
        this.name,
        this.email,
        this.workMode,
        this.companyId,
        this.emailVerifiedAt,
        this.twoFactorSecret,
        this.twoFactorRecoveryCodes,
        this.twoFactorConfirmedAt,
        this.fcmToken,
        this.createdAt,
        this.updatedAt,
        this.phone,
        this.role,
        this.position,
        this.department,
        this.jabatanId,
        this.departemenId,
        this.shiftKerjaId,
        this.faceEmbedding,
        this.imageUrl,
        this.shiftKerja,
        this.departemen,
    });

    factory User.fromJson(String str) => User.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory User.fromMap(Map<String, dynamic> json) => User(
        id: asInt(json["id"]),
        name: asString(json["name"]),
        email: asString(json["email"]),
        workMode: asString(json["work_mode"]),
        companyId: asInt(json["company_id"]),
        emailVerifiedAt: asDate(json["email_verified_at"]),
        twoFactorSecret: json["two_factor_secret"],
        twoFactorRecoveryCodes: json["two_factor_recovery_codes"],
        twoFactorConfirmedAt: json["two_factor_confirmed_at"],
        fcmToken: json["fcm_token"],
        createdAt: asDate(json["created_at"]),
        updatedAt: asDate(json["updated_at"]),
        phone: asString(json["phone"]),
        // `role`, `position`, dan `department` bisa berupa teks atau objek
        // relasi `{id, name}` tergantung endpoint; keduanya dibaca sebagai nama.
        role: asString(json["role"]),
        position: asString(json["position"]),
        department: asString(json["department"]),
        jabatanId: asInt(json["jabatan_id"]),
        departemenId: asInt(json["departemen_id"]),
        shiftKerjaId: asInt(json["shift_kerja_id"]),
        faceEmbedding: json["face_embedding"],
        imageUrl: json["image_url"],
        shiftKerja: asModel(json["shift_kerja"], ShiftKerja.fromMap),
        departemen: asModel(json["departemen"], Departemen.fromMap),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "email": email,
        "work_mode": workMode,
        "company_id": companyId,
        "email_verified_at": emailVerifiedAt?.toIso8601String(),
        "two_factor_secret": twoFactorSecret,
        "two_factor_recovery_codes": twoFactorRecoveryCodes,
        "two_factor_confirmed_at": twoFactorConfirmedAt,
        "fcm_token": fcmToken,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "phone": phone,
        "role": role,
        "position": position,
        "department": department,
        "jabatan_id": jabatanId,
        "departemen_id": departemenId,
        "shift_kerja_id": shiftKerjaId,
        "face_embedding": faceEmbedding,
        "image_url": imageUrl,
        "shift_kerja": shiftKerja?.toMap(),
        "departemen": departemen?.toMap(),
    };
}

class ShiftKerja {
    final int? id;
    final String? name;
    final String? startTime;
    final String? endTime;
    final bool? isCrossDay;
    final int? gracePeriodMinutes;
    final bool? isActive;
    final String? description;
    final DateTime? createdAt;
    final DateTime? updatedAt;

    ShiftKerja({
        this.id,
        this.name,
        this.startTime,
        this.endTime,
        this.isCrossDay,
        this.gracePeriodMinutes,
        this.isActive,
        this.description,
        this.createdAt,
        this.updatedAt,
    });

    factory ShiftKerja.fromJson(String str) => ShiftKerja.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory ShiftKerja.fromMap(Map<String, dynamic> json) => ShiftKerja(
        id: asInt(json["id"]),
        name: asString(json["name"]),
        startTime: asString(json["start_time"]),
        endTime: asString(json["end_time"]),
        isCrossDay: asBool(json["is_cross_day"]),
        gracePeriodMinutes: asInt(json["grace_period_minutes"]),
        isActive: asBool(json["is_active"]),
        description: asString(json["description"]),
        createdAt: asDate(json["created_at"]),
        updatedAt: asDate(json["updated_at"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "start_time": startTime,
        "end_time": endTime,
        "is_cross_day": isCrossDay,
        "grace_period_minutes": gracePeriodMinutes,
        "is_active": isActive,
        "description": description,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}

class Departemen {
    final int? id;
    final String? name;
    final String? description;
    final DateTime? createdAt;
    final DateTime? updatedAt;

    Departemen({
        this.id,
        this.name,
        this.description,
        this.createdAt,
        this.updatedAt,
    });

    factory Departemen.fromJson(String str) => Departemen.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory Departemen.fromMap(Map<String, dynamic> json) => Departemen(
        id: asInt(json["id"]),
        name: asString(json["name"]),
        description: asString(json["description"]),
        createdAt: asDate(json["created_at"]),
        updatedAt: asDate(json["updated_at"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "description": description,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}

class DefaultShift {
    final int? id;
    final String? name;

    DefaultShift({
        this.id,
        this.name,
    });

    factory DefaultShift.fromJson(String str) => DefaultShift.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory DefaultShift.fromMap(Map<String, dynamic> json) => DefaultShift(
        id: asInt(json["id"]),
        name: asString(json["name"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
    };
}

class DefaultShiftDetail {
    final int? id;
    final String? name;
    final String? startTime;
    final String? endTime;

    DefaultShiftDetail({
        this.id,
        this.name,
        this.startTime,
        this.endTime,
    });

    factory DefaultShiftDetail.fromJson(String str) => DefaultShiftDetail.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory DefaultShiftDetail.fromMap(Map<String, dynamic> json) => DefaultShiftDetail(
        id: asInt(json["id"]),
        name: asString(json["name"]),
        startTime: asString(json["start_time"]),
        endTime: asString(json["end_time"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "start_time": startTime,
        "end_time": endTime,
    };
}

class Department {
    final int? id;
    final String? name;

    Department({
        this.id,
        this.name,
    });

    factory Department.fromJson(String str) => Department.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory Department.fromMap(Map<String, dynamic> json) => Department(
        id: asInt(json["id"]),
        name: asString(json["name"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
    };
}

class Position {
    final int? id;
    final String? name;

    Position({
        this.id,
        this.name,
    });

    factory Position.fromJson(String str) => Position.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory Position.fromMap(Map<String, dynamic> json) => Position(
        id: asInt(json["id"]),
        name: asString(json["name"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
    };
}
