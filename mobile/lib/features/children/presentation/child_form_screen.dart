import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../monitoring/domain/monitoring_models.dart';
import '../../../core/di/injection_container.dart';
import '../../monitoring/presentation/bloc/children_bloc.dart';
import '../../monitoring/presentation/bloc/map_bloc.dart';
import 'bloc/child_form_bloc.dart';
import 'bloc/child_form_event.dart';
import 'bloc/child_form_state.dart';

class ChildFormScreen extends StatelessWidget {
  const ChildFormScreen({super.key, this.child});

  final ChildModel? child;

  bool get isEditing => child != null;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChildFormBloc>(),
      child: _ChildFormView(child: child),
    );
  }
}

class _ChildFormView extends StatefulWidget {
  const _ChildFormView({this.child});

  final ChildModel? child;

  @override
  State<_ChildFormView> createState() => _ChildFormViewState();
}

class _ChildFormViewState extends State<_ChildFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();
  DateTime? _selectedDate;
  String? _selectedPhotoPath;
  String? _existingPhotoUrl;

  bool get isEditing => widget.child != null;

  @override
  void initState() {
    super.initState();
    if (widget.child != null) {
      _nameController.text = widget.child!.fullName;
      _notesController.text = widget.child!.notes ?? '';
      _selectedDate = widget.child!.dateOfBirth;
      _existingPhotoUrl = widget.child!.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_selectedPhotoPath != null || _existingPhotoUrl != null)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() {
                    _selectedPhotoPath = null;
                    _existingPhotoUrl = null;
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedPhotoPath = pickedFile.path;
          _existingPhotoUrl = null; // Clear existing URL when new photo is selected
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? DateTime(now.year - 4);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2010),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos.')),
      );
      return;
    }

    context.read<ChildFormBloc>().add(
      ChildFormSubmitted(
        CreateChildPayload(
          fullName: _nameController.text.trim(),
          dateOfBirth: _selectedDate!,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          photoPath: _selectedPhotoPath,
        ),
        childId: widget.child?.id,
      ),
    );
  }

  Widget _buildPhotoSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
          ),
          image: _selectedPhotoPath != null
              ? DecorationImage(
                  image: FileImage(File(_selectedPhotoPath!)),
                  fit: BoxFit.cover,
                )
              : _existingPhotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_existingPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: _selectedPhotoPath == null && _existingPhotoUrl == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.camera,
                    size: 32,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agregar foto',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.pencil,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChildFormBloc, ChildFormState>(
      listener: (context, state) {
        if (state.status == ChildFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? 'Niño actualizado correctamente.'
                    : 'Niño registrado correctamente.',
              ),
            ),
          );
          // Refresh the children list and map
          context.read<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
          context.read<MapBloc>().add(const MapRefreshChild());
          context.pop(true); // Return true to indicate success
        } else if (state.status == ChildFormStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Error desconocido')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Editar niño' : 'Registrar niño'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Photo selector
                _buildPhotoSelector(),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      prefixIcon: Icon(LucideIcons.calendar),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null
                              ? 'Seleccionar fecha'
                              : _formatDate(_selectedDate!),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(LucideIcons.stickyNote),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                BlocBuilder<ChildFormBloc, ChildFormState>(
                  builder: (context, state) {
                    final isLoading = state.status == ChildFormStatus.loading;
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isEditing
                                    ? LucideIcons.save
                                    : LucideIcons.userPlus,
                              ),
                        label: Text(
                          isEditing ? 'Guardar cambios' : 'Registrar niño',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
