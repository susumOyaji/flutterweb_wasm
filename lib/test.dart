import 'package:flutter/material.dart';
import 'package:flutterweb_wasm/fixed_third_section.dart';
import 'dart:convert';
import 'dart:js_interop';
import 'fixed_top_section.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

@JS()
@staticInterop
external JSPromise fetch_data_rust(String codesJson);

void main() {
  runApp(const MyAppTest());
}

class MyAppTest extends StatelessWidget {
  const MyAppTest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FutureBuilder TestSample',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<void> _fetchDataFuture;
  List<dynamic> fetchTopDataList = []; // 仮のリスト名
  List<dynamic> fetchThirdDataList = []; // 仮のリスト名
  List<Map<String, dynamic>> fetchThirdStorageDataList = []; // 仮のリスト名

  final List<String> items = ['アイテム1', 'アイテム2', 'アイテム3'];
  final String _storageKey = 'stock_data';
  List<Map<String, dynamic>> _savedData = [];

  bool _dataLoaded = false;
  bool _showInputScreen = false;


   @override
  void initState() {
    super.initState();
    //_loadSavedData(); // 初期データをロード
    // _fetchData();
    _fetchDataFuture = _loadSavedData().then((_) => _fetchData());
   
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
      //setState(() {
        _dataLoaded = true;
        _showInputScreen = true;
        _showInitialInputDialog(); // ローカルストレージが空の場合はアラートを表示
     // });
    }
  }

  Future<String> fetchStockData(String codesJson) async {
    final jsResult = await fetch_data_rust(codesJson).toDart; // JSAny? を取得

    print("jsResult の型: ${jsResult.runtimeType} - 値: $jsResult"); // デバッグ用なので削除

    return jsResult.toString(); // ✅ そのまま文字列を返す
  }

  Future<void> _fetchData() async {
    String codesJson = jsonEncode(
      fetchThirdStorageDataList.map((item) => item['Code'] as String).toList(),
    );
    print("codesJson: $codesJson"); // デバッグ用
    String result = await fetchStockData(codesJson);

    try {
      List<dynamic> dataList = jsonDecode(result);
      setState(() {
      fetchTopDataList = List.from(dataList.take(2)); // 先頭2件
      fetchThirdDataList = List.from(dataList.skip(2)); // 3件目以降

      });
    } catch (e) {
      print("JSON デコードエラー: $e");
    }
  }

  Future<void> _saveInitialData(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonData = jsonEncode([newData]); // 初期データはリストとして保存
    //setState(() {
      await prefs.setString(_storageKey, jsonData);
    //});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('初期データが保存されました！')));
    await _loadSavedData();
  }

  

  void _showInitialInputDialog() {
    final codeController = TextEditingController();
    final sharesController = TextEditingController();
    final unitPriceController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('初期株価データの入力'),
          content: SingleChildScrollView(
            child: ConstrainedBox( // ConstrainedBox で高さを制限
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7, // 画面の高さの70%まで
              ),
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
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // キャンセル処理
                Navigator.of(context).pop();
                // ignore: invalid_use_of_protected_member
                if (context is StatefulElement && context.mounted) {
                  setState(() {
                    _showInputScreen = true; // キャンセルされた場合は入力画面を表示
                  });
                }
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

  Future<void> _saveEditedData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(_savedData);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('株価データが保存されました！')));
    await _loadSavedData();// データを再読み込み
  }

  void _addStockData(Map<String, dynamic> newStock) {
    setState(() {
      _savedData.add(newStock); // 追加
     });
    _saveEditedData();
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
      _savedData.clear();
      fetchThirdStorageDataList.clear(); // fetchThirdStorageDataList もクリア
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存されたデータをすべて削除しました！')));
    //await _loadSavedData(); // データを再読み込み
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FutureBuilder Sample (void)')),
      body: Center(
        child: FutureBuilder<void>(
          // Future の型を void にする
          future: _fetchDataFuture, // 非同期処理を行う Future を指定
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            // AsyncSnapshot の型も void にする
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Future が完了するまでのローディング状態
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              // Future がエラーで完了した場合
              return Text('エラー: ${snapshot.error}');
            } else if (snapshot.connectionState == ConnectionState.done) {
              // Future が正常に完了した場合 (void なので data は null)
              return Column(
                children: [
                  Text('処理完了！', style: TextStyle(fontSize: 20)),
                  FixedTopSection(dataList: fetchTopDataList),
                  Expanded(child:
                  FixedThirdSection(
                    fetchDataList: fetchThirdDataList,
                    storageKey: _storageKey,
                    savedData: fetchThirdStorageDataList,
                    items: items,
                    onDeleteItem: _deleteItem,
                    onEditItem: _showEditDialog,
                  ),
              ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showInputScreen = true;
                      });
                      _showAddDialog();
                    },
                    child: const Text('データ読み込みand登録'),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _saveEditedData,
                    child: const Text('データ保存'),
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
              );
            } else {
              // 初期状態
              return const Text('処理開始前');
            }
          },
        ),
      ),
    );
  }
}



 /*
  // 非同期処理をシミュレートする関数
  Future<String> _fetchData1() async {
    // 2秒間の遅延を導入して、非同期処理を模倣
    await Future.delayed(const Duration(seconds: 2));

    // 何らかのデータを返す (成功)
    // return 'データがロードされました！';

    // エラーを発生させる場合
    throw Exception('データのロードに失敗しました！');
  }
  */