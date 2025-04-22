import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:js_util'; // 🔹 getProperty を使うために必要
//import '../pending/mainalt.dart'; // これを追加
import 'fixed_top_section.dart';
import 'fixed_second_section.dart';
import 'fixed_third_section.dart'; // 子ウィジットのファイルをインポート
import 'package:flutter/services.dart'; // For input formatters
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'test.dart';

typedef OnDeleteItemCallback = void Function(int index);
typedef OnEditItemCallback = void Function(int index);

@JS()
@staticInterop
external JSPromise fetch_data_rust(String codesJson);

void main() {
  runApp(const MyAppTest());
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
  final List<String> items = ['アイテム1', 'アイテム2', 'アイテム3'];

  List<dynamic> fetchTopDataList = []; // 仮のリスト名
  List<dynamic> fetchThirdDataList = []; // 仮のリスト名
  List<Map<String, dynamic>> fetchThirdStorageDataList = []; // 仮のリスト名

  double totalPurchaseValue = 0;
  double totalMarketCapValue = 0; // Declare the total market cap value here
  double differenceTotal = 0;

  final String _storageKey = 'stock_data';
  List<Map<String, dynamic>> _savedData = [];

  bool _dataLoaded = false;
  bool _showInputScreen = false;
  Future<void>? _dataFetchingFuture;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _dataFetchingFuture = _fetchData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);
    if (savedJson != null && savedJson.isNotEmpty && savedJson != '[]') {
      setState(() {
        _savedData =
            (jsonDecode(savedJson) as List).cast<Map<String, dynamic>>();
        _dataLoaded = true;
        _showInputScreen = false;
        fetchThirdStorageDataList = List.from(_savedData); // 保存データを設定
        print('_loadSavedData: ${_savedData.toString()}');
        //_fetchData();
      });
    } else {
      setState(() {
        _dataLoaded = true;
        _showInputScreen = true;
        _showInitialInputDialog(); // ローカルストレージが空の場合はアラートを表示
      });
    }
  }

  void _showInitialInputDialog() {
    final codeController = TextEditingController();
    final sharesController = TextEditingController();
    final unitPriceController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // ユーザーがダイアログの外側をタップしても閉じないようにする
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('初期株価データの入力'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('ローカルストレージにデータが見つかりませんでした。初期データを入力してください。'),
                const SizedBox(height: 16.0),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'コード'),
                ),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '株数'),
                ),
                TextField(
                  controller: unitPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '単価'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // キャンセル処理（必要であれば）
                Navigator.of(context).pop();
                setState(() {
                  _showInputScreen = true; // キャンセルされた場合は入力画面を表示
                });
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final code = codeController.text;
                if (code.isNotEmpty) {
                  final newData = {
                    'Code': code,
                    'Shares': int.tryParse(sharesController.text) ?? 0,
                    'Unitprice': int.tryParse(unitPriceController.text) ?? 0,
                  };
                  _saveInitialData(newData);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('コードは必須です。')));
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveInitialData(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonData = jsonEncode([newData]); // 初期データはリストとして保存
    setState(() {
      prefs.setString(_storageKey, jsonData);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('初期データが保存されました！')));
    await _loadSavedData();
  }

  Future<void> _saveEditedData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_savedData);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('株価データが保存されました！')));
    await _loadSavedData();
  }

  Future<void> _editDataItem(int index, Map<String, dynamic> newData) async {
    setState(() {
      fetchThirdStorageDataList[index] = newData; // 追加
    });
    await _saveEditedData();
  }

  void _showAddDialog() {
    final codeController = TextEditingController();
    final sharesController = TextEditingController();
    final unitPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('株価データの追加'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'コード'),
                ),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '株数'),
                ),
                TextField(
                  controller: unitPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '単価'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final newStock = {
                  'Code': codeController.text,
                  'Shares': int.tryParse(sharesController.text) ?? 0,
                  'Unitprice': int.tryParse(unitPriceController.text) ?? 0,
                };
                // ここで _savedData を更新し、UI を再描画する
                setState(() {
                  fetchThirdStorageDataList.add(newStock); // 追加
                });

                if (newStock['Code'] != null &&
                    (newStock['Code'] as String).isNotEmpty) {
                  _addStockData(newStock);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('コードは必須です。')));
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _addStockData(Map<String, dynamic> newStock) {
    setState(() {
      fetchThirdStorageDataList.add(newStock); // 追加
    });
    _saveEditedData();
  }

  void _showEditDialog(int index) {
    final currentData = Map<String, dynamic>.from(_savedData[index]);
    final codeController = TextEditingController(text: currentData['Code']);
    final sharesController = TextEditingController(
      text: currentData['Shares'].toString(),
    );
    final unitPriceController = TextEditingController(
      text: currentData['Unitprice'].toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('株価データの編集'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'コード'),
                ),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '株数'),
                ),
                TextField(
                  controller: unitPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '単価'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final newData = {
                  'Code': codeController.text,
                  'Shares': int.tryParse(sharesController.text) ?? 0,
                  'Unitprice': int.tryParse(unitPriceController.text) ?? 0,
                };
                _editDataItem(index, newData);
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllData() async {
    setState(() {
      fetchThirdStorageDataList.clear(); // クリア
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存されたデータをすべて削除しました！')));
    _loadSavedData();
  }

  // 新しい削除処理関数を追加
  void _deleteItem(int index) async {
     setState(() {
      //_savedData.removeAt(index);
      fetchThirdStorageDataList.removeAt(index); // ここで削除
    });
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(fetchThirdStorageDataList);
    await prefs.setString(_storageKey, jsonData);

   

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('株価データが削除されました！')));
    //await _loadSavedData();
  }

  // 新しい削除処理関数を追加
  Future<void> _deleteDataItem(int index) async {
    setState(() {
      _savedData.removeAt(index);
      fetchThirdStorageDataList.removeAt(index); // 追加
    });
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_savedData);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('株価データが削除されました！')));
  }

  double _calculateTotalPurchaseValue(List<dynamic> data) {
    double total = 0;
    for (var item in data) {
      final shares = item['Shares'] ?? 0;
      final unitPrice = item['Unitprice'] ?? 0;
      total += shares * unitPrice;
    }
    return total;
  }

  double _calculateTotalMarketCapValue(
    List<dynamic> data,
    List<Map<String, dynamic>> stockdata,
  ) {
    double total = 0;
    for (var i = 0; i < data.length; i++) {
      final item = data[i] as Map<String, dynamic>;

      final shares = stockdata[i]['Shares'] ?? 0;
      final marketCapString = (item['price']?.toString() ?? '0.0').replaceAll(
        ',',
        '',
      );
      final marketCapValue = (double.tryParse(marketCapString) ?? 0.0) * shares;
      total += marketCapValue;
    }
    return total;
  }

  Future<void> _fetchData() async {
    String codesJson = jsonEncode(
      fetchThirdStorageDataList.map((item) => item['Code'] as String).toList(),
    );
    String result = await fetchStockData(codesJson);

    try {
      List<dynamic> dataList = jsonDecode(result);
      //setState(() {
        fetchTopDataList = List.from(dataList.take(2)); // 先頭2件
        fetchThirdDataList = List.from(dataList.skip(2)); // 3件目以降
        totalPurchaseValue = _calculateTotalPurchaseValue(
          fetchThirdStorageDataList.toList(),
        ); // ここで合計を計算
        totalMarketCapValue = _calculateTotalMarketCapValue(
          dataList.skip(2).toList(),
          fetchThirdStorageDataList,
        );
        differenceTotal = totalMarketCapValue - totalPurchaseValue;
      //});
    } catch (e) {
      print("JSON デコードエラー: $e");
    }
  }

  Future<String> fetchStockData(String codesJson) async {
    final jsResult = await fetch_data_rust(codesJson).toDart; // JSAny? を取得

    print("jsResult の型: ${jsResult.runtimeType} - 値: $jsResult"); // デバッグ用なので削除

    return jsResult.toString(); // ✅ そのまま文字列を返す
  }

  void _editItem(int index) {
    print('編集が要求されました: $index');
    // ここで編集処理（アラート表示など）を行う
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('編集'),
          content: Text('インデックス $index のアイテムを編集します。'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          //ウィンドウの向き（縦横）やサイズが変更されるたびに再ビルドをトリガーします。
          builder: (context, orientation) {
            return Center(
              child: FutureBuilder(
                future: _dataFetchingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
                  } else {
                    return Column(
                      // Changed to Column to accommodate multiple children
                      children: [
                        FixedTopSection(dataList: fetchTopDataList),

                        // Added FixedTopSection
                        
                        FixedSecondSection(
                          dataList: fetchThirdStorageDataList,
                          differenceTotal: differenceTotal,
                          totalPurchaseValue: totalPurchaseValue,
                          totalMarketCapValue: totalMarketCapValue,
                        ),
                        
                        ElevatedButton(
                          onPressed: _showAddDialog,
                          child: const Text('追加'),
                        ),
                        // Assuming ChildWidget needs to expand in the remaining space
                        Expanded(child:
                        FixedThirdSection(
                          items: items,
                          fetchDataList: fetchThirdDataList,
                          //stockdata: _savedData,
                          savedData: fetchThirdStorageDataList, //保存されているデータを渡す
                          storageKey: _storageKey,
                          onDeleteItem: _deleteItem,
                          onEditItem: _showEditDialog, //_editItem,
                          //onShowAlert: _showAlert,
                        ),
                        ),
                        
                        ElevatedButton(
                          onPressed: _deleteAllData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            '全データを削除',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
