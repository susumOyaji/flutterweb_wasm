import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:js_interop';
import 'package:flutter/material.dart';
// 以下は実際のファイルパスに合わせてください
import 'fixed_top_section.dart';
import 'fixed_second_section.dart';
// import 'fixed_third_section.dart'; // fixed_third_section.dart は GridView になったので不要かも
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // min 関数を使うために追加

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
  List<Map<String, dynamic>> stockData = []; // 保存された設定データ (Code, Shares, Unitprice)
  List<dynamic> stockDataList = [];         // fetch結果全体 (Top2 + ThirdData)
  List<dynamic> fetchTopDataList = [];      // fetch結果のTop2
  List<dynamic> fetchThirdDataList = [];    // fetch結果の株価詳細リスト (stockDataに対応)
  List<Map<String, dynamic>> fetchThirdStorageDataList = []; // 仮のリスト名
  List<Map<String, dynamic>> _savedData = [];


  double totalPurchaseValue = 0;
  double totalMarketCapValue = 0;
  double differenceTotal = 0;

  final String _storageKey = 'stock_data';
  bool _showInputScreen = false; // 初期データ入力画面表示フラグ
  bool _isLoading = false;       // ローディング状態フラグ (主にFABの制御用)
  // bool _dataLoaded = false;   // FutureBuilder が状態を管理するので不要になる場合がある

  // FutureBuilder で使用する Future
  Future<void>? _fetchDataFuture;
  Object? _lastFetchError; // fetch のエラーを保持する変数 (オプション)


  @override
  void initState() {
    super.initState();
    // 最初に保存データをロードし、その後で株価データを取得する Future を開始
    _loadSavedDataAndFetchInitial();
  }

  // initState から呼び出す初期化処理
  Future<void> _loadSavedDataAndFetchInitial() async {
    await _loadSavedData(); // 保存データをロード (これにより stockData がセットされる)
    // マウントされているか確認し、保存データがあれば最初のデータ取得を開始
    if (mounted && stockData.isNotEmpty) {
      setState(() {
        _fetchDataFuture = _fetchData(); // 最初の fetch を実行
      });
    } else if (mounted && stockData.isEmpty && !_showInputScreen) {
       // 保存データが空で、入力画面でもない場合（＝削除後など）
       // データがない状態を明確にする（例: 空のリストをセット）
       setState(() {
          stockDataList = [];
          fetchTopDataList = [];
          fetchThirdDataList = [];
          totalPurchaseValue = 0;
          totalMarketCapValue = 0;
          differenceTotal = 0;
          _fetchDataFuture = Future.value(); // 空の完了済み Future をセット
       });
    }
    // _showInputScreen == true の場合は、ユーザーの入力待ちなので何もしない
  }

  // 保存データをロードするメソッド (変更なし)
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);
    if (savedJson != null) {
      // setState はここでは呼ばず、呼び出し元で処理する方が FutureBuilder と組み合わせやすいかも
      // または、ここで setState しても良いが、その後の fetch 開始タイミングに注意
      stockData = (jsonDecode(savedJson) as List).cast<Map<String, dynamic>>();
      _showInputScreen = false;
      print('_loadSavedData: Loaded ${stockData.length} items');
    } else {
      stockData = []; // データがない場合は空リストに
      _showInputScreen = true;
      // initState でなければダイアログ表示
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //    if (mounted && _showInputScreen) _showInitialInputDialog();
      // });
       print('_loadSavedData: No data found, show input screen');
       // 初期ダイアログは build メソッド側で状態を見て表示するか、
       // initState完了後に表示するのが安全
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _showInputScreen) {
             _showInitialInputDialog();
          }
       });
    }
    // setState(() {}); // 呼び出し元で setState するか、ここで状態を更新
  }

  // --- データ取得メソッド (_fetchData) ---
  // FutureBuilderで使うため、内部でのsetStateはUIデータ更新に必要。
  // エラーは FutureBuilder で検知できるよう工夫するか、状態変数に持つ。
  Future<void> _fetchData() async {
    // ローディング状態のチェックと設定
    if (_isLoading) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _lastFetchError = null; // エラー状態をリセット
      });
    }

    // 保存されているデータがなければ何もしない
    if (stockData.isEmpty) {
       print('_fetchData: No stock codes to fetch.');
       if (mounted) {
          setState(() {
             _isLoading = false;
             // データがない状態をUIに反映
             stockDataList = [];
             fetchTopDataList = [];
             fetchThirdDataList = [];
             totalPurchaseValue = 0;
             totalMarketCapValue = 0;
             differenceTotal = 0;
          });
       }
       return; // 重要: データがない場合はここで処理を終了
    }


    String codesJson = jsonEncode(stockData.map((item) => item['Code'] as String).toList());
    print('_fetchData fetching for codes: ${codesJson}');

    try {
      String result = await fetchStockData(codesJson);
      List<dynamic> dataList = jsonDecode(result);
      print('fetchStockData raw result: ${dataList}'); // デバッグ用

      // --- データ取得成功時の処理 ---
      if (mounted) {
        setState(() {
          stockDataList = dataList;
          // skip(2) する前に dataList の長さを確認する方が安全
          if (dataList.length > 2) {
             fetchTopDataList = dataList.sublist(0, 2);
             fetchThirdDataList = List.from(dataList.skip(2));
          } else if (dataList.length > 0){
             // TopデータはあるがThirdデータがない場合など
             fetchTopDataList = dataList; // とりあえず全部Topに入れる（仕様による）
             fetchThirdDataList = [];
          } else {
             fetchTopDataList = [];
             fetchThirdDataList = [];
          }

          // 計算処理 (fetchThirdDataList の長さと stockData の長さが一致するか確認が必要)
          // min を使って安全な長さでループする
          final int calcLength = min(fetchThirdDataList.length, stockData.length);

          totalPurchaseValue = _calculateTotalPurchaseValue(stockData.sublist(0, calcLength));
          totalMarketCapValue = _calculateTotalMarketCapValue(
             fetchThirdDataList.sublist(0, calcLength), // fetch結果
             stockData.sublist(0, calcLength)  // 設定データ
          );
          differenceTotal = totalMarketCapValue - totalPurchaseValue;

          // _dataLoaded フラグは FutureBuilder が管理するので基本不要だが、
          // 内部のUI要素で使うなら残しても良い
          // _dataLoaded = stockDataList.isNotEmpty;
        });
      }
    } catch (e, stacktrace) { // stacktraceもキャッチするとデバッグしやすい
      print("データ取得またはJSONデコードエラー: $e");
      print("Stacktrace: $stacktrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データの取得に失敗しました: $e')));
        // エラー状態をセット (FutureBuilderで使う場合)
        setState(() {
           _lastFetchError = e;
           // エラー発生時はデータをクリアするか、古いデータを表示し続けるか選択
           // fetchThirdDataList = []; // 例えばクリアする
        });
        // FutureBuilder にエラーを伝えるために再スローする場合
        // throw e;
      }
    } finally {
      // --- ローディング状態を解除 ---
       if (mounted) {
          setState(() {
             _isLoading = false;
          });
       }
    }
  }

  // --- リフレッシュ処理 ---
  // FABなどから呼ばれる
  void _triggerRefresh() {
    // isLoading チェックは _fetchData 内で行われるので不要かもしれない
    if (!_isLoading) {
       print("Refresh triggered");
       setState(() {
         _fetchDataFuture = _fetchData(); // 新しい Future をセットして再実行 & 追跡開始
       });
    }
  }


  // --- 保存・編集・追加・削除メソッド ---
  // 変更点: 処理の最後に直接 _triggerRefresh() を呼ぶ (または _fetchData() を呼んで Future を更新)

  Future<void> _saveInitialData(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();
    // 初期データなので、既存のものは上書きまたは無視して新しいリストを作成
    stockData = [newData]; // 新しいデータのみのリストにする
    final jsonData = jsonEncode(stockData);
    await prefs.setString(_storageKey, jsonData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('初期データが保存されました！')));
      setState(() {
        _showInputScreen = false; // 入力画面を閉じる
      });
      _triggerRefresh(); // 保存後にデータをフェッチ
    }
  }

  Future<void> _saveEditedData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(stockData); // 現在の stockData を保存
    await prefs.setString(_storageKey, jsonData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('株価データが保存されました！')));
      // 編集保存だけならリフレッシュ不要かもしれないが、コードが変わった場合はリフレッシュ推奨
      // _triggerRefresh(); // 必要ならリフレッシュ
    }
  }

  Future<void> _editDataItem(int index, Map<String, dynamic> newData) async {
    // コードが変更されたかチェック
    bool codeChanged = false;
    if (mounted) {
       setState(() {
         codeChanged = stockData[index]['Code'] != newData['Code'];
         stockData[index] = newData;
       });
       await _saveEditedData(); // 編集内容を保存
       if (codeChanged) {
         // コードが変更された場合は、関連する株価データが変わる可能性が高いのでリフレッシュ
         _triggerRefresh();
       }
    }
  }

   void _addStockData(Map<String, dynamic> newStock) {
    if (mounted) {
      setState(() {
         stockData.add(newStock); // リストに追加
      });
      _saveEditedData(); // 追加したリストを保存
      _triggerRefresh();   // 新しいコードのデータを取得するためにリフレッシュ
    }
   }

   Future<void> _deleteDataItem(int index) async {
      if (mounted) {
         setState(() {
           stockData.removeAt(index); // リストから削除
         });
         await _saveEditedData(); // 削除後のリストを保存
         _triggerRefresh();   // リストが変わったので再計算と表示更新のためにリフレッシュ
      }
   }

   Future<void> _deleteAllData() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存されたデータをすべて削除しました！')));
         setState(() {
           stockData.clear();
           stockDataList.clear();
           fetchTopDataList.clear();
           fetchThirdDataList.clear();
           totalPurchaseValue = 0;
           totalMarketCapValue = 0;
           differenceTotal = 0;
           _fetchDataFuture = Future.value(); // 空の完了済み Future
           _lastFetchError = null;
           _showInputScreen = true; // 初期入力画面に戻す
         });
         // 必要なら初期入力ダイアログを再表示
         WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted && _showInputScreen) {
                 _showInitialInputDialog();
             }
         });
      }
   }


  // --- ダイアログ表示メソッド (変更なし) ---
  //void _showEditDialog(int index) {/* ... */}
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

  //void _showInitialInputDialog() {/* ... */}
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
  //void _showAddDialog() {/* ... */}
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

  // --- 計算メソッド (変更なし) ---
  double _calculateTotalPurchaseValue(List<dynamic> currentStockData) {
     double total = 0;
     for (var item in currentStockData) { // 引数を現在の stockData に変更
       final shares = item['Shares'] ?? 0;
       final unitPrice = item['Unitprice'] ?? 0;
       total += shares * unitPrice;
     }
     return total;
   }

  double _calculateTotalMarketCapValue(List<dynamic> fetchedThirdData, List<Map<String, dynamic>> currentStockData) {
     double total = 0;
     // fetchedThirdData と currentStockData の短い方の長さに合わせる
     final int length = min(fetchedThirdData.length, currentStockData.length);
     for (var i = 0; i < length; i++) {
       final item = fetchedThirdData[i] as Map<String, dynamic>; // fetch結果
       final stockConfig = currentStockData[i]; // 設定

       final shares = stockConfig['Shares'] ?? 0;
       final marketCapString = (item['price']?.toString() ?? '0.0').replaceAll(',', '');
       final marketCapValue = (double.tryParse(marketCapString) ?? 0.0) * shares;
       total += marketCapValue;
     }
     return total;
   }


  // --- JS呼び出しラッパー (変更なし) ---
  Future<String> fetchStockData(String codesJson) async {
    final jsResult = await fetch_data_rust(codesJson).toDart;
    print("jsResult Type: ${jsResult.runtimeType} - Value: $jsResult");
    return jsResult.toString();
  }


  // --- build メソッド ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Web 株価データ'),
      ),
      body: SafeArea(
        // --- FutureBuilderでラップ ---
        child: FutureBuilder<void>(
          future: _fetchDataFuture, // 追跡する Future を指定
          builder: (context, snapshot) {

            // --- ローディング状態の表示 ---
            // snapshot.connectionState と _isLoading を組み合わせることも可能
            if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // --- エラー状態の表示 (エラーを state に持つか、Futureがエラーを投げる場合) ---
            if (snapshot.hasError || _lastFetchError != null) {
              return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Text('エラーが発生しました: ${snapshot.error ?? _lastFetchError}'),
                          ElevatedButton(
                              onPressed: _triggerRefresh,
                              child: Text('再試行')
                          )
                      ]
                  )
              );
            }

            // --- 完了状態 (エラーなし) ---
            // Futureが完了したら、既存のロジックでUIを構築する
            // _showInputScreen や stockData.isEmpty などに基づいて表示を切り替える
            return OrientationBuilder(
              builder: (context, orientation) {
                // データロード完了後でも、初期入力画面が表示されるべきかチェック
                if (_showInputScreen) {
                   // _showInitialInputDialog() は initState で呼ばれるのでここでは不要かも
                   // Center表示だけで良いかもしれない
                    return const Center(child: Text('初期データを入力して保存してください。'));
                }

                // データロード完了後、データがある場合のメインUI
                return Column(
                  children: [
                    // データが実際にロードされたか（fetch成功後）も考慮
                    // stockDataList などが空でないかで判断する方がより正確かも
                    if (stockDataList.isNotEmpty) ...[
                       FixedTopSection(dataList: fetchTopDataList), // Topデータを渡す
                       FixedSecondSection(
                         // dataList: stockData, // これは設定データ
                         differenceTotal: differenceTotal,
                         totalPurchaseValue: totalPurchaseValue,
                         totalMarketCapValue: totalMarketCapValue,
                       ),
                    ] else if (stockData.isNotEmpty) ...[
                       // fetch 前、または fetch 失敗/結果なしだが、stockData はある場合
                       // ローディング中表示は FutureBuilder が担当するので、ここでは空かメッセージ
                       // または、FixedSecondSection だけ表示するなど仕様による
                       FixedSecondSection(
                         differenceTotal: 0,
                         totalPurchaseValue: _calculateTotalPurchaseValue(stockData), // 保存データだけで計算
                         totalMarketCapValue: 0, // マーケットキャップは不明
                       ),

                    ] else ...[
                       // stockData も空の場合 (データ削除後など)
                       SizedBox.shrink(), // 何も表示しない
                    ],

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding( // RowにPadding追加
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Text(
                                  '保存された株価データ:',
                                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8), // ボタンとの間隔
                                ElevatedButton(
                                   // データが空でも追加はできるようにする
                                   onPressed: _isLoading ? null : _showAddDialog, // ローディング中は無効化
                                   child: const Text('追加')
                                ),
                              ],
                            ),
                          ),
                          //const SizedBox(height: 8.0), // Paddingがあるので不要かも
                          stockData.isEmpty
                              ? const Expanded(
                                  child: Center(child: Text('「追加」ボタンからデータを登録してください。')),
                                )
                              : Expanded(
                                  child: GridView.builder(
                                    // physics: const AlwaysScrollableScrollPhysics(), // RefreshIndicatorないので不要
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      // 画面サイズに応じて crossAxisCount を変更する例
                                      crossAxisCount: 5, // ここを動的に変更しても良い
                                      crossAxisSpacing: 4.0, // 間隔を狭める
                                      mainAxisSpacing: 4.0,  // 間隔を狭める
                                      childAspectRatio: 1.1, // 高さを少し増やす (1.0 -> 1.1)
                                    ),
                                    // itemCount は stockData に基づく
                                    itemCount: stockData.length,
                                    itemBuilder: (context, int index) {
                                      // --- RangeError を防ぐチェック ---
                                      if (index >= fetchThirdDataList.length) {
                                        // データがまだロードされていないか、同期ズレ
                                        final stock = stockData[index];
                                        return Card(
                                          margin: EdgeInsets.all(2.0), // マージン調整
                                          color: Colors.grey.shade300,
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0), // パディング調整
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                 FittedBox(child: Text('Code: ${stock['Code'] ?? 'N/A'}')), // FittedBox追加
                                                 const SizedBox(height: 4),
                                                 const FittedBox(child: Text('Loading...')), // FittedBox追加
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      // --- データがある場合の処理 ---
                                      final stock = stockData[index];
                                      final fatchData = fetchThirdDataList[index];
                                      // ... (計算ロジック) ...
                                      final shares = stock['Shares'] ?? 0;
                                      final unitPrice = stock['Unitprice'] ?? 0;
                                      final purchaseValue = shares * unitPrice;
                                      final marketCapString = (fatchData['price']?.toString() ?? '0.0').replaceAll(',', '');
                                      final marketCapValue = (double.tryParse(marketCapString) ?? 0.0) * shares;
                                      final difference = marketCapValue - purchaseValue;
                                      final formattedDifference = NumberFormat('#,###').format(difference.abs());
                                      final differenceSign = difference >= 0 ? '' : '-';

                                      Color cardColor;
                                      // ignore: format
                                      cardColor = fatchData['ratio'].toString().startsWith('-') == false
                                           ? Colors.red // 少し薄い色に
                                           : Colors.green; // 少し薄い色に

                                      // --- Card の中身 ---
                                      return Card(
                                        color: cardColor,
                                        margin: EdgeInsets.all(2.0), // マージン調整
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0), // パディング調整
                                          // SingleChildScrollView や FittedBox を使う
                                          // ここでは FittedBox を試す
                                          child: FittedBox(
                                            fit: BoxFit.contain,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                 // テキストサイズは FittedBox が調整するので不要かも
                                                 Text('Code: ${fatchData['code']?.toString() ?? 'N/A'}'),
                                                 Text('Name: ${fatchData['name']?.toString() ?? 'N/A'}', overflow: TextOverflow.ellipsis), // Nameは省略記号
                                                 Text('Price: ${fatchData['price']?.toString() ?? 'N/A'}'),
                                                 Text('Ratio: ${fatchData['ratio']?.toString() ?? 'N/A'}'),
                                                 Text('%: ${fatchData['percent']?.toString() ?? 'N/A'}'), // Percent ラベル短縮
                                                 Text('Shr: ${stock['Shares']?.toString()}@${stock['Unitprice']?.toString()}', overflow: TextOverflow.ellipsis), // Shares ラベル短縮
                                                 Text('Prch: ￥${NumberFormat('#,###').format(purchaseValue)}'),
                                                 Text('Mrkt: ￥${NumberFormat('#,###').format(marketCapValue)}'),
                                                 Text(
                                                   'Diff: $differenceSign￥${NumberFormat('#,###').format(difference.abs())}',
                                                   style: TextStyle(fontWeight: FontWeight.bold),
                                                 ),
                                                 Row(
                                                   mainAxisAlignment: MainAxisAlignment.end,
                                                   children: [
                                                     // IconButton は FittedBox で小さくなりすぎる可能性
                                                     // InkWell や GestureDetector + Icon の方が良いかも
                                                     IconButton(
                                                       iconSize: 18, // サイズ指定してもFittedBoxの影響受ける
                                                       visualDensity: VisualDensity.compact, // 密度調整
                                                       padding: EdgeInsets.zero,
                                                       constraints: BoxConstraints(),
                                                       icon: const Icon(Icons.edit),
                                                       onPressed: () => _showEditDialog(index),
                                                     ),
                                                     IconButton(
                                                       iconSize: 18,
                                                       visualDensity: VisualDensity.compact,
                                                       padding: EdgeInsets.zero,
                                                       constraints: BoxConstraints(),
                                                       icon: const Icon(Icons.delete),
                                                       color: Colors.black54, // 色調整
                                                       onPressed: () => _deleteDataItem(index),
                                                     ),
                                                   ],
                                                 ),
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
                    // --- 全データ削除ボタン ---
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _deleteAllData, // ローディング中は無効化
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('全データを削除', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      // --- フローティングアクションボタン ---
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _triggerRefresh, // ローディング中は無効化
        tooltip: '株価を更新',
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }
}

// --- ダミーの子ウィジェット（実際のファイルからインポートしてください） ---
class FixedTopSection extends StatelessWidget {
  final List<dynamic> dataList; // 型を明確に (例: List<Map<String, dynamic>>)
  const FixedTopSection({Key? key, required this.dataList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // dataList の最初の2要素を使ってUIを構築 (存在チェックが必要)
    final topData1 = dataList.isNotEmpty ? dataList[0] : null;
    final topData2 = dataList.length > 1 ? dataList[1] : null;
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.blue[50],
      child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceAround,
         children: [
            Text('Top1: ${topData1?['name'] ?? 'N/A'} (${topData1?['price'] ?? 'N/A'})'),
            Text('Top2: ${topData2?['name'] ?? 'N/A'} (${topData2?['price'] ?? 'N/A'})'),
         ]
      ),
    );
  }
}

class FixedSecondSection extends StatelessWidget {
 // final List<Map<String, dynamic>> dataList; // stockData (設定) が渡されていたはず
  final double differenceTotal;
  final double totalPurchaseValue;
  final double totalMarketCapValue;

  const FixedSecondSection({
    Key? key,
   // required this.dataList, // 不要かも？合計値だけ受け取る
    required this.differenceTotal,
    required this.totalPurchaseValue,
    required this.totalMarketCapValue
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     final differenceSign = differenceTotal >= 0 ? '+' : '-';
     final formattedDifference = NumberFormat('#,###.##').format(differenceTotal.abs());
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.green[50],
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceAround,
         children: [
           Text('購入合計: ￥${NumberFormat('#,###').format(totalPurchaseValue)}'),
           Text('評価額合計: ￥${NumberFormat('#,###').format(totalMarketCapValue)}'),
           Text(
              '差額合計: $differenceSign￥${NumberFormat('#,###').format(differenceTotal.abs())}',
              style: TextStyle(color: differenceTotal >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
           ),
         ]
      ),
    );
  }
}

// --- 他のメソッド (_showEditDialog, etc.) は省略 ---