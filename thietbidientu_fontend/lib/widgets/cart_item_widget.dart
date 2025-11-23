// lib/widgets/CartItemWidget.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/cart_item.dart';

const Color kBrandColor = Color(0xFF353839);

class CartItemWidget extends StatelessWidget {
  final CartItem cartItem;
  final Function onRemove;
  final Function(int) onQuantityChanged;

  const CartItemWidget({
    required this.cartItem,
    required this.onRemove,
    required this.onQuantityChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Radio demo: không chọn mặc định
          Radio<int>(
            value: int.tryParse(cartItem.product.id) ??
                0, // Chuyển String sang int nếu cần
            groupValue: null, // không mục nào được chọn
            activeColor: kBrandColor,
            onChanged: (_) {}, // TODO: xử lý chọn
          ),

          // Ảnh sản phẩm
          Container(
            height: 70,
            width: 70,
            margin: const EdgeInsets.only(right: 15),
            child: Image.network(cartItem.product.imageUrl ?? '',
                fit: BoxFit.cover),
          ),

          // Thông tin sản phẩm (Expanded để tránh tràn ngang)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cartItem.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    cartItem.product.description ??
                        'Mô tả ngắn sản phẩm', // Kiểm tra xem description có null không
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  Text(
                    '${cartItem.totalPrice}đ',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBrandColor),
                  ),
                ],
              ),
            ),
          ),

          // Hành động: xoá + số lượng
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: kBrandColor),
                  onPressed: () => onRemove(),
                  tooltip: 'Xoá khỏi giỏ',
                ),
                Row(
                  children: [
                    _QtyButton(
                      icon: CupertinoIcons.minus,
                      onTap: () => onQuantityChanged(cartItem.quantity - 1),
                    ),
                    SizedBox(width: 8),
                    Text(
                      cartItem.quantity.toString(),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kBrandColor),
                    ),
                    SizedBox(width: 8),
                    _QtyButton(
                      icon: CupertinoIcons.plus,
                      onTap: () => onQuantityChanged(cartItem.quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final Function() onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: kBrandColor),
      ),
    );
  }
}
