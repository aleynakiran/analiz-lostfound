import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_lost_found/core/utils/validators.dart';
import 'package:campus_lost_found/core/utils/date_time_x.dart';
import 'package:campus_lost_found/core/domain/audit_log.dart';
import 'package:campus_lost_found/features/report_found/presentation/widgets/category_picker.dart';
import 'package:campus_lost_found/features/report_found/presentation/widgets/location_picker.dart';
import 'package:campus_lost_found/providers/providers.dart';

class ReportFoundPage extends ConsumerStatefulWidget {
  const ReportFoundPage({super.key});

  @override
  ConsumerState<ReportFoundPage> createState() => _ReportFoundPageState();
}

class _ReportFoundPageState extends ConsumerState<ReportFoundPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedLocation;
  DateTime? _foundDate;
  TimeOfDay? _foundTime;
  final List<XFile> _selectedPhotos = [];

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _foundDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _foundTime = time;
      });
    }
  }

  Future<void> _pickPhoto() async {
    if (_selectedPhotos.length >= 3) return;

    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() {
        _selectedPhotos.add(picked);
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() &&
        _selectedCategory != null &&
        _selectedLocation != null &&
        _foundDate != null &&
        _foundTime != null) {
      final user = ref.read(currentUserProvider);

      final foundDateTime = DateTime(
        _foundDate!.year,
        _foundDate!.month,
        _foundDate!.day,
        _foundTime!.hour,
        _foundTime!.minute,
      );

      final itemsNotifier = ref.read(foundItemsStateProvider.notifier);
      final auditRepo = ref.read(auditLogRepositoryProvider);
      final photosRepo = ref.read(itemPhotosRepositoryProvider);

      if (_selectedPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one photo'),
          ),
        );
        return;
      }

      final item = await itemsNotifier.addItem(
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        foundLocation: _selectedLocation!,
        foundAt: foundDateTime,
        createdByOfficerId: user.id,
      );

      // Upload photos (min 1, max 3)
      for (final xfile in _selectedPhotos.take(3)) {
        await photosRepo.uploadFoundItemPhoto(
          itemId: item.id,
          file: File(xfile.path),
        );
      }

      auditRepo.addLog(
        actorId: user.id,
        actionType: ActionType.itemCreated,
        entityType: EntityType.foundItem,
        entityId: item.id,
        details: {
          'title': item.title,
          'category': item.category,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item "${item.title}" reported successfully!'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              context.push('/item/${item.id}');
            },
          ),
        ),
      );

      // Reset form
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = null;
        _selectedLocation = null;
        _foundDate = null;
        _foundTime = null;
        _selectedPhotos.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Found Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Permission notice removed: both students and officers can report found items.
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Item Title',
                  hintText: 'e.g., iPhone 14 Pro, Blue Backpack',
                ),
                validator: (value) => Validators.required(value, fieldName: 'Title'),
              ),
              const SizedBox(height: 16),
              CategoryPicker(
                selectedCategory: _selectedCategory,
                onCategorySelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
              const SizedBox(height: 16),
              LocationPicker(
                selectedLocation: _selectedLocation,
                onLocationSelected: (location) {
                  setState(() {
                    _selectedLocation = location;
                  });
                },
              ),
              const SizedBox(height: 16),
              _PhotoPickerGrid(
                photos: _selectedPhotos,
                onAddPhoto: _pickPhoto,
                onRemovePhoto: _removePhoto,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Found Date',
                          filled: true,
                        ),
                        child: Text(
                          _foundDate != null
                              ? _foundDate!.toFormattedDate()
                              : 'Select date',
                          style: TextStyle(
                            color: _foundDate != null
                                ? null
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Found Time',
                          filled: true,
                        ),
                        child: Text(
                          _foundTime != null
                              ? _foundTime!.format(context)
                              : 'Select time',
                          style: TextStyle(
                            color: _foundTime != null
                                ? null
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_foundDate == null || _foundTime == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    'Please select both date and time',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the item, its condition, and any identifying features',
                ),
                maxLines: 5,
                validator: (value) => Validators.required(value, fieldName: 'Description'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Report Found Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerGrid extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onAddPhoto;
  final void Function(int index) onRemovePhoto;

  const _PhotoPickerGrid({
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[
      for (var i = 0; i < photos.length; i++)
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(photos[i].path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.surface.withOpacity(0.9),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => onRemovePhoto(i),
                ),
              ),
            ),
          ],
        ),
      if (photos.length < 3)
        InkWell(
          onTap: onAddPhoto,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add photo',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Min 1, max 3',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: items,
        ),
      ],
    );
  }
}

