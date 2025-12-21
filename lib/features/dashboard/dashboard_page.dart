import 'package:flutter/material.dart';
import '../../core/routing/app_router.dart';
import '../../models/gateway.dart';
import '../../services/gateway_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GatewayService _gatewayService = GatewayService();
  final TextEditingController _gatewayIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingNumberController = TextEditingController();
  final TextEditingController _doorNumberController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  bool _showAddGateway = false;
  String _filterStatus = 'all'; // all, connected, disconnected, lowBattery
  BuildingType? _selectedBuildingType;

  @override
  void initState() {
    super.initState();
    _gatewayService.initialize();
  }

  @override
  void dispose() {
    _gatewayIdController.dispose();
    _nameController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    _doorNumberController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _addGateway() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final gatewayId = _gatewayIdController.text.trim();
    final name = _nameController.text.trim().isEmpty 
        ? 'Gateway ${gatewayId.substring(0, gatewayId.length > 4 ? 4 : gatewayId.length)}'
        : _nameController.text.trim();

    final success = await _gatewayService.addGateway(
      gatewayId,
      name: name,
      buildingType: _selectedBuildingType,
      street: _streetController.text.trim(),
      buildingNumber: _buildingNumberController.text.trim(),
      doorNumber: _doorNumberController.text.trim().isEmpty 
          ? null 
          : _doorNumberController.text.trim(),
      district: _districtController.text.trim(),
      city: _cityController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
    );
    
    if (mounted) {
      if (success) {
        _clearForm();
        setState(() {
          _showAddGateway = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gateway eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu Gateway zaten ekli veya geçersiz ID'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearForm() {
    _gatewayIdController.clear();
    _nameController.clear();
    _streetController.clear();
    _buildingNumberController.clear();
    _doorNumberController.clear();
    _districtController.clear();
    _cityController.clear();
    _postalCodeController.clear();
    _selectedBuildingType = null;
  }

  List<Gateway> _getFilteredGateways() {
    final all = _gatewayService.gateways.value;
    switch (_filterStatus) {
      case 'connected':
        return all.where((g) => g.isConnected).toList();
      case 'disconnected':
        return all.where((g) => !g.isConnected).toList();
      case 'lowBattery':
        return all.where((g) => g.isLowBattery).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _gatewayService.getStatistics();
    final avgBattery = _gatewayService.getAverageBattery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hayat Ağı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.settings);
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Gateway>>(
        valueListenable: _gatewayService.gateways,
        builder: (context, gateways, _) {
          return RefreshIndicator(
            onRefresh: () async {
              // TODO: Refresh gateway data
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Network Overview Cards
                  _buildOverviewCards(stats, avgBattery),
                  const SizedBox(height: 24),
                  
                  // Add Gateway Section
                  _buildAddGatewaySection(),
                  const SizedBox(height: 24),
                  
                  // Filter Chips
                  _buildFilterChips(),
                  const SizedBox(height: 16),
                  
                  // Gateway List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gateway\'ler (${_getFilteredGateways().length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (gateways.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRouter.disasterHome);
                          },
                          icon: const Icon(Icons.warning, color: Colors.red),
                          label: const Text(
                            'Afet Modu',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Gateway List
                  if (_getFilteredGateways().isEmpty)
                    _buildEmptyState()
                  else
                    ..._getFilteredGateways().map((gateway) => 
                      _buildGatewayCard(gateway)
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCards(Map<String, int> stats, double avgBattery) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Toplam',
            stats['total'].toString(),
            Icons.devices,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Aktif',
            stats['connected'].toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Batarya',
            '${avgBattery.toInt()}%',
            Icons.battery_charging_full,
            avgBattery > 50 ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGatewaySection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Gateway Ekle'),
        leading: const Icon(Icons.add_circle_outline),
        initiallyExpanded: _showAddGateway,
        onExpansionChanged: (expanded) {
          setState(() {
            _showAddGateway = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gateway ID
                    TextFormField(
                      controller: _gatewayIdController,
                      decoration: InputDecoration(
                        labelText: 'Gateway ID *',
                        hintText: 'Gateway ID\'sini girin',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _gatewayIdController.clear(),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Gateway ID gereklidir';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Custom Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Gateway Adı',
                        hintText: 'Örn: Ev Gateway, İş Yeri Gateway',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    
                    // Building Type Dropdown
                    StatefulBuilder(
                      builder: (context, setState) {
                        return DropdownButtonFormField<BuildingType>(
                          value: _selectedBuildingType,
                          decoration: const InputDecoration(
                            labelText: 'Bina Tipi *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                          ),
                          hint: const Text('Bina tipini seçin'),
                          items: BuildingType.values.map((type) {
                            return DropdownMenuItem<BuildingType>(
                              value: type,
                              child: Text(type.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBuildingType = value;
                            });
                            this.setState(() {
                              _selectedBuildingType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Bina tipi seçilmelidir';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Address Section Header
                    const Divider(),
                    const Text(
                      'Adres Bilgileri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Street
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Sokak/Cadde *',
                        hintText: 'Sokak veya cadde adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.streetview),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Sokak/Cadde gereklidir';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Building Number and Door Number in Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _buildingNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Bina No *',
                              hintText: 'Bina numarası',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Bina no gereklidir';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _doorNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Kapı No',
                              hintText: 'Daire/Kapı',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.door_front_door),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // District
                    TextFormField(
                      controller: _districtController,
                      decoration: const InputDecoration(
                        labelText: 'İlçe *',
                        hintText: 'İlçe adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'İlçe gereklidir';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // City and Postal Code in Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'İl *',
                              hintText: 'Şehir adı',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.map),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'İl gereklidir';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _postalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Posta Kodu *',
                              hintText: '34000',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.markunread_mailbox),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Posta kodu gereklidir';
                              }
                              if (value.trim().length != 5) {
                                return 'Posta kodu 5 haneli olmalıdır';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addGateway,
                        icon: const Icon(Icons.add),
                        label: const Text('Gateway Ekle'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Tümü', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Bağlı', 'connected'),
          const SizedBox(width: 8),
          _buildFilterChip('Bağlantı Kesildi', 'disconnected'),
          const SizedBox(width: 8),
          _buildFilterChip('Düşük Batarya', 'lowBattery'),
        ],
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
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildGatewayCard(Gateway gateway) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(gateway.status).withValues(alpha: 0.2),
          child: Icon(
            _getStatusIcon(gateway.status),
            color: _getStatusColor(gateway.status),
          ),
        ),
        title: Text(
          gateway.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${gateway.id}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildBatteryIndicator(gateway.batteryLevel),
                const SizedBox(width: 8),
                if (gateway.signalStrength != null)
                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        size: 16,
                        color: gateway.hasGoodSignal ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text('${gateway.signalStrength} dBm'),
                    ],
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              gateway.status.displayName,
              style: TextStyle(
                color: _getStatusColor(gateway.status),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (gateway.lastSeen != null)
              Text(
                _formatLastSeen(gateway.lastSeen!),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRouter.gatewayDetails,
            arguments: gateway.id,
          );
        },
      ),
    );
  }

  Widget _buildBatteryIndicator(int level) {
    Color color;
    IconData icon;
    
    if (level > 50) {
      color = Colors.green;
      icon = Icons.battery_full;
    } else if (level > 20) {
      color = Colors.orange;
      icon = Icons.battery_3_bar;
    } else {
      color = Colors.red;
      icon = Icons.battery_alert;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$level%', style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz gateway eklenmedi',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yukarıdaki "Gateway Ekle" bölümünden\nyeni bir gateway ekleyebilirsiniz',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
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

