

class SyncQueueItem {
  final String id;
  final String operation; // 'create', 'update', 'delete'
  String entryId; // ID do entry no Firestore (vazio se ainda não criado)

  // The entry's stable local identity (SleepEntry.localId). Used to resolve
  // entryId at sync time when it was empty at queue time (e.g. an 'update'
  // queued for an entry whose paired 'create' hasn't synced yet).
  final String? localEntryId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  String status; // 'pending', 'syncing', 'synced', 'failed'

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.entryId,
    this.localEntryId,
    required this.data,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation,
    'entryId': entryId,
    'localEntryId': localEntryId,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
    id: json['id'],
    operation: json['operation'],
    entryId: json['entryId'],
    localEntryId: json['localEntryId'] as String?,
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['createdAt']),
    status: json['status'] ?? 'pending',
  );
}
