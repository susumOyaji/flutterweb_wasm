import 'package:flutter/material.dart';
import 'mainsample.dart'; // 親ウィジットのコールバック関数の型定義がある場所

class ChildWidget extends StatelessWidget {
  final ShowAlertCallback onShowAlert;
  final ShowEditAlertCallback onShowEditAlert;

  const ChildWidget({super.key, required this.onShowAlert,required this.onShowEditAlert});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            onShowAlert('子ウィジットからのお知らせです！'); // 親ウィジットのコールバック関数を呼び出す
          },
          child: const Text('アラートを表示'),
        ),
        ElevatedButton(
          onPressed: () {
            onShowEditAlert('子ウィジットEditからのお知らせです！'); // 親ウィジットのコールバック関数を呼び出す// 別の処理
          },
          child: const Text('Editアラートを表示'),
        ),
      ],
    );
  }
}