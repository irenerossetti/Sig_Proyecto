import 'package:equatable/equatable.dart';
import '../../../monitoring/domain/monitoring_models.dart';

abstract class ChildFormEvent extends Equatable {
  const ChildFormEvent();

  @override
  List<Object?> get props => [];
}

class ChildFormSubmitted extends ChildFormEvent {
  final CreateChildPayload payload;
  final int? childId; // null = create, not null = update

  const ChildFormSubmitted(this.payload, {this.childId});

  @override
  List<Object?> get props => [payload, childId];
}
