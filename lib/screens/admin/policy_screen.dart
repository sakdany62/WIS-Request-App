// lib/screens/admin/policy_screen.dart
import 'package:flutter/material.dart';
import '../../services/policy_service.dart';
import '../../models/policy_model.dart';
import '../../utils/responsive.dart';

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
      
      _autoApproveFirstCountController.text = _currentPolicy!.autoApproveFirstCount.toString();
      _autoApproveSecondCountController.text = _currentPolicy!.autoApproveSecondCount.toString();
      _firstRequestMessageController.text = _currentPolicy!.firstRequestMessage;
      _secondRequestMessageController.text = _currentPolicy!.secondRequestMessage;
      _thirdRequestMessageController.text = _currentPolicy!.thirdRequestMessage;
      
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
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Allowed Reason',
          style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 2),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            hintText: 'Enter reason',
            hintStyle: TextStyle(fontSize: fontSize),
            border: const OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isMobile ? 10 : 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF173B69),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Add',
              style: TextStyle(fontSize: fontSize),
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

  // ✅ Helper method to build bordered card
  Widget _buildBorderedCard({
    required Widget child,
    double? elevation,
  }) {
    return Card(
      elevation: elevation ?? 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ប្រើ Responsive
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final EdgeInsets padding = Responsive.padding(context);
    final double buttonHeight = Responsive.buttonHeight(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leave Policies',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            SizedBox(
              width: isMobile ? 20 : 24,
              height: isMobile ? 20 : 24,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: padding,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ General Settings Card with Border
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'General Settings',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(fontSize: fontSize),
                              decoration: InputDecoration(
                                labelText: 'Policy Name',
                                labelStyle: TextStyle(fontSize: fontSize),
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: isMobile ? 10 : 14,
                                ),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            SizedBox(height: spacing * 1.5),
                            TextFormField(
                              controller: _descriptionController,
                              style: TextStyle(fontSize: fontSize),
                              decoration: InputDecoration(
                                labelText: 'Description',
                                labelStyle: TextStyle(fontSize: fontSize),
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: isMobile ? 10 : 14,
                                ),
                              ),
                              maxLines: isMobile ? 2 : 3,
                            ),
                            SizedBox(height: spacing * 1.5),
                            SwitchListTile(
                              title: Text(
                                'Active Policy',
                                style: TextStyle(fontSize: fontSize),
                              ),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                              activeColor: Colors.green,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 2),
                    
                    // ✅ Leave Limits Card with Border
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave Limits',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            TextFormField(
                              controller: _maxDaysPerRequestController,
                              style: TextStyle(fontSize: fontSize),
                              decoration: InputDecoration(
                                labelText: 'Max Days Per Request',
                                labelStyle: TextStyle(fontSize: fontSize),
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: isMobile ? 10 : 14,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            SizedBox(height: spacing * 1.5),
                            TextFormField(
                              controller: _maxDaysPerYearController,
                              style: TextStyle(fontSize: fontSize),
                              decoration: InputDecoration(
                                labelText: 'Max Days Per Year',
                                labelStyle: TextStyle(fontSize: fontSize),
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: isMobile ? 10 : 14,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 2),
                    
                    // ✅ Advance Notice Card with Border
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advance Notice',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            TextFormField(
                              controller: _minDaysAdvanceController,
                              style: TextStyle(fontSize: fontSize),
                              decoration: InputDecoration(
                                labelText: 'Minimum Days in Advance',
                                labelStyle: TextStyle(fontSize: fontSize),
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: isMobile ? 10 : 14,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            SizedBox(height: spacing * 1.5),
                            TextFormField(
                              controller: _maxDaysAdvanceController,
                              style: TextStyle(fontSize: fontSize),
                              decoration: InputDecoration(
                                labelText: 'Maximum Days in Advance',
                                labelStyle: TextStyle(fontSize: fontSize),
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: isMobile ? 10 : 14,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 2),
                    
                    // ✅ Allowed Reasons Card with Border
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allowed Reasons',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            Wrap(
                              spacing: spacing,
                              runSpacing: spacing / 2,
                              children: _allowedReasons.map((reason) {
                                return Chip(
                                  label: Text(
                                    reason,
                                    style: TextStyle(fontSize: fontSize * 0.9),
                                  ),
                                  onDeleted: () => _removeReason(reason),
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: isMobile ? 16 : 18,
                                  ),
                                  visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
                                );
                              }).toList(),
                            ),
                            SizedBox(height: spacing),
                            ElevatedButton.icon(
                              onPressed: _showAddReasonDialog,
                              icon: Icon(Icons.add, size: isMobile ? 18 : 20),
                              label: Text(
                                'Add Reason',
                                style: TextStyle(fontSize: fontSize),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF173B69),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing * 2,
                                  vertical: isMobile ? 8 : 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 2),
                    
                    // ✅ Auto Approve Settings Card with Border
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Approve Settings',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            SwitchListTile(
                              title: Text(
                                'Enable Auto Approve',
                                style: TextStyle(fontSize: fontSize),
                              ),
                              subtitle: Text(
                                'Automatically approve requests based on count',
                                style: TextStyle(fontSize: fontSize * 0.85),
                              ),
                              value: _autoApprove,
                              onChanged: (value) {
                                setState(() {
                                  _autoApprove = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (_autoApprove) ...[
                              SizedBox(height: spacing),
                              TextFormField(
                                controller: _autoApproveFirstCountController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'First Auto Approve Count',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: spacing),
                              TextFormField(
                                controller: _autoApproveSecondCountController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'Second Auto Approve Count',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: spacing * 1.5),
                              TextFormField(
                                controller: _firstRequestMessageController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'First Request Message',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                maxLines: 2,
                              ),
                              SizedBox(height: spacing),
                              TextFormField(
                                controller: _secondRequestMessageController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'Second Request Message',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                maxLines: 2,
                              ),
                              SizedBox(height: spacing),
                              TextFormField(
                                controller: _thirdRequestMessageController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'Third Request Message',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 2),
                    
                    // ✅ Additional Settings Card with Border
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional Settings',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            SwitchListTile(
                              title: Text(
                                'Require Document',
                                style: TextStyle(fontSize: fontSize),
                              ),
                              subtitle: Text(
                                'Staff must attach document for leave request',
                                style: TextStyle(fontSize: fontSize * 0.85),
                              ),
                              value: _requireDocument,
                              onChanged: (value) {
                                setState(() {
                                  _requireDocument = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // ✅ Notification Settings Card with Border
                    SizedBox(height: spacing * 2),
                    _buildBorderedCard(
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Settings',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF173B69),
                              ),
                            ),
                            const Divider(height: 20),
                            SizedBox(height: spacing),
                            SwitchListTile(
                              title: Text(
                                'Enable Notifications',
                                style: TextStyle(fontSize: fontSize),
                              ),
                              subtitle: Text(
                                'Turn on/off all notifications for this policy',
                                style: TextStyle(fontSize: fontSize * 0.85),
                              ),
                              value: _enableNotifications,
                              onChanged: (value) {
                                setState(() {
                                  _enableNotifications = value;
                                });
                              },
                              activeColor: Colors.blue,
                              contentPadding: EdgeInsets.zero,
                            ),
                            
                            const Divider(),
                            
                            if (_enableNotifications) ...[
                              SizedBox(height: spacing),
                              TextFormField(
                                controller: _notificationTitleController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'Notification Title',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.title, size: isMobile ? 20 : 24),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                validator: (value) => 
                                    value?.isEmpty ?? true ? 'Title is required' : null,
                              ),
                              SizedBox(height: spacing * 1.5),
                              TextFormField(
                                controller: _notificationBodyController,
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  labelText: 'Notification Body',
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.message, size: isMobile ? 20 : 24),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                maxLines: 2,
                                validator: (value) => 
                                    value?.isEmpty ?? true ? 'Body is required' : null,
                              ),
                              SizedBox(height: spacing * 2),
                              
                              Text(
                                'When to send notifications:',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: spacing / 2),
                              SwitchListTile(
                                title: Text(
                                  'On Request Submit',
                                  style: TextStyle(fontSize: fontSize * 0.9),
                                ),
                                subtitle: Text(
                                  'Notify when a request is submitted',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                ),
                                value: _notifyOnRequestSubmit,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnRequestSubmit = value;
                                  });
                                },
                                activeColor: Colors.blue,
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                title: Text(
                                  'On Status Change',
                                  style: TextStyle(fontSize: fontSize * 0.9),
                                ),
                                subtitle: Text(
                                  'Notify when request status changes',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                ),
                                value: _notifyOnStatusChange,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnStatusChange = value;
                                  });
                                },
                                activeColor: Colors.blue,
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                title: Text(
                                  'On Approval',
                                  style: TextStyle(fontSize: fontSize * 0.9),
                                ),
                                subtitle: Text(
                                  'Notify when request is approved',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                ),
                                value: _notifyOnApproval,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnApproval = value;
                                  });
                                },
                                activeColor: Colors.green,
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                title: Text(
                                  'On Rejection',
                                  style: TextStyle(fontSize: fontSize * 0.9),
                                ),
                                subtitle: Text(
                                  'Notify when request is rejected',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                ),
                                value: _notifyOnRejection,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyOnRejection = value;
                                  });
                                },
                                activeColor: Colors.red,
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                title: Text(
                                  'Notify Admin on New Request',
                                  style: TextStyle(fontSize: fontSize * 0.9),
                                ),
                                subtitle: Text(
                                  'Send notification to admin when new request is submitted',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                ),
                                value: _notifyAdminOnNewRequest,
                                onChanged: (value) {
                                  setState(() {
                                    _notifyAdminOnNewRequest = value;
                                  });
                                },
                                activeColor: Colors.orange,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 3),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
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
                            ? SizedBox(
                                height: isMobile ? 20 : 24,
                                width: isMobile ? 20 : 24,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save Policy',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize : fontSize + 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    SizedBox(height: isMobile ? 60 : 80),
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