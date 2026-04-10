import '../core/parsing/typed_parser.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.createdAt,
    this.age,
    this.authId,
    this.firstName,
    this.isAgeVerified,
    this.lastName,
    this.location,
    this.locationUpdatedAt,
    required this.preferredRadiusM,
    this.repScore,
    this.role,
  });

  final int id;
  final String username;
  final DateTime createdAt;
  final int? age;
  final String? authId;
  final String? firstName;
  final bool? isAgeVerified;
  final String? lastName;
  final Object? location;
  final DateTime? locationUpdatedAt;
  final int preferredRadiusM;
  final int? repScore;
  final int? role;

  String get displayName {
    final first = firstName?.trim();
    final last = lastName?.trim();
    final fullName = [
      if (first != null && first.isNotEmpty) first,
      if (last != null && last.isNotEmpty) last,
    ].join(' ');
    return fullName.isNotEmpty ? fullName : username;
  }

  factory AppUser.fromJson(Object? json) {
    final typed = TypedMap(asJsonMap(json), context: 'AppUser');

    return AppUser(
      id: typed.reqInt('id'),
      username: typed.reqString('username'),
      createdAt: typed.reqDateTime('created_at'),
      age: typed.optInt('age'),
      authId: typed.optString('auth_id'),
      firstName: typed.optString('first_name'),
      isAgeVerified: typed.optBool('is_age_verified'),
      lastName: typed.optString('last_name'),
      location: typed.optObject('location'),
      locationUpdatedAt: typed.optDateTime('location_updated_at'),
      preferredRadiusM: typed.optInt('preferred_radius_m') ?? 0,
      repScore: typed.optInt('rep_score'),
      role: typed.optInt('role'),
    );
  }
}
