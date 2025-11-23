// lib/models/warehouse.dart
class Warehouse {
  final int warehouseId;
  final String name;
  final String? address;
  final String? description;

  Warehouse({
    required this.warehouseId,
    required this.name,
    this.address,
    this.description,
  });

  factory Warehouse.fromJson(Map<String, dynamic> j) {
    return Warehouse(
      warehouseId: int.tryParse(j['WarehouseID'].toString()) ?? 0,
      name: j['Name'] ?? '',
      address: j['Address'],
      description: j['Description'],
    );
  }
}
