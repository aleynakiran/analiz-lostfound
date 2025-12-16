import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_lost_found/core/widgets/status_badge.dart';
import 'package:campus_lost_found/core/utils/date_time_x.dart';
import 'package:campus_lost_found/core/constants/categories.dart';
import 'package:campus_lost_found/features/found_items/presentation/widgets/photo_carousel.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/features/claims/domain/claim_request.dart';
import 'package:campus_lost_found/core/domain/audit_log.dart';
import 'package:campus_lost_found/providers/providers.dart';
import 'package:campus_lost_found/core/domain/app_user.dart';

class FoundItemDetailsPage extends ConsumerWidget {
  final String itemId;

  const FoundItemDetailsPage({
    super.key,
    required this.itemId,
  });

  void _showClaimBottomSheet(BuildContext context, WidgetRef ref, FoundItem item) {
    // item is guaranteed to be non-null here
    final nameController = TextEditingController();
    final studentNoController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Submit Claim Request',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your full name',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: studentNoController,
                  decoration: const InputDecoration(
                    labelText: 'Student Number (Optional)',
                    hintText: 'STU-2023-001',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Notes',
                    hintText: 'Describe how you can verify this is yours (serial number, stickers, etc.)',
                  ),
                  maxLines: 4,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Verification notes are required' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final currentUserAsync = ref.read(currentUserProvider);
                      final user = currentUserAsync.value;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'You need to be signed in to submit a claim'),
                          ),
                        );
                        return;
                      }

                      final claimsNotifier =
                          ref.read(claimsStateProvider.notifier);
                      final auditRepo = ref.read(auditLogRepositoryProvider);

                      claimsNotifier.addClaim(
                        itemId: item.id,
                        requesterUid: user.uid,
                        requesterName: nameController.text,
                        requesterStudentNo: studentNoController.text.isEmpty
                            ? null
                            : studentNoController.text,
                        notes: notesController.text,
                      );

                      auditRepo.addLog(
                        actorId: user.uid,
                        actionType: ActionType.claimSubmitted,
                        entityType: EntityType.claimRequest,
                        entityId: item.id,
                        details: {'itemId': item.id},
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Claim request submitted successfully'),
                        ),
                      );
                      context.pop();
                    }
                  },
                  child: const Text('Submit Claim'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _markDelivered(BuildContext context, WidgetRef ref, FoundItem item) {
    // item is guaranteed to be non-null here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: const Text('This will mark the item as delivered and complete the claim process.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final currentUserAsync = ref.read(currentUserProvider);
              final user = currentUserAsync.value;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You need to be signed in to mark delivery'),
                  ),
                );
                return;
              }

              final itemsNotifier =
                  ref.read(foundItemsStateProvider.notifier);
              final auditRepo = ref.read(auditLogRepositoryProvider);

              itemsNotifier.updateItemStatus(
                item.id,
                ItemStatus.delivered,
                deliveredAt: DateTime.now(),
              );

              auditRepo.addLog(
                actorId: user.uid,
                actionType: ActionType.itemDelivered,
                entityType: EntityType.foundItem,
                entityId: item.id,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item marked as delivered'),
                ),
              );
              context.pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(foundItemsProvider);
    FoundItem? item;
    try {
      item = items.firstWhere((i) => i.id == itemId);
    } catch (e) {
      item = null;
    }
    final currentUserAsync = ref.watch(currentUserProvider);
    final user = currentUserAsync.value;
    final allClaims = ref.watch(claimsProvider);
    final claims = allClaims.where((c) => c.itemId == itemId).toList();

    // Stream of photos from Firestore subcollection
    final photosAsync = ref.watch(itemPhotosProvider(itemId));

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item Details')),
        body: const Center(child: Text('Item not found')),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final isOwner = item.createdByOfficerId == user.uid;

    final canClaim = !isOwner &&
        item.status == ItemStatus.inStorage &&
        user.role == UserRole.student;

    final canApprove =
        user.role == UserRole.officer || user.role == UserRole.admin;

    final hasPendingClaims =
        claims.any((c) => c.status == ClaimStatus.pending);

    final canMarkDelivered = item.status == ItemStatus.pendingClaim &&
        canApprove &&
        claims.any((c) => c.status == ClaimStatus.approved);

    // Only non-owners can start chat.
    final canMessage =
        !isOwner && item.status != ItemStatus.delivered;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(item.title),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                photosAsync.when(
                  data: (photos) =>
                      PhotoCarousel(photos: photos, category: item!.category),
                  loading: () =>
                      PhotoCarousel(photos: const [], category: item!.category),
                  error: (_, __) =>
                      PhotoCarousel(photos: const [], category: item!.category),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          StatusBadge(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: '${ItemCategories.icons[item.category]} ${item.category}',
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Found Location',
                        value: item.foundLocation,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Found Date',
                        value: item.foundAt.toFormattedDateTime(),
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.tag_outlined,
                        label: 'Item ID',
                        value: item.id,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (hasPendingClaims) ...[
                        const SizedBox(height: 24),
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This item has pending claim requests',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (canClaim)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showClaimBottomSheet(context, ref, item!),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Claim This Item'),
                          ),
                        ),
                      if (canMessage)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.push('/item/${item!.id}/chat'),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Chat'),
                          ),
                        ),
                      if (isOwner) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/item/${item!.id}/edit'),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Item'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
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
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed != true) return;

                              final photosRepo =
                                  ref.read(itemPhotosRepositoryProvider);
                              final itemsRepo =
                                  ref.read(foundItemsRepositoryProvider);

                              try {
                                await photosRepo
                                    .deleteAllPhotosForItem(item!.id);
                                await itemsRepo.deleteItem(item!.id);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Item and photos deleted')),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Delete failed: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete Item',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                      if (canMarkDelivered)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _markDelivered(context, ref, item!),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Mark as Delivered'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

