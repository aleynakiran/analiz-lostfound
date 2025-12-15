import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/core/utils/id_generator.dart';

/// Firestore-backed repository for found items.
class FoundItemsRepository {
  final FirebaseFirestore _firestore;

  FoundItemsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('found_items');

  /// Real-time stream of all found items ordered by createdAt desc.
  Stream<List<FoundItem>> watchAllItems() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        final statusString =
            (data['status'] as String? ?? 'IN_STORAGE').toUpperCase();
        final ItemStatus status;
        switch (statusString) {
          case 'PENDING_CLAIM':
            status = ItemStatus.pendingClaim;
            break;
          case 'DELIVERED':
            status = ItemStatus.delivered;
            break;
          default:
            status = ItemStatus.inStorage;
        }

        final foundAt =
            (data['foundAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final deliveredAt =
            (data['deliveredAt'] as Timestamp?)?.toDate();

        return FoundItem(
          id: doc.id,
          title: data['title'] as String? ?? '',
          category: data['category'] as String? ?? 'Other',
          description: data['description'] as String? ?? '',
          foundLocation: data['location'] as String? ?? '',
          foundAt: foundAt,
          status: status,
          // Photos are loaded via subcollection repository
          photos: const [],
          qrValue: data['qrValue'] as String? ??
              IdGenerator.generateQrValue(doc.id),
          createdByOfficerId: data['createdByOfficerId'] as String? ?? '',
          deliveredAt: deliveredAt,
        );
      }).toList();
    });
  }

  /// One-time fetch of a single item.
  Future<FoundItem?> getItemById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;

    final statusString =
        (data['status'] as String? ?? 'IN_STORAGE').toUpperCase();
    final ItemStatus status;
    switch (statusString) {
      case 'PENDING_CLAIM':
        status = ItemStatus.pendingClaim;
        break;
      case 'DELIVERED':
        status = ItemStatus.delivered;
        break;
      default:
        status = ItemStatus.inStorage;
    }

    final foundAt =
        (data['foundAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final deliveredAt =
        (data['deliveredAt'] as Timestamp?)?.toDate();

    return FoundItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      description: data['description'] as String? ?? '',
      foundLocation: data['location'] as String? ?? '',
      foundAt: foundAt,
      status: status,
      photos: const [],
      qrValue:
          data['qrValue'] as String? ?? IdGenerator.generateQrValue(doc.id),
      createdByOfficerId: data['createdByOfficerId'] as String? ?? '',
      deliveredAt: deliveredAt,
    );
  }

  /// Create a new found item document.
  Future<FoundItem> addItem({
    required String title,
    required String category,
    required String description,
    required String foundLocation,
    required DateTime foundAt,
    required String createdByOfficerId,
    List<String>? photoPaths,
  }) async {
    final docRef = _collection.doc();
    final qrValue = IdGenerator.generateQrValue(docRef.id);

    await docRef.set({
      'title': title,
      'description': description,
      'category': category,
      'location': foundLocation,
      'status': 'IN_STORAGE',
      'createdAt': FieldValue.serverTimestamp(),
      'createdByOfficerId': createdByOfficerId,
      'foundAt': Timestamp.fromDate(foundAt),
      'foundAtRaw': foundAt.toIso8601String(),
      'coverPhotoUrl': null,
      'qrValue': qrValue,
    });

    return FoundItem(
      id: docRef.id,
      title: title,
      category: category,
      description: description,
      foundLocation: foundLocation,
      foundAt: foundAt,
      status: ItemStatus.inStorage,
      photos: const [],
      qrValue: qrValue,
      createdByOfficerId: createdByOfficerId,
    );
  }

  /// Update item status (inStorage / pendingClaim / delivered).
  Future<void> updateItemStatus(
    String id,
    ItemStatus status, {
    DateTime? deliveredAt,
  }) async {
    String statusString;
    switch (status) {
      case ItemStatus.pendingClaim:
        statusString = 'PENDING_CLAIM';
        break;
      case ItemStatus.delivered:
        statusString = 'DELIVERED';
        break;
      case ItemStatus.inStorage:
      default:
        statusString = 'IN_STORAGE';
    }

    final update = <String, dynamic>{
      'status': statusString,
    };

    if (deliveredAt != null) {
      update['deliveredAt'] = Timestamp.fromDate(deliveredAt);
    }

    await _collection.doc(id).update(update);
  }

  /// Utility to clear all found items (for demo reset).
  Future<void> reset() async {
    final snapshot = await _collection.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}

