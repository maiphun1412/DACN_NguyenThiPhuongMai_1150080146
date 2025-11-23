class Review {
  final int reviewId;
  final int productId;
  final int customerId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final String customerName;
  final List<String> images;

  Review({
    required this.reviewId,
    required this.productId,
    required this.customerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.isEdited,
    required this.customerName,
    required this.images,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    reviewId: j['ReviewID'],
    productId: j['ProductID'],
    customerId: j['CustomerID'],
    rating: (j['Rating'] as num).toDouble(),
    comment: j['Comment'],
    createdAt: DateTime.parse(j['CreatedAt']),
    updatedAt: j['UpdatedAt'] != null ? DateTime.parse(j['UpdatedAt']) : null,
    isEdited: (j['IsEdited'] ?? false) == true || j['IsEdited'] == 1,
    customerName: j['CustomerName'] ?? 'Khách hàng',
    images: (j['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class ReviewStats {
  final int total;
  final double avg;
  ReviewStats({required this.total, required this.avg});
  factory ReviewStats.fromJson(Map<String, dynamic> j) =>
      ReviewStats(total: j['TotalReviews'] ?? 0, avg: (j['AvgRating'] as num?)?.toDouble() ?? 0);
}
