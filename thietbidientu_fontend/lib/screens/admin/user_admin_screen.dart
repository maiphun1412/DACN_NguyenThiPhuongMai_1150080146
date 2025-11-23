import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/admin_user.dart';
import 'package:thietbidientu_fontend/services/admin_user_service.dart';

class UserAdminScreen extends StatefulWidget {
  const UserAdminScreen({super.key});

  @override
  State<UserAdminScreen> createState() => _UserAdminScreenState();
}

class _UserAdminScreenState extends State<UserAdminScreen> {
  bool _loading = true;
  String? _error;
  List<AdminUser> _users = [];
  String _keyword = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final data = await AdminUserService.fetchUsers(keyword: _keyword);
      setState(() {
        _users = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.redAccent;
      case 'shipper':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'shipper':
        return 'Shipper';
      default:
        return 'Khách hàng';
    }
  }

  Future<void> _showUserDetail(AdminUser user) async {
    final detail = await AdminUserService.fetchDetail(user.userId);

    String selectedRole = detail.role.toLowerCase();
    bool isActive = detail.isActive;
    final reasonCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final maxWidth = MediaQuery.of(context).size.width * 0.9;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Thông tin người dùng',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: avatar + tên + email
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: detail.isActive
                            ? Colors.green.shade600
                            : Colors.grey.shade500,
                        child: Text(
                          (detail.fullName.isNotEmpty
                                  ? detail.fullName[0]
                                  : detail.email[0])
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.fullName.isNotEmpty
                                  ? detail.fullName
                                  : detail.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail.email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            if (detail.phone != null &&
                                detail.phone!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'SĐT: ${detail.phone}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Chips: role + trạng thái
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(_roleLabel(detail.role)),
                        avatar: const Icon(Icons.verified_user, size: 18),
                        backgroundColor:
                            _roleColor(detail.role).withOpacity(0.08),
                        labelStyle: TextStyle(
                          color: _roleColor(detail.role),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Chip(
                        label: Text(isActive ? 'Đang hoạt động' : 'Đã khóa'),
                        avatar: Icon(
                          isActive ? Icons.check_circle : Icons.block,
                          size: 18,
                          color: isActive
                              ? Colors.green.shade700
                              : Colors.redAccent,
                        ),
                        backgroundColor:
                            isActive ? Colors.green.shade50 : Colors.red.shade50,
                        labelStyle: TextStyle(
                          color: isActive
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Phân quyền
                  const Text(
                    'Phân quyền',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.security, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Quyền hiện tại:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'customer',
                              child: Text('Khách hàng'),
                            ),
                            DropdownMenuItem(
                              value: 'shipper',
                              child: Text('Shipper'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              selectedRole = v;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đang chọn: ${_roleLabel(selectedRole)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _roleColor(selectedRole),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Trạng thái đăng nhập
                  const Text(
                    'Trạng thái tài khoản',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isActive ? 'Cho phép đăng nhập' : 'Đã khóa đăng nhập',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.green.shade800
                              : Colors.red.shade700,
                        ),
                      ),
                      subtitle: Text(
                        isActive
                            ? 'Tắt công tắc để khóa tài khoản này.'
                            : 'Bật lại để cho phép người dùng đăng nhập.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      value: isActive,
                      onChanged: (v) {
                        setState(() {
                          isActive = v;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    isActive
                        ? 'Lý do khóa tài khoản (tuỳ chọn, khi bạn tắt tài khoản)'
                        : 'Lý do khóa tài khoản (nên nhập)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'Ví dụ: Spam đơn hàng, sử dụng thông tin giả, gây rối...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (detail.banReason != null &&
                      detail.banReason!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Lý do lần trước: ${detail.banReason}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Lưu thay đổi'),
              onPressed: () async {
                try {
                  // Cập nhật role nếu thay đổi
                  if (selectedRole != detail.role.toLowerCase()) {
                    await AdminUserService.updateRole(
                      userId: detail.userId,
                      role: selectedRole,
                    );
                  }

                  // Cập nhật trạng thái hoạt động, lý do là optional
                  if (isActive != detail.isActive) {
                    final reasonText = reasonCtrl.text.trim();
                    await AdminUserService.updateBanStatus(
                      userId: detail.userId,
                      isActive: isActive,
                      reason: isActive
                          ? null
                          : (reasonText.isEmpty ? null : reasonText),
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadUsers();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi cập nhật: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng')),
      body: Column(
        children: [
          // Ô tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo email, tên, số điện thoại...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _keyword = '';
                          });
                          _loadUsers();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                setState(() {
                  _keyword = value;
                });
                _loadUsers();
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _users.isEmpty
                        ? const Center(child: Text('Không có người dùng nào'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final u = _users[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: u.isActive
                                        ? Colors.green.shade600
                                        : Colors.grey.shade500,
                                    child: Text(
                                      u.fullName.isNotEmpty
                                          ? u.fullName[0].toUpperCase()
                                          : u.email[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    u.fullName.isNotEmpty
                                        ? u.fullName
                                        : u.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.email,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              u.isActive
                                                  ? Icons.check_circle
                                                  : Icons.block,
                                              size: 14,
                                              color: u.isActive
                                                  ? Colors.green
                                                  : Colors.redAccent,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              u.isActive
                                                  ? 'Hoạt động'
                                                  : 'Đã khóa',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: u.isActive
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _roleColor(u.role)
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _roleLabel(u.role),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _roleColor(u.role),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onTap: () => _showUserDetail(u),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
