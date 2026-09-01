import 'dart:convert';

class LeaveResponseModel {
  final String? message;
  final List<Leave>? data;
  final int? currentPage;
  final int? lastPage;
  final int? total;

  LeaveResponseModel({
    this.message,
    this.data,
    this.currentPage,
    this.lastPage,
    this.total,
  });

  factory LeaveResponseModel.fromJson(String str) =>
      LeaveResponseModel.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory LeaveResponseModel.fromMap(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map && rawData['data'] is List) {
      list = rawData['data'] as List;
    } else {
      list = const [];
    }

    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};

    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return LeaveResponseModel(
      message: json['message']?.toString(),
      data: list
          .whereType<Map>()
          .map((x) => Leave.fromMap(Map<String, dynamic>.from(x)))
          .toList(),
      currentPage: asInt(meta['current_page']),
      lastPage: asInt(meta['last_page']),
      total: asInt(meta['total']),
    );
  }

  Map<String, dynamic> toMap() => {
        'message': message,
        'data':
            data == null ? [] : List<dynamic>.from(data!.map((x) => x.toMap())),
      };
}

/// Lampiran pengajuan izin/cuti (JPG, PNG, WEBP, PDF s/d 5 MB).
class LeaveAttachment {
  final String? url;
  final String? name;
  final String? mime;
  final int? size;

  const LeaveAttachment({this.url, this.name, this.mime, this.size});

