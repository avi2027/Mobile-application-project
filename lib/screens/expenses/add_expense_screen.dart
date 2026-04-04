import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/group_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/auth_service.dart';
import 'package:split/services/expense_service.dart';
import 'package:split/services/group_service.dart';
import 'package:split/services/user_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;

  const AddExpenseScreen({
    required this.groupId,
    super.key,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  SplitType _splitType = SplitType.equally;
  String? _selectedPayerId;
  File? _receiptImage;
  bool _isLoading = false;
  GroupModel? _group;
  List<UserModel> _members = [];
  Map<String, double> _unequalAmounts = {};
  final Map<String, int> _shares = {};

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    final groupService = context.read<GroupService>();
    final userService = context.read<UserService>();
    final auth = context.read<AuthService>();
    
    final group = await groupService.getGroupById(widget.groupId);
    if (group == null) return;
    
    setState(() {
      _group = group;
      _selectedPayerId = auth.currentUser?.uid ?? group.memberIds.first;
    });

    // Load member details
    final members = <UserModel>[];
    final unequalAmounts = <String, double>{};
    
    for (final memberId in group.memberIds) {
      final user = await userService.getUserById(memberId);
      if (user != null) {
        members.add(user);
        unequalAmounts[memberId] = 0.0;
        _shares[memberId] = 1;
      }
    }
    
    setState(() {
      _members = members;
      _unequalAmounts = unequalAmounts;
      // Calculate equal split initially if amount is entered
      if (_amountController.text.isNotEmpty) {
        _calculateEqualSplit();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _receiptImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadReceipt() async {
    if (_receiptImage == null) return null;

    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child('receipts/${const Uuid().v4()}.jpg');
      await ref.putFile(_receiptImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      return null;
    }
  }

  void _calculateEqualSplit() {
    if (_group == null || _amountController.text.isEmpty) return;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final perPerson = amount / _group!.memberIds.length;
    
    setState(() {
      _unequalAmounts = {};
      for (final memberId in _group!.memberIds) {
        _unequalAmounts[memberId] = perPerson;
      }
    });
  }

  void _calculateSharesSplit() {
    if (_group == null || _amountController.text.isEmpty) return;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final totalShares = _shares.values.fold<int>(0, (sum, shares) => sum + shares);
    if (totalShares == 0) return;
    
    final perShare = amount / totalShares;
    
    setState(() {
      _unequalAmounts = {};
      for (final entry in _shares.entries) {
        _unequalAmounts[entry.key] = perShare * entry.value;
      }
    });
  }

  Future<void> _createExpense() async {
    if (_group == null || _amountController.text.isEmpty || _selectedPayerId == null) {
      _showError('Please fill in all required fields');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    setState(() => _isLoading = true);

    final expenseService = context.read<ExpenseService>();

    try {
      String? receiptUrl;
      if (_receiptImage != null) {
        receiptUrl = await _uploadReceipt();
      }

      Map<String, double> splitDetails;
      if (_splitType == SplitType.equally) {
        _calculateEqualSplit();
        splitDetails = Map<String, double>.from(_unequalAmounts);
      } else if (_splitType == SplitType.shares) {
        _calculateSharesSplit();
        splitDetails = Map<String, double>.from(_unequalAmounts);
      } else {
        // Unequally - use the manually entered amounts
        splitDetails = Map<String, double>.from(_unequalAmounts);
      }

      // Ensure splitDetails is not empty
      if (splitDetails.isEmpty) {
        _showError('Please enter split amounts for all members');
        setState(() => _isLoading = false);
        return;
      }

      // Validate split totals
      final total = splitDetails.values.fold<double>(0.0, (sum, val) => sum + val);
      if (total == 0) {
        _showError('Split amounts cannot be zero. Please enter valid amounts.');
        setState(() => _isLoading = false);
        return;
      }
      if ((total - amount).abs() > 0.01) {
        _showError('Split amounts (BDT ${total.toStringAsFixed(2)}) must equal the total amount (BDT ${amount.toStringAsFixed(2)})');
        setState(() => _isLoading = false);
        return;
      }

      final expense = ExpenseModel(
        id: const Uuid().v4(),
        groupId: widget.groupId,
        payerId: _selectedPayerId!,
        amount: amount,
        description: _descriptionController.text.trim(),
        date: DateTime.now(),
        receiptUrl: receiptUrl,
        splitType: _splitType,
        splitDetails: splitDetails,
      );

      await expenseService.createExpense(expense);
      debugPrint('Expense created: ${expense.id}');

      if (!mounted) return;
      context.pop();
    } catch (e) {
      debugPrint('Error creating expense: $e');
      _showError('Failed to create expense: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Expense')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense'),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                hintText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: 'BDT ',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_splitType == SplitType.equally) {
                  _calculateEqualSplit();
                } else if (_splitType == SplitType.shares) {
                  _calculateSharesSplit();
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Who Paid?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _members.length < 2
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _members.isEmpty
                          ? 'Loading members...'
                          : _members.first.displayName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : SegmentedButton<String>(
                    segments: _members
                        .map(
                          (member) => ButtonSegment<String>(
                            value: member.id,
                            label: Text(
                              member.displayName.split(' ').first,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    selected: {_selectedPayerId ?? _members.first.id},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedPayerId = selection.first);
                    },
                  ),
            const SizedBox(height: 24),
            const Text('Split Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<SplitType>(
              selected: {_splitType},
              segments: const [
                ButtonSegment<SplitType>(
                  value: SplitType.equally,
                  label: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('Equally'),
                  ),
                ),
                ButtonSegment<SplitType>(
                  value: SplitType.unequally,
                  label: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('Unequally'),
                  ),
                ),
                ButtonSegment<SplitType>(
                  value: SplitType.shares,
                  label: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('Shares'),
                  ),
                ),
              ],
              onSelectionChanged: (Set<SplitType> value) {
                setState(() {
                  _splitType = value.first;
                  if (_splitType == SplitType.equally) {
                    _calculateEqualSplit();
                  } else if (_splitType == SplitType.shares) {
                    _calculateSharesSplit();
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            if (_splitType == SplitType.unequally) ...[
              const Text('Split Amounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._members.map((member) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(member.displayName),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: TextEditingController(
                            text: (_unequalAmounts[member.id] ?? 0.0) > 0
                                ? (_unequalAmounts[member.id] ?? 0.0).toStringAsFixed(2)
                                : '',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _unequalAmounts[member.id] = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else if (_splitType == SplitType.shares) ...[
              const Text('Shares per Person', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._members.map((member) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(member.displayName),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '1',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: (_shares[member.id] ?? 1).toString(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _shares[member.id] = int.tryParse(value) ?? 1;
                              _calculateSharesSplit();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (_splitType != SplitType.unequally && _unequalAmounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Split Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._members.map((member) {
                final amount = _unequalAmounts[member.id] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(member.displayName),
                      Text('BDT ${amount.toStringAsFixed(2)}'),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: _pickImage,
              child: Row(
                children: [
                  const Icon(Icons.camera),
                  const SizedBox(width: 8),
                  Text(_receiptImage == null ? 'Add Receipt' : 'Change Receipt'),
                ],
              ),
            ),
            if (_receiptImage != null)
              Container(
                height: 200,
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_receiptImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _createExpense,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

