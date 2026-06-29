import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/request_service.dart';
import 'package:permission_system/app_fonts.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String selectedReason = 'Sick';
  final TextEditingController otherController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  int totalDays = 0;
  bool _isSubmitting = false;
  final RequestService _requestService = RequestService();

  @override
  void initState() {
    super.initState();
    _checkUserDepartment();
  }

  Future<void> _checkUserDepartment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .get();
        if (doc.docs.isNotEmpty) {
          final data = doc.docs.first.data() as Map<String, dynamic>;
          print('👤 Staff department: ${data['department']}');
          print('👤 Staff roleId: ${data['roleId']}');
        }
      } catch (e) {
        print('❌ Error checking user: $e');
      }
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    return DateFormat('dd MMM yyyy').format(date);
  }

  void calculateDays() {
    if (startDate != null && endDate != null) {
      setState(() {
        totalDays = 1;
      });
    }
  }

  Future<void> pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
        endDate = picked;
        totalDays = 1;
      });
    }
  }

  Future<void> pickEndDate() async {
    _showError('Request can only be for 1 day');
  }

  void pickFile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("File upload feature coming soon")),
    );
  }

  void pickImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Image upload feature coming soon")),
    );
  }

  Future<void> _submitRequest() async {
    if (startDate == null) {
      _showError('Please select a start date');
      return;
    }
    if (endDate == null) {
      _showError('Please select an end date');
      return;
    }
    if (totalDays <= 0) {
      _showError('Invalid date range');
      return;
    }

    if (totalDays > 1) {
      _showError('Request can only be for 1 day');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final finalReason = selectedReason == 'Other' 
          ? otherController.text.trim() 
          : selectedReason;
      
      if (selectedReason == 'Other' && finalReason.isEmpty) {
        _showError('Please specify a reason');
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final result = await _requestService.submitRequestWithAutoApprove(
        startDate: formatDate(startDate),
        endDate: formatDate(endDate),
        totalDays: totalDays,
        reason: selectedReason,
        otherReason: otherController.text.trim(),
        fileUrl: null,
        imageUrl: null,
      );

      if (mounted) {
        final status = result['status'];
        final message = result['message'];
        
        if (status == 'approved') {
          _showSuccess(message ?? 'Request automatically approved!');
        } else if (message?.contains('contact') == true) {
          _showWarning(message ?? 'You must contact your manager directly');
        } else {
          _showWarning(message ?? 'Request is pending manager approval');
        }
        
        setState(() {
          startDate = null;
          endDate = null;
          totalDays = 0;
          selectedReason = 'Sick';
          otherController.clear();
          _isSubmitting = false;
        });
      }
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code} - ${e.message}');
      if (mounted) {
        if (e.code == 'permission-denied') {
          _showError('You do not have permission to submit requests. Please contact Admin');
        } else {
          _showError('System error: ${e.message}');
        }
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      print('❌ Submit error: $e');
      if (mounted) {
        _showError('Error: ${e.toString().replaceFirst('Exception: ', '')}');
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: AppFonts.md),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: AppFonts.md),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: AppFonts.md),
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF1A3B68);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Leave Request",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: AppFonts.md,
          ),
        ),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Date",
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Start Date",
                      style: TextStyle(fontSize: AppFonts.md),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: pickStartDate,
                      child: _box(formatDate(startDate)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            "Total Days: 1 day",
                            style: TextStyle(
                              fontSize: AppFonts.md,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Document Reference (Optional)",
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              "File",
                              style: TextStyle(fontSize: AppFonts.md),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickImage,
                            icon: const Icon(Icons.image),
                            label: Text(
                              "Image",
                              style: TextStyle(fontSize: AppFonts.md),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reason for Leave",
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRadio("Sick"),
                    _buildRadio("Personal issue"),
                    _buildRadio("Vacation"),
                    _buildRadio("Emergency"),
                    _buildRadio("Other"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: otherController,
                      enabled: selectedReason == "Other",
                      style: TextStyle(fontSize: AppFonts.md),
                      decoration: InputDecoration(
                        hintText: "Please specify other reason",
                        hintStyle: TextStyle(fontSize: AppFonts.md),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: selectedReason == "Other" 
                            ? Colors.white 
                            : Colors.grey.shade50,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Submit Request",
                            style: TextStyle(fontSize: AppFonts.md),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(
            text == "Select Date" ? Icons.calendar_today : Icons.check_circle,
            size: 18,
            color: text == "Select Date" ? Colors.grey : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: AppFonts.md,
              color: text == "Select Date" ? Colors.grey : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(String title) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedReason = title;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: title,
              groupValue: selectedReason,
              onChanged: (value) {
                setState(() {
                  selectedReason = value!;
                });
              },
              activeColor: const Color(0xFF1A3B68),
            ),
            Text(
              title,
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ],
        ),
      ),
    );
  }
}