  factory LeaveAttachment.fromMap(Map<String, dynamic> json) => LeaveAttachment(
        url: json['url']?.toString(),
        name: json['name']?.toString(),
        mime: json['mime']?.toString(),
        size: (json['size'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'name': name,
        'mime': mime,
        'size': size,
      };

  bool get isPdf =>
      (mime ?? '').contains('pdf') ||
      (name ?? url ?? '').toLowerCase().endsWith('.pdf');

  bool get isImage => (mime ?? '').startsWith('image/') || !isPdf;

  /// Ukuran siap tampil, mis. `180 KB`.
  String get sizeLabel {
    final bytes = size;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class LeaveEmployee {
  final int? id;
  final String? name;
  final String? email;

  const LeaveEmployee({this.id, this.name, this.email});

  factory LeaveEmployee.fromMap(Map<String, dynamic> json) => LeaveEmployee(
        id: (json['id'] as num?)?.toInt(),
        name: json['name']?.toString(),
        email: json['email']?.toString(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'email': email};
}

class Leave {
  final int? id;
  final int? employeeId;
  final int? leaveTypeId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? totalDays;
  final String? reason;

  /// Bentuk lama: URL lampiran sebagai string.
  final String? attachmentUrl;

  /// Bentuk baru: objek lampiran lengkap dengan nama, mime, dan ukuran.
  final LeaveAttachment? attachment;
  final String? status;
  final String? statusLabel;
  final bool? canEdit;
  final bool? canCancel;
  final int? approvedBy;
  final DateTime? approvedAt;
  final DateTime? cancelledAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final LeaveType? leaveType;
  final LeaveEmployee? employee;
  final Approver? approver;

  Leave({
    this.id,
    this.employeeId,
    this.leaveTypeId,
    this.startDate,
    this.endDate,
    this.totalDays,
    this.reason,
    this.attachmentUrl,
    this.attachment,
    this.status,
    this.statusLabel,
    this.canEdit,
    this.canCancel,
    this.approvedBy,
    this.approvedAt,
    this.cancelledAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.leaveType,
    this.employee,
    this.approver,
  });

  factory Leave.fromJson(String str) => Leave.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory Leave.fromMap(Map<String, dynamic> json) {
    Map<String, dynamic>? sub(String key) =>
        json[key] is Map ? Map<String, dynamic>.from(json[key] as Map) : null;

    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.tryParse(json[key].toString())?.toLocal();

    final attachmentNode = sub('attachment');

    return Leave(
      id: (json['id'] as num?)?.toInt(),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      leaveTypeId: (json['leave_type_id'] as num?)?.toInt(),
      startDate: date('start_date'),
      endDate: date('end_date'),
      totalDays: (json['total_days'] as num?)?.toInt(),
      reason: json['reason']?.toString(),
      attachmentUrl: json['attachment_url']?.toString() ??
          attachmentNode?['url']?.toString(),
      attachment: attachmentNode == null
          ? (json['attachment_url'] == null
              ? null
              : LeaveAttachment(url: json['attachment_url'].toString()))
          : LeaveAttachment.fromMap(attachmentNode),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      canEdit: json['can_edit'] as bool?,
      canCancel: json['can_cancel'] as bool?,
      approvedBy: (json['approved_by'] as num?)?.toInt(),
      approvedAt: date('approved_at'),
      cancelledAt: date('cancelled_at'),
      notes: json['notes']?.toString(),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      leaveType:
          sub('leave_type') == null ? null : LeaveType.fromMap(sub('leave_type')!),
      employee: sub('employee') == null
          ? null
          : LeaveEmployee.fromMap(sub('employee')!),
      approver:
          sub('approver') == null ? null : Approver.fromMap(sub('approver')!),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'leave_type_id': leaveTypeId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'total_days': totalDays,
        'reason': reason,
        'attachment_url': attachmentUrl,
        'attachment': attachment?.toMap(),
        'status': status,
        'status_label': statusLabel,
        'can_edit': canEdit,
        'can_cancel': canCancel,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'notes': notes,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'leave_type': leaveType?.toMap(),
        'employee': employee?.toMap(),
        'approver': approver?.toMap(),
      };

  /// Teks status siap tampil. Utamakan `status_label` dari server.
  String get displayStatus {
    if (statusLabel != null && statusLabel!.isNotEmpty) return statusLabel!;
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status ?? '-';
    }
  }

  bool get isPending => status == 'pending';

  bool get isApproved => status == 'approved';

  bool get isRejected => status == 'rejected';

  bool get isCancelled => status == 'cancelled';

  /// Hanya pengajuan `pending` milik sendiri yang bisa diubah/dibatalkan.
  bool get editable => canEdit ?? isPending;

  bool get cancellable => canCancel ?? isPending;

  bool get hasAttachment =>
      attachment?.url != null && attachment!.url!.isNotEmpty;
}

class LeaveType {
  final int? id;
  final String? name;
  final int? quotaDays;
  final bool? isPaid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeaveType({
    this.id,
    this.name,
    this.quotaDays,
    this.isPaid,
    this.createdAt,
    this.updatedAt,
  });

  factory LeaveType.fromJson(String str) => LeaveType.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory LeaveType.fromMap(Map<String, dynamic> json) => LeaveType(
        id: (json['id'] as num?)?.toInt(),
        name: json['name']?.toString(),
        quotaDays: (json['quota_days'] as num?)?.toInt(),
        isPaid: json['is_paid'] as bool?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quota_days': quotaDays,
        'is_paid': isPaid,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class Approver {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? role;
  final String? position;
  final String? department;
  final String? imageUrl;

  Approver({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.role,
    this.position,
    this.department,
    this.imageUrl,
  });

  factory Approver.fromJson(String str) => Approver.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory Approver.fromMap(Map<String, dynamic> json) => Approver(
        id: (json['id'] as num?)?.toInt(),
        name: json['name']?.toString(),
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        role: json['role']?.toString(),
        // Backend baru mengirim `position` sebagai objek `{id, name}`.
        position: json['position'] is Map
            ? (json['position'] as Map)['name']?.toString()
            : json['position']?.toString(),
        department: json['department'] is Map
            ? (json['department'] as Map)['name']?.toString()
            : json['department']?.toString(),
        imageUrl: json['image_url']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'position': position,
        'department': department,
        'image_url': imageUrl,
      };
}
