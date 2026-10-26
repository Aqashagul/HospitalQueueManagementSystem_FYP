import 'dart:typed_data';
import 'package:queue_management_system/models/doctor_model.dart';



class Department {
  final String? id; // Firestore document ID (null if not saved yet)
  final String name;
  final String head;
  final int assignedDoctors; // calculated, not stored in Firestore
  final String status; // Active | Inactive
  final String createdDate;

  // The department's picture. Saved to Firestore as a small base64 JPEG
  // (field "photoBase64"), so it shows on the patient app too.
  final Uint8List? photoBytes;

  const Department({
    this.id,
    required this.name,
    required this.head,
    required this.assignedDoctors,
    required this.status,
    required this.createdDate,
    this.photoBytes,
  });

  /// Builds a Department from a Firestore document.
  factory Department.fromMap(
    String id,
    Map<String, dynamic> map, {
    int assignedDoctors = 0,
  }) {
    return Department(
      id: id,
      name: map['name'] as String? ?? '',
      head: map['head'] as String? ?? '',
      assignedDoctors: assignedDoctors,
      status: map['status'] as String? ?? 'Active',
      createdDate: map['createdDate'] as String? ?? '',
      photoBytes: ImageCodec.fromBase64(map['photoBase64'] as String?),
    );
  }

  /// Converts this Department to a map for Firestore.
  Map<String, dynamic> toMap() {
    // Shrunk to a small JPEG text. Null when there is no photo (or it could
    // not be made small enough), in which case the field is left out and an
    // already saved photo is not touched.
    final String? photoBase64 = photoBytes == null
        ? null
        : ImageCodec.toStorableBase64(photoBytes!);

    return {
      'name': name,
      'head': head,
      'status': status,
      'createdDate': createdDate,
      'photoBase64': ?photoBase64,
    };
  }
}