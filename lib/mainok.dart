import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'fixed_top_section.dart';
import 'fixed_second_section.dart';
import 'fixed_third_section.dart'; // 子ウィジットのファイルをインポート
import 'package:shared_preferences/shared_preferences.dart';
//import 'mainflu.dart';

@JS()
@staticInterop
external JSPromise fetch_data_rust(String codesJson);

void main() {
  runApp(const MyAppalt());
}

class MyAppalt extends StatelessWidget {
  const MyAppalt({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Web Stock Data',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StockDataScreen(),
    );
  }
}

class StockDataScreen extends StatefulWidget {
  const StockDataScreen({super.key});

  @override
  State<StockDataScreen> createState() => _StockDataScreenState();
}

class _StockDataScreenState extends State<StockDataScreen> {
  List<Map<String, dynamic>> stockData = [];
  List<dynamic> fetchTopDataList = []; // 仮のリスト名
  List<dynamic> fetchThirdDataList = []; // 仮のリスト名
  List<Map<String, dynamic>> fetchThirdStorageDataList = []; // 仮のリスト名
  double totalPurchaseValue = 0;
  double totalMarketCapValue = 0; // Declare the total market cap value here
  double differenceTotal = 0;

  List<dynamic> stockDataList = []; // 株価データを格納するリスト
  final String _storageKey = 'stock_data';
  List<Map<String, dynamic>> stockdata = [];
  bool _dataLoaded = false;
  bool _showInputScreen = false;
  bool _isLoading = false; // --- リフレッシュ中の状態を示すフラグを追加 ---

  @override
  void initState() {
    super.initState();
    //_fetchDataFuture = _loadSavedData().then((_) => _fetchData());
    _loadSavedData().then((_) => _fetchData());
    //_loadSavedData();
    //_fetchData(); // Fetch data when the app starts
    //WidgetsBinding.instance.addPostFrameCallback((_) {
    //  _loadSavedData();
    //  _fetchData();
    //});
  }

