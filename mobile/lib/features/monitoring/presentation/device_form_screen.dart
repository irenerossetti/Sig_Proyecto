import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/injection_container.dart';
import 'bloc/children_bloc.dart';
import 'bloc/device_bloc.dart';

class DeviceFormScreen extends StatelessWidget {
  const DeviceFormScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final int childId;
  final String childName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DeviceBloc>(),
      child: _DeviceFormView(childId: childId, childName: childName),
    );
  }
}

class _DeviceFormView extends StatefulWidget {
  const _DeviceFormView({
    required this.childId,
    required this.childName,
  });

  final int childId;
  final String childName;

  @override
  State<_DeviceFormView> createState() => _DeviceFormViewState();
}

class _DeviceFormViewState extends State<_DeviceFormView> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  String _selectedType = 'gps_tracker';

  final _deviceTypes = const [
    {'value': 'gps_tracker', 'label': 'Rastreador GPS', 'icon': LucideIcons.radio},
    {'value': 'smartwatch', 'label': 'Reloj inteligente', 'icon': LucideIcons.watch},
    {'value': 'smartphone', 'label': 'Teléfono móvil', 'icon': LucideIcons.smartphone},
  ];

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<DeviceBloc>().add(
          DeviceCreateRequested(
            childId: widget.childId,
            deviceId: _deviceIdController.text.trim(),
            deviceType: _selectedType,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar dispositivo'),
      ),
      body: BlocConsumer<DeviceBloc, DeviceState>(
        listener: (context, state) {
          if (state is DeviceCreated) {
            // Refresh children list to show the new device
            context.read<ChildrenBloc>().add(ChildrenFetchRequested());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dispositivo registrado exitosamente.'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop(true); // Return true to indicate success
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Child info card
                  Card.filled(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primary,
                            child: Icon(LucideIcons.baby, color: scheme.onPrimary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Asignar dispositivo a:',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                                      ),
                                ),
                                Text(
                                  widget.childName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tipo de dispositivo',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_deviceTypes.length, (index) {
                          final type = _deviceTypes[index];
                          final isSelected = _selectedType == type['value'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => setState(() => _selectedType = type['value'] as String),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? scheme.primary : scheme.outline,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      type['icon'] as IconData,
                                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      type['label'] as String,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected ? scheme.primary : scheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isSelected)
                                      Icon(LucideIcons.circleCheck, color: scheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _deviceIdController,
                          decoration: const InputDecoration(
                            labelText: 'ID del dispositivo',
                            hintText: 'Ej: GPS-001, IMEI, etc.',
                            prefixIcon: Icon(LucideIcons.fingerprint),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa el ID del dispositivo.';
                            }
                            if (value.trim().length < 3) {
                              return 'El ID debe tener al menos 3 caracteres.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (state is DeviceError) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.circleAlert, color: scheme.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.message,
                                    style: TextStyle(color: scheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FilledButton.icon(
                          onPressed: state is DeviceLoading ? null : _submit,
                          icon: state is DeviceLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(LucideIcons.link),
                          label: Text(state is DeviceLoading ? 'Registrando...' : 'Vincular dispositivo'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info card
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.info, color: scheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '¿Cómo funciona?',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Registra el dispositivo con su ID único.\n'
                            '2. El dispositivo enviará su ubicación GPS.\n'
                            '3. Podrás ver la ubicación en tiempo real en el mapa.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
