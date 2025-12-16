import 'dart:async';
import 'package:campus_lost_found/core/data/audit_log_repository.dart';
import 'package:campus_lost_found/core/data/user_repository.dart';
import 'package:campus_lost_found/core/domain/app_user.dart';
import 'package:campus_lost_found/core/domain/item_photo.dart';
import 'package:campus_lost_found/features/auth/data/firebase_auth_service.dart';
import 'package:campus_lost_found/features/chat/data/chat_repository.dart';
import 'package:campus_lost_found/features/chat/domain/chat.dart';
import 'package:campus_lost_found/features/chat/domain/chat_message.dart';
import 'package:campus_lost_found/features/claims/data/claims_repository.dart';
import 'package:campus_lost_found/features/claims/domain/claim_request.dart';
import 'package:campus_lost_found/features/found_items/data/found_items_repository.dart';
import 'package:campus_lost_found/features/found_items/data/item_photos_repository.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return FirebaseAuthService(
    userRepository: ref.read(userRepositoryProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// State providers for reactivity

/// Current `AppUser` backed by Firestore users/{uid}, or `null` when signed out.
final currentUserProvider =
    StreamProvider.autoDispose<AppUser?>((ref) async* {
  final authService = ref.read(firebaseAuthServiceProvider);
  yield* authService.authStateChanges();
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
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.watchMessages(chatId);
});

/// Stream of chats (conversations) for a given user uid.
final userChatsProvider =
    StreamProvider.family<List<Chat>, String>((ref, uid) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.userChatsStream(uid);
});

/// User-specific found items (for "My Found Items" page).
final myFoundItemsProvider =
    StreamProvider.family<List<FoundItem>, String>((ref, uid) {
  final repo = ref.read(foundItemsRepositoryProvider);
  return repo.watchItemsByUser(uid);
});

// Notifiers

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

  /// Utility to clear all found items (for demo reset / debugging).
  Future<void> reset() async {
    await _repository.reset();
  }
}

class ClaimsNotifier extends StateNotifier<List<ClaimRequest>> {
  final ClaimsRepository _repository;

  StreamSubscription<List<ClaimRequest>>? _subscription;

  ClaimsNotifier(this._repository) : super(const []) {
    _subscription = _repository.watchAllClaims().listen((claims) {
      state = claims;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void addClaim({
    required String itemId,
    required String requesterUid,
    required String requesterName,
    String? requesterStudentNo,
    required String notes,
  }) {
    _repository.addClaim(
      itemId: itemId,
      requesterUid: requesterUid,
      requesterName: requesterName,
      requesterStudentNo: requesterStudentNo,
      notes: notes,
    );
  }

  void updateClaimStatus(
      String id, ClaimStatus status, String decidedByOfficerId) {
    _repository.updateClaimStatus(id, status, decidedByOfficerId);
  }

  void reset() {
    // No-op for Firestore-backed claims; keep for API compatibility.
  }
}

