import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:split/models/expense_model.dart';
import 'package:split/models/group_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/models/meal_model.dart';
import 'package:split/services/settlement_service.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  Future<void> generateExpenseReport({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required Map<String, UserModel> userMap,
    List<MealModel>? meals,
  }) async {
    final pdf = pw.Document();
    final settlementService = SettlementService();
    final settlements = settlementService.calculateSettlements(
      expenses,
      userMap.values.toList(),
    );
    final summary = settlementService.getSettlementSummary(
      settlements,
      userMap,
    );

    final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    group.name,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (group.description != null)
                    pw.Text(
                      group.description!,
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on: ${dateFormat.format(DateTime.now())} at ${timeFormat.format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Header(
              level: 1,
              child: pw.Text('Summary'),
            ),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(expenses.length.toString(), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'BDT ${totalAmount.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Group Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        group.type.toString().split('.').last.replaceAll('Mess', ' Mess'),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Settlement Section
            if (summary.isNotEmpty) ...[
              pw.Header(
                level: 1,
                child: pw.Text('Settlements'),
              ),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Settlement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...summary.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.debtorName} owes ${item.creditorName}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'BDT ${item.amount.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // Expense Details Section
            pw.Header(
              level: 1,
              child: pw.Text('Expense Details'),
            ),
            ...expenses.asMap().entries.map((entry) {
              final expense = entry.value;
              final index = entry.key + 1;
              final payer = userMap[expense.payerId];
              final payerName = payer?.displayName ?? 'Unknown';

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Expense #$index: ${expense.description.isEmpty ? "No description" : expense.description}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'BDT ${expense.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Paid by: $payerName • ${dateFormat.format(expense.date)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Split Type: ${expense.splitType.toString().split('.').last}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Split Details:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    ...expense.splitDetails.entries.map((splitEntry) {
                      final user = userMap[splitEntry.key];
                      final userName = user?.displayName ?? 'Unknown';
                      final amount = splitEntry.value;
                      final percentage = (amount / expense.amount * 100).toStringAsFixed(1);

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, top: 2),
                        child: pw.Text(
                          '• $userName: BDT ${amount.toStringAsFixed(2)} ($percentage%)',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

            // Meal Calculations Section (if meals exist)
            if (meals != null && meals.isNotEmpty && group.type == GroupType.bachelorMess) ...[
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Header(
                level: 1,
                child: pw.Text('Meal Calculations'),
              ),
              pw.SizedBox(height: 12),
              ..._buildSimpleMealSection(
                meals: meals,
                expenses: expenses,
                userMap: userMap,
                dateFormat: dateFormat,
              ),
            ],

            // Footer
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'This report was generated by Splitter App',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    // Show print/share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<String> savePdfToFile({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required Map<String, UserModel> userMap,
  }) async {
    final pdf = pw.Document();
    final settlementService = SettlementService();
    final settlements = settlementService.calculateSettlements(
      expenses,
      userMap.values.toList(),
    );
    final summary = settlementService.getSettlementSummary(
      settlements,
      userMap,
    );

    final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    group.name,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (group.description != null)
                    pw.Text(
                      group.description!,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on: ${dateFormat.format(DateTime.now())} at ${timeFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Summary')),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(expenses.length.toString(), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'BDT ${totalAmount.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Header(level: 1, child: pw.Text('Settlements')),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Settlement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...summary.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.debtorName} owes ${item.creditorName}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'BDT ${item.amount.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Expense Details')),
            ...expenses.map((expense) {
              final payer = userMap[expense.payerId];
              final payerName = payer?.displayName ?? 'Unknown';

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            expense.description.isEmpty ? "No description" : expense.description,
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Text(
                          'BDT ${expense.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Paid by: $payerName • ${dateFormat.format(expense.date)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Split Details:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ...expense.splitDetails.entries.map((splitEntry) {
                      final user = userMap[splitEntry.key];
                      final userName = user?.displayName ?? 'Unknown';
                      final amount = splitEntry.value;
                      final percentage = (amount / expense.amount * 100).toStringAsFixed(1);

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, top: 2),
                        child: pw.Text(
                          '• $userName: BDT ${amount.toStringAsFixed(2)} ($percentage%)',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${group.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }


  List<pw.Widget> _buildSimpleMealSection({
    required List<MealModel> meals,
    required List<ExpenseModel> expenses,
    required Map<String, UserModel> userMap,
    required DateFormat dateFormat,
  }) {
    // Group meals by month
    final mealsByMonth = <String, List<MealModel>>{};
    final expensesByMonth = <String, List<ExpenseModel>>{};

    for (final meal in meals) {
      final monthKey = DateFormat('MMMM yyyy').format(meal.date);
      mealsByMonth.putIfAbsent(monthKey, () => []).add(meal);
    }

    for (final expense in expenses) {
      final monthKey = DateFormat('MMMM yyyy').format(expense.date);
      expensesByMonth.putIfAbsent(monthKey, () => []).add(expense);
    }

    final sections = <pw.Widget>[];

    // Process each month
    for (final monthKey in mealsByMonth.keys.toList()..sort()) {
      final monthMeals = mealsByMonth[monthKey]!;
      final monthExpenses = expensesByMonth[monthKey] ?? [];

      // Calculate basic statistics
      final totalInvestment = monthExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final totalMeals = monthMeals.length;
      final costPerMeal = totalMeals > 0 ? totalInvestment / totalMeals : 0.0;

      // Count meals per user
      final mealCounts = <String, int>{};
      for (final meal in monthMeals) {
        mealCounts[meal.userId] = (mealCounts[meal.userId] ?? 0) + 1;
      }

      // Calculate payments per user
      final userPayments = <String, double>{};
      for (final expense in monthExpenses) {
        userPayments[expense.payerId] = (userPayments[expense.payerId] ?? 0.0) + expense.amount;
      }

      sections.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Month: $monthKey',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
            pw.SizedBox(height: 8),
            // Summary Table
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Investment', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('BDT ${totalInvestment.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Meals', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(totalMeals.toString(), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Cost Per Meal', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('BDT ${costPerMeal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            // Member Meal Counts
            pw.Text(
              'Meal Counts by Member',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Member', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Meals', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Deposit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...mealCounts.entries.map((entry) {
                  final userId = entry.key;
                  final mealCount = entry.value;
                  final user = userMap[userId];
                  final userName = user?.displayName ?? 'Unknown';
                  final deposit = userPayments[userId] ?? 0.0;
                  final cost = mealCount * costPerMeal;
                  final balance = deposit - cost;
                  final balanceText = balance > 0.01
                      ? '+BDT ${balance.toStringAsFixed(2)}'
                      : balance < -0.01
                          ? '-BDT ${(-balance).toStringAsFixed(2)}'
                          : 'BDT 0.00';

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(userName, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('$mealCount', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('BDT ${deposit.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(balanceText, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        ),
      );
    }

    return sections;
  }
}

