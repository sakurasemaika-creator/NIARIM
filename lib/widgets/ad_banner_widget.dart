import 'package:flutter/material.dart';

class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.grey[900],
      child: const Center(
        child: Text('AD BANNER', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }
}
