import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/gateway.dart';
import '../../services/gateway_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/danger_button.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../ble/ble_service.dart';
import '../ble/BLEConstants.dart';
import '../ble/BLEConnectionManager.dart';
import '../ble/activation_dialog.dart';

class GatewayDetailsPage extends StatefulWidget {
  final String gatewayId;

  const GatewayDetailsPage({
    super.key,
    required this.gatewayId,
  });

  @override
  State<GatewayDetailsPage> createState() => _GatewayDetailsPageState();
}

class _GatewayDetailsPageState extends State<GatewayDetailsPage> {
  final GatewayService _gatewayService = GatewayService();
  final BleService _bleService = BleService();
  bool _isConnecting = false;

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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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

  Future<void> _connectGateway(Gateway gateway) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final controller = _bleService.bleConnection;

      // ── Fast path: BLE link is already up (singleton survived navigation) ──
      if (_bleService.isConnected.value && controller.isAuthenticated.value) {
        _gatewayService.updateGatewayStatus(gateway.id, GatewayStatus.connected);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gateway zaten bağlı'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return;
      }

      // ── Scan for the device ──
      await _bleService.scanDevices();

      final results = _bleService.results.value;

      // Try matching by exact remoteId first, then fall back to device name.
      // The gateway ID might not match remoteId if the user entered it
      // manually (e.g. when auto-fill didn't work on the first add).
      ScanResult? deviceResult;
      for (final r in results) {
        if (r.device.remoteId.toString() == gateway.id) {
          deviceResult = r;
          break;
        }
      }
      if (deviceResult == null) {
        // Fallback: match by device name (case-insensitive)
        final gatewayNameUpper = gateway.name.toUpperCase();
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          if (name.toUpperCase() == gatewayNameUpper ||
              name.toUpperCase() == BleConstants.deviceName) {
            deviceResult = r;
            break;
          }
        }
      }
      if (deviceResult == null && results.isNotEmpty) {
        // Last resort: if exactly one ESP32 device was found, use it
        deviceResult = results.first;
      }
      if (deviceResult == null) {
        throw Exception(
          'Cihaz bulunamadı. ESP32 cihazınızın açık ve yayın yaptığından emin olun.',
        );
      }

      // ── Connect ──
      await _bleService.connect(deviceResult);

      if (!_bleService.isConnected.value) {
        throw Exception(
          'Bağlantı başarısız: ${_bleService.bleConnection.status.value}',
        );
      }

      // ── Check if device needs activation (factory reset or new flash) ──
      final activationNeeded = await _bleService.waitForActivationPrompt();
      if (activationNeeded && mounted) {
        final activated = await showActivationDialog(context);
        if (!mounted) return;
        if (!activated) {
          await _bleService.disconnect();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cihaz aktive edilmedi — bağlantı kesildi'),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
      }

      _gatewayService.updateGatewayStatus(gateway.id, GatewayStatus.connected);

      // If the gateway was added with a manually-entered ID, update it
      // to the real BLE remoteId so future reconnects work reliably.
      final realId = deviceResult.device.remoteId.toString();
      if (gateway.id != realId) {
        _gatewayService.updateGatewayBleId(gateway.id, realId);
      }

      // Query how many mobile devices are registered to this gateway.
      final deviceCount = await _bleService.queryDeviceCount();
      if (deviceCount != null) {
        _gatewayService.updateGatewayDeviceCount(realId, deviceCount);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gateway\'e başarıyla bağlandı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı hatası: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnectGateway(Gateway gateway) async {
    try {
      await _bleService.disconnect();
    await _gatewayService.disconnectFromGateway(gateway.id);
      
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı kesildi'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı kesme hatası: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showDeleteDialog(Gateway gateway) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gateway\'i Kaldır'),
        content: Text(
          '${gateway.name} gateway\'ini kaldırmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await _gatewayService.removeGateway(gateway.id);
              if (mounted) {
                navigator.pop(); // Close dialog
                navigator.pop(); // Go back to dashboard
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Gateway kaldırıldı'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Kaldır', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label panoya kopyalandı'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gateway = _gatewayService.getGateway(widget.gatewayId);

    if (gateway == null) {
      return AppScaffold(
        title: 'Gateway Detayları',
        body: const Center(
          child: Text('Gateway bulunamadı'),
        ),
      );
    }

    return AppScaffold(
      title: gateway.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteDialog(gateway),
        ),
      ],
      body: ValueListenableBuilder<List<Gateway>>(
        valueListenable: _gatewayService.gateways,
        builder: (context, gateways, _) {
          final updatedGateway = _gatewayService.getGateway(widget.gatewayId);
          if (updatedGateway == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Header
                      _buildHeroHeader(updatedGateway, context),
                      const SizedBox(height: AppSpacing.lg),

                      // Health Section
                      SectionHeader(
                        title: 'Sağlık',
                        subtitle: 'Battery ve sinyal durumu',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildHealthSection(updatedGateway, context),
                      const SizedBox(height: AppSpacing.lg),

                      // Connection Info
                      SectionHeader(
                        title: 'Bağlantı Bilgileri',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildConnectionInfo(updatedGateway, context),
                      const SizedBox(height: AppSpacing.lg),

                      // Address Information
                      if (updatedGateway.hasCompleteAddress ||
                          updatedGateway.street != null ||
                          updatedGateway.city != null) ...[
                        SectionHeader(
                          title: 'Adres Bilgileri',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildAddressCard(updatedGateway, context),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Statistics
                      SectionHeader(
                        title: 'İstatistikler',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildStatisticsCard(updatedGateway, context),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Household Profile Button
                      PrimaryButton(
                        label: 'Hane Profili',
                        icon: Icons.family_restroom,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRouter.householdProfile,
                            arguments: updatedGateway.id,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Connect/Disconnect Button
                      if (updatedGateway.isConnected)
                        SecondaryButton(
                          label: 'Bağlantıyı Kes',
                          icon: Icons.link_off,
                          onPressed: _isConnecting ? null : () => _disconnectGateway(updatedGateway),
                        )
                      else
                        PrimaryButton(
                          label: 'Bağlan',
                          icon: Icons.link,
                          onPressed: () => _connectGateway(updatedGateway),
                          isLoading: _isConnecting,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      // Remove Button
                      DangerButton(
                        label: 'Gateway\'i Kaldır',
                        icon: Icons.delete_outline,
                        isOutlined: true,
                        onPressed: () => _showDeleteDialog(updatedGateway),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(Gateway gateway, BuildContext context) {
    final theme = Theme.of(context);
    return ModernCard(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getStatusIcon(gateway.status),
              color: theme.colorScheme.onPrimaryContainer,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gateway.name,
                  style: AppTypography.headlineMedium(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                StatusPill(
                  label: gateway.status.displayName,
                  type: _getStatusType(gateway.status),
                  icon: _getStatusIcon(gateway.status),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSection(Gateway gateway, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildHealthMetric(
            context: context,
            icon: Icons.battery_charging_full,
            label: 'Batarya',
            value: '${gateway.batteryLevel}%',
            color: gateway.batteryLevel > 50
                ? AppColors.success
                : gateway.batteryLevel > 20
                    ? AppColors.warning
                    : AppColors.danger,
            progress: gateway.batteryLevel / 100,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildHealthMetric(
            context: context,
            icon: Icons.signal_cellular_alt,
            label: 'Sinyal',
            value: gateway.signalStrength != null
                ? '${gateway.signalStrength} dBm'
                : 'N/A',
            color: gateway.signalStrength != null
                ? (gateway.hasGoodSignal ? AppColors.success : AppColors.warning)
                : AppColors.textSecondaryLight,
            progress: gateway.signalStrength != null
                ? ((gateway.signalStrength! + 100) / 50).clamp(0.0, 1.0)
                : 0.0,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetric({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double progress,
  }) {
    return ModernCard(
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.headlineSmall(context).copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall(context).copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(Gateway gateway, BuildContext context) {
    return ModernCard(
      child: Column(
        children: [
          _buildInfoRow(
            context: context,
            label: 'Gateway ID',
            value: gateway.id,
            onTap: () => _copyToClipboard(gateway.id, 'Gateway ID'),
          ),
          const Divider(height: 1),
          if (gateway.macAddress != null) ...[
            _buildInfoRow(
              context: context,
              label: 'MAC Adresi',
              value: gateway.macAddress!,
              onTap: () => _copyToClipboard(gateway.macAddress!, 'MAC Adresi'),
            ),
            const Divider(height: 1),
          ],
          if (gateway.connectedAt != null)
            _buildInfoRow(
              context: context,
              label: 'Bağlanma Zamanı',
              value: _formatDateTime(gateway.connectedAt!),
            ),
          if (gateway.lastSeen != null) ...[
            if (gateway.connectedAt != null) const Divider(height: 1),
            _buildInfoRow(
              context: context,
              label: 'Son Görülme',
              value: _formatLastSeen(gateway.lastSeen!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard(Gateway gateway, BuildContext context) {
    final address = gateway.hasCompleteAddress
        ? gateway.formattedAddress
        : gateway.formattedAddress;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  address,
                  style: AppTypography.bodyMedium(context),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(address, 'Adres'),
                tooltip: 'Kopyala',
              ),
            ],
          ),
          if (gateway.latitude != null && gateway.longitude != null) ...[
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${gateway.latitude!.toStringAsFixed(6)}, ${gateway.longitude!.toStringAsFixed(6)}',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(Gateway gateway, BuildContext context) {
    return ModernCard(
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context: context,
              label: 'Gönderilen',
              value: gateway.messagesSent.toString(),
              icon: Icons.send,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          Expanded(
            child: _buildStatItem(
              context: context,
              label: 'Alınan',
              value: gateway.messagesReceived.toString(),
              icon: Icons.inbox,
            ),
          ),
          if (gateway.connectedDeviceCount != null) ...[
            Container(
              width: 1,
              height: 40,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            Expanded(
              child: _buildStatItem(
                context: context,
                label: 'Kayıtlı Cihaz',
                value: gateway.connectedDeviceCount.toString(),
                icon: Icons.phone_android,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.headlineSmall(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.bodySmall(context).copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.copy,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
