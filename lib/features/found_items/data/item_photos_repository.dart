import 'dart:io';

import 'package:campus_lost_found/core/domain/item_photo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Repository for uploading and streaming item photos from Storage/Firestore.
class ItemPhotosRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ItemPhotosRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        // Use explicit bucket URL from Firebase Console to fix object-not-found error
        // Bucket URL: gs://campus-lost-found-83347.firebasestorage.app
        // Only override if explicitly provided for testing
        _storage = storage ?? 
            FirebaseStorage.instanceFor(
              app: Firebase.app(),
              bucket: 'campus-lost-found-83347.firebasestorage.app',
            );

  /// Real-time stream of photos for an item from subcollection:
  /// found_items/{itemId}/photos
  Stream<List<ItemPhoto>> watchPhotos(String itemId) {
    final collection = _firestore
        .collection('found_items')
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
  /// Storage path: found_items/{itemId}/found/{photoId}.jpg
  Future<ItemPhoto> uploadFoundItemPhoto({
    required String itemId,
    required File file,
  }) async {
    // CRITICAL: Verify authentication before upload
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthenticated',
        message: 'User must be authenticated to upload photos',
      );
    }

    try {
      debugPrint(
          '[ItemPhotosRepository] Upload started. itemId=$itemId, path=${file.path}');
      debugPrint(
          '[ItemPhotosRepository] Current user: ${currentUser.uid}');

      // Verify file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist at path: ${file.path}');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty: ${file.path}');
      }

      debugPrint(
          '[ItemPhotosRepository] File verified. Size: $fileSize bytes');

      final photoId = const Uuid().v4();
      final storageRef = _storage
          .ref()
          .child('found_items/$itemId/found/$photoId.jpg');

      debugPrint(
          '[ItemPhotosRepository] Storage path: ${storageRef.fullPath}');
      debugPrint(
          '[ItemPhotosRepository] Storage bucket: ${_storage.bucket}');

      // CRITICAL: Explicit metadata with contentType is REQUIRED for iOS
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'itemId': itemId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      debugPrint(
          '[ItemPhotosRepository] Starting upload with metadata...');

      // Upload with explicit metadata - this is CRITICAL for iOS
      // putFile signature: putFile(File file, [SettableMetadata? metadata])
      final uploadTask = storageRef.putFile(file, metadata);

      // Monitor upload progress (optional, for debugging)
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        if (taskSnapshot.totalBytes > 0) {
          final progress = (taskSnapshot.bytesTransferred /
                  taskSnapshot.totalBytes) *
              100;
          debugPrint(
              '[ItemPhotosRepository] Upload progress: ${progress.toStringAsFixed(1)}%');
        }
      });

      // Wait for upload to complete with timeout
      final taskSnapshot = await uploadTask.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Upload timeout after 2 minutes');
        },
      );
      
      debugPrint(
          '[ItemPhotosRepository] Upload completed. bytesTransferred=${taskSnapshot.bytesTransferred}, totalBytes=${taskSnapshot.totalBytes}');

      if (taskSnapshot.bytesTransferred == 0 || taskSnapshot.totalBytes == 0) {
        throw Exception('Upload completed but no bytes were transferred');
      }

      // Get download URL with timeout and better error handling
      String url;
      try {
        url = await storageRef.getDownloadURL().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Failed to get download URL: timeout');
          },
        );
        debugPrint('[ItemPhotosRepository] Download URL obtained: $url');
        
        // Validate URL
        if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
          throw Exception('Invalid download URL format: $url');
        }
      } catch (e) {
        debugPrint('[ItemPhotosRepository] Error getting download URL: $e');
        rethrow;
      }

      if (url.isEmpty) {
        throw Exception('Download URL is empty after upload');
      }

      // Create Firestore document
      final docRef = _firestore
          .collection('found_items')
          .doc(itemId)
          .collection('photos')
          .doc(photoId);

      await docRef.set({
        'url': url,
        'type': 'found',
        'uploadedBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '[ItemPhotosRepository] Photo document created under found_items/$itemId/photos/$photoId');

      // Update coverPhotoUrl on parent item (only if not already set)
      try {
        await _firestore.collection('found_items').doc(itemId).update({
          'coverPhotoUrl': url,
        });
        debugPrint(
            '[ItemPhotosRepository] coverPhotoUrl updated on found_items/$itemId');
      } catch (e) {
        debugPrint(
            '[ItemPhotosRepository] Warning: Could not update coverPhotoUrl: $e');
        // Non-critical, continue
      }

      return ItemPhoto(
        id: photoId,
        itemId: itemId,
        type: PhotoType.found,
        assetPath: url,
        uploadedAt: DateTime.now(),
      );
    } on FirebaseException catch (e, st) {
      debugPrint(
          '[ItemPhotosRepository] FirebaseException while uploading photo:');
      debugPrint('[ItemPhotosRepository] Code: ${e.code}');
      debugPrint('[ItemPhotosRepository] Message: ${e.message}');
      debugPrint('[ItemPhotosRepository] Plugin: ${e.plugin}');
      debugPrint('[ItemPhotosRepository] Stacktrace: $st');
      debugPrint(
          '[ItemPhotosRepository] Storage bucket used: ${_storage.bucket}');
      debugPrint(
          '[ItemPhotosRepository] Current user: ${FirebaseAuth.instance.currentUser?.uid ?? "null"}');

      // Provide more specific error messages
      String userMessage = 'Photo upload failed';
      if (e.code == 'unauthenticated' || e.code == 'unauthorized') {
        userMessage = 'Authentication required. Please sign in again.';
      } else if (e.code == 'unknown') {
        userMessage =
            'Upload failed. Please check your internet connection and try again.';
      } else if (e.code == 'canceled') {
        userMessage = 'Upload was canceled.';
      }

      rethrow;
    } catch (e, st) {
      debugPrint(
          '[ItemPhotosRepository] Unknown error while uploading photo: $e');
      debugPrint('[ItemPhotosRepository] Error type: ${e.runtimeType}');
      debugPrint('[ItemPhotosRepository] Stacktrace: $st');
      rethrow;
    }
  }

  /// Delete all photos (Firestore docs + Storage objects) for a given item.
  Future<void> deleteAllPhotosForItem(String itemId) async {
    try {
      final photosSnap = await _firestore
          .collection('found_items')
          .doc(itemId)
          .collection('photos')
          .get();

      for (final doc in photosSnap.docs) {
        final photoId = doc.id;

        // Storage path follows the same pattern as upload
        final ref = _storage
            .ref()
            .child('found_items/$itemId/found/$photoId.jpg');

        try {
          await ref.delete();
          debugPrint(
              '[ItemPhotosRepository] Deleted storage object ${ref.fullPath}');
        } catch (e) {
          debugPrint(
              '[ItemPhotosRepository] Warning: Failed to delete storage object ${ref.fullPath}: $e');
        }

        try {
          await doc.reference.delete();
        } catch (e) {
          debugPrint(
              '[ItemPhotosRepository] Warning: Failed to delete photo doc ${doc.reference.path}: $e');
        }
      }
    } catch (e, st) {
      debugPrint(
          '[ItemPhotosRepository] Error while deleting all photos for item $itemId: $e');
      debugPrint('[ItemPhotosRepository] Stacktrace: $st');
      rethrow;
    }
  }
}