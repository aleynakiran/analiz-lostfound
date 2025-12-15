import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_lost_found/core/widgets/empty_state.dart';
import 'package:campus_lost_found/core/domain/app_user.dart';
import 'package:campus_lost_found/features/claims/presentation/widgets/claim_card.dart';
import 'package:campus_lost_found/features/claims/presentation/widgets/claim_decision_dialog.dart';
import 'package:campus_lost_found/features/claims/domain/claim_request.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/core/domain/audit_log.dart';
import 'package:campus_lost_found/providers/providers.dart';

class ClaimsPage extends ConsumerStatefulWidget {
  const ClaimsPage({super.key});

  @override
  ConsumerState<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends ConsumerState<ClaimsPage> {
  ClaimStatus _selectedFilter = ClaimStatus.pending;

  void _handleClaimDecision(
    ClaimRequest claim,
    ClaimStatus newStatus,
  ) {
    final user = ref.read(currentUserProvider);
    final claimsNotifier = ref.read(claimsStateProvider.notifier);
    final itemsNotifier = ref.read(foundItemsStateProvider.notifier);
    final auditRepo = ref.read(auditLogRepositoryProvider);

    claimsNotifier.updateClaimStatus(claim.id, newStatus, user.id);

    if (newStatus == ClaimStatus.approved) {
      final allItems = ref.read(foundItemsProvider);
      try {
        final item = allItems.firstWhere((i) => i.id == claim.itemId);
        if (item.status == ItemStatus.inStorage) {
          itemsNotifier.updateItemStatus(claim.itemId, ItemStatus.pendingClaim);
        }
      } catch (e) {
        // Item not found, skip status update
      }
    }

    auditRepo.addLog(
      actorId: user.id,
      actionType: newStatus == ClaimStatus.approved
          ? ActionType.claimApproved
          : ActionType.claimRejected,
      entityType: EntityType.claimRequest,
      entityId: claim.id,
      details: {'itemId': claim.itemId},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == ClaimStatus.approved
              ? 'Claim approved'
              : 'Claim rejected',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(currentUserProvider);
    final claims = ref.watch(claimsProvider);
    final canReview = user.role == UserRole.officer || user.role == UserRole.admin;

    // Filter claims based on role and selected status
    Iterable<ClaimRequest> filtered = claims.where(
      (c) => c.status == _selectedFilter,
    );

    if (!canReview) {
      filtered = filtered.where((c) => c.requesterName == user.name);
    }

    final displayClaims = filtered.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claims'),
        actions: [
          if (canReview)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${claims.where((c) => c.status == ClaimStatus.pending).length} pending',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusFilterChip(
                  label: 'Pending',
                  selected: _selectedFilter == ClaimStatus.pending,
                  onSelected: () {
                    setState(() {
                      _selectedFilter = ClaimStatus.pending;
                    });
                  },
                ),
                _StatusFilterChip(
                  label: 'Approved',
                  selected: _selectedFilter == ClaimStatus.approved,
                  onSelected: () {
                    setState(() {
                      _selectedFilter = ClaimStatus.approved;
                    });
                  },
                ),
                _StatusFilterChip(
                  label: 'Rejected',
                  selected: _selectedFilter == ClaimStatus.rejected,
                  onSelected: () {
                    setState(() {
                      _selectedFilter = ClaimStatus.rejected;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: displayClaims.isEmpty
                ? EmptyState(
              icon: '📋',
              title: canReview ? 'No claims to review' : 'No claims submitted',
              subtitle: canReview
                  ? 'Claim requests from students will appear here'
                  : 'You haven\'t submitted any claim requests yet',
            )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayClaims.length,
                    itemBuilder: (context, index) {
                      final claim = displayClaims[index];
                      return ClaimCard(
                        claim: claim,
                        onTap: canReview && claim.status == ClaimStatus.pending
                            ? () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ClaimDecisionDialog(
                                    claim: claim,
                                    onApprove: () => _handleClaimDecision(
                                      claim,
                                      ClaimStatus.approved,
                                    ),
                                    onReject: () => _handleClaimDecision(
                                      claim,
                                      ClaimStatus.rejected,
                                    ),
                                  ),
                                );
                              }
                            : () {
                                // View item details
                                context.push('/item/${claim.itemId}');
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      shape: StadiumBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

