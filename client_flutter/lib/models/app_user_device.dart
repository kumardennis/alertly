import '../core/parsing/typed_parser.dart';

class AppUserDevice {
  AppUserDevice({
    required this.id,
    required this.fcmToken,
    required this.createdAt,
    this.platform,
    this.updatedAt,
    this.userId,
  });

  final int id;
  final String fcmToken;
  final DateTime createdAt;
  final String? platform;
  final DateTime? updatedAt;
  final int? userId;

  factory AppUserDevice.fromJson(Object? json) {
    final typed = TypedMap(asJsonMap(json), context: 'AppUserDevice');

    return AppUserDevice(
      id: typed.reqInt('id'),
      fcmToken: typed.reqString('fcm_token'),
      createdAt: typed.reqDateTime('created_at'),
      platform: typed.optString('platform'),
      updatedAt: typed.optDateTime('updated_at'),
      userId: typed.optInt('user_id'),
    );
  }
}
