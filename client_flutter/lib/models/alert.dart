import 'package:client_flutter/models/app_user.dart';

import '../core/parsing/typed_parser.dart';

class AlertVerification {
  AlertVerification({
    required this.id,
    this.alertId,
    this.createdAt,
    this.userId,
    this.users,
    this.verified,
  });

  final int id;
  final int? alertId;
  final DateTime? createdAt;
  final int? userId;
  final AppUser? users;
  final bool? verified;

  factory AlertVerification.fromJson(Object? json) {
    final typed = TypedMap(asJsonMap(json), context: 'AlertVerification');

    return AlertVerification(
      id: typed.reqInt('id'),
      alertId: typed.optInt('alert_id'),
      createdAt: typed.optDateTime('created_at'),
      userId: typed.optInt('user_id'),
      users: _parseVerificationUsers(typed),
      verified: typed.optBool('verified'),
    );
  }
}

AppUser? _parseVerificationUsers(TypedMap typed) {
  final raw = typed.optObject('user') ?? typed.optObject('users');
  if (raw == null) {
    return null;
  }

  return AppUser.fromJson(raw);
}

class Tier {
  Tier({required this.id, this.createdAt, this.priority, this.tier});

  final int id;
  final DateTime? createdAt;
  final String? priority;
  final String? tier;

  factory Tier.fromJson(Object? json) {
    final typed = TypedMap(asJsonMap(json), context: 'Tier');

    return Tier(
      id: typed.reqInt('id'),
      createdAt: typed.optDateTime('created_at'),
      priority: typed.optString('priority'),
      tier: typed.optString('tier'),
    );
  }
}

class Alert {
  Alert({
    required this.id,
    required this.category,
    required this.createdAt,
    required this.flagged,
    required this.location,
    this.body,
    this.publishedAt,
    this.radiusM,
    this.status,
    this.tier,
    this.tierInfo,
    this.title,
    this.userId,
    this.verifications = const [],
  });

  final int id;
  final String category;
  final DateTime createdAt;
  final bool flagged;
  final Object location;
  final String? body;
  final DateTime? publishedAt;
  final int? radiusM;
  final String? status;
  final int? tier;
  final Tier? tierInfo;
  final String? title;
  final int? userId;
  final List<AlertVerification> verifications;

  factory Alert.fromJson(Object? json) {
    final typed = TypedMap(asJsonMap(json), context: 'Alert');

    return Alert(
      id: typed.reqInt('id'),
      category: typed.reqString('category'),
      createdAt: typed.reqDateTime('created_at'),
      flagged: typed.reqBool('flagged'),
      location: typed.reqObject('location'),
      body: typed.optString('body'),
      publishedAt: typed.optDateTime('published_at'),
      radiusM: typed.optInt('radius_m'),
      status: typed.optString('status'),
      tier: typed.optInt('tier'),
      tierInfo: typed.opt('tierInfo', Tier.fromJson),
      title: typed.optString('title'),
      userId: typed.optInt('user_id'),
      verifications: _parseVerifications(typed),
    );
  }
}

List<AlertVerification> _parseVerifications(TypedMap typed) {
  final raw =
      typed.optObject('verifications') ??
      typed.optObject('alerts_verifications');
  if (raw == null) {
    return const [];
  }

  final list = asJsonMapList(raw, context: 'Alert.alerts_verifications');
  return list.map(AlertVerification.fromJson).toList();
}
