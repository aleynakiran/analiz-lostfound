import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:campus_lost_found/core/domain/item_photo.dart';

/// Repository for uploading and streaming item photos from Storage/Firestore.
class ItemPhotosRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ItemPhotosRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Real-time stream of photos for an item from subcollection:
  /// foundItems/{itemId}/photos
  Stream<List<ItemPhoto>> watchPhotos(String itemId) {
    final collection = _firestore
        .collection('foundItems')
        .doc(itemId)
        .collection('photos')
        .orderBy('createdAt', descending: false);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final url = data['url'] as String? ?? '';
        final typeString =
            (data['type'] as String? ?? 'FOUND').toUpperCase();

        final PhotoType type =
            typeString == 'HANDOVER' ? PhotoType.handover : PhotoType.found;

        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        return ItemPhoto(
          id: doc.id,
          itemId: itemId,
          type: type,
          // For backend we store the download URL in assetPath.
          assetPath: url,
          uploadedAt: createdAt,
        );
      }).toList();
    });
  }

  /// Upload a photo to Storage and create a Firestore doc under photos subcollection.
  ///
  /// Storage path: foundItems/{itemId}/photos/{photoId}.jpg
  ///
  /// TODO(UI): Call this from your "Add Photo" button after picking an image file.
  Future<ItemPhoto> uploadFoundItemPhoto({
    required String itemId,
    required File file,
  }) async {
    final photoId = const Uuid().v4();

    final storageRef = _storage
        .ref()
        .child('foundItems/$itemId/photos/$photoId.jpg');

    await storageRef.putFile(file);
    final url = await storageRef.getDownloadURL();

    final docRef = _firestore
        .collection('foundItems')
        .doc(itemId)
        .collection('photos')
        .doc(photoId);

    await docRef.set({
      'url': url,
      'type': 'FOUND',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update coverPhotoUrl on parent item.
    await _firestore.collection('foundItems').doc(itemId).update({
      'coverPhotoUrl': url,
    });

    return ItemPhoto(
      id: photoId,
      itemId: itemId,
      type: PhotoType.found,
      assetPath: url,
      uploadedAt: DateTime.now(),
    );
  }
}


