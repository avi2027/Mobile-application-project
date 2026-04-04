import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MealType { breakfast, lunch, dinner }

class MealModel extends Equatable {
  final String id;
  final String groupId;
  final String userId;
  final MealType mealType;
  final DateTime date;

  const MealModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.mealType,
    required this.date,
  });

  factory MealModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final mealTypeString = json['mealType'] as String? ?? 'breakfast';
    MealType mealType;
    try {
      mealType = MealType.values.firstWhere(
        (e) => e.toString().split('.').last == mealTypeString,
      );
    } catch (_) {
      mealType = MealType.breakfast;
    }

    return MealModel(
      id: id ?? json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      mealType: mealType,
      date: json['date'] is Timestamp
          ? (json['date'] as Timestamp).toDate()
          : json['date'] is String
              ? DateTime.parse(json['date'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'userId': userId,
      'mealType': mealType.toString().split('.').last,
      'date': Timestamp.fromDate(date), // Store as Firestore Timestamp for proper querying
    };
  }

  @override
  List<Object?> get props => [id, groupId, userId, mealType, date];
}

