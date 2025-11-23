// lib/models/supplier.dart
class Supplier {
  final int supplierId;
  final String name;
  final String? email;
  final String? phone;
  final String? address;

  Supplier({
    required this.supplierId,
    required this.name,
    this.email,
    this.phone,
    this.address,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) {
    return Supplier(
      supplierId: int.tryParse(j['SupplierID'].toString()) ?? 0,
      name: j['Name'] ?? '',
      email: j['Email'],
      phone: j['Phone'],
      address: j['Address'],
    );
  }
}
