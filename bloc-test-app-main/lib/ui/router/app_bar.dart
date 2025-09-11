import 'package:water_boiler_rfid_labeler/data/models/variables.dart';
import 'package:flutter/material.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_router.dart'; // pageNames için

AppBar commonAppBar(BuildContext context, String title,
    {bool showBack = false, VoidCallback? onBack}) {
  final textAndIconColor = titleTextAndIconColor;
  final backgroundColor = titleBackgroundColor;

  return AppBar(
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (onBack != null) {
                  onBack();
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    pageNames[0], // "Main"
                    (route) => false,
                  );
                }
              },
            )
          : null,

      // Başlığı tam ortaya sabitle
      centerTitle: true,

      // TAŞMAYI ÖNLE: Row genişlesin, metin Flexible ile ellipsize olsun
      title: Row(
        mainAxisSize: MainAxisSize.max, // tüm genişliği kullan
        mainAxisAlignment: MainAxisAlignment.center, // ortala
        children: [
          // Logoyu toolbar yüksekliğine göre sınırla ve çok az yukarı kaydır
          Transform.translate(
            offset: const Offset(0, -1),
            child: Image.asset(
              'assets/images/c4_TT_Logo_RGB_only_logo.png',
              height: kToolbarHeight * 0.6, // ölçek yerine yükseklik
              color: titleTextAndIconColor,
            ),
          ),
          const SizedBox(width: 8),
          // Uzun başlık taşmasın
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),

      // Leading varken sağda simetri için görünmez boşluk bırak
      actions: showBack ? const [SizedBox(width: kToolbarHeight)] : null,
      foregroundColor: textAndIconColor,
      backgroundColor: backgroundColor);
}
