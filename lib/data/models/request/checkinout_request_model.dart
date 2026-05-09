import 'dart:convert';

class CheckInOutRequestModel {
    final String? latitude;
    final String? longitude;
    final String? workMode;

    CheckInOutRequestModel({
        this.latitude,
        this.longitude,
        this.workMode,
    });

    factory CheckInOutRequestModel.fromJson(String str) => CheckInOutRequestModel.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory CheckInOutRequestModel.fromMap(Map<String, dynamic> json) => CheckInOutRequestModel(
        latitude: json["latitude"],
        longitude: json["longitude"],
        workMode: json["work_mode"],
    );

    Map<String, dynamic> toMap() {
        final map = <String, dynamic>{
            "latitude": latitude,
            "longitude": longitude,
        };
        if (workMode != null) map["work_mode"] = workMode;
        return map;
    }
}