  refresh() {
    //setState(() {
    (_isLoading || !_dataLoaded) ? null : _fetchData();
    // _loadSavedData();
    //});
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);
    if (savedJson != null) {
      setState(() {
        stockData = (jsonDecode(savedJson) as List).cast<Map<String, dynamic>>();
        //_dataLoaded = true;
        _showInputScreen = false;
      });
      print('_loadSavedData: ${stockData}'); // デバッグ用
    } else {
      setState(() {
        // _dataLoaded = true;
        _showInputScreen = true;
        _showInitialInputDialog();
      });
    }
  }

  Future<void> _saveInitialData(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode([newData]);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('初期データが保存されました！')));
    refresh(); //await _loadSavedData();
  }

  Future<void> _saveEditedData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(stockData);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('株価データが保存されました！')));
    refresh(); //await _loadSavedData();
  }

  Future<void> _editDataItem(int index, Map<String, dynamic> newData) async {
    setState(() {
      stockData[index] = newData;
    });
    await _saveEditedData();
  }

  void _showEditDialog(int index) {
    final currentData = Map<String, dynamic>.from(stockData[index]);
    final codeController = TextEditingController(text: currentData['Code']);
    final sharesController = TextEditingController(text: currentData['Shares'].toString());
    final unitPriceController = TextEditingController(text: currentData['Unitprice'].toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('株価データの編集'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'コード')),
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('初期株価データの入力'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('ローカルストレージにデータが見つかりませんでした。初期データを入力してください。'),
                const SizedBox(height: 16.0),
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'コード')),
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
                setState(() {
                  _showInputScreen = true;
                });
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
                if (newData['Code'] != null && (newData['Code'] as String).isNotEmpty) {
                  _saveInitialData(newData);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コードは必須です。')));
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
      stockData.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存されたデータをすべて削除しました！')));
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
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'コード')),
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
                if (newStock['Code'] != null && (newStock['Code'] as String).isNotEmpty) {
                  _addStockData(newStock);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コードは必須です。')));
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
      stockData.add(newStock);
    });

    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      final jsonData = jsonEncode(stockData);
      prefs.setString(_storageKey, jsonData);
    });
    _saveEditedData();
  }

  Future<void> _deleteDataItem(int index) async {
    setState(() {
      stockData.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(stockData);
    await prefs.setString(_storageKey, jsonData);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('株価データが削除されました！')));
    refresh(); //await _loadSavedData();
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

  double _calculateTotalMarketCapValue(List<dynamic> data, List<Map<String, dynamic>> stockdata) {
    double total = 0;
    for (var i = 0; i < data.length; i++) {
      final item = data[i] as Map<String, dynamic>;

      final shares = stockdata[i]['Shares'] ?? 0;
      final marketCapString = (item['price']?.toString() ?? '0.0').replaceAll(',', '');
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
    // --- すでにロード中の場合は処理を中断 ---
    if (_isLoading) return;

    // --- ローディング状態を開始 ---
    setState(() {
      _isLoading = true;
    });

    String codesJson = jsonEncode(stockData.map((item) => item['Code'] as String).toList());

    print('_fetchData: ${codesJson}'); // デバッグ用
    String result = await fetchStockData(codesJson);

    try {
      List<dynamic> dataList = jsonDecode(result);
      print('fetchStockData: ${dataList}'); // デバッグ用
      setState(() {
        stockDataList = dataList;
        //fetchThirdDataList = dataList.skip(2).toList();
        fetchThirdDataList = List.from(dataList.skip(2));
        totalPurchaseValue = _calculateTotalPurchaseValue(stockData.toList()); // ここで合計を計算
        totalMarketCapValue = _calculateTotalMarketCapValue(dataList.skip(2).toList(), stockData);
        differenceTotal = totalMarketCapValue - totalPurchaseValue;

        final differenceSignTotal = differenceTotal >= 0 ? '' : '-'; // Calculate total market cap
        _dataLoaded = dataList.isNotEmpty;
      });
    } catch (e) {
      print("JSON デコードエラー: $e");
      // エラーメッセージをユーザーに表示する (例: SnackBar)
      if (mounted) {
        // mountedチェックを追加
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データの取得に失敗しました: $e')));
      }
    } finally {
      // --- ローディング状態を解除 ---
      if (mounted) {
        // mountedチェックを追加
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Column(
              children: [
                _dataLoaded // _dataLoaded の値に基づいて表示を切り替え
                    ? FixedTopSection(dataList: stockDataList)
                    : const SizedBox.shrink(), // データがロードされていない場合は非表示

                _dataLoaded // _dataLoaded の値に基づいて表示を切り替え
                    ? FixedSecondSection(
                      dataList: stockData,
                      differenceTotal: differenceTotal,
                      totalPurchaseValue: totalPurchaseValue,
                      totalMarketCapValue: totalMarketCapValue,
                    )
                    : const SizedBox.shrink(), // データがロードされていない場合は非表示
                Expanded(
                  child:
                      !_dataLoaded
                          ? const Center(child: CircularProgressIndicator())
                          : _showInputScreen
                          ? const Center(child: Text('初期データを入力して保存してください。'))
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Text(
                                    '保存された株価データ:',
                                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                                  ),
                                  ElevatedButton(onPressed: _showAddDialog, child: const Text('追加')),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              stockData.isEmpty
                                  ? const Text('まだデータは保存されていません。')
                                  : Expanded(
                                    child: GridView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 5,
                                        crossAxisSpacing: 18.0,
                                        mainAxisSpacing: 8.0,
                                        childAspectRatio: 1.0,
                                      ),
                                      itemCount: stockData.length,
                                      itemBuilder: (context, int index) {
                                        // --- fetchThirdDataList にインデックスが存在するか確認 ---
                                        if (index >= fetchThirdDataList.length) {
                                          // まだ株価データが取得されていない新しい項目
                                          // または何らかの理由でデータが不足している場合
                                          final stock = stockData[index]; // 設定データは存在するはず
                                          return Card(
                                            margin: EdgeInsets.all(0.0),
                                            color: Colors.grey.shade300, // ローディング中を示す色
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center, // 中央寄せなど
                                                children: [
                                                  Text('Code: ${stock['Code'] ?? 'N/A'}'),
                                                  SizedBox(height: 8),
                                                  Text('株価取得中...'), // ローディングメッセージ
                                                  // FittedBoxで囲むか、内容を調整する必要がある
                                                ],
                                              ),
                                            ),
                                          );
                                        }

                                        final stock = stockData[index];
                                        final fatchData = fetchThirdDataList[index];
                                        final shares = stock['Shares'] ?? 0;

                                        final unitPrice = stock['Unitprice'] ?? 0;
                                        final purchaseValue = shares * unitPrice;

                                        final marketCapString = (fatchData['price']?.toString() ?? '0.0').replaceAll(
                                          ',',
                                          '',
                                        );
                                        final marketCapValue = (double.tryParse(marketCapString) ?? 0.0) * shares;

                                        final difference = marketCapValue - purchaseValue;
                                        final formattedDifference = NumberFormat('#,###.##').format(difference.abs());
                                        final differenceSign = difference >= 0 ? '' : '-';

                                        Color cardColor;
                                        // ignore: format
                                        cardColor =
                                            fatchData['ratio'].toString().startsWith('-') == false
                                                ? Colors.red
                                                : Colors.greenAccent; // 最初のカードの色

                                        return Card(
                                          color: cardColor,
                                          margin: EdgeInsets.all(0.0),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            // --- Column全体をFittedBoxでラップ ---
                                            child: FittedBox(
                                              fit: BoxFit.contain, // 子をアスペクト比を保ったまま、境界内に収まるようにスケーリング
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize:
                                                    MainAxisSize.min, // FittedBox内でColumnが自身のコンテンツに必要なサイズになるように
                                                children: [
                                                  // --- Textウィジェット (maxLines/overflowはFittedBoxを使うなら不要な場合も) ---
                                                  // FittedBoxが全体を縮小するため、個々のTextのoverflow処理は
                                                  // 見た目に影響しなくなる可能性がありますが、念のため残しても良いでしょう。
                                                  Text('Code: ${fatchData['code']?.toString() ?? 'コードなし'}',style: TextStyle(fontWeight: FontWeight.bold)),
                                                  SizedBox(height: 0),
                                                  Text('Name: ${fatchData['name']?.toString() ?? '名前なし'}'),
                                                  SizedBox(height: 0),
                                                  Text('Price: ${fatchData['price']?.toString() ?? '価格なし'}'),
                                                  SizedBox(height: 0),
                                                  Text('Ratio: ${fatchData['ratio']?.toString() ?? '比率なし'}'),
                                                  SizedBox(height: 0),
                                                  Text(
                                                    'Percent: ${fatchData['percent']?.toString() ?? 'Percent not found'}%',
                                                  ),
                                                  SizedBox(height: 0),
                                                  Text(
                                                    'Shares: ${stock['Shares']?.toString()}   Unit Price: ￥${stock['Unitprice']?.toString()}',
                                                  ),
                                                  SizedBox(height: 0),
                                                  Text('Purchase: ￥${NumberFormat('#,###.##').format(purchaseValue)}'),
                                                  SizedBox(height: 0),
                                                  Text(
                                                    'Market Cap: ￥${NumberFormat('#,###.##').format(marketCapValue)}',
                                                  ),
                                                  SizedBox(height: 0),
                                                  Text(
                                                    'Difference: $differenceSign￥$formattedDifference',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  // --- Spacerの挙動に注意 ---
                                                  // FittedBox内でのSpacerの挙動は期待通りにならない場合があります。
                                                  // ColumnのサイズがFittedBoxによって決定されるため、
                                                  // Spacerが意図したスペースを確保できない可能性があります。
                                                  // 固定のSizedBoxなどで代替するか、Spacerなしのレイアウトを検討する必要があるかもしれません。
                                                  //const Spacer(),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit),
                                                        onPressed: () => _showEditDialog(index),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete),
                                                        color: const Color.fromARGB(255, 1, 59, 250),
                                                        onPressed: () => _deleteDataItem(index),
                                                      ),
                                                    ],
                                                  ),

                                                  //),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                            ],
                          ),
                ),

                ElevatedButton(
                  onPressed: _deleteAllData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('全データを削除', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      ),
      // --- ここに FloatingActionButton を追加 ---
      floatingActionButton: FloatingActionButton(
        // --- onPressed ロジックは IconButton と同じ ---
        onPressed: (_isLoading || !_dataLoaded) ? null : _fetchData,
        tooltip: '株価を更新',
        // --- ローディング中はインジケータを表示（オプション） ---
        child:
            _isLoading
                ? const SizedBox(
                  // FABに収まるようにサイズ指定
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white, // FAB背景色に合わせた色
                    strokeWidth: 2.0,
                  ),
                )
                : const Icon(Icons.refresh), // 通常は更新アイコン
      ),
      // -----------------------------------------
    );
  }
}
