import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;



class DoctorModel {
  final String? id; // Firestore document ID (null if not saved yet)
  final String name;
  final String specialization;
  final String department;
  final int patientsCount; // calculated, not stored in Firestore
  final String status;

  // The doctor's picture. Saved to Firestore as a small base64 JPEG
  // (field "photoBase64"), so it shows on the patient app too.
  final Uint8List? photoBytes;
  final String? photoAssetPath;
  final String? experience;
  final String? workingHours;
  final String? qualification;
  final String? tokenPrefix;
  final int fee;
  final String? email; // doctor's login email (display only)
  final String? authUid; // Firebase Auth uid of the doctor's login
  // Admin-controlled access to the app: 'invited' | 'active' | 'revoked'
  // (missing = never invited). Read only: it is changed by the invite /
  // revoke buttons, never by the Edit Doctor form.
  final String? loginStatus;

  const DoctorModel({
    this.id,
    required this.name,
    required this.specialization,
    required this.department,
    required this.patientsCount,
    required this.status,
    this.photoBytes,
    this.photoAssetPath,
    this.experience,
    this.workingHours,
    this.qualification,
    this.tokenPrefix,
    required this.fee,
    this.email,
    this.authUid,
    this.loginStatus,
  });

  /// 'none' | 'invited' | 'active' | 'revoked'
  String get accessStatus =>
      loginStatus ?? (authUid != null ? 'invited' : 'none');

  /// Builds a DoctorModel from a Firestore document.
  factory DoctorModel.fromMap(
    String id,
    Map<String, dynamic> map, {
    int patientsCount = 0,
  }) {
    return DoctorModel(
      id: id,
      name: map['name'] as String? ?? '',
      specialization: map['specialization'] as String? ?? '',
      department: map['department'] as String? ?? '',
      patientsCount: patientsCount,
      status: map['status'] as String? ?? 'Available',
      photoBytes: ImageCodec.fromBase64(map['photoBase64'] as String?),
      photoAssetPath: map['photoAssetPath'] as String?,
      experience: map['experience'] as String?,
      workingHours: map['workingHours'] as String?,
      qualification: map['qualification'] as String?,
      tokenPrefix: map['tokenPrefix'] as String?,
      fee: (map['fee'] as num?)?.toInt() ?? 0,
      email: map['email'] as String?,
      authUid: map['authUid'] as String?,
      loginStatus: map['loginStatus'] as String?,
    );
  }

  /// Converts this doctor to a map for Firestore.
  Map<String, dynamic> toMap() {
    // Shrunk to a small JPEG text. Null when there is no photo (or it could
    // not be made small enough), in which case the field is left out and an
    // already saved photo is not touched.
    final String? photoBase64 = photoBytes == null
        ? null
        : ImageCodec.toStorableBase64(photoBytes!);

    return {
      'name': name,
      'specialization': specialization,
      'department': department,
      'status': status,
      'photoAssetPath': photoAssetPath,
      'experience': experience,
      'workingHours': workingHours,
      'qualification': qualification,
      'tokenPrefix': tokenPrefix,
      'fee': fee,
      if (email != null) 'email': email,
      if (authUid != null) 'authUid': authUid,
      'photoBase64': ?photoBase64,
    };
  }
}

/// Turns a picked photo into a small text string that fits inside a
/// Firestore document (and back). Used for doctor and department pictures,
/// so no Firebase Storage (paid plan) is needed.
///
/// A Firestore document can be at most 1 MiB, so big photos are shrunk to
/// a small JPEG first.
class ImageCodec {
  ImageCodec._();

  // Longest side of the stored picture, in pixels.
  static const int maxSide = 480;

  // JPEG quality, 1 to 100.
  static const int jpegQuality = 80;

  // A photo that is already this small is stored as it is.
  static const int _alreadySmallBytes = 150 * 1024;

  // Safety limit for the final text (well under Firestore's 1 MiB).
  static const int _maxEncodedLength = 600 * 1024;

  /// Photo bytes -> base64 text for Firestore. Returns null when the photo
  /// cannot be made small enough (or is not a picture), so the caller can
  /// skip it instead of breaking the whole save.
  static String? toStorableBase64(Uint8List bytes) {
    try {
      Uint8List smallBytes = bytes;

      if (bytes.length > _alreadySmallBytes) {
        final decoded = img.decodeImage(bytes);
        if (decoded == null) return null;

        final img.Image resized =
            (decoded.width > maxSide || decoded.height > maxSide)
            ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? maxSide : null,
                height: decoded.height > decoded.width ? maxSide : null,
              )
            : decoded;

        smallBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: jpegQuality),
        );
      }

      final encoded = base64Encode(smallBytes);
      if (encoded.length > _maxEncodedLength) return null;
      return encoded;
    } catch (e) {
      debugPrint('ImageCodec.toStorableBase64 failed: $e');
      return null;
    }
  }

  /// base64 text from Firestore -> photo bytes. Returns null when there is
  /// no photo or the text is not valid.
  static Uint8List? fromBase64(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return base64Decode(text);
    } catch (_) {
      return null;
    }
  }
}