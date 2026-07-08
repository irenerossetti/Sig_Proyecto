import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../alerts/presentation/alerts_screen.dart' show AlertsListView;
import '../../auth/presentation/bloc/auth_bloc.dart';

import '../../profile/presentation/profile_screen.dart';
import '../../monitoring/domain/monitoring_models.dart';

import '../../monitoring/presentation/bloc/alerts_bloc.dart';
import '../../monitoring/presentation/bloc/children_bloc.dart';
import '../../monitoring/presentation/bloc/map_bloc.dart';
import '../../monitoring/presentation/all_children_map_view.dart';
import '../../groups/presentation/bloc/groups_bloc.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/data/group_repository.dart';
import '../../../core/config/theme_cubit.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../core/utils/ui_utils.dart' as ui_utils;
import '../../../core/services/websocket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialTab,
    this.initialChildId,
  });
  
  /// Tab inicial (0=Inicio, 1=Niños, 2=Alertas, 3=Mapa, 4=Perfil)
  final int? initialTab;
  
  /// ID del niño a seleccionar en el mapa (solo si initialTab == 3)
  final int? initialChildId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  
  // Control de tabs visitados para lazy loading
  final Set<int> _visitedTabs = {0}; // Dashboard siempre cargado
  StreamSubscription? _websocketAlertSubscription;

  void _onTabSelected(int index) {
    _previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index); // Marcar como visitado para lazy loading
    });
    
    // Notificar al MapBloc sobre visibilidad
    if (_previousIndex == 3 && index != 3) {
      // Saliendo del mapa
      context.read<MapBloc>().add(MapStopListening());
    } else if (index == 3 && _previousIndex != 3) {
      // Entrando al mapa - refrescar datos para mostrar niños actualizados
      context.read<ChildrenBloc>().add(const ChildrenFetchRequested());
      context.read<GroupsBloc>().add(const GroupsFetchRequested());
      context.read<MapBloc>().add(MapStartListening());
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial fetch
    context.read<ChildrenBloc>().add(const ChildrenFetchRequested());
    context.read<AlertsBloc>().add(AlertsFetchRequested());
    context.read<GroupsBloc>().add(const GroupsFetchRequested());
    
    _applyInitialParams();

    // Escuchar alertas del WebSocket para mostrar un SnackBar rojo emergente en tiempo real
    _websocketAlertSubscription = WebSocketService().alerts.listen((alert) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.bellRing, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¡ALERTA! ${alert.childName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        alert.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'VER',
              textColor: Colors.white,
              onPressed: () {
                _onTabSelected(3); // Cambiar a la pestaña del mapa (3)
                context.read<MapBloc>().add(MapChildSelected(alert.childId));
              },
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _websocketAlertSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si los parámetros cambiaron, aplicarlos
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialChildId != widget.initialChildId) {
      _applyInitialParams();
    }
  }

  void _applyInitialParams() {
    // Si hay un tab inicial, seleccionarlo
    if (widget.initialTab != null) {
      _previousIndex = _currentIndex;
      setState(() {
        _currentIndex = widget.initialTab!;
        _visitedTabs.add(widget.initialTab!);
      });
      
      // Notificar visibilidad del mapa si es necesario
      if (widget.initialTab == 3) {
        context.read<MapBloc>().add(MapStartListening());
      }
    }
    
    // Si hay un niño inicial para el mapa, seleccionarlo
    if (widget.initialChildId != null && widget.initialTab == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MapBloc>().add(MapChildSelected(widget.initialChildId!));
        }
      });
    }
  }

  /// Construye un tab con lazy loading - solo carga si fue visitado
  Widget _buildLazyTab(int index, Widget Function() builder) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return Offstage(
      offstage: _currentIndex != index,
      child: TickerMode(
        enabled: _currentIndex == index,
        child: builder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floatingActionButton = _currentIndex == 1
        ? FloatingActionButton.extended(
            onPressed: () => context.pushNamed('child-create'),
            icon: const Icon(LucideIcons.userPlus),
            label: const Text('Registrar niño'),
          )
        : null;

    return Scaffold(
      // Lazy loading: solo carga tabs visitados, mejor rendimiento inicial
      body: Stack(
        children: [
          _buildLazyTab(0, () => _DashboardTab(
            onShowChildren: () => _onTabSelected(1),
            onShowAlerts: () => _onTabSelected(2),
            onRegisterChild: () => context.pushNamed('child-create'),
            onShowGroups: () => context.pushNamed('groups'),
          )),
          _buildLazyTab(1, () => const _ChildrenTab()),
          _buildLazyTab(2, () => const _AlertsTab()),
          _buildLazyTab(3, () => const _MapTab()),
          _buildLazyTab(4, () => const _ProfileTab()),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutDashboard),
            selectedIcon: Icon(LucideIcons.layoutDashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.baby),
            selectedIcon: Icon(LucideIcons.baby),
            label: 'Niños',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bell),
            selectedIcon: Icon(LucideIcons.bell),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.mapPin),
            selectedIcon: Icon(LucideIcons.mapPin),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            selectedIcon: Icon(LucideIcons.user),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.onShowChildren,
    required this.onShowAlerts,
    required this.onRegisterChild,
    required this.onShowGroups,
  });

  final VoidCallback onShowChildren;
  final VoidCallback onShowAlerts;
  final VoidCallback onRegisterChild;
  final VoidCallback onShowGroups;

  Future<void> _refresh(BuildContext context) async {
    context.read<ChildrenBloc>().add(ChildrenFetchRequested());
    context.read<AlertsBloc>().add(AlertsFetchRequested());
    context.read<GroupsBloc>().add(const GroupsFetchRequested());
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: BlocBuilder<ChildrenBloc, ChildrenState>(
        // Solo reconstruir cuando cambie el tipo de estado o la lista de niños
        buildWhen: (previous, current) {
          if (previous.runtimeType != current.runtimeType) return true;
          if (previous is ChildrenLoaded && current is ChildrenLoaded) {
            return previous.children != current.children;
          }
          return false;
        },
        builder: (context, childrenState) {
          return BlocBuilder<AlertsBloc, AlertsState>(
            // Solo reconstruir cuando cambie el tipo de estado o la lista de alertas
            buildWhen: (previous, current) {
              if (previous.runtimeType != current.runtimeType) return true;
              if (previous is AlertsLoaded && current is AlertsLoaded) {
                return previous.alerts != current.alerts;
              }
              return false;
            },
            builder: (context, alertsState) {
              final children = childrenState is ChildrenLoaded ? childrenState.children : <ChildModel>[];
              final alerts = alertsState is AlertsLoaded ? alertsState.alerts : <AlertModel>[];
              
              final pendingAlerts = alerts.where((alert) => alert.status != 'resolved').length;
              final onlineDevices = children.where((child) => child.device?.isOnline ?? false).length;
              
              final stats = DashboardStats(
                totalChildren: children.length,
                activeDevices: onlineDevices,
                pendingAlerts: pendingAlerts,
              );

              return CustomScrollView(
                slivers: [
                  const SliverAppBar(
                    floating: true,
                    title: Text('Panel GeoGuard'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _DashboardStatsCard(childrenState: childrenState, alertsState: alertsState, stats: stats),
                        const SizedBox(height: 16),
                        _QuickActions(
                          onRegisterChild: onRegisterChild,
                          onViewAlerts: onShowAlerts,
                          onViewGroups: onShowGroups,
                        ),
                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: 'Niños monitoreados',
                          subtitle: 'Resumen general',
                          actionLabel: 'Ver todos',
                          onAction: onShowChildren,
                        ),
                        const SizedBox(height: 8),
                        _ChildrenPreview(state: childrenState),
                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: 'Alertas recientes',
                          subtitle: 'Últimas notificaciones',
                          actionLabel: 'Ver historial',
                          onAction: onShowAlerts,
                        ),
                        const SizedBox(height: 8),
                        _AlertsPreview(state: alertsState),
                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: 'Grupos',
                          subtitle: 'Monitoreo colaborativo',
                          actionLabel: 'Ver todos',
                          onAction: onShowGroups,
                        ),
                        const SizedBox(height: 8),
                        const _GroupsPreview(),
                        const SizedBox(height: 80), // Bottom padding for FAB
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ChildrenTab extends StatefulWidget {
  const _ChildrenTab();

  @override
  State<_ChildrenTab> createState() => _ChildrenTabState();
}

enum ChildrenFilterType { all, group, noGroup }

class _ChildrenTabState extends State<_ChildrenTab> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  
  // Filtros
  ChildrenFilterType _filterType = ChildrenFilterType.all;
  int? _selectedGroupId;
  
  // Grupos con detalles cargados (incluyen membresías)
  Map<int, ChildGroupModel> _groupsWithDetails = {};
  bool _loadingGroupDetails = false;

  @override
  bool get wantKeepAlive => true; // Preservar estado al cambiar de tab

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Carga los detalles de todos los grupos (con membresías)
  Future<void> _loadGroupsWithDetails(List<ChildGroupModel> groups) async {
    if (_loadingGroupDetails) return;
    
    final token = context.read<AuthBloc>().state.token;
    if (token == null) return;
    
    setState(() => _loadingGroupDetails = true);
    
    try {
      final repo = sl<GroupRepository>();
      final detailedGroups = <int, ChildGroupModel>{};
      
      for (final group in groups) {
        try {
          final detail = await repo.fetchGroupDetail(token: token, groupId: group.id);
          detailedGroups[group.id] = detail;
        } catch (e) {
          debugPrint('Error loading group ${group.id} details: $e');
          detailedGroups[group.id] = group; // Usar el básico si falla
        }
      }
      
      if (mounted) {
        setState(() {
          _groupsWithDetails = detailedGroups;
          _loadingGroupDetails = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group details: $e');
      if (mounted) {
        setState(() => _loadingGroupDetails = false);
      }
    }
  }

  void _showFilterSelector(BuildContext context, List<ChildGroupModel> groups) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filtrar niños',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Todos los niños
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _filterType == ChildrenFilterType.all 
                              ? colorScheme.primaryContainer 
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.users,
                          size: 20,
                          color: _filterType == ChildrenFilterType.all 
                              ? colorScheme.primary 
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        'Todos los niños',
                        style: TextStyle(
                          fontWeight: _filterType == ChildrenFilterType.all ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: _filterType == ChildrenFilterType.all
                          ? Icon(LucideIcons.check, color: colorScheme.primary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _filterType = ChildrenFilterType.all;
                          _selectedGroupId = null;
                        });
                      },
                    ),
                    
                    // Sin grupo
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _filterType == ChildrenFilterType.noGroup 
                              ? colorScheme.primaryContainer 
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.userMinus,
                          size: 20,
                          color: _filterType == ChildrenFilterType.noGroup 
                              ? colorScheme.primary 
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        'Sin grupo asignado',
                        style: TextStyle(
                          fontWeight: _filterType == ChildrenFilterType.noGroup ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: const Text('Niños que no pertenecen a ningún grupo'),
                      trailing: _filterType == ChildrenFilterType.noGroup
                          ? Icon(LucideIcons.check, color: colorScheme.primary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _filterType = ChildrenFilterType.noGroup;
                          _selectedGroupId = null;
                        });
                      },
                    ),
                    
                    const Divider(height: 1),
                    
                    // Grupos
                    if (groups.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Por grupo',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...groups.map((group) => ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _filterType == ChildrenFilterType.group && _selectedGroupId == group.id
                                ? colorScheme.primaryContainer 
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            LucideIcons.usersRound,
                            size: 20,
                            color: _filterType == ChildrenFilterType.group && _selectedGroupId == group.id
                                ? colorScheme.primary 
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          group.name,
                          style: TextStyle(
                            fontWeight: _filterType == ChildrenFilterType.group && _selectedGroupId == group.id 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${group.membersCount} niño${group.membersCount == 1 ? '' : 's'}'),
                        trailing: _filterType == ChildrenFilterType.group && _selectedGroupId == group.id
                            ? Icon(LucideIcons.check, color: colorScheme.primary, size: 20)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _filterType = ChildrenFilterType.group;
                            _selectedGroupId = group.id;
                          });
                        },
                      )),
                    ] else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No tienes grupos creados',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _filterLabel {
    switch (_filterType) {
      case ChildrenFilterType.all:
        return 'Todos';
      case ChildrenFilterType.noGroup:
        return 'Sin grupo';
      case ChildrenFilterType.group:
        return 'Grupo';
    }
  }

  IconData get _filterIcon {
    switch (_filterType) {
      case ChildrenFilterType.all:
        return LucideIcons.users;
      case ChildrenFilterType.noGroup:
        return LucideIcons.userMinus;
      case ChildrenFilterType.group:
        return LucideIcons.usersRound;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    final colorScheme = Theme.of(context).colorScheme;
    
    return BlocBuilder<GroupsBloc, GroupsState>(
      builder: (context, groupsState) {
        final groups = groupsState is GroupsLoaded ? groupsState.groups : <ChildGroupModel>[];
        
        // Cargar detalles de grupos si aún no están cargados
        if (groups.isNotEmpty && _groupsWithDetails.isEmpty && !_loadingGroupDetails) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadGroupsWithDetails(groups);
          });
        }
        
        // Usar grupos con detalles si están disponibles, sino los básicos
        final groupsToUse = _groupsWithDetails.isNotEmpty 
            ? _groupsWithDetails.values.toList() 
            : groups;
        
        // Crear mapa de childId -> grupos usando los grupos con detalles
        final childGroups = <int, List<ChildGroupModel>>{};
        for (final group in groupsToUse) {
          if (group.memberships != null) {
            for (final membership in group.memberships!) {
              childGroups.putIfAbsent(membership.childId, () => []).add(group);
            }
          }
        }
        
        return BlocBuilder<ChildrenBloc, ChildrenState>(
          buildWhen: (previous, current) {
            if (previous.runtimeType != current.runtimeType) return true;
            if (previous is ChildrenLoaded && current is ChildrenLoaded) {
              return previous.children != current.children;
            }
            return false;
          },
          builder: (context, state) {
            final allChildren = state is ChildrenLoaded ? state.children : <ChildModel>[];
            
            // Aplicar filtro de grupo usando grupos con detalles
            List<ChildModel> filteredByGroup;
            switch (_filterType) {
              case ChildrenFilterType.all:
                filteredByGroup = allChildren;
                break;
              case ChildrenFilterType.noGroup:
                filteredByGroup = allChildren.where((c) => !childGroups.containsKey(c.id)).toList();
                break;
              case ChildrenFilterType.group:
                if (_selectedGroupId == null) {
                  filteredByGroup = allChildren;
                } else {
                  // Usar el grupo con detalles si está disponible
                  final group = _groupsWithDetails[_selectedGroupId] ?? groupsToUse.firstWhere(
                    (g) => g.id == _selectedGroupId,
                    orElse: () => const ChildGroupModel(
                      id: 0, name: '', ownerId: 0, color: '#000', icon: '', isActive: false, membersCount: 0, tutorsCount: 0,
                    ),
                  );
                  final childIds = group.memberships?.map((m) => m.childId).toSet() ?? <int>{};
                  filteredByGroup = allChildren.where((c) => childIds.contains(c.id)).toList();
                }
                break;
            }
            
            final childCount = filteredByGroup.length;
            final isFiltering = _filterType != ChildrenFilterType.all;
            
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  childCount > 0 
                      ? 'Niños registrados ($childCount)'
                      : 'Niños registrados',
                ),
                actions: [
                  // Botón de filtro
                  TextButton.icon(
                    onPressed: () => _showFilterSelector(context, groups),
                    icon: Icon(
                      _filterIcon, 
                      size: 18,
                      color: isFiltering ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _filterLabel,
                      style: TextStyle(
                        color: isFiltering ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        fontWeight: isFiltering ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: isFiltering ? colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  // Search bar
                  if (allChildren.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre...',
                          prefixIcon: const Icon(LucideIcons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                  // Children list con info de grupo
                  Expanded(
                    child: _FilteredChildrenListView(
                      padding: const EdgeInsets.all(16),
                      searchQuery: _searchQuery,
                      children: filteredByGroup,
                      childGroups: childGroups,
                      filterType: _filterType,
                      selectedGroupId: _selectedGroupId,
                      groups: groups,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// ListView de niños con soporte para filtros y mostrar grupos
class _FilteredChildrenListView extends StatelessWidget {
  const _FilteredChildrenListView({
    required this.padding,
    required this.searchQuery,
    required this.children,
    required this.childGroups,
    required this.filterType,
    required this.groups,
    this.selectedGroupId,
  });

  final EdgeInsetsGeometry padding;
  final String searchQuery;
  final List<ChildModel> children;
  final Map<int, List<ChildGroupModel>> childGroups;
  final ChildrenFilterType filterType;
  final int? selectedGroupId;
  final List<ChildGroupModel> groups;

  @override
  Widget build(BuildContext context) {
    // Filtrar por búsqueda
    final filteredChildren = searchQuery.isEmpty
        ? children
        : children.where((child) =>
            child.fullName.toLowerCase().contains(searchQuery.toLowerCase())
          ).toList();

    if (children.isEmpty) {
      return _buildEmptyFilterState(context);
    }

    if (filteredChildren.isEmpty) {
      return _buildNoResultsState(context, searchQuery);
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ChildrenBloc>().add(ChildrenFetchRequested());
        context.read<GroupsBloc>().add(const GroupsFetchRequested());
      },
      child: ListView.separated(
        padding: padding,
        itemBuilder: (context, index) => _ChildCardWithGroup(
          child: filteredChildren[index],
          groups: childGroups[filteredChildren[index].id] ?? [],
        ),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: filteredChildren.length,
      ),
    );
  }

  Widget _buildEmptyFilterState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    String message;
    IconData icon;
    
    switch (filterType) {
      case ChildrenFilterType.all:
        message = 'No hay niños registrados';
        icon = LucideIcons.baby;
        break;
      case ChildrenFilterType.noGroup:
        message = 'Todos los niños tienen grupo asignado';
        icon = LucideIcons.userCheck;
        break;
      case ChildrenFilterType.group:
        final groupName = groups.firstWhere(
          (g) => g.id == selectedGroupId,
          orElse: () => const ChildGroupModel(
            id: 0, name: 'este grupo', ownerId: 0, color: '#000', icon: '', isActive: false, membersCount: 0, tutorsCount: 0,
          ),
        ).name;
        message = 'No hay niños en $groupName';
        icon = LucideIcons.usersRound;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: colorScheme.outline),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, String query) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.searchX, size: 48, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Sin resultados',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron niños con "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de niño que muestra a qué grupo(s) pertenece
class _ChildCardWithGroup extends StatelessWidget {
  const _ChildCardWithGroup({
    required this.child,
    required this.groups,
  });

  final ChildModel child;
  final List<ChildGroupModel> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initial = child.fullName.isNotEmpty
        ? child.fullName.substring(0, 1).toUpperCase()
        : '?';
    final age = date_utils.calculateAge(child.dateOfBirth);
    final hasDevice = child.device != null;
    final isOnline = child.device?.isOnline ?? false;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () async {
          await context.pushNamed(
            'child-detail',
            pathParameters: {'id': child.id.toString()},
            extra: child,
          );
          // Refrescar cuando regresamos del detalle
          if (context.mounted) {
            context.read<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con avatar y info principal
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                            ? NetworkImage(child.photoUrl!)
                            : null,
                        child: child.photoUrl == null || child.photoUrl!.isEmpty
                            ? Text(
                                initial,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (hasDevice)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.cake, size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '$age años',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (hasDevice) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOnline ? 'En línea' : 'Sin conexión',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isOnline ? Colors.green : Colors.grey,
                                ),
                              ),
                            ] else ...[
                              Icon(LucideIcons.unlink, size: 12, color: colorScheme.error),
                              const SizedBox(width: 4),
                              Text(
                                'Sin dispositivo',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    color: colorScheme.outline,
                    size: 20,
                  ),
                ],
              ),
            ),
            
            // Chips de grupos
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: groups.map((group) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _parseGroupColor(group.color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _parseGroupColor(group.color).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.usersRound,
                          size: 12,
                          color: _parseGroupColor(group.color),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          group.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _parseGroupColor(group.color),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.userMinus,
                        size: 12,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sin grupo',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
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
  }

  Color _parseGroupColor(String hex) {
    try {
      final hexCode = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      body: const AlertsListView(padding: EdgeInsets.all(16)),
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab();

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  @override
  void initState() {
    super.initState();
    // Ya no iniciamos polling automáticamente aquí
    // El polling se maneja desde HomeScreen según visibilidad
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ChildrenBloc, ChildrenState>(
        buildWhen: (previous, current) {
          if (previous.runtimeType != current.runtimeType) return true;
          if (previous is ChildrenLoaded && current is ChildrenLoaded) {
            return previous.children != current.children;
          }
          return false;
        },
        builder: (context, childrenState) {
          if (childrenState is ChildrenLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (childrenState is ChildrenError) {
            return Center(child: Text(childrenState.message));
          }

          if (childrenState is ChildrenLoaded) {
            final trackable = childrenState.children.where(_hasCoordinates).toList();
            if (trackable.isEmpty) {
              return const Center(child: Text('No hay ubicaciones disponibles.'));
            }

            // Usar el nuevo mapa con todos los niños
            return AllChildrenMapView(
              children: childrenState.children,
              onChildTapped: (child) {
                // Navegar al detalle del niño si se desea
                context.pushNamed(
                  'child-detail',
                  pathParameters: {'id': child.id.toString()},
                  extra: child,
                );
              },
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }
}


class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              final isDark = themeMode == ThemeMode.dark;
              return IconButton(
                icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
                onPressed: () => context.read<ThemeCubit>().toggleTheme(),
              );
            },
          ),
        ],
      ),
      body: const ProfileScreen(padding: EdgeInsets.all(16)),
    );
  }
}

class _DashboardStatsCard extends StatelessWidget {
  const _DashboardStatsCard({
    required this.childrenState,
    required this.alertsState,
    required this.stats,
  });

  final ChildrenState childrenState;
  final AlertsState alertsState;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    if (childrenState is ChildrenLoading || alertsState is AlertsLoading) {
      return const _LoadingCard(height: 90);
    }
    if (childrenState is ChildrenError) {
      return _ErrorCard(message: (childrenState as ChildrenError).message);
    }
    if (alertsState is AlertsError) {
      return _ErrorCard(message: (alertsState as AlertsError).message);
    }

    return Card.filled(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatTile(label: 'Niños', value: stats.totalChildren.toString()),
            _StatTile(label: 'Dispositivos', value: stats.activeDevices.toString()),
            _StatTile(
              label: 'Alertas',
              value: stats.pendingAlerts.toString(),
              highlight: stats.pendingAlerts > 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: textTheme.headlineMedium?.copyWith(
            color: highlight ? Theme.of(context).colorScheme.error : textTheme.headlineMedium?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onRegisterChild,
    required this.onViewAlerts,
    required this.onViewGroups,
  });

  final VoidCallback onRegisterChild;
  final VoidCallback onViewAlerts;
  final VoidCallback onViewGroups;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onRegisterChild,
                icon: const Icon(LucideIcons.userPlus),
                label: const Text('Registrar niño'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onViewAlerts,
                icon: const Icon(LucideIcons.bell),
                label: const Text('Ver alertas'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onViewGroups,
            icon: const Icon(LucideIcons.users),
            label: const Text('Administrar grupos'),
          ),
        ),
      ],
    );
  }
}

class _ChildrenPreview extends StatelessWidget {
  const _ChildrenPreview({required this.state});

  final ChildrenState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s is ChildrenLoaded) {
      final items = s.children;
      if (items.isEmpty) {
        return const _EmptyState(message: 'Aún no registraste niños.');
      }
      final preview = items.take(3).toList();
      return Column(
        children: preview
            .map(
              (child) => Card.outlined(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(child.fullName.isNotEmpty ? child.fullName.substring(0, 1) : '?'),
                  ),
                  title: Text(child.fullName),
                  subtitle: Text('Nacimiento: ${date_utils.formatDateSimple(child.dateOfBirth)}'),
                  trailing: Chip(
                    label: Text(child.isActive ? 'Activo' : 'Inactivo'),
                  ),
                ),
              ),
            )
            .toList(),
      );
    } else if (s is ChildrenLoading) {
      return const _LoadingCard(height: 120);
    } else if (s is ChildrenError) {
      return _ErrorCard(message: s.message);
    }
    return const SizedBox.shrink();
  }
}

class _AlertsPreview extends StatelessWidget {
  const _AlertsPreview({required this.state});

  final AlertsState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s is AlertsLoaded) {
      final items = s.alerts;
      if (items.isEmpty) {
        return const _EmptyState(message: 'No hay alertas recientes.');
      }
      final preview = items.take(3).toList();
      return Column(
        children: preview
            .map(
              (alert) => Card.outlined(
                child: ListTile(
                  leading: Icon(
                    LucideIcons.bell,
                    color: ui_utils.alertStatusColor(alert.status),
                  ),
                  title: Text(alert.childName),
                  subtitle: Text(alert.message),
                  trailing: Text(date_utils.relativeTime(alert.createdAt)),
                ),
              ),
            )
            .toList(),
      );
    } else if (s is AlertsLoading) {
      return const _LoadingCard(height: 120);
    } else if (s is AlertsError) {
      return _ErrorCard(message: s.message);
    }
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color)),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.circleAlert, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _GroupsPreview extends StatelessWidget {
  const _GroupsPreview();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupsBloc, GroupsState>(
      builder: (context, state) {
        if (state is GroupsLoaded) {
          final items = state.groups;
          if (items.isEmpty) {
            return const _EmptyState(message: 'No tienes grupos. Crea uno para monitorear varios niños.');
          }
          final preview = items.take(2).toList();
          return Column(
            children: preview.map((group) {
              return Card.outlined(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(group.color),
                    child: Icon(
                      _parseIcon(group.icon),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    '${group.membersCount} miembro${group.membersCount == 1 ? '' : 's'} • ${group.tutorsCount} tutor${group.tutorsCount == 1 ? '' : 'es'}',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () async {
                    await context.pushNamed(
                      'group-detail',
                      pathParameters: {'id': group.id.toString()},
                    );
                    if (context.mounted) {
                      context.read<GroupsBloc>().add(const GroupsFetchRequested(forceRefresh: true));
                      context.read<ChildrenBloc>().add(const ChildrenFetchRequested(forceRefresh: true));
                    }
                  },
                ),
              );
            }).toList(),
          );
        } else if (state is GroupsLoading) {
          return const _LoadingCard(height: 100);
        } else if (state is GroupsError) {
          return _ErrorCard(message: state.message);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.blue;
    }
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
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
      default:
        return LucideIcons.users;
    }
  }
}




bool _hasCoordinates(ChildModel child) {
  final lat = child.device?.lastLatitude;
  final lng = child.device?.lastLongitude;
  return lat != null && lng != null;
}




