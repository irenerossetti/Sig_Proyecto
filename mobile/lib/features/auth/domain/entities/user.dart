import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.photoUrl,
  });

  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? photoUrl;

  @override
  List<Object?> get props => [id, fullName, email, phone, photoUrl];
}
