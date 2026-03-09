import 'package:flutter/material.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/gateway.dart';
import '../../services/gateway_service.dart';
// import '../../services/device_password_service.dart'; // Removed: obsolete
import '../ble/ble_service.dart';
import 'add_gateway_bottom_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GatewayService _gatewayService = GatewayService();
  final BleService _bleService = BleService();
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, connected, disconnected, lowBattery
  final String _sortBy = 'name'; // name, battery, signal, lastSeen

  @override
  void initState() {
    super.initState();
    // Deferred to post-frame so that ValueListenableBuilder is fully mounted
    // before any notification fires. This prevents the "setState() called
    // during build" crash when initialize() mutates the gateways notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndAutoReconnect();
    });
  }

  /// Load persisted gateways, then drain any pending messages from a
  /// previous session (e.g. earthquake messages saved before app closed).
  Future<void> _initAndAutoReconnect() async {
    await _gatewayService.initialize();
    if (!mounted) return;
    await _bleService.loadAndDrainPendingQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addGateway(
    String gatewayId,
    String? name,
    BuildingType? buildingType,
    String? street,
    String? buildingNumber,
    String? doorNumber,
    String? neighborhood,
    String? district,
    String? city,
    String? postalCode,
    double? latitude,
    double? longitude,
  ) async {
    final finalName = name ??
        'Gateway ${gatewayId.substring(0, gatewayId.length > 4 ? 4 : gatewayId.length)}';

    final success = await _gatewayService.addGateway(
      gatewayId,
      name: finalName,
      buildingType: buildingType,
      street: street,
      buildingNumber: buildingNumber,
      doorNumber: doorNumber,
      neighborhood: neighborhood,
      district: district,
      city: city,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gateway eklendi — bağlanılıyor…'),
            backgroundColor: AppColors.success,
          ),
        );
        // Auto-connect right after adding — no extra tap needed
        _gatewayService.connectToGateway(gatewayId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bu Gateway zaten ekli veya geçersiz ID'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showAddGatewaySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGatewayBottomSheet(onAdd: _addGateway),
    );
  }

  List<Gateway> _getFilteredGateways() {
    final all = _gatewayService.gateways.value;
    List<Gateway> filtered;

    switch (_filterStatus) {
      case 'connected':
        filtered = all.where((g) => g.isConnected).toList();
        break;
      case 'disconnected':
        filtered = all.where((g) => !g.isConnected).toList();
        break;
      case 'lowBattery':
        filtered = all.where((g) => g.isLowBattery).toList();
        break;
      default:
        filtered = all;
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((g) {
        return g.name.toLowerCase().contains(query) ||
            g.id.toLowerCase().contains(query);
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'battery':
        filtered.sort((a, b) => b.batteryLevel.compareTo(a.batteryLevel));
        break;
      case 'signal':
        filtered.sort((a, b) {
          final aSignal = a.signalStrength ?? -100;
          final bSignal = b.signalStrength ?? -100;
          return bSignal.compareTo(aSignal);
        });
        break;
      case 'lastSeen':
        filtered.sort((a, b) {
          final aSeen = a.lastSeen ?? DateTime(1970);
          final bSeen = b.lastSeen ?? DateTime(1970);
          return bSeen.compareTo(aSeen);
        });
        break;
      case 'name':
      default:
        filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return filtered;
  }

  StatusType _getStatusType(GatewayStatus status) {
    switch (status) {
      case GatewayStatus.connected:
        return StatusType.success;
      case GatewayStatus.disconnected:
        return StatusType.neutral;
      case GatewayStatus.connecting:
      case GatewayStatus.scanning:
        return StatusType.info;
      case GatewayStatus.error:
        return StatusType.danger;
    }
  }

  IconData _getStatusIcon(GatewayStatus status) {
    switch (status) {
      case GatewayStatus.connected:
        return Icons.check_circle;
      case GatewayStatus.disconnected:
        return Icons.cancel;
      case GatewayStatus.scanning:
        return Icons.search;
      case GatewayStatus.connecting:
        return Icons.sync;
      case GatewayStatus.error:
        return Icons.error;
    }
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} sa önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _gatewayService.getStatistics();
    final avgBattery = _gatewayService.getAverageBattery();
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Hayat Ağı',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.pushNamed(context, AppRouter.settings);
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGatewaySheet,
        icon: const Icon(Icons.add),
        label: const Text('Gateway Ekle'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ValueListenableBuilder<List<Gateway>>(
        valueListenable: _gatewayService.gateways,
        builder: (context, gateways, _) {
          final filteredGateways = _getFilteredGateways();

          return RefreshIndicator(
            onRefresh: () async {
              // TODO: Refresh gateway data
              await Future.delayed(const Duration(seconds: 1));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Network Summary Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Ağ Özeti',
                          subtitle: 'Gateway durumları ve istatistikler',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Toplam',
                                value: stats['total'].toString(),
                                icon: Icons.devices,
                                iconColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: StatCard(
                                label: 'Aktif',
                                value: stats['connected'].toString(),
                                icon: Icons.check_circle,
                                iconColor: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        StatCard(
                          label: 'Ortalama Batarya',
                          value: '${avgBattery.toInt()}%',
                          icon: Icons.battery_charging_full,
                          iconColor: avgBattery > 50
                              ? AppColors.success
                              : avgBattery > 20
                                  ? AppColors.warning
                                  : AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                ),

                // Search and Filter Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    child: Column(
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Gateway ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Filter and Sort Chips
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('Tümü', 'all'),
                                    const SizedBox(width: AppSpacing.xs),
                                    _buildFilterChip('Bağlı', 'connected'),
                                    const SizedBox(width: AppSpacing.xs),
                                    _buildFilterChip('Kesik', 'disconnected'),
                                    const SizedBox(width: AppSpacing.xs),
                                    _buildFilterChip('Düşük Batarya', 'lowBattery'),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sort),
                              tooltip: 'Sırala',
                              onPressed: () {
                                // TODO: Show sort bottom sheet
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sıralama yakında eklenecek'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Gateway List Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.lg,
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gateway\'ler (${filteredGateways.length})',
                          style: AppTypography.headlineSmall(context),
                        ),
                        if (gateways.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRouter.disasterHome);
                            },
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text('Afet Modu'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Gateway List
                if (filteredGateways.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.devices_other,
                      title: 'Henüz gateway eklenmedi',
                      description: 'Yeni gateway eklemek için sağ alttaki butona tıklayın',
                      actionLabel: 'Gateway Ekle',
                      onAction: _showAddGatewaySheet,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final gateway = filteredGateways[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _buildGatewayCard(gateway, theme),
                          );
                        },
                        childCount: filteredGateways.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
    );
  }

  Widget _buildGatewayCard(Gateway gateway, ThemeData theme) {
    return ModernCard(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRouter.gatewayDetails,
          arguments: gateway.id,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              // Gateway Icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(gateway.status),
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name and ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gateway.name,
                      style: AppTypography.titleLarge(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'ID: ${gateway.id}',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Pill
              StatusPill(
                label: gateway.status.displayName,
                type: _getStatusType(gateway.status),
                icon: _getStatusIcon(gateway.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Metrics Row
          Row(
            children: [
              // Battery
              _buildMetricChip(
                context: context,
                icon: Icons.battery_charging_full,
                label: '${gateway.batteryLevel}%',
                color: gateway.batteryLevel > 50
                    ? AppColors.success
                    : gateway.batteryLevel > 20
                        ? AppColors.warning
                        : AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              // Signal
              if (gateway.signalStrength != null)
                _buildMetricChip(
                  context: context,
                  icon: Icons.signal_cellular_alt,
                  label: '${gateway.signalStrength} dBm',
                  color: gateway.hasGoodSignal
                      ? AppColors.success
                      : AppColors.warning,
                ),
              if (gateway.connectedDeviceCount != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _buildMetricChip(
                  context: context,
                  icon: Icons.phone_android,
                  label: '${gateway.connectedDeviceCount} cihaz',
                  color: AppColors.primary,
                ),
              ],
              const Spacer(),
              // Last Seen
              if (gateway.lastSeen != null)
                Text(
                  _formatLastSeen(gateway.lastSeen!),
                  style: AppTypography.bodySmall(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelSmall(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
