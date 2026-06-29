import 'package:flutter/material.dart';
import '../../services/policy_service.dart';
import '../../models/policy_model.dart';
// 👇 Use the same import as other files (adjust if needed)
import 'package:permission_system/app_fonts.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final PolicyService _policyService = PolicyService();
  bool _isLoading = true;
  PolicyModel? _currentPolicy;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxDaysPerRequestController = TextEditingController();
  final _maxDaysPerYearController = TextEditingController();
  final _minDaysAdvanceController = TextEditingController();
  final _maxDaysAdvanceController = TextEditingController();
  List<String> _allowedReasons = ['Sick', 'Personal issue', 'Vacation', 'Emergency'];
  bool _requireDocument = false;
  bool _autoApprove = false;
  String _applicableTo = 'all';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() {
      _isLoading = true;
    });
    
    _currentPolicy = await _policyService.getActivePolicy();
    
    if (_currentPolicy != null) {
      _nameController.text = _currentPolicy!.name;
      _descriptionController.text = _currentPolicy!.description;
      _maxDaysPerRequestController.text = _currentPolicy!.maxDaysPerRequest.toString();
      _maxDaysPerYearController.text = _currentPolicy!.maxDaysPerYear.toString();
      _minDaysAdvanceController.text = _currentPolicy!.minDaysAdvance.toString();
      _maxDaysAdvanceController.text = _currentPolicy!.maxDaysAdvance.toString();
      _allowedReasons = _currentPolicy!.allowedReasons;
      _requireDocument = _currentPolicy!.requireDocument;
      _autoApprove = _currentPolicy!.autoApprove;
      _applicableTo = _currentPolicy!.applicableTo;
      _isActive = _currentPolicy!.isActive;
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final policy = PolicyModel(
      id: _currentPolicy?.id ?? '',
      name: _nameController.text,
      description: _descriptionController.text,
      maxDaysPerRequest: int.parse(_maxDaysPerRequestController.text),
      maxDaysPerYear: int.parse(_maxDaysPerYearController.text),
      minDaysAdvance: int.parse(_minDaysAdvanceController.text),
      maxDaysAdvance: int.parse(_maxDaysAdvanceController.text),
      allowedReasons: _allowedReasons,
      requireDocument: _requireDocument,
      autoApprove: _autoApprove,
      applicableTo: _applicableTo,
      isActive: _isActive,
      createdAt: _currentPolicy?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    try {
      await _policyService.savePolicy(policy);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Policy saved successfully',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadPolicy();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddReasonDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Allowed Reason',
          style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(fontSize: AppFonts.md),
          decoration: InputDecoration(
            hintText: 'Enter reason',
            hintStyle: TextStyle(fontSize: AppFonts.md),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _allowedReasons.add(controller.text);
                });
              }
              Navigator.pop(context);
            },
            child: Text(
              'Add',
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ),
        ],
      ),
    );
  }

  void _removeReason(String reason) {
    setState(() {
      _allowedReasons.remove(reason);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leave Policies',
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'General Settings',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                labelText: 'Policy Name',
                                labelStyle: TextStyle(fontSize: AppFonts.md),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                labelText: 'Description',
                                labelStyle: TextStyle(fontSize: AppFonts.md),
                                border: const OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: Text(
                                'Active Policy',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave Limits',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _maxDaysPerRequestController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                labelText: 'Max Days Per Request',
                                labelStyle: TextStyle(fontSize: AppFonts.md),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _maxDaysPerYearController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                labelText: 'Max Days Per Year',
                                labelStyle: TextStyle(fontSize: AppFonts.md),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advance Notice',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _minDaysAdvanceController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                labelText: 'Minimum Days in Advance',
                                labelStyle: TextStyle(fontSize: AppFonts.md),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _maxDaysAdvanceController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                labelText: 'Maximum Days in Advance',
                                labelStyle: TextStyle(fontSize: AppFonts.md),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allowed Reasons',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: _allowedReasons.map((reason) {
                                return Chip(
                                  label: Text(
                                    reason,
                                    style: TextStyle(fontSize: AppFonts.md),
                                  ),
                                  onDeleted: () => _removeReason(reason),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _showAddReasonDialog,
                              icon: const Icon(Icons.add),
                              label: Text(
                                'Add Reason',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF173B69),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional Settings',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: Text(
                                'Require Document',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              subtitle: Text(
                                'Staff must attach document for leave request',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              value: _requireDocument,
                              onChanged: (value) {
                                setState(() {
                                  _requireDocument = value;
                                });
                              },
                            ),
                            SwitchListTile(
                              title: Text(
                                'Auto Approve',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              subtitle: Text(
                                'Automatically approve requests that meet all criteria',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              value: _autoApprove,
                              onChanged: (value) {
                                setState(() {
                                  _autoApprove = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _savePolicy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF173B69),
                        ),
                        child: Text(
                          'Save Policy',
                          style: TextStyle(fontSize: AppFonts.md),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxDaysPerRequestController.dispose();
    _maxDaysPerYearController.dispose();
    _minDaysAdvanceController.dispose();
    _maxDaysAdvanceController.dispose();
    super.dispose();
  }
}