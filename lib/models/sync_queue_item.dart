import 'package:intl/intl.dart';

class SyncQueueItem {
  final String id;
  final String operation; // 'create', 'update', 'delete'
  final String entryId; // ID do entry no Firestore (null se create)
  final Map<String, dynamic> data;
  final DateTime createdAt;
  String status; // 'pending', 'syncing', 'synced', 'failed'

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.entryId,
    required this.data,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation,
    'entryId': entryId,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
    id: json['id'],
    operation: json['operation'],
    entryId: json['entryId'],
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['createdAt']),
    status: json['status'] ?? 'pending',
  );
}
