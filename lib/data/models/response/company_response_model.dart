import 'dart:convert';

import 'package:flutter_absensi_app/data/models/response/json_value.dart';

class CompanyResponseModel {
    final Company? company;

    CompanyResponseModel({
        this.company,
    });

    factory CompanyResponseModel.fromJson(String str) => CompanyResponseModel.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory CompanyResponseModel.fromMap(Map<String, dynamic> json) => CompanyResponseModel(
        company: asModel(json["company"], Company.fromMap),
    );

    Map<String, dynamic> toMap() => {
        "company": company?.toMap(),
    };
}

class Company {
    final int? id;
    final String? name;
    final String? email;
    final String? address;
    final String? latitude;
    final String? longitude;
    final String? radiusKm;
    final String? timeIn;
    final String? timeOut;
    final String? attendanceType;
    final DateTime? createdAt;
    final DateTime? updatedAt;

    Company({
        this.id,
        this.name,
        this.email,
        this.address,
        this.latitude,
        this.longitude,
        this.radiusKm,
        this.timeIn,
        this.timeOut,
        this.createdAt,
        this.updatedAt,
        this.attendanceType,
    });

    factory Company.fromJson(String str) => Company.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory Company.fromMap(Map<String, dynamic> json) => Company(
        id: asInt(json["id"]),
        name: asString(json["name"]),
        email: asString(json["email"]),
        address: asString(json["address"]),
        // Koordinat dan radius dikirim sebagai teks atau angka tergantung cast
        // di backend; keduanya disimpan sebagai teks di sini.
        latitude: asString(json["latitude"]),
        longitude: asString(json["longitude"]),
        radiusKm: asString(json["radius_km"]),
        timeIn: asString(json["time_in"]),
        timeOut: asString(json["time_out"]),
        attendanceType: asString(json["attendance_type"]),
        createdAt: asDate(json["created_at"]),
        updatedAt: asDate(json["updated_at"]),
    );

    Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "email": email,
        "address": address,
        "latitude": latitude,
        "longitude": longitude,
        "radius_km": radiusKm,
        "time_in": timeIn,
        "time_out": timeOut,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
