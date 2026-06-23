// lib/screens/admin/policy_screen.dart
import 'package:flutter/material.dart';
import '../../services/policy_service.dart';
import '../../models/policy_model.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final PolicyService _policyService = PolicyService();
  bool _isLoading = true;
  bool _isSaving = false;
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
      _isActive = _currentPolicy!.isActive;
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
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
      applicableTo: 'all',
      isActive: _isActive,
      createdAt: _currentPolicy?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    try {
      await _policyService.savePolicy(policy);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Policy saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPolicy();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showAddReasonDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Allowed Reason'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Add'),
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
        title: const Text('Leave Policies'),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        // ============ បន្ថែម Back Button ============
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // ត្រឡប់ទៅ Admin Settings
          },
        ),
        actions: [
          if (_isSaving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
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
                            const Text(
                              'General Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Policy Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Active Policy'),
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
                            const Text(
                              'Leave Limits',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _maxDaysPerRequestController,
                              decoration: const InputDecoration(
                                labelText: 'Max Days Per Request',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _maxDaysPerYearController,
                              decoration: const InputDecoration(
                                labelText: 'Max Days Per Year',
                                border: OutlineInputBorder(),
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
                            const Text(
                              'Advance Notice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _minDaysAdvanceController,
                              decoration: const InputDecoration(
                                labelText: 'Minimum Days in Advance',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _maxDaysAdvanceController,
                              decoration: const InputDecoration(
                                labelText: 'Maximum Days in Advance',
                                border: OutlineInputBorder(),
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
                            const Text(
                              'Allowed Reasons',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: _allowedReasons.map((reason) {
                                return Chip(
                                  label: Text(reason),
                                  onDeleted: () => _removeReason(reason),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
  onPressed: _showAddReasonDialog,
  icon: const Icon(Icons.add),
  label: const Text('Add Reason'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF173B69),
    foregroundColor: Colors.white, 
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            const Text(
                              'Additional Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Require Document'),
                              subtitle: const Text('Staff must attach document for leave request'),
                              value: _requireDocument,
                              onChanged: (value) {
                                setState(() {
                                  _requireDocument = value;
                                });
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Auto Approve'),
                              subtitle: const Text('Automatically approve requests that meet all criteria'),
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
    onPressed: _isSaving ? null : _savePolicy,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2C5F8A), 
      foregroundColor: Colors.white, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 2,
    ),
    child: _isSaving
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Text(
            'Save Policy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
  ),
)
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