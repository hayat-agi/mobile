import 'package:flutter/material.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/gateway.dart';

/// Bottom sheet for adding a new gateway
class AddGatewayBottomSheet extends StatefulWidget {
  final Function(
    String gatewayId,
    String? name,
    BuildingType? buildingType,
    String? street,
    String? buildingNumber,
    String? doorNumber,
    String? district,
    String? city,
    String? postalCode,
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
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
  BuildingType? _selectedBuildingType;

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
      _districtController.text.trim(),
      _cityController.text.trim(),
      _postalCodeController.text.trim(),
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
                      'Yeni Gateway Ekle',
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
                      // Gateway ID
                      TextFormField(
                        controller: _gatewayIdController,
                        decoration: const InputDecoration(
                          labelText: 'Gateway ID *',
                          hintText: 'Gateway ID\'sini girin',
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Gateway ID gereklidir';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Custom Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Gateway Adı',
                          hintText: 'Örn: Ev Gateway, İş Yeri Gateway',
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
                        label: 'Gateway Ekle',
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

