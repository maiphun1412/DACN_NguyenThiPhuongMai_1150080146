import 'dart:convert';
import 'package:flutter/material.dart';

const _brand = Color(0xFF353839);

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _form = GlobalKey<FormState>();

  // ====== mock data (bind API thật sau) ======
  String storeName = 'Thiết Bị Điện Tử MaiTech';
  String supportEmail = 'support@maitech.vn';
  String supportPhone = '0900 123 456';

  bool acceptingOrders = true;
  bool pushNotification = true;

  String currency = 'VND'; // VND | USD
  double vat = 8;

  // SMTP
  String smtpHost = 'smtp.gmail.com';
  String smtpPort = '587';
  String smtpUser = 'maitech@gmail.com';
  String smtpPass = ''; // app password
  bool smtpTLS = true;  // STARTTLS
  bool smtpSSL = false; // SMTPS

  // ====== helpers ======
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Map<String, dynamic> _toMap() => {
        'general': {
          'storeName': storeName,
          'supportEmail': supportEmail,
          'supportPhone': supportPhone,
        },
        'ops': {
          'acceptingOrders': acceptingOrders,
          'pushNotification': pushNotification,
        },
        'finance': {
          'currency': currency,
          'vat': vat,
        },
        'smtp': {
          'host': smtpHost,
          'port': smtpPort,
          'user': smtpUser,
          'pass': smtpPass,
          'tls': smtpTLS,
          'ssl': smtpSSL,
        },
      };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();

    // TODO: gọi API PUT /admin/settings với _toMap()
    await Future.delayed(const Duration(milliseconds: 400));
    _toast('Đã lưu cài đặt ✨');
  }

  Future<void> _exportJson() async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_toMap());
    // Ở mobile, bạn có thể dùng share_plus hoặc path_provider để lưu file.
    // Tạm thời hiển thị dialog xem trước JSON.
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cấu hình (JSON)'),
        content: SingleChildScrollView(
          child: SelectableText(jsonStr, style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  Future<void> _importJson() async {
    // Demo: nhập nhanh qua dialog text (thực tế: mở file picker rồi đọc)
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dán JSON cấu hình'),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '{ "general": { "storeName": "..."} }',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Áp dụng')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final map = jsonDecode(ctrl.text) as Map<String, dynamic>;
      setState(() {
        final g = (map['general'] ?? {}) as Map? ?? {};
        storeName = (g['storeName'] ?? storeName).toString();
        supportEmail = (g['supportEmail'] ?? supportEmail).toString();
        supportPhone = (g['supportPhone'] ?? supportPhone).toString();

        final ops = (map['ops'] ?? {}) as Map? ?? {};
        acceptingOrders = (ops['acceptingOrders'] ?? acceptingOrders) == true;
        pushNotification = (ops['pushNotification'] ?? pushNotification) == true;

        final f = (map['finance'] ?? {}) as Map? ?? {};
        currency = (f['currency'] ?? currency).toString();
        vat = double.tryParse('${f['vat'] ?? vat}') ?? vat;

        final s = (map['smtp'] ?? {}) as Map? ?? {};
        smtpHost = (s['host'] ?? smtpHost).toString();
        smtpPort = (s['port'] ?? smtpPort).toString();
        smtpUser = (s['user'] ?? smtpUser).toString();
        smtpPass = (s['pass'] ?? smtpPass).toString();
        smtpTLS = (s['tls'] ?? smtpTLS) == true;
        smtpSSL = (s['ssl'] ?? smtpSSL) == true;
      });
      _toast('Đã nạp cấu hình từ JSON ✅');
    } catch (e) {
      _toast('JSON không hợp lệ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brand,
        title: const Text('Cài đặt hệ thống'),
        actions: [
          IconButton(
            tooltip: 'Tải cấu hình (JSON)',
            onPressed: _exportJson,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Nhập cấu hình (JSON)',
            onPressed: _importJson,
            icon: const Icon(Icons.upload_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: const Color(0xFFF4F6FA),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Cấu hình chung',
              child: Column(
                children: [
                  _Labeled(
                    label: 'Tên cửa hàng',
                    child: TextFormField(
                      initialValue: storeName,
                      onSaved: (v) => storeName = v!.trim(),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'Email hỗ trợ',
                    child: TextFormField(
                      initialValue: supportEmail,
                      onSaved: (v) => supportEmail = v!.trim(),
                      validator: (v) =>
                          (v != null && RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) ? null : 'Email không hợp lệ',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'Số điện thoại',
                    child: TextFormField(
                      initialValue: supportPhone,
                      onSaved: (v) => supportPhone = v!.trim(),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _Section(
              title: 'Vận hành',
              child: Column(
                children: [
                  SwitchListTile(
                    value: acceptingOrders,
                    onChanged: (v) => setState(() => acceptingOrders = v),
                    title: const Text('Nhận đơn hàng'),
                    subtitle: const Text('Tắt để tạm ngưng nhận đơn'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: pushNotification,
                    onChanged: (v) => setState(() => pushNotification = v),
                    title: const Text('Thông báo đẩy'),
                    subtitle: const Text('Gửi thông báo đến khách hàng/nhân viên'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _Section(
              title: 'Thuế & Tiền tệ',
              child: Column(
                children: [
                  _Labeled(
                    label: 'Loại tiền',
                    child: DropdownButtonFormField<String>(
                      value: currency,
                      items: const [
                        DropdownMenuItem(value: 'VND', child: Text('VND – Việt Nam Đồng')),
                        DropdownMenuItem(value: 'USD', child: Text('USD – US Dollar')),
                      ],
                      onChanged: (v) => setState(() => currency = v ?? 'VND'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'VAT (%)',
                    child: TextFormField(
                      initialValue: vat.toString(),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => vat = double.tryParse(v ?? '') ?? vat,
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d < 0 || d > 50) return '0–50';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _Section(
              title: 'Email (SMTP)',
              child: Column(
                children: [
                  _Labeled(
                    label: 'SMTP Host',
                    child: TextFormField(
                      initialValue: smtpHost,
                      onSaved: (v) => smtpHost = v!.trim(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'Port',
                    child: TextFormField(
                      initialValue: smtpPort,
                      keyboardType: TextInputType.number,
                      onSaved: (v) => smtpPort = v!.trim(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'User',
                    child: TextFormField(
                      initialValue: smtpUser,
                      onSaved: (v) => smtpUser = v!.trim(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'App Password',
                    child: TextFormField(
                      initialValue: smtpPass,
                      obscureText: true,
                      onSaved: (v) => smtpPass = v ?? '',
                    ),
                  ),
                  const Divider(height: 24),
                  CheckboxListTile(
                    value: smtpTLS,
                    onChanged: (v) => setState(() => smtpTLS = v ?? false),
                    title: const Text('STARTTLS (587)'),
                  ),
                  CheckboxListTile(
                    value: smtpSSL,
                    onChanged: (v) => setState(() => smtpSSL = v ?? false),
                    title: const Text('SSL/TLS (465)'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: gọi API test SMTP
                        _toast('Đã gửi email test (giả lập)');
                      },
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Gửi email test'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _save,
                child: const Text('Lưu cài đặt', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----- small UI helpers -----
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _brand)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
