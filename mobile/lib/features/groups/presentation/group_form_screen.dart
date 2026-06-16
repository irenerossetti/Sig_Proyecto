import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/group_models.dart';
import '../data/group_repository.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../../core/di/injection_container.dart';
import 'bloc/groups_bloc.dart';

class GroupFormScreen extends StatefulWidget {
  const GroupFormScreen({super.key, this.group});

  final ChildGroupModel? group;

  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Color y icono seleccionados
  late String _selectedColor;
  late String _selectedIcon;

  // Colores disponibles
  static const _availableColors = [
    {'name': 'Azul', 'hex': '#2196F3'},
    {'name': 'Verde', 'hex': '#4CAF50'},
    {'name': 'Rojo', 'hex': '#F44336'},
    {'name': 'Naranja', 'hex': '#FF9800'},
    {'name': 'Púrpura', 'hex': '#9C27B0'},
    {'name': 'Rosa', 'hex': '#E91E63'},
    {'name': 'Turquesa', 'hex': '#00BCD4'},
    {'name': 'Índigo', 'hex': '#3F51B5'},
  ];

  // Iconos disponibles (solo datos, iconos se resuelven en tiempo de ejecución)
  static const _availableIconNames = [
    {'name': 'Usuarios', 'value': 'users'},
    {'name': 'Escuela', 'value': 'school'},
    {'name': 'Casa', 'value': 'home'},
    {'name': 'Bus', 'value': 'bus'},
    {'name': 'Corazón', 'value': 'heart'},
    {'name': 'Estrella', 'value': 'star'},
    {'name': 'Libro', 'value': 'book'},
    {'name': 'Música', 'value': 'music'},
  ];

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _descriptionController = TextEditingController(text: widget.group?.description ?? '');
    _selectedColor = widget.group?.color ?? '#2196F3';
    _selectedIcon = widget.group?.icon ?? 'users';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData _getIconData(String iconValue) {
    switch (iconValue) {
      case 'users':
        return LucideIcons.users;
      case 'school':
        return LucideIcons.school;
      case 'home':
        return LucideIcons.house;
      case 'bus':
        return LucideIcons.bus;
      case 'heart':
        return LucideIcons.heart;
      case 'star':
        return LucideIcons.star;
      case 'book':
        return LucideIcons.bookOpen;
      case 'music':
        return LucideIcons.music;
      default:
        return LucideIcons.users;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState.status != AuthStatus.authenticated || authState.token == null) {
        setState(() {
          _errorMessage = 'No autenticado';
          _isLoading = false;
        });
        return;
      }

      final repository = sl<GroupRepository>();
      final token = authState.token!;

      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'color': _selectedColor,
        'icon': _selectedIcon,
      };

      if (_isEditing) {
        await repository.updateGroup(
          token: token,
          groupId: widget.group!.id,
          data: data,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grupo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final payload = CreateGroupPayload(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor,
          icon: _selectedIcon,
        );
        await repository.createGroup(token: token, payload: payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grupo creado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Refrescar lista de grupos
      if (mounted) {
        context.read<GroupsBloc>().add(const GroupsFetchRequested());
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('GroupRepositoryException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar grupo' : 'Crear grupo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview del grupo
              _buildGroupPreview(),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.circleAlert, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Campo nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del grupo *',
                  hintText: 'Ej: Kinder Sol Naciente',
                  prefixIcon: Icon(LucideIcons.users),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Campo descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Describe el propósito del grupo',
                  prefixIcon: Icon(LucideIcons.fileText),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // Selector de color
              Text(
                'Color del grupo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildColorSelector(),
              const SizedBox(height: 24),

              // Selector de icono
              Text(
                'Icono del grupo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildIconSelector(),
              const SizedBox(height: 32),

              // Botón de guardar
              FilledButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Icon(_isEditing ? LucideIcons.save : LucideIcons.plus),
                label: Text(_isEditing ? 'Guardar cambios' : 'Crear grupo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPreview() {
    final color = _parseColor(_selectedColor);
    final icon = _getIconData(_selectedIcon);
    final name = _nameController.text.trim().isEmpty 
        ? 'Nuevo grupo' 
        : _nameController.text.trim();

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vista previa del grupo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableColors.map((colorData) {
        final hexColor = colorData['hex'] as String;
        final color = _parseColor(hexColor);
        final isSelected = _selectedColor == hexColor;

        return GestureDetector(
          onTap: () => setState(() => _selectedColor = hexColor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(LucideIcons.check, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconSelector() {
    final selectedColor = _parseColor(_selectedColor);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableIconNames.map((iconData) {
        final iconValue = iconData['value'] as String;
        final iconWidget = _getIconData(iconValue);
        final isSelected = _selectedIcon == iconValue;

        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = iconValue),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: selectedColor, width: 2)
                  : Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
            ),
            child: Icon(
              iconWidget,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }
}
