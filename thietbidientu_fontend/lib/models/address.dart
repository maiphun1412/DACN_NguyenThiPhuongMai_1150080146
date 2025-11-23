class Address {
  final int addressId;
  final String fullName;
  final String phone;
  final String line1;
  final String? ward;
  final String? district;
  final String? province;
  final bool isDefault;

  Address({
    required this.addressId,
    required this.fullName,
    required this.phone,
    required this.line1,
    this.ward,
    this.district,
    this.province,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> j) => Address(
    addressId: j['AddressID'] ?? j['addressId'],
    fullName: j['FullName'] ?? j['fullName'],
    phone:    j['Phone'],
    line1:    j['Line1'],
    ward:     j['Ward'],
    district: j['District'],
    province: j['Province'],
    isDefault: (j['IsDefault'] is int) ? j['IsDefault'] == 1 : (j['IsDefault'] ?? false),
  );
}
