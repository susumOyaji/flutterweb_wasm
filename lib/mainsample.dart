import 'package:flutter/material.dart';
import '../child_widget.dart'; // 子ウィジットのファイルをインポート
import 'fixed_third_section.dart'; // FixedThirdSection をインポート


// アラートを表示するためのコールバック関数の型を定義
typedef ShowAlertCallback = void Function(String message);
typedef ShowEditAlertCallback = void Function(String message);
typedef OnEditItemCallback = void Function(int index);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('親ウィジット')),
        body: const ParentWidget(),
      ),
    );
  }
}

class ParentWidget extends StatefulWidget {
  const ParentWidget({super.key});

  @override
  State<ParentWidget> createState() => _ParentWidgetState();
}

class _ParentWidgetState extends State<ParentWidget> {
  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('アラート！'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  void _showEditAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editアラート！'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  
/*
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChildWidget(
        onShowAlert: _showAlert, // コールバック関数を子ウィジットに渡す
        onShowEditAlert: _showEditAlert,
      ),
    );
  }
*/
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChildWidget(
          onShowAlert: _showAlert, // コールバック関数を子ウィジットに渡す
          onShowEditAlert: _showEditAlert,
        ),
      // FixedThirdSection を追加
      ],
    );
  }
}