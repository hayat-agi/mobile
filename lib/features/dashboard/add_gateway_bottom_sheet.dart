import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/gateway.dart';
import '../ble/ble_service.dart';
import '../ble/BLEConstants.dart';
import '../ble/activation_dialog.dart';
import '../../services/device_password_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bottom sheet for adding a new gateway
class AddGatewayBottomSheet extends StatefulWidget {
  final Function(
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
  ) onAdd;

  const AddGatewayBottomSheet({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddGatewayBottomSheet> createState() => _AddGatewayBottomSheetState();
}

class _AddGatewayBottomSheetState extends State<AddGatewayBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _gatewayIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingNumberController = TextEditingController();
  final TextEditingController _doorNumberController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
  final BleService _bleService = BleService();
  BuildingType? _selectedBuildingType;
  bool _showBleScan = false;
  bool _isSelectingDevice = false;
  double? _latitude;
  double? _longitude;
  // Raw advertisement name captured from the BLE peripheral on connect
  // (e.g., "ESP32_LifeNet_Node_3"). Kept separate from the editable form
  // name so we can still derive the LoRa address even if the operator
  // renames the gateway to something custom.
  String? _bleAdvName;

  @override
  void initState() {
    super.initState();
    _bleService.results.addListener(_onBleResultsChanged);
  }

  void _onBleResultsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _bleService.results.removeListener(_onBleResultsChanged);

    _gatewayIdController.dispose();
    _nameController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    _doorNumberController.dispose();
    _neighborhoodController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _startBleScan() async {
    setState(() {
      _showBleScan = true;
    });
    await _bleService.scanDevices();
  }

  Future<void> _selectBleDevice(ScanResult result) async {
    if (_isSelectingDevice) return;
    _isSelectingDevice = true;

    try {
      final deviceName = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : result.advertisementData.advName;
      final deviceId = result.device.remoteId.toString();

      // Show connecting dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text('Bağlanıyor...\n$deviceName'),
            ],
          ),
        ),
      );

      try {
        // Connect to the device — this handles everything automatically:
        // service discovery, notifications, etc.
        await _bleService.connect(result);

        if (!mounted) return;

        // Check if connected
        if (!_bleService.isConnected.value) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Bağlantı başarısız: ${_bleService.status.value}'),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        // Close connecting dialog
        Navigator.of(context).pop();

        // Make sure we're still connected after all that
        if (!_bleService.isConnected.value || !mounted) {
          await _bleService.disconnect();
          return;
        }

        // Check if device needs activation.
        // Primary: wait for NEED_ACTIVATION notification from ESP32 (handles factory-reset case).
        // Fallback: if the notification is missed (timing issue), check local activation record.
        debugPrint('[ADD_GW] Calling waitForActivationPrompt...');
        final activationNeeded = await _bleService.waitForActivationPrompt();
        debugPrint('[ADD_GW] activationNeeded=$activationNeeded, mounted=$mounted');

        // The ESP32 is the source of truth.
        // It only sends NEED_ACTIVATION when genuinely unactivated (NVS flag = false).
        // If no NEED_ACTIVATION arrives within the timeout, the device is already
        // activated — regardless of what the local app cache says.
        // (The local cache is wiped on reinstall, which previously caused a false dialog.)
        if (activationNeeded && mounted) {
          debugPrint('[ADD_GW] Showing activation dialog...');
          final activated = await showActivationDialog(context);
          debugPrint('[ADD_GW] Activation dialog result: activated=$activated');
          if (!mounted) return;

          if (!activated) {
            await _bleService.disconnect();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cihaz aktive edilmedi — bağlantı kesildi'),
                backgroundColor: AppColors.warning,
              ),
            );
            return;
          }

          // Cache activation state locally (used for future reference only)
          await DevicePasswordService().markActivated(deviceId);
        }

        // Bağlantı başarılı! Formu doldur ve cihaz bilgilerini kaydet
        await _saveDeviceInfoAndFillForm(deviceId, deviceName);

        // Close scan view
        setState(() {
          _showBleScan = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deviceName başarıyla bağlandı'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        // Close connecting dialog if still open
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Bağlantı hatası: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
        return; // Don't try GPS if connection failed
      }

      // GPS konumu al ve adres alanlarını doldur
      // Bu kısım BLE try-catch'inin DIŞINDA — kendi hata yönetimi var
      debugPrint('[Location] _fetchAndFillLocation() CALLED');
      await _fetchAndFillLocation();
    } finally {
      _isSelectingDevice = false;
    }
  }
  
  /// Fill in the form with the connected device's info
  Future<void> _saveDeviceInfoAndFillForm(String deviceId, String deviceName) async {
    // REQ-GW-05: Persist the device ID for automatic reconnection
    await DevicePasswordService().saveLastConnectedDeviceId(deviceId);

    // Fill in the Gateway ID field automatically
    _gatewayIdController.text = deviceId;

    // Remember the BLE-advertised name as-is so the backend can derive
    // the LoRa address from it (the firmware embeds the node number via
    // DEVICE_NAME, e.g., "ESP32_LifeNet_Node_3"). The operator may later
    // edit the form name field; this raw value stays untouched.
    if (deviceName.isNotEmpty) {
      _bleAdvName = deviceName;
    }

    // Use the device name if user hasn't typed a custom name
    if (_nameController.text.isEmpty && deviceName.isNotEmpty) {
      _nameController.text = deviceName;
    }
  }
  
  /// Fetch GPS location and reverse geocode to fill address fields.
  Future<void> _fetchAndFillLocation() async {
    try {
      // Check if location service is enabled — if not, prompt user to open settings
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Konum Servisi Kapalı'),
              content: const Text(
                'Adres bilgilerini otomatik doldurmak için konum servisini açmanız gerekiyor.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Geç'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ayarları Aç'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await Geolocator.openLocationSettings();
            // Wait a moment for user to toggle settings and come back
            await Future.delayed(const Duration(seconds: 2));
            // Re-check
            serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('⚠️ Konum hâlâ kapalı — adresi elle girin'),
                    backgroundColor: AppColors.warning,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
          } else {
            return;
          }
        } else {
          return;
        }
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('⚠️ Konum izni verilmedi — adresi elle girin'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Konum İzni Gerekli'),
              content: const Text(
                'Konum izni kalıcı olarak reddedilmiş. Uygulama ayarlarından izni açmanız gerekiyor.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Geç'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ayarları Aç'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await Geolocator.openAppSettings();
          }
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Konum alınıyor…'),
              ],
            ),
            duration: const Duration(seconds: 15),
            backgroundColor: AppColors.info,
          ),
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      debugPrint('[Location] GPS OK: ${position.latitude}, ${position.longitude}');

      // Reverse geocode
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;

          // Debug: print all available placemark fields
          // In Turkey: street=mahalle adı, thoroughfare=gerçek cadde/sokak, subLocality=mahalle
          debugPrint('[Location] Placemark: '
              'street=${place.street}, '
              'thoroughfare=${place.thoroughfare}, '
              'subThoroughfare=${place.subThoroughfare}, '
              'subLocality=${place.subLocality}, '
              'locality=${place.locality}, '
              'subAdminArea=${place.subAdministrativeArea}, '
              'adminArea=${place.administrativeArea}, '
              'postalCode=${place.postalCode}');

          // Hierarchical address fields are overwritten from the placemark
          // (street/neighborhood/district/city/postalCode) so coordinates and
          // address always describe the same place. Door/building number are
          // preserved because Turkish reverse geocoding rarely returns them
          // reliably and they're typically entered by hand.
          //
          // Previous behaviour only filled empty fields, which produced
          // gateways whose stored lat/lng pointed at the user's current GPS
          // location (e.g. Pursaklar) while the address still read whatever
          // the user had typed earlier (e.g. Etimesgut). The mismatch showed
          // up as map markers in one district and gateway listings in another.
          setState(() {
            final street = place.thoroughfare ?? place.street;
            _streetController.text = (street != null && street.isNotEmpty) ? street : '';

            final neighborhood = place.subLocality;
            _neighborhoodController.text =
                (neighborhood != null && neighborhood.isNotEmpty) ? neighborhood : '';

            final district = place.subAdministrativeArea?.isNotEmpty == true
                ? place.subAdministrativeArea
                : place.locality;
            _districtController.text =
                (district != null && district.isNotEmpty) ? district : '';

            final city = place.administrativeArea;
            _cityController.text = (city != null && city.isNotEmpty) ? city : '';

            final postal = place.postalCode;
            _postalCodeController.text = (postal != null && postal.isNotEmpty) ? postal : '';

            // Bina No: subThoroughfare = kapı/bina numarası. Only auto-fill if
            // we got a value AND the field is empty — placemarks return this
            // sporadically, so we don't want to clobber a manual entry with
            // nothing.
            final buildingNo = place.subThoroughfare;
            if (buildingNo != null && buildingNo.isNotEmpty &&
                _buildingNumberController.text.isEmpty) {
              _buildingNumberController.text = buildingNo;
            }
          });

          // Dismiss loading snackbar and show success
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('📍 Konum alındı — adres alanları GPS\'e göre güncellendi'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // No placemarks returned for these coordinates. Clear the
          // hierarchical address fields so a previously-typed address can't
          // travel with the new lat/lng and create a mismatch.
          if (mounted) {
            setState(() {
              _streetController.clear();
              _neighborhoodController.clear();
              _districtController.clear();
              _cityController.clear();
              _postalCodeController.clear();
            });
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📍 Koordinatlar alındı (${position.latitude.toStringAsFixed(4)}, '
                    '${position.longitude.toStringAsFixed(4)}) — adres çevrilemedi, lütfen elle girin'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[Location] Reverse geocoding failed: $e');
        // Geocoding threw before we could verify the address. Coordinates
        // already updated above, so clear the hierarchical address fields
        // to avoid silently shipping stale text alongside fresh lat/lng.
        if (mounted) {
          setState(() {
            _streetController.clear();
            _neighborhoodController.clear();
            _districtController.clear();
            _cityController.clear();
            _postalCodeController.clear();
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 GPS alındı ama adres çevrilemedi, lütfen elle girin: $e'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Location] GPS error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Konum alınamadı: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.onAdd(
      _gatewayIdController.text.trim(),
      _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      _selectedBuildingType,
      _streetController.text.trim(),
      _buildingNumberController.text.trim(),
      _doorNumberController.text.trim().isEmpty
          ? null
          : _doorNumberController.text.trim(),
      _neighborhoodController.text.trim().isEmpty
          ? null
          : _neighborhoodController.text.trim(),
      _districtController.text.trim(),
      _cityController.text.trim(),
      _postalCodeController.text.trim(),
      _latitude,
      _longitude,
      _bleAdvName,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Yeni Hayat Ağı Cihazı Ekle',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: keyboardHeight),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      children: [
                      // BLE Scan Option
                      SecondaryButton(
                        label: _showBleScan ? 'Aramayı Durdur' : 'Hayat Ağı Cihazı Ara',
                        icon: _showBleScan ? Icons.stop : Icons.bluetooth_searching,
                        onPressed: _showBleScan ? () {
                          setState(() {
                            _showBleScan = false;
                          });
                        } : _startBleScan,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // BLE Scan Results
                      if (_showBleScan)
                        Obx(() {
                          final controller = _bleService.bleConnection;
                          final results = controller.results.toList();
                          final isScanning = controller.isScanning.value;
                          
                          // Debug: Print results count
                          print('📋 UI Builder (Obx): results.length = ${results.length}');
                          print('📋 UI Builder (Obx): isScanning = $isScanning');
                          
                          // Show scanning indicator at top if scanning, but still show results
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Scanning indicator
                              if (isScanning)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Hayat Ağı Cihazı aranıyor...',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Obx(() {
                                                final status = controller.status.value;
                                                return Text(
                                                  status,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: AppColors.textSecondaryLight,
                                                    fontSize: 11,
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              // Empty state (only show when not scanning and no results)
                              if (results.isEmpty && !isScanning)
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: AppSpacing.lg),
                                      Icon(
                                        Icons.bluetooth_disabled,
                                        size: 48,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Cihaz bulunamadı',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Hayat Ağı cihazınızın açık ve yayın yaptığından emin olun',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Obx(() {
                                        final status = controller.status.value;
                                        return Container(
                                          padding: const EdgeInsets.all(AppSpacing.sm),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'Durum:',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: AppSpacing.xs),
                                              Text(
                                                status,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppColors.textSecondaryLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              
                              // Show results if available (even during scan)
                              if (results.isNotEmpty) ...[
                                Text(
                                  'Bulunan Cihazlar (${results.length})',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                // Show all results
                                // REQ-GW-03: Show friendly names, hide MAC address
                                ...results.asMap().entries.map((entry) {
                                  final result = entry.value;

                                  // Get the device name — use advertised name if available
                                  final platformName = result.device.platformName;
                                  final advName = result.advertisementData.advName;
                                  final rawName = platformName.isNotEmpty ? platformName : advName;

                                  // Show a friendly name: use the advertised name,
                                  // or fall back to "HayatAğ Gateway" + number
                                  final displayName = rawName.isNotEmpty
                                      ? rawName
                                      : 'Hayat Ağı Cihazı ${entry.key + 1}';

                                  // Signal strength indicator
                                  final rssi = result.rssi;
                                  final signalIcon = rssi > -50
                                      ? Icons.signal_cellular_alt        // Excellent
                                      : rssi > -70
                                          ? Icons.signal_cellular_alt_2_bar // Good
                                          : Icons.signal_cellular_alt_1_bar; // Weak
                                  final signalColor = rssi > -50
                                      ? AppColors.success    // Green = excellent
                                      : rssi > -70
                                          ? AppColors.warning  // Yellow = good
                                          : AppColors.danger;  // Red = weak

                                  return Card(
                                    key: ValueKey(result.device.remoteId.str),
                                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                    child: ListTile(
                                      // Signal strength icon on the left
                                      leading: Icon(
                                        signalIcon,
                                        color: signalColor,
                                      ),
                                      // Friendly device name
                                      title: Text(
                                        displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      // Show signal strength in dBm instead of MAC
                                      subtitle: Text('Sinyal: $rssi dBm'),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      onTap: () async {
                                        await _selectBleDevice(result);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ],
                          );
                        }),
                      if (_showBleScan) const SizedBox(height: AppSpacing.md),
                      
                      // Gateway ID
                      TextFormField(
                        controller: _gatewayIdController,
                        decoration: const InputDecoration(
                          labelText: 'Cihaz ID *',
                          hintText: 'Cihaz ID\'sini girin veya taramadan seçin',
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Cihaz ID gereklidir';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Custom Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Cihaz Adı',
                          hintText: 'Örn: Ev Cihazı, İş Yeri Cihazı',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Building Type
                      DropdownButtonFormField<BuildingType>(
                        initialValue: _selectedBuildingType,
                        decoration: const InputDecoration(
                          labelText: 'Bina Tipi *',
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
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Bina tipi seçilmelidir';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Address Section
                      SectionHeader(
                        title: 'Adres Bilgileri',
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Street
                      TextFormField(
                        controller: _streetController,
                        decoration: const InputDecoration(
                          labelText: 'Sokak/Cadde *',
                          hintText: 'Sokak veya cadde adı',
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
                      const SizedBox(height: AppSpacing.md),
                      
                      // Building Number
                      TextFormField(
                        controller: _buildingNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Bina No *',
                          hintText: 'Bina numarası',
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
                      const SizedBox(height: AppSpacing.md),
                      
                      // Door Number
                      TextFormField(
                        controller: _doorNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Kapı No',
                          hintText: 'Daire/Kapı (opsiyonel)',
                          prefixIcon: Icon(Icons.door_front_door),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Neighborhood
                      TextFormField(
                        controller: _neighborhoodController,
                        decoration: const InputDecoration(
                          labelText: 'Mahalle',
                          hintText: 'Mahalle adı (opsiyonel)',
                          prefixIcon: Icon(Icons.holiday_village_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // District
                      TextFormField(
                        controller: _districtController,
                        decoration: const InputDecoration(
                          labelText: 'İlçe *',
                          hintText: 'İlçe adı',
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
                      const SizedBox(height: AppSpacing.md),
                      
                      // City
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'İl *',
                          hintText: 'Şehir adı',
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
                      const SizedBox(height: AppSpacing.md),
                      
                      // Postal Code
                      TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Posta Kodu *',
                          hintText: '34000',
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
                      const SizedBox(height: AppSpacing.xl),
                      
                      // Submit Button
                      PrimaryButton(
                        label: 'Cihaz Ekle',
                        icon: Icons.add,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.screenPadding),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

