import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_lost_found/features/chat/domain/chat_message.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  Stream<List<ChatMessage>> watchMessages(String itemId) {
    return _chats
        .doc(itemId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          senderUid: data['senderUid'] as String? ?? '',
          text: data['text'] as String? ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });
  }

  Future<void> sendMessage({
    required String itemId,
    required String senderUid,
    required String text,
    required String finderUid,
    required String claimantUid,
  }) async {
    if (text.trim().isEmpty) return;

    final chatRef = _chats.doc(itemId);

    await chatRef.set({
      'itemId': itemId,
      'finderUid': finderUid,
      'claimantUid': claimantUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'senderUid': senderUid,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}


