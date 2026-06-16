import 'package:equatable/equatable.dart';

enum ChildFormStatus { initial, loading, success, failure }

class ChildFormState extends Equatable {
  final ChildFormStatus status;
  final String? errorMessage;

  const ChildFormState({
    this.status = ChildFormStatus.initial,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, errorMessage];
}
