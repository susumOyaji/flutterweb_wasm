import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:js_util'; // 🔹 getProperty を使うために必要
import 'mainok.dart'; // これを追加
import 'fixed_top_section.dart';
import 'fixed_second_section.dart';
import 'fixed_third_section.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences



typedef OnDeleteItemCallback = void Function(int index); // ここに記述
typedef OnEditItemCallback = void Function(int index);



@JS()
@staticInterop
external JSPromise fetch_data_rust(String codesJson);

List<Map<String, dynamic>> stockdata = [
  {"Code": "4755", "Shares": 100, "Unitprice": 977},
  {"Code": "5016", "Shares": 300, "Unitprice": 1008},
  {"Code": "6758", "Shares": 1000, "Unitprice": 333},
  {"Code": "6758", "Shares": 100, "Unitprice": 2596},
  {"Code": "6758", "Shares": 31, "Unitprice": 2596},
  {"Code": "5803", "Shares": 0, "Unitprice": 0},
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Rust Bridge',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const _MyHomePage(), //ScrapingPage(),
    );
  }
}

class _MyHomePage extends StatefulWidget {
  const _MyHomePage({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<_MyHomePage> {
  List<dynamic> stockDataList = []; // 株価データを格納するリスト
   final List<String> items = ['アイテム1', 'アイテム2', 'アイテム3'];

   
  double totalPurchaseValue = 0;
  double totalMarketCapValue = 0; // Declare the total market cap value here
  double differenceTotal = 0;

  final String _storageKey = 'stock_data';
  List<Map<String, dynamic>> _savedData = [];
  bool _dataLoaded = false;
  bool _showInputScreen = false;
  

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 初期状態で1つの入力フォームを追加しておく
      //_loadStockData(); // initStateでデータを読み込む
      //ウィジェットのビルドが完了した後に _loadData を呼び出す
      _fetchData();
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);
    if (savedJson != null) {
      setState(() {
        _savedData =
            (jsonDecode(savedJson) as List).cast<Map<String, dynamic>>();
        _dataLoaded = true;
        _showInputScreen = false;
        print(_savedData);
      });
    } else {
      setState(() {
        _dataLoaded = true;
        _showInputScreen = true;
        _showInitialInputDialog(); // ローカルストレージが空の場合はアラートを表示
      });
    }
  }

  Future<void> _saveInitialData(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode([newData]); // 初期データはリストとして保存
    await prefs.setString(_storageKey, jsonData);
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
      _savedData[index] = newData;
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
      _savedData.add(newStock);
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

  Future<void> _deleteAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    setState(() {
      _savedData.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存されたデータをすべて削除しました！')));
    _loadSavedData();
  }

  // 新しい削除処理関数を追加
  void _deleteItem(int index) async {
    setState(() {
      _savedData.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_savedData);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('株価データが削除されました！')));
  }

  // 新しい削除処理関数を追加
  Future<void> _deleteDataItem(int index) async {
    setState(() {
      _savedData.removeAt(index);
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

  Future<String> fetchStockData(String codesJson) async {
    final jsResult = await fetch_data_rust(codesJson).toDart; // JSAny? を取得

    print("jsResult の型: ${jsResult.runtimeType} - 値: $jsResult"); // デバッグ用なので削除

    return jsResult.toString(); // ✅ そのまま文字列を返す
  }

  void _fetchData() async {
    String codesJson = jsonEncode(
      _savedData.map((item) => item['Code'] as String).toList(),
    );
    String result = await fetchStockData(codesJson);

    try {
      List<dynamic> dataList = jsonDecode(result);
      setState(() {
        stockDataList = dataList;
        totalPurchaseValue = _calculateTotalPurchaseValue(
          stockdata.toList(),
        ); // ここで合計を計算
        totalMarketCapValue = _calculateTotalMarketCapValue(
          dataList.skip(2).toList(),
          stockdata,
        );
        differenceTotal = totalMarketCapValue - totalPurchaseValue;

        final differenceSignTotal =
            differenceTotal >= 0 ? '' : '-'; // Calculate total market cap
      });
    } catch (e) {
      print("JSON デコードエラー: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        //appBar: AppBar(title: const Text('Flutter Web × Rust (WASM)')),
        body:
            stockDataList.isNotEmpty
                ? Column(
                  children: [
                    ElevatedButton(
                      onPressed: _showAddDialog,
                      child: const Text('追加'),
                    ),
                    FixedTopSection(dataList: stockDataList), // 変更
                    // _buildFixedTopSection(stockDataList),
                    FixedSecondSection(
                      dataList: stockDataList,
                      differenceTotal: differenceTotal,
                      totalPurchaseValue: totalPurchaseValue,
                      totalMarketCapValue: totalMarketCapValue,
                    ), // 変更
                    //_buildFixedSecondSection(stockDataList),
                    FixedThirdSection(
                       items: items,
                      fetchDataList: stockDataList,
                      //stockdata: stockdata,
                      savedData: _savedData,
                      storageKey: _storageKey,
                      onDeleteItem: _deleteItem, // コールバック関数を渡す
                      onEditItem: _showEditDialog, // 編集用のコールバック関数を渡す
                    ), // 変更
                    //_buildScrollableBottomSection(stockDataList),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _saveEditedData,
                      child: const Text('データを保存'),
                    ),
                    const SizedBox(height: 8.0),
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
                )
                : const Center(child: Text("データを取得します")),
        floatingActionButton: FloatingActionButton(
          onPressed: _fetchData,
          tooltip: 'データ取得',
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
