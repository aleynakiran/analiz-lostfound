import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_lost_found/core/data/user_repository.dart';
import 'package:campus_lost_found/core/data/audit_log_repository.dart';
import 'package:campus_lost_found/features/found_items/data/found_items_repository.dart';
import 'package:campus_lost_found/features/claims/data/claims_repository.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/features/claims/domain/claim_request.dart';
import 'package:campus_lost_found/core/domain/app_user.dart';
import 'package:campus_lost_found/core/domain/item_photo.dart';
import 'package:campus_lost_found/features/found_items/data/item_photos_repository.dart';
import 'package:campus_lost_found/features/chat/data/chat_repository.dart';
import 'package:campus_lost_found/features/chat/domain/chat_message.dart';
import 'package:campus_lost_found/features/auth/data/firebase_auth_service.dart';

// Repositories (singletons)
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final foundItemsRepositoryProvider = Provider<FoundItemsRepository>((ref) {
  return FoundItemsRepository();
});

final claimsRepositoryProvider = Provider<ClaimsRepository>((ref) {
  return ClaimsRepository();
});

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository();
});

final itemPhotosRepositoryProvider = Provider<ItemPhotosRepository>((ref) {
  return ItemPhotosRepository();
});

/// Firebase Auth service provider to access auth backend from UI.
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// State providers for reactivity
final currentUserProvider = StateNotifierProvider<UserNotifier, AppUser>((ref) {
  return UserNotifier(ref.read(userRepositoryProvider));
});

final foundItemsStateProvider =
    StateNotifierProvider<FoundItemsNotifier, List<FoundItem>>((ref) {
  return FoundItemsNotifier(ref.read(foundItemsRepositoryProvider));
});

final claimsStateProvider =
    StateNotifierProvider<ClaimsNotifier, List<ClaimRequest>>((ref) {
  return ClaimsNotifier(ref.read(claimsRepositoryProvider));
});

// Convenience providers
final foundItemsProvider = Provider((ref) {
  return ref.watch(foundItemsStateProvider);
});

final claimsProvider = Provider((ref) {
  return ref.watch(claimsStateProvider);
});

final pendingClaimsProvider = Provider((ref) {
  return ref
      .watch(claimsProvider)
      .where((c) => c.status == ClaimStatus.pending)
      .toList();
});

/// Stream of photos for a found item, from Firestore subcollection.
final itemPhotosProvider =
    StreamProvider.family<List<ItemPhoto>, String>((ref, itemId) {
  final repo = ref.read(itemPhotosRepositoryProvider);
  return repo.watchPhotos(itemId);
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, itemId) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.watchMessages(itemId);
});

// Notifiers
class UserNotifier extends StateNotifier<AppUser> {
  final UserRepository _repository;

  UserNotifier(this._repository) : super(_repository.getCurrentUser());

  void setUser(AppUser user) {
    _repository.setCurrentUser(user);
    state = _repository.getCurrentUser();
  }

  void updateRole(UserRole role) {
    _repository.updateUserRole(role);
    state = _repository.getCurrentUser();
  }
}

class FoundItemsNotifier extends StateNotifier<List<FoundItem>> {
  final FoundItemsRepository _repository;
  StreamSubscription<List<FoundItem>>? _subscription;

  FoundItemsNotifier(this._repository) : super(const []) {
    _subscription = _repository.watchAllItems().listen((items) {
      state = items;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<FoundItem> addItem({
    required String title,
    required String category,
    required String description,
    required String foundLocation,
    required DateTime foundAt,
    required String createdByOfficerId,
    List<String>? photoPaths,
  }) {
    return _repository.addItem(
      title: title,
      category: category,
      description: description,
      foundLocation: foundLocation,
      foundAt: foundAt,
      createdByOfficerId: createdByOfficerId,
      photoPaths: photoPaths,
    );
  }

  Future<void> updateItemStatus(
    String id,
    ItemStatus status, {
    DateTime? deliveredAt,
  }) {
    return _repository.updateItemStatus(id, status, deliveredAt: deliveredAt);
  }

  Future<void> reset() async {
    await _repository.reset();
  }
}

class ClaimsNotifier extends StateNotifier<List<ClaimRequest>> {
  final ClaimsRepository _repository;

  ClaimsNotifier(this._repository) : super(_repository.getAllClaims()) {
    _refresh();
  }

  void _refresh() {
    state = _repository.getAllClaims();
  }

  void addClaim({
    required String itemId,
    required String requesterName,
    String? requesterStudentNo,
    required String notes,
  }) {
    _repository.addClaim(
      itemId: itemId,
      requesterName: requesterName,
      requesterStudentNo: requesterStudentNo,
      notes: notes,
    );
    _refresh();
  }

  void updateClaimStatus(
      String id, ClaimStatus status, String decidedByOfficerId) {
    _repository.updateClaimStatus(id, status, decidedByOfficerId);
    _refresh();
  }

  void reset() {
    _repository.reset();
    _refresh();
  }
}


