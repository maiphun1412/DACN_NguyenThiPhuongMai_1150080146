class CategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final String? image; // absolute URL từ backend

  CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.image,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
        id: j['id'] is int ? j['id'] : int.parse(j['id'].toString()),
        name: j['name'] ?? '',
        parentId: j['parentId'],
        image: j['image'],
      );
}
