import 'package:flutter/material.dart';

class FixedTopSection extends StatelessWidget {
  final List<dynamic> dataList;

  const FixedTopSection({super.key, required this.dataList});

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
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: firstTwo.length,
      itemBuilder: (BuildContext context, int index) {
        final stock = firstTwo[index] as Map<String, dynamic>;
        Color cardColor;
        if (index == 0) {
          cardColor =
              stock['ratio'].toString().startsWith('-') == false
                  ? const Color.fromARGB(255, 255, 0, 0)
                  : const Color.fromARGB(255, 0, 255, 55); // 最初のカードの色
        } else if (index == 1) {
          cardColor =
              stock['ratio'].toString().startsWith('-') == false
                  ? const Color.fromARGB(255, 255, 0, 0)
                  : const Color.fromARGB(255, 0, 255, 55); // 最初のカードの色
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
                  Text(
                    'Code: ${stock['code']?.toString() ?? 'Code not fount'}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'Name: ${stock['name']?.toString() ?? 'Name not fount'}',
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'Price: ${stock['price']?.toString() ?? 'Price not fount'}',
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'Ratio: ${stock['ratio']?.toString() ?? 'Ratoin not fount'}',
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'Percent: ${stock['percent']?.toString() ?? 'Percent not fount'}',
                  ),
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
