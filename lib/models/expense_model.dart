import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum SplitType { equally, unequally, shares }

class ExpenseModel extends Equatable {
  final String id;
  final String groupId;
  final String payerId;
  final double amount;
  final String description;
  final DateTime date;
  final String? receiptUrl;
  final SplitType splitType;
  final Map<String, double> splitDetails;

  const ExpenseModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.description,
    required this.date,
    this.receiptUrl,
    required this.splitType,
    required this.splitDetails,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final splitTypeString = json['splitType'] as String? ?? 'equally';
    SplitType splitType;
    try {
      splitType = SplitType.values.firstWhere(
        (e) => e.toString().split('.').last == splitTypeString,
      );
    } catch (_) {
      splitType = SplitType.equally;
    }
    
    final splitDetailsMap = json['splitDetails'] as Map<String, dynamic>? ?? {};
    final splitDetails = splitDetailsMap.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
    
    return ExpenseModel(
      id: id ?? json['id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      payerId: json['payerId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      date: json['date'] is Timestamp
          ? (json['date'] as Timestamp).toDate()
          : json['date'] is String
              ? DateTime.parse(json['date'] as String)
              : DateTime.now(),
      receiptUrl: json['receiptUrl'] as String?,
      splitType: splitType,
      splitDetails: splitDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'payerId': payerId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'receiptUrl': receiptUrl,
      'splitType': splitType.toString().split('.').last,
      'splitDetails': splitDetails,
    };
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        payerId,
        amount,
        description,
        date,
        receiptUrl,
        splitType,
        splitDetails,
      ];
}
