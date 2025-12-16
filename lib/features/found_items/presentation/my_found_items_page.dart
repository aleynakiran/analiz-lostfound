import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/features/found_items/presentation/widgets/found_item_card.dart';
import 'package:campus_lost_found/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyFoundItemsPage extends ConsumerWidget {
  const MyFoundItemsPage({super.key});

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    FoundItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'This will delete the item and all associated photos. '
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final photosRepo = ref.read(itemPhotosRepositoryProvider);
    final itemsRepo = ref.read(foundItemsRepositoryProvider);

    try {
      await photosRepo.deleteAllPhotosForItem(item.id);
      await itemsRepo.deleteItem(item.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item and photos deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Text('Sign in to view your items.'),
            ),
          );
        }

        final myItemsAsync = ref.watch(myFoundItemsProvider(user.uid));

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Found Items'),
          ),
          body: myItemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('You have not reported any items yet.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FoundItemCard(
                        item: item,
                        onTap: () => context.push('/item/${item.id}'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                context.push('/item/${item.id}/edit'),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () =>
                                _confirmAndDelete(context, ref, item),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(
              child: Text('Failed to load your items: $e'),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Failed to load user: $e')),
      ),
    );
  }
}

