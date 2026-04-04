import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum GroupType { trip, bachelorMess }

class GroupModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final GroupType type;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final bool isClosed;
  final DateTime? closedAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.isClosed = false,
    this.closedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final typeString = json['type'] as String? ?? 'trip';
    GroupType type;
    try {
      type = GroupType.values.firstWhere(
        (e) => e.toString().split('.').last == typeString,
      );
    } catch (_) {
      type = GroupType.trip;
    }
    
    return GroupModel(
      id: id ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      type: type,
      memberIds: (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      isClosed: json['isClosed'] as bool? ?? false,
      closedAt: json['closedAt'] is Timestamp
          ? (json['closedAt'] as Timestamp).toDate()
          : json['closedAt'] is String
              ? DateTime.parse(json['closedAt'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isClosed': isClosed,
      if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props =>
      [id, name, description, type, memberIds, createdBy, createdAt, isClosed, closedAt];
}
