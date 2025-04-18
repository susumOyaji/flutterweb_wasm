import 'package:flutter/material.dart';
//import 'dart:convert';
import 'package:intl/intl.dart';

class FixedSecondSection extends StatelessWidget {
  final List<dynamic> dataList;
  final double differenceTotal, totalPurchaseValue, totalMarketCapValue;
  const FixedSecondSection({
    super.key,
    required this.dataList,
    required this.differenceTotal,
    required this.totalPurchaseValue,
    required this.totalMarketCapValue,
  });
  

  @override
  Widget build(BuildContext context) {
    final firstTwo = dataList.take(2).toList();
    if (firstTwo.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 1行に表示するアイテム数
        childAspectRatio: 2.5, // アイテムの縦横比
        //crossAxisSpacing: crossAxisSpacing, // 動的に横方向の間隔を設定
        mainAxisSpacing: 8.0, // アイテム間の縦方向の間隔
      ),
      itemCount: firstTwo.length,
      itemBuilder: (BuildContext context, int index) {
        //final stock = firstTwo[index] as Map<String, dynamic>;

        Color cardColor;
        if (index == 0) {
          cardColor =
              differenceTotal.toString().startsWith('-') == false
                  ? const Color.fromARGB(255, 255, 94, 0)
                  : const Color.fromARGB(255, 0, 255, 55); // 最初のカードの色
        } else if (index == 1) {
          cardColor = const Color.fromARGB(218, 142, 153, 144); // 2番目のカードの色
        } else {
          cardColor = Colors.grey.shade300; // デフォルトの色
        }

        return Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (index == 0) ...[
                    Text(
                      "Management status",
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Total Purchase Value: ￥${NumberFormat('#,###.##').format(totalPurchaseValue)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Market Cap Value: ￥${NumberFormat('#,###.##').format(totalMarketCapValue)}',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Difference Value: ￥${NumberFormat('#,###.##').format(differenceTotal)}',
                      style: const TextStyle(
                        //fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (index == 1) ...[
                    const Text(
                      '別のタイトルB',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('こちらは2番目のカードで全く違う内容を表示しています。'),
                    const Text('例えば、画像やボタンなども配置できます。'),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  //),
  //);
}
