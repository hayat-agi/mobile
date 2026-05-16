import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/status_pill.dart';
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
    _gatewayService.locationCheckNeeded.addListener(_onLocationCheckNeeded);
    // Deferred to post-frame so that ValueListenableBuilder is fully mounted
    // before any notification fires. This prevents the "setState() called
    // during build" crash when initialize() mutates the gateways notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndAutoReconnect();
      // Handle the case where locationCheckNeeded was set before we listened
      if (_gatewayService.locationCheckNeeded.value != null) {
        _onLocationCheckNeeded();
      }
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
    _gatewayService.locationCheckNeeded.removeListener(_onLocationCheckNeeded);
    _searchController.dispose();
    super.dispose();
  }

  // ─── Periodic location check ──────────────────────────────────────

  void _onLocationCheckNeeded() {
    final gatewayId = _gatewayService.locationCheckNeeded.value;
    if (gatewayId == null || !mounted) return;
    // Small delay so the connection UI settles first
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _performLocationCheck(gatewayId);
    });
  }

  /// Fetches current GPS position and compares it to the gateway's stored
  /// coordinates. If the device has moved more than 150 m, prompts the user
  /// to review the address. Always records the check date when done.
  Future<void> _performLocationCheck(String gatewayId) async {
    final gateway = _gatewayService.getGateway(gatewayId);
    if (gateway == null ||
        gateway.latitude == null ||
        gateway.longitude == null) {
      _gatewayService.markLocationChecked(gatewayId);
      return;
    }

    // Need location permission — skip silently if denied
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _gatewayService.markLocationChecked(gatewayId);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _gatewayService.markLocationChecked(gatewayId);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final distanceMeters = Geolocator.distanceBetween(
        gateway.latitude!,
        gateway.longitude!,
        position.latitude,
        position.longitude,
      );

      debugPrint(
        '[LocationCheck] gateway="${gateway.name}" '
        'stored=(${gateway.latitude}, ${gateway.longitude}) '
        'current=(${position.latitude}, ${position.longitude}) '
        'distance=${distanceMeters.toStringAsFixed(1)}m',
      );

      // Mark checked regardless of outcome so we don't nag on every connect
      _gatewayService.markLocationChecked(gatewayId);

      // Only alert if the device appears to have moved significantly
      if (distanceMeters > 150 && mounted) {
        _showLocationChangedDialog(gateway, distanceMeters.round());
      }
    } catch (e) {
      debugPrint('[LocationCheck] GPS failed: $e');
      // GPS failed — record the check so we don't retry until next interval
      _gatewayService.markLocationChecked(gatewayId);
    }
  }

  void _showLocationChangedDialog(Gateway gateway, int distanceMeters) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Konum Değişikliği'),
          ],
        ),
        content: Text(
          '"${gateway.name}" cihazının konumu yaklaşık $distanceMeters metre '
          'değişmiş görünüyor.\n\n'
          'Deprem senaryosunda kurtarma ekiplerinin doğru adrese ulaşabilmesi '
          'için adres bilgilerini güncellemenizi öneririz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Daha Sonra'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_location_alt, size: 18),
            label: const Text('Detaylara Git'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(
                context,
                AppRouter.gatewayDetails,
                arguments: gateway.id,
              );
            },
          ),
        ],
      ),
    );
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
    String? bleAdvName,
  ) async {
    final finalName =
        name ??
        'Cihaz ${gatewayId.substring(0, gatewayId.length > 4 ? 4 : gatewayId.length)}';

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
      bleAdvName: bleAdvName,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cihaz eklendi — bağlanılıyor…'),
            backgroundColor: AppColors.success,
          ),
        );
        // Auto-connect right after adding — no extra tap needed
        _gatewayService.connectToGateway(gatewayId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bu Cihaz zaten ekli veya geçersiz ID'),
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
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Hayat Ağı',
      bottomNavigationBar: const AppBottomNavBar(currentItem: AppNavItem.home),
      floatingActionButton: ValueListenableBuilder<List<Gateway>>(
        valueListenable: _gatewayService.gateways,
        builder: (context, gateways, _) {
          if (gateways.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _showAddGatewaySheet,
            icon: const Icon(Icons.add),
            label: const Text('Cihaz Ekle'),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ValueListenableBuilder<List<Gateway>>(
        valueListenable: _gatewayService.gateways,
        builder: (context, gateways, _) {
          final stats = _gatewayService.getStatistics();
          final filteredGateways = _getFilteredGateways();

          return RefreshIndicator(
            onRefresh: () async {
              // TODO: Refresh gateway data
              await Future.delayed(const Duration(seconds: 1));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.screenPadding,
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                    ),
                    child: Column(
                      children: [
                        _buildNetworkSummaryCard(context, stats),
                        const SizedBox(height: AppSpacing.md),
                        _buildSearchAndFiltersCard(context),
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
                          'Cihazlar (${filteredGateways.length})',
                          style: AppTypography.headlineSmall(context),
                        ),
                        if (gateways.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.disasterHome,
                              );
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
                      title: 'Henüz cihaz eklenmedi',
                      description:
                          'Yeni cihaz eklemek için sağ alttaki butona tıklayın',
                      actionLabel: 'Cihaz Ekle',
                      onAction: _showAddGatewaySheet,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final gateway = filteredGateways[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _buildGatewayCard(gateway, theme),
                        );
                      }, childCount: filteredGateways.length),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isDark
              ? AppColors.surfaceVariantDark
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: isSelected
              ? null
              : Border.all(color: AppColors.sterlingGray),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : isDark
                ? AppColors.textPrimaryDark
                : AppColors.midnightInk,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkSummaryCard(
    BuildContext context,
    Map<String, int> stats,
  ) {
    final theme = Theme.of(context);

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ağ Özeti', style: AppTypography.titleLarge(context)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Cihaz durumları ve istatistikler',
                      style: AppTypography.bodySmall(
                        context,
                      ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  context: context,
                  label: 'Toplam',
                  value: stats['total'].toString(),
                  icon: Icons.devices_outlined,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(
                height: 44,
                child: VerticalDivider(
                  width: AppSpacing.lg,
                  color: theme.colorScheme.outline.withValues(alpha: 0.35),
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  context: context,
                  label: 'Aktif',
                  value: stats['connected'].toString(),
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.headlineSmall(
                  context,
                ).copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFiltersCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Standalone pill search bar
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceVariantDark
                : AppColors.surfaceVariantLight,
            borderRadius: BorderRadius.circular(50),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cihaz ara...',
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Pill filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tümü', 'all'),
              const SizedBox(width: AppSpacing.sm),
              _buildFilterChip('Bağlı', 'connected'),
              const SizedBox(width: AppSpacing.sm),
              _buildFilterChip('Kesik', 'disconnected'),
              const SizedBox(width: AppSpacing.sm),
              _buildFilterChip('Düşük Batarya', 'lowBattery'),
            ],
          ),
        ),
      ],
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
                      style: AppTypography.bodySmall(
                        context,
                      ).copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                  label: gateway.signalQualityLabel,
                  color: gateway.signalStrength! >= -60
                      ? AppColors.success
                      : gateway.signalStrength! >= -80
                      ? AppColors.warning
                      : AppColors.danger,
                ),
              const SizedBox(width: AppSpacing.sm),
              _buildMetricChip(
                context: context,
                icon: Icons.phone_android,
                label: '${gateway.connectedDeviceCount ?? 0} cihaz',
                color: AppColors.primary,
              ),
              const Spacer(),
              // Last Seen
              if (gateway.lastSeen != null)
                Text(
                  _formatLastSeen(gateway.lastSeen!),
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelSmall(
              context,
            ).copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
