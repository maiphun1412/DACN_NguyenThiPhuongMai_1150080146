import 'package:flutter/material.dart';

class ItemAppBar extends StatelessWidget {
  const ItemAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(25),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(
              Icons.arrow_back,
              size: 30,
              color: Color(0xFF353839),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20),
            child: Text(
              "Sản phẩm",
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF353839),
              ),
            ),
          ),
          const Spacer(),
          // ✅ Giỏ hàng thay cho trái tim
          InkWell(
            onTap: () {
              // Điều hướng sang trang giỏ hàng
              Navigator.pushNamed(context, '/cart');
            },
            borderRadius: BorderRadius.circular(50),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 30,
                color: Color(0xFF353839),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
