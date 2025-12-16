import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditFoundItemPage extends ConsumerStatefulWidget {
  final String itemId;

  const EditFoundItemPage({super.key, required this.itemId});

  @override
  ConsumerState<EditFoundItemPage> createState() => _EditFoundItemPageState();
}

class _EditFoundItemPageState extends ConsumerState<EditFoundItemPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  bool _loading = true;
  FoundItem? _item;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final repo = ref.read(foundItemsRepositoryProvider);
    try {
      final item = await repo.getItemById(widget.itemId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
        if (item != null) {
          _titleController.text = item.title;
          _descriptionController.text = item.description;
          _locationController.text = item.foundLocation;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load item: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _item == null) return;

    final repo = ref.read(foundItemsRepositoryProvider);
    try {
      await repo.updateItemDetails(
        _item!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        foundLocation: _locationController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_item == null) {
      return const Scaffold(
        body: Center(child: Text('Item not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Found Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Found Location',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Location is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

