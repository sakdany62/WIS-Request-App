// lib/screens/admin/telegram_config_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/telegram_config_service.dart';
import '../../services/telegram_service.dart';
import '../../utils/responsive.dart';
import '../../app_fonts.dart';

class TelegramConfigScreen extends StatefulWidget {
  const TelegramConfigScreen({super.key});

  @override
  State<TelegramConfigScreen> createState() => _TelegramConfigScreenState();
}

class _TelegramConfigScreenState extends State<TelegramConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupChatIdController = TextEditingController();
  final _managerChatIdController = TextEditingController();
  final _adminChatIdController = TextEditingController();
  final _botTokenController = TextEditingController();

  // សម្រាប់ Additional Chat IDs
  final _newChatIdController = TextEditingController();
  final _newChatTypeController = TextEditingController();
  List<Map<String, String>> _additionalChatIds = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAddingChat = false;
  String? _statusMessage;
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _groupChatIdController.dispose();
    _managerChatIdController.dispose();
    _adminChatIdController.dispose();
    _botTokenController.dispose();
    _newChatIdController.dispose();
    _newChatTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    setState(() => _isLoading = true);
    try {
      final configs = await TelegramConfigService.getTelegramConfigs();
      _groupChatIdController.text = configs['groupChatId'] ?? '';
      _managerChatIdController.text = configs['managerChatId'] ?? '';
      _adminChatIdController.text = configs['adminChatId'] ?? '';
      _botTokenController.text = configs['botToken'] ?? '';

      // ដក Additional Chat IDs
      final additionalJson = configs['additionalChatIds'] ?? '[]';
      try {
        final List<dynamic> decoded = jsonDecode(additionalJson);
        _additionalChatIds = decoded
            .map((item) => {
                  'chatId': item['chatId']?.toString() ?? '',
                  'type': item['type']?.toString() ?? 'Other',
                })
            .toList();
      } catch (e) {
        _additionalChatIds = [];
      }
    } catch (e) {
      _showStatus('Error loading configs: $e', Colors.red);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfigs() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // បំប្លែង Additional Chat IDs ទៅជា JSON
      final additionalJson = jsonEncode(_additionalChatIds);

      final success = await TelegramConfigService.updateTelegramConfigs(
        groupChatId: _groupChatIdController.text.trim(),
        managerChatId: _managerChatIdController.text.trim(),
        adminChatId: _adminChatIdController.text.trim(),
        botToken: _botTokenController.text.trim(),
        additionalChatIds: additionalJson,
      );

      if (success) {
        _showStatus(' Configurations saved successfully!', Colors.green);
      } else {
        _showStatus('❌ Failed to save configurations', Colors.red);
      }
    } catch (e) {
      _showStatus('❌ Error: $e', Colors.red);
    }
    setState(() => _isSaving = false);
  }

  Future<void> _addNewChatId() async {
    final chatId = _newChatIdController.text.trim();
    final chatType = _newChatTypeController.text.trim();

    if (chatId.isEmpty) {
      _showStatus('⚠️ Please enter a Chat ID', Colors.orange);
      return;
    }

    // ពិនិត្យមើលថា Chat ID មានរួចហើយ
    final exists = _additionalChatIds.any((item) => item['chatId'] == chatId);
    if (exists) {
      _showStatus('⚠️ Chat ID already exists', Colors.orange);
      return;
    }

    setState(() {
      _additionalChatIds.add({
        'chatId': chatId,
        'type': chatType.isNotEmpty ? chatType : 'Other',
      });
      _newChatIdController.clear();
      _newChatTypeController.clear();
      _isAddingChat = false;
    });

    _showStatus(' Chat ID added successfully', Colors.green);
  }

  void _removeChatId(int index) {
    setState(() {
      _additionalChatIds.removeAt(index);
    });
    _showStatus(' Chat ID removed', Colors.green);
  }

  Future<void> _testBot() async {
    setState(() => _isSaving = true);
    try {
      final isWorking = await TelegramService.checkBotStatus();
      if (isWorking) {
        final sent = await TelegramService.sendTestMessage();
        if (sent) {
          _showStatus(' Bot is working! Test message sent successfully.', Colors.green);
        } else {
          _showStatus(' Bot is working but failed to send test message.', Colors.orange);
        }
      } else {
        _showStatus('❌ Bot is not working. Please check your Bot Token.', Colors.red);
      }
    } catch (e) {
      _showStatus('❌ Error testing bot: $e', Colors.red);
    }
    setState(() => _isSaving = false);
  }

  void _showStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _statusMessage = null;
          _statusColor = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Configuration'),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadConfigs,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(spacing * 2),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header

                    SizedBox(height: spacing * 2),

                    // Bot Token
                    _buildTextField(
                      controller: _botTokenController,
                      label: 'Bot Token',
                      hint: 'Enter your Telegram Bot Token',
                      icon: Icons.vpn_key,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bot Token is required';
                        }
                        if (!value.contains(':')) {
                          return 'Invalid Bot Token format';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: spacing * 1.5),

                    // Group Chat ID
                    _buildTextField(
                      controller: _groupChatIdController,
                      label: 'Group Chat ID',
                      hint: 'Enter Group Chat ID (e.g., -1003899446883)',
                      icon: Icons.group,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Group Chat ID is required';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: spacing * 1.5),

                    // Manager Chat ID
                    _buildTextField(
                      controller: _managerChatIdController,
                      label: 'Manager Chat ID',
                      hint: 'Enter Manager Chat ID (e.g., 1273488926)',
                      icon: Icons.person,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Manager Chat ID is required';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: spacing * 1.5),

                    // Admin Chat ID
                    _buildTextField(
                      controller: _adminChatIdController,
                      label: 'Admin Chat ID',
                      hint: 'Enter Admin Chat ID (e.g., 1273488926)',
                      icon: Icons.admin_panel_settings,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Admin Chat ID is required';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: spacing * 2),

                    // ===== ADDITIONAL CHAT IDs SECTION =====
                    Container(
                      padding: EdgeInsets.all(spacing * 1.5),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Colors.purple[700],
                                size: 24,
                              ),
                              SizedBox(width: spacing / 2),
                              Text(
                                'Additional Chat IDs',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize : fontSize + 2,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                              const Spacer(),
                              if (_additionalChatIds.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: spacing / 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_additionalChatIds.length}',
                                    style: TextStyle(
                                      fontSize: isMobile ? fontSize * 0.8 : fontSize,
                                      color: Colors.purple[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          SizedBox(height: spacing),

                          // បញ្ជី Chat IDs ដែលបានបន្ថែម
                          if (_additionalChatIds.isNotEmpty)
                            ..._additionalChatIds.asMap().entries.map((entry) {
                              final index = entry.key;
                              final chat = entry.value;
                              return Container(
                                margin: EdgeInsets.only(bottom: spacing / 2),
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: spacing / 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: spacing / 1.5,
                                        vertical: spacing / 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        chat['type'] ?? 'Other',
                                        style: TextStyle(
                                          fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.75,
                                          color: Colors.purple[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: spacing / 2),
                                    Expanded(
                                      child: Text(
                                        chat['chatId'] ?? '',
                                        style: TextStyle(
                                          fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: Colors.red.shade400,
                                        size: 18,
                                      ),
                                      onPressed: () => _removeChatId(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          // ទម្រង់បន្ថែម Chat ID
                          if (_isAddingChat)
                            Container(
                              padding: EdgeInsets.all(spacing),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _newChatIdController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter Chat ID',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: spacing,
                                        vertical: isMobile ? 8 : 12,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: isMobile ? fontSize : fontSize + 1,
                                    ),
                                  ),
                                  SizedBox(height: spacing / 2),
                                  TextFormField(
                                    controller: _newChatTypeController,
                                    decoration: InputDecoration(
                                      hintText: 'Type (e.g., Manager, Team, HR)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: spacing,
                                        vertical: isMobile ? 8 : 12,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: isMobile ? fontSize : fontSize + 1,
                                    ),
                                  ),
                                  SizedBox(height: spacing / 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: isMobile ? 36 : 40,
                                          child: ElevatedButton(
                                            onPressed: _addNewChatId,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Add',
                                              style: TextStyle(
                                                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: spacing / 2),
                                      Expanded(
                                        child: SizedBox(
                                          height: isMobile ? 36 : 40,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              setState(() {
                                                _isAddingChat = false;
                                                _newChatIdController.clear();
                                                _newChatTypeController.clear();
                                              });
                                            },
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          if (!_isAddingChat)
                            SizedBox(
                              width: double.infinity,
                              height: isMobile ? 40 : 44,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isAddingChat = true;
                                  });
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(
                                  'Add New Chat ID',
                                  style: TextStyle(
                                    fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.purple,
                                  side: BorderSide(
                                    color: Colors.purple.withValues(alpha: 0.3),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: spacing * 2),

                    // Status Message
                    if (_statusMessage != null)
                      Container(
                        padding: EdgeInsets.all(spacing),
                        decoration: BoxDecoration(
                          color: _statusColor?.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _statusColor ?? Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _statusColor == Colors.green
                                  ? Icons.check_circle
                                  : _statusColor == Colors.orange
                                      ? Icons.warning
                                      : Icons.error,
                              color: _statusColor,
                            ),
                            SizedBox(width: spacing),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: isMobile ? fontSize * 0.9 : fontSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: spacing * 2),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: isMobile ? 44 : 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _testBot,
                              icon: _isSaving
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow),
                              label: Text(_isSaving ? 'Testing...' : 'Test Bot'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: SizedBox(
                            height: isMobile ? 44 : 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveConfigs,
                              icon: _isSaving
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_isSaving ? 'Saving...' : 'Save Configs'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: spacing * 2),

                    // Info Card
                    Container(
                      padding: EdgeInsets.all(spacing * 1.5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ' How to get IDs:',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize : fontSize + 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: spacing / 2),
                          Text(
                            '1. For Personal Chat:\n'
                            '   - Open Telegram\n'
                            '   - Search @userinfobot\n'
                            '   - Click Start, bot will give your Chat ID\n\n'
                            '2. For Group Chat:\n'
                            '   - Open Telegram\n'
                            '   - Search @userinfobot\n'
                            '   - Choose Button Group\n'
                            '   - Choose Your Group, @userinfobot will give your group ID\n',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.85 : fontSize,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: spacing * 2),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isMobile,
    required double fontSize,
    required double spacing,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? fontSize * 0.85 : fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: spacing / 2),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: spacing,
              vertical: isMobile ? 12 : 16,
            ),
          ),
          style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 1),
          validator: validator,
        ),
      ],
    );
  }
}
