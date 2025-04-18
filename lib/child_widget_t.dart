import 'package:flutter/material.dart';
import 'main2.dart'; // 親ウィジットのコールバック関数の型定義がある場所
import 'dart:convert';
import 'package:intl/intl.dart';


class ChildWidget extends StatelessWidget {
  final List<dynamic> fetchDataList;
  //final List<Map<String, dynamic>> stockdata;
  final String storageKey;
  final List<Map<String, dynamic>> savedData;

  final List<String> items;
  final OnDeleteItemCallback onDeleteItem;
  final OnEditItemCallback onEditItem;

  const ChildWidget({
    super.key,
    required this.fetchDataList,
   // required this.stockdata,
    required this.storageKey,
    required this.savedData,
    required this.items,
    required this.onDeleteItem,
    required this.onEditItem,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = savedData.toList();//DJI & NIKKEI to skip
    if (remaining.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("データチェック中..."),
      );
    }


  //@override
  //Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // グリッドの列数（必要に応じて変更してください）
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 2.2, // カードの縦横比（必要に応じて調整してください）
      ),
      itemCount: remaining.length,
      itemBuilder: (BuildContext context, int index) {
        final stock = remaining[index] as Map<String, dynamic>;
        final item = items[index];
         final stock1 = fetchDataList[index];

                    final shares = stock['Shares'] ?? 0;
                    final unitPrice = stock['Unitprice'] ?? 0;
                    final purchaseValue = shares * unitPrice;

                    final marketCapString = (stock['price']?.toString() ??
                            '0.0')
                        .replaceAll(',', '');
                    final marketCapValue =
                        (double.tryParse(marketCapString) ?? 0.0) * shares;

                    final difference = marketCapValue - purchaseValue;
                    final formattedDifference = NumberFormat(
                      '#,###.##',
                    ).format(difference.abs());
                    final differenceSign = difference >= 0 ? '' : '-';
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              //crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  //mainAxisAlignment: MainAxisAlignment.start,// ← このRowで左右の配置を制御
                  children: [
                    Column(
                      // Textをまとめて左に表示
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code: ${stock1['code']?.toString() ?? 'コードなし'}',
                          style: TextStyle(fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Name: ${stock1['name']?.toString() ?? 'コードなし'}',
                          style: TextStyle(
                            //fontSize: 12,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Price: ${stock1['price']?.toString() ?? 'コードなし'}',
                          style: TextStyle(
                            //fontSize: 12,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ratio: ${stock1['ratio']?.toString() ?? 'コードなし'}',
                          style: TextStyle(
                            //fontSize: 12,
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                              'Percent: ${stock1['percent']?.toString() ?? 'Percent not found'}%',
                              style: TextStyle(),
                            ),
                            Text(
                              'Shares: ${stock['Shares']?.toString()}  Unit Price: ￥${stock['Unitprice']?.toString()}',
                              style: TextStyle(),
                            ),

                            Text(
                              'Purchase: ￥${NumberFormat('#,###.##').format(purchaseValue)}',
                              style: TextStyle(),
                            ),

                            Text(
                              'Market Cap: ￥${NumberFormat('#,###.##').format(marketCapValue)}',
                              style: TextStyle(),
                            ),
                             Text(
                              'Difference: $differenceSign￥$formattedDifference',
                              style: TextStyle(
                                color:
                                    difference >= 0
                                        ? const Color.fromARGB(255, 255, 1, 1)
                                        : const Color.fromARGB(235, 0, 0, 0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ],
                    ),
                    //const Spacer(),
                    Column(
                      // IconButtonを右端に表示
                      //mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => onEditItem(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () => onDeleteItem(index),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
