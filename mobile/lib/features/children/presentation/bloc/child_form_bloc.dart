import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../monitoring/data/monitoring_repository.dart';
import 'child_form_event.dart';
import 'child_form_state.dart';

class ChildFormBloc extends Bloc<ChildFormEvent, ChildFormState> {
  final MonitoringRepository _repo;
  final AuthBloc _authBloc;

  ChildFormBloc({
    required MonitoringRepository repo,
    required AuthBloc authBloc,
  })  : _repo = repo,
        _authBloc = authBloc,
        super(const ChildFormState()) {
    on<ChildFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    ChildFormSubmitted event,
    Emitter<ChildFormState> emit,
  ) async {
    emit(const ChildFormState(status: ChildFormStatus.loading));
    final token = _authBloc.state.token;

    if (token == null || token.isEmpty) {
      emit(const ChildFormState(
        status: ChildFormStatus.failure,
        errorMessage: 'No estás autenticado.',
      ));
      return;
    }

    try {
      if (event.childId != null) {
        // Update existing child
        await _repo.updateChild(
          token: token,
          childId: event.childId!,
          payload: event.payload,
        );
      } else {
        // Create new child
        await _repo.createChild(token: token, payload: event.payload);
      }
      emit(const ChildFormState(status: ChildFormStatus.success));
    } catch (e) {
      emit(ChildFormState(
        status: ChildFormStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
