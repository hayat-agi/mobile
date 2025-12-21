import 'package:flutter/material.dart';
import '../../models/gateway.dart';
import '../../services/gateway_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final gateway = _gatewayService.getGateway(widget.gatewayId);

    if (gateway == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gateway Detayları')),
        body: const Center(
          child: Text('Gateway bulunamadı'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(gateway.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(gateway),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Gateway>>(
        valueListenable: _gatewayService.gateways,
        builder: (context, gateways, _) {
          final updatedGateway = _gatewayService.getGateway(widget.gatewayId);
          if (updatedGateway == null) {
            Navigator.pop(context);
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                _buildStatusCard(updatedGateway),
                const SizedBox(height: 16),

                // Connection Info
                _buildSectionTitle('Bağlantı Bilgileri'),
                _buildInfoCard([
                  _buildInfoRow('Durum', updatedGateway.status.displayName,
                      _getStatusColor(updatedGateway.status)),
                  _buildInfoRow('Gateway ID', updatedGateway.id, null),
                  if (updatedGateway.macAddress != null)
                    _buildInfoRow('MAC Adresi', updatedGateway.macAddress!, null),
                  if (updatedGateway.connectedAt != null)
                    _buildInfoRow(
                        'Bağlanma Zamanı',
                        _formatDateTime(updatedGateway.connectedAt!),
                        null),
                  if (updatedGateway.lastSeen != null)
                    _buildInfoRow('Son Görülme',
                        _formatLastSeen(updatedGateway.lastSeen!), null),
                ]),
                const SizedBox(height: 16),
                
                // Address Information
                if (updatedGateway.hasCompleteAddress) ...[
                  _buildSectionTitle('Adres Bilgileri'),
                  _buildInfoCard([
                    if (updatedGateway.buildingType != null)
                      _buildInfoRow('Bina Tipi', 
                          updatedGateway.buildingType!.displayName, null),
                    if (updatedGateway.street != null)
                      _buildInfoRow('Sokak/Cadde', updatedGateway.street!, null),
                    if (updatedGateway.buildingNumber != null)
                      _buildInfoRow('Bina No', updatedGateway.buildingNumber!, null),
                    if (updatedGateway.doorNumber != null)
                      _buildInfoRow('Kapı No', updatedGateway.doorNumber!, null),
                    if (updatedGateway.district != null)
                      _buildInfoRow('İlçe', updatedGateway.district!, null),
                    if (updatedGateway.city != null)
                      _buildInfoRow('İl', updatedGateway.city!, null),
                    if (updatedGateway.postalCode != null)
                      _buildInfoRow('Posta Kodu', updatedGateway.postalCode!, null),
                    if (updatedGateway.latitude != null && updatedGateway.longitude != null)
                      _buildInfoRow('Koordinatlar', 
                          '${updatedGateway.latitude!.toStringAsFixed(6)}, ${updatedGateway.longitude!.toStringAsFixed(6)}', null),
                  ]),
                ] else if (updatedGateway.street != null || updatedGateway.city != null) ...[
                  _buildSectionTitle('Adres Bilgileri'),
                  _buildInfoCard([
                    _buildInfoRow('Adres', updatedGateway.formattedAddress, null),
                  ]),
                ],
                const SizedBox(height: 16),

                // Battery & Signal
                _buildSectionTitle('Performans'),
                Row(
                  children: [
                    Expanded(
                      child: _buildBatteryCard(updatedGateway.batteryLevel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSignalCard(updatedGateway.signalStrength),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Statistics
                _buildSectionTitle('İstatistikler'),
                _buildInfoCard([
                  _buildInfoRow('Gönderilen Mesaj',
                      updatedGateway.messagesSent.toString(), null),
                  _buildInfoRow('Alınan Mesaj',
                      updatedGateway.messagesReceived.toString(), null),
                ]),
                const SizedBox(height: 24),

                // Actions
                _buildSectionTitle('İşlemler'),
                if (updatedGateway.isConnected)
                  _buildActionButton(
                    'Bağlantıyı Kes',
                    Icons.link_off,
                    Colors.red,
                    () => _disconnectGateway(updatedGateway),
                  )
                else
                  _buildActionButton(
                    'Bağlan',
                    Icons.link,
                    Colors.green,
                    () => _connectGateway(updatedGateway),
                  ),
                const SizedBox(height: 12),
                _buildActionButton(
                  'Gateway\'i Kaldır',
                  Icons.delete_outline,
                  Colors.red,
                  () => _showDeleteDialog(updatedGateway),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(Gateway gateway) {
    return Card(
      color: _getStatusColor(gateway.status).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: _getStatusColor(gateway.status).withValues(alpha: 0.2),
              child: Icon(
                _getStatusIcon(gateway.status),
                color: _getStatusColor(gateway.status),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gateway.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gateway.status.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      color: _getStatusColor(gateway.status),
                      fontWeight: FontWeight.w500,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(int batteryLevel) {
    Color color;
    IconData icon;

    if (batteryLevel > 50) {
      color = Colors.green;
      icon = Icons.battery_full;
    } else if (batteryLevel > 20) {
      color = Colors.orange;
      icon = Icons.battery_3_bar;
    } else {
      color = Colors.red;
      icon = Icons.battery_alert;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              '$batteryLevel%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Batarya',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: batteryLevel / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard(int? signalStrength) {
    if (signalStrength == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.signal_cellular_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'N/A',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sinyal',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final color = signalStrength > -70 ? Colors.green : Colors.orange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.signal_cellular_alt, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              '$signalStrength dBm',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sinyal',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _connectGateway(Gateway gateway) async {
    await _gatewayService.connectToGateway(gateway.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gateway\'e bağlanılıyor...'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _disconnectGateway(Gateway gateway) async {
    await _gatewayService.disconnectFromGateway(gateway.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı kesildi'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showDeleteDialog(Gateway gateway) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gateway\'i Kaldır'),
        content: Text('${gateway.name} gateway\'ini kaldırmak istediğinize emin misiniz?'),
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
                  const SnackBar(
                    content: Text('Gateway kaldırıldı'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(GatewayStatus status) {
    switch (status) {
      case GatewayStatus.connected:
        return Colors.green;
      case GatewayStatus.disconnected:
        return Colors.grey;
      case GatewayStatus.scanning:
      case GatewayStatus.connecting:
        return Colors.blue;
      case GatewayStatus.error:
        return Colors.red;
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
}

