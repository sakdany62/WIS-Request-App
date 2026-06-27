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

  // Notification Controllers
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();
  bool _enableNotifications = true;
  bool _notifyOnRequestSubmit = true;
  bool _notifyOnStatusChange = true;
  bool _notifyOnApproval = true;
  bool _notifyOnRejection = true;
  bool _notifyAdminOnNewRequest = true;

  // Auto Approve Controllers
  final _autoApproveFirstCountController = TextEditingController();
  final _autoApproveSecondCountController = TextEditingController();
  final _firstRequestMessageController = TextEditingController();
  final _secondRequestMessageController = TextEditingController();
  final _thirdRequestMessageController = TextEditingController();

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
      
      // Auto Approve Settings
      _autoApproveFirstCountController.text = _currentPolicy!.autoApproveFirstCount.toString();
      _autoApproveSecondCountController.text = _currentPolicy!.autoApproveSecondCount.toString();
      _firstRequestMessageController.text = _currentPolicy!.firstRequestMessage;
      _secondRequestMessageController.text = _currentPolicy!.secondRequestMessage;
      _thirdRequestMessageController.text = _currentPolicy!.thirdRequestMessage;
      
      // Notification Settings
      _enableNotifications = _currentPolicy!.enableNotifications;
      _notificationTitleController.text = _currentPolicy!.notificationTitle;
      _notificationBodyController.text = _currentPolicy!.notificationBody;
      _notifyOnRequestSubmit = _currentPolicy!.notifyOnRequestSubmit;
      _notifyOnStatusChange = _currentPolicy!.notifyOnStatusChange;
      _notifyOnApproval = _currentPolicy!.notifyOnApproval;
      _notifyOnRejection = _currentPolicy!.notifyOnRejection;
      _notifyAdminOnNewRequest = _currentPolicy!.notifyAdminOnNewRequest;
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
      autoApproveFirstCount: int.tryParse(_autoApproveFirstCountController.text) ?? 1,
      autoApproveSecondCount: int.tryParse(_autoApproveSecondCountController.text) ?? 2,
      firstRequestMessage: _firstRequestMessageController.text,
      secondRequestMessage: _secondRequestMessageController.text,
      thirdRequestMessage: _thirdRequestMessageController.text,
      enableNotifications: _enableNotifications,
      notificationTitle: _notificationTitleController.text,
      notificationBody: _notificationBodyController.text,
      notifyOnRequestSubmit: _notifyOnRequestSubmit,
      notifyOnStatusChange: _notifyOnStatusChange,
      notifyOnApproval: _notifyOnApproval,
      notifyOnRejection: _notifyOnRejection,
      notifyAdminOnNewRequest: _notifyAdminOnNewRequest,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
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
                    // General Settings Card
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
                    
                    // Leave Limits Card
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
                    
                    // Advance Notice Card
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
                    
                    // Allowed Reasons Card
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
                    
                    // Auto Approve Settings Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto Approve Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Enable Auto Approve'),
                              subtitle: const Text('Automatically approve requests based on count'),
                              value: _autoApprove,
                              onChanged: (value) {
                                setState(() {
                                  _autoApprove = value;
                                });
                              },
                            ),
                            if (_autoApprove) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _autoApproveFirstCountController,
                                      decoration: const InputDecoration(
                                        labelText: 'First Auto Approve Count',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _autoApproveSecondCountController,
                                      decoration: const InputDecoration(
                                        labelText: 'Second Auto Approve Count',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _firstRequestMessageController,
                                decoration: const InputDecoration(
                                  labelText: 'First Request Message',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _secondRequestMessageController,
                                decoration: const InputDecoration(
                                  labelText: 'Second Request Message',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _thirdRequestMessageController,
                                decoration: const InputDecoration(
                                  labelText: 'Third Request Message',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Additional Settings Card
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
                          ],
                        ),
                      ),
                    ),
                    
                    // Notification Settings Card
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notification Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Enable Notifications'),
                              subtitle: const Text('Turn on/off all notifications for this policy'),
                              value: _enableNotifications,
                              onChanged: (value) {
                                setState(() {
                                  _enableNotifications = value;
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            
                            const Divider(),
                            
                            if (_enableNotifications) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _notificationTitleController,
                                decoration: const InputDecoration(
                                  labelText: 'Notification Title',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.title),
                                ),
                                validator: (value) => 
                                    value?.isEmpty ?? true ? 'Title is required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notificationBodyController,
                                decoration: const InputDecoration(
                                  labelText: 'Notification Body',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.message),
                                ),
                                maxLines: 2,
                                validator: (value) => 
                                    value?.isEmpty ?? true ? 'Body is required' : null,
                              ),
                              const SizedBox(height: 16),
                              
                              const Text(
                                'When to send notifications:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SwitchListTile(
                                title: const Text('On Request Submit'),
                                subtitle: const Text('Notify when a request is submitted'),
                                value: _notifyOnRequestSubmit,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnRequestSubmit = value;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                              SwitchListTile(
                                title: const Text('On Status Change'),
                                subtitle: const Text('Notify when request status changes'),
                                value: _notifyOnStatusChange,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnStatusChange = value;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                              SwitchListTile(
                                title: const Text('On Approval'),
                                subtitle: const Text('Notify when request is approved'),
                                value: _notifyOnApproval,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnApproval = value;
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                              SwitchListTile(
                                title: const Text('On Rejection'),
                                subtitle: const Text('Notify when request is rejected'),
                                value: _notifyOnRejection,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnRejection = value;
                                  });
                                },
                                activeColor: Colors.red,
                              ),
                              SwitchListTile(
                                title: const Text('Notify Admin on New Request'),
                                subtitle: const Text('Send notification to admin when new request is submitted'),
                                value: _notifyAdminOnNewRequest,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyAdminOnNewRequest = value;
                                  });
                                },
                                activeColor: Colors.orange,
                              ),
                            ],
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
    _autoApproveFirstCountController.dispose();
    _autoApproveSecondCountController.dispose();
    _firstRequestMessageController.dispose();
    _secondRequestMessageController.dispose();
    _thirdRequestMessageController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    super.dispose();
  }
}