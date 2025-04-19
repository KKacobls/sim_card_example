import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // 需要添加此依賴到 pubspec.yaml

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ .env 載入成功");
  } catch (e) {
    debugPrint("⚠️ .env 載入失敗: $e");
    // 提供默認值，避免後續使用時出錯
    dotenv.env['DISCORD_BOT_TOKEN'] = '';
    dotenv.env['CHANNELS'] = '';
  }

  runApp(const MyApp());
}

/// 根 Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIM + POST Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeWrapper(),
    );
  }
}

/// Scaffold + Drawer 切換兩頁
class HomeWrapper extends StatefulWidget {
  const HomeWrapper({Key? key}) : super(key: key);

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

// 1. 在 _HomeWrapperState 中新增日誌頁面和索引
class _HomeWrapperState extends State<HomeWrapper> {
  int _selectedIndex = 0; // 0: SIM 資訊頁, 1: POST Example, 2: 日誌頁
  Map<String, Map<String, String>> _versions = {};

  late SimInfoPage simInfoPage;
  late PostExamplePage postExamplePage;
  late LogsPage logsPage;

  @override
  void initState() {
    super.initState();
    _loadVersionsFromPrefs();
    simInfoPage = SimInfoPage(
      onGetVersions: () => _versions,
      onDoPostSimData: _doPostWithSimData, 
    );
    postExamplePage = PostExamplePage(
      onGetVersions: () => _versions,
      onSaveVersions: _saveVersionsToPrefs,
      onVersionsChanged: (newVersions) {
        setState(() {
          _versions = newVersions;
        });
      },
      onDoPost: _doPostWithVersionJson,
    );
    logsPage = const LogsPage();
  }
  
  // 2. 修改 _doPostWithVersionJson 方法以記錄日誌
  Future<String> _doPostWithVersionJson(String versionName) async {
    final data = _versions[versionName];
    if (data == null) {
      return "找不到版本 '$versionName' 或尚未儲存";
    }

    final url = (data["url"] ?? "").trim();
    if (url.isEmpty) {
      return "版本 '$versionName' 中的 URL 為空";
    }

    // 解析 headers
    late Map<String, String> headersMap;
    try {
      final decoded = jsonDecode(data["headers"] ?? "{}") as Map<String, dynamic>;
      headersMap = decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return "版本 '$versionName' 的 headers JSON 解析失敗: $e";
    }
    // 解析 data["jsonData"]
    late Object? jsonDataObj;
    try {
      jsonDataObj = jsonDecode(data["jsonData"] ?? "{}");
    } catch (e) {
      return "版本 '$versionName' 的 JSON Data 解析失敗: $e";
    }

    String responseResult = "";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headersMap,
        body: jsonEncode(jsonDataObj),
      );
      responseResult = "狀態碼: ${response.statusCode}\n回傳值: ${response.body}";
      
      // 記錄日誌
      await LogsService.addLog(LogEntry(
        url: url,
        headers: data["headers"] ?? "{}",
        jsonData: data["jsonData"] ?? "{}",
        versionName: versionName,
        timestamp: DateTime.now(),
        responseStatus: responseResult,
      ));
      
      return responseResult;
    } catch (e) {
      responseResult = "POST 發生錯誤: $e";
      
      // 同樣記錄錯誤
      await LogsService.addLog(LogEntry(
        url: url,
        headers: data["headers"] ?? "{}",
        jsonData: data["jsonData"] ?? "{}",
        versionName: versionName,
        timestamp: DateTime.now(),
        responseStatus: responseResult,
      ));
      
      return responseResult;
    }
  }

  // 3. 修改 _doPostWithSimData 方法以記錄日誌
  Future<String> _doPostWithSimData(String versionName, List<Map<String, dynamic>> simCards) async {
    final data = _versions[versionName];
    if (data == null) {
      return "找不到版本 '$versionName' 或尚未儲存";
    }

    final url = (data["url"] ?? "").trim();
    if (url.isEmpty) {
      return "版本 '$versionName' 中的 URL 為空";
    }

    // 解析 headers
    late Map<String, String> headersMap;
    try {
      final decoded = jsonDecode(data["headers"] ?? "{}") as Map<String, dynamic>;
      headersMap = decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return "版本 '$versionName' 的 headers JSON 解析失敗: $e";
    }

    // 將 simCards 轉成 JSON 字串
    final simJsonString = jsonEncode(simCards);

    // 依你需求: {"content": <sim卡字串>}
    final bodyObj = {
      "content": simJsonString,
    };
    
    // 轉為JSON字串用於日誌記錄
    final jsonDataString = jsonEncode(bodyObj);

    String responseResult = "";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headersMap,
        body: jsonEncode(bodyObj),
      );
      responseResult = "狀態碼: ${response.statusCode}\n回傳值: ${response.body}";
      
      // 記錄日誌
      await LogsService.addLog(LogEntry(
        url: url,
        headers: data["headers"] ?? "{}",
        jsonData: jsonDataString,
        versionName: versionName,
        timestamp: DateTime.now(),
        responseStatus: responseResult,
      ));
      
      return responseResult;
    } catch (e) {
      responseResult = "POST 發生錯誤: $e";
      
      // 同樣記錄錯誤
      await LogsService.addLog(LogEntry(
        url: url,
        headers: data["headers"] ?? "{}",
        jsonData: jsonDataString,
        versionName: versionName,
        timestamp: DateTime.now(),
        responseStatus: responseResult,
      ));
      
      return responseResult;
    }
  }
  
  // 4. 修改 build 方法以添加日誌選項到 Drawer 中
  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_selectedIndex == 0) {
      body = simInfoPage;
    } else if (_selectedIndex == 1) {
      body = postExamplePage;
    } else {
      body = logsPage;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SIM + POST Example')),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('選單', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              title: const Text('SIM 資訊'),
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
              selected: _selectedIndex == 0,
            ),
            ListTile(
              title: const Text('POST Example'),
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
              selected: _selectedIndex == 1,
            ),
            ListTile(
              title: const Text('POST 日誌'),
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
              selected: _selectedIndex == 2,
            ),
          ],
        ),
      ),
      body: body,
    );
  }

/// 儲存版本資料到 SharedPreferences
Future<void> _saveVersionsToPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('versions', jsonEncode(_versions));
  debugPrint("✅ 版本資料已儲存");
}

/// 從 SharedPreferences 載入版本資料
Future<void> _loadVersionsFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString('versions');
  if (jsonStr != null) {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final parsed = decoded.map((key, value) =>
          MapEntry(key, Map<String, String>.from(value)));
      setState(() {
        _versions = parsed;
      });
      debugPrint("✅ 載入版本資料成功: ${_versions.length} 筆");
    } catch (e) {
      debugPrint("❌ 版本資料解析失敗: $e");
    }
  }
}
}
/// 第一欄 (主畫面) - 顯示 SIM 卡資訊 + 下方可選版本, 重新讀取, POST
/// 這次在 POST 時 -> json_data={"content": <simCards的JSON>}
class SimInfoPage extends StatefulWidget {
  final Map<String, Map<String, String>> Function() onGetVersions;
  final Future<String> Function(String versionName, List<Map<String, dynamic>> simCards) onDoPostSimData;

  const SimInfoPage({
    Key? key,
    required this.onGetVersions,
    required this.onDoPostSimData,
  }) : super(key: key);

  @override
  State<SimInfoPage> createState() => _SimInfoPageState();
}

class _SimInfoPageState extends State<SimInfoPage> {
  static const MethodChannel _channel = MethodChannel('com.example.sim_card_example/sim');
  List<Map<String, dynamic>> _simCards = [];
  bool _isLoading = false;
  String _simInfoStatus = '';
  String _postResult = '';

  // 用來選取要 POST 的版本
  String? _selectedVersion;

  @override
  void initState() {
    super.initState();
    _loadSimData();
  }

  /// 讀取 SIM 資訊
  Future<void> _loadSimData() async {
    setState(() {
      _isLoading = true;
      _simInfoStatus = '正在讀取 SIM 卡資料...';
    });

    try {
      final result = await _channel.invokeMethod('getSimData');
      if (result is List) {
        final parsed = result.map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {
          _simCards = parsed;
          _simInfoStatus = '讀取完成，共 ${parsed.length} 筆 SIM 資訊';
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _simInfoStatus = '讀取 SIM 卡失敗: $e';
      });
    }

    setState(() => _isLoading = false);
  }

  /// 在此把 SIM 卡資訊包成 {"content": sim卡JSON} 發送
  Future<void> _doPost() async {
    if (_selectedVersion == null) {
      setState(() {
        _postResult = '請先選擇版本！';
      });
      return;
    }
    // 調用父層方法 onDoPostSimData
    final msg = await widget.onDoPostSimData(_selectedVersion!, _simCards);
    setState(() {
      _postResult = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionsMap = widget.onGetVersions();
    final versionNames = versionsMap.keys.toList();

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: Text(_simInfoStatus))
                : _simCards.isEmpty
                    ? Center(child: Text(_simInfoStatus))
                    : ListView.builder(
                        itemCount: _simCards.length,
                        itemBuilder: (context, index) {
                          final sim = _simCards[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('''
=== SIM #$index ===
subscriptionId: ${sim["subscriptionId"]}
slotIndex:      ${sim["slotIndex"]}
displayName:    ${sim["displayName"]}
carrierName:    ${sim["carrierName"]}
iccId:          ${sim["iccId"]}
number:         ${sim["number"]}
countryIso:     ${sim["countryIso"]}
dataRoaming:    ${sim["dataRoaming"]}
isEmbedded:     ${sim["isEmbedded"]}
isOpportunistic:${sim["isOpportunistic"]}
                              '''),
                            ),
                          );
                        },
                      ),
          ),

          ElevatedButton(
            onPressed: _loadSimData,
            child: const Text("重新讀取"),
          ),
          const SizedBox(height: 8),

          // 版本下拉 + POST
          if (versionNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text("選擇版本以進行 POST"),
                value: _selectedVersion,
                items: versionNames.map((vName) {
                  return DropdownMenuItem(
                    value: vName,
                    child: Text(vName),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedVersion = newValue;
                    _postResult = '';
                  });
                },
              ),
            ),
          ElevatedButton(
            onPressed: _doPost,
            child: const Text("POST (SIM 資訊)"),
          ),

          if (_postResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black12,
              width: double.infinity,
              child: Text(_postResult),
            ),
        ],
      ),
    );
  }
}

/// 第二欄 - POST Example (可編輯, 儲存版本, 載入版本, POST)
class PostExamplePage extends StatefulWidget {
  final Map<String, Map<String, String>> Function() onGetVersions;
  final Future<void> Function() onSaveVersions;
  final void Function(Map<String, Map<String, String>> newVersions) onVersionsChanged;
  // 這裡用「原本的版本 JSON」(若要發訊息、非 SIM 資料)
  final Future<String> Function(String versionName) onDoPost;

  const PostExamplePage({
    Key? key,
    required this.onGetVersions,
    required this.onSaveVersions,
    required this.onVersionsChanged,
    required this.onDoPost,
  }) : super(key: key);

  @override
  State<PostExamplePage> createState() => _PostExamplePageState();
}

class _PostExamplePageState extends State<PostExamplePage> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _headersCtrl = TextEditingController();
  final TextEditingController _jsonCtrl = TextEditingController();
  final TextEditingController _versionNameCtrl = TextEditingController();

  String _responseInfo = '';
  String? _selectedVersion;

  Map<String, Map<String, String>> get versions => widget.onGetVersions();

  @override
  void initState() {
    super.initState();

    final discordToken = dotenv.env['DISCORD_BOT_TOKEN'] ?? '';
    final channels = dotenv.env['CHANNELS'] ?? '';

    if (discordToken.isEmpty || channels.isEmpty) {
      debugPrint('⚠️ .env 未正確提供 DISCORD_BOT_TOKEN 或 CHANNELS');
    }

    _urlCtrl.text = "https://discord.com/api/v9/channels/$channels/messages";
    _headersCtrl.text = jsonEncode({
      "Authorization": "Bot $discordToken",
      "Content-Type": "application/json"
    });
    _jsonCtrl.text = jsonEncode({
      "content": "Hello from Flutter PostExamplePage!"
    });
  }

  Future<void> _saveCurrentVersion() async {
    final name = _versionNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _responseInfo = "版本名稱不可為空白");
      return;
    }
    final newData = {
      "url": _urlCtrl.text,
      "headers": _headersCtrl.text,
      "jsonData": _jsonCtrl.text,
    };

    final newVersions = Map<String, Map<String, String>>.from(versions);
    newVersions[name] = newData;
    widget.onVersionsChanged(newVersions);
    await widget.onSaveVersions();
    setState(() {
      _responseInfo = "版本 '$name' 已儲存";
    });
  }

  void _loadVersion(String versionName) {
    final data = versions[versionName];
    if (data != null) {
      setState(() {
        _urlCtrl.text = data["url"] ?? '';
        _headersCtrl.text = data["headers"] ?? '';
        _jsonCtrl.text = data["jsonData"] ?? '';
        _responseInfo = "載入版本 '$versionName'";
      });
    }
  }

  Future<void> _doPost() async {
    if (_selectedVersion == null) {
      setState(() {
        _responseInfo = "請先選擇版本";
      });
      return;
    }
    final msg = await widget.onDoPost(_selectedVersion!);
    setState(() {
      _responseInfo = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionNames = versions.keys.toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: "URL"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _headersCtrl,
              decoration: const InputDecoration(labelText: "Headers (JSON)"),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _jsonCtrl,
              decoration: const InputDecoration(labelText: "JSON Data (JSON)"),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _versionNameCtrl,
              decoration: const InputDecoration(labelText: "版本名稱"),
            ),
            const SizedBox(height: 16),

            // 儲存版本 + 載入版本
            Row(
              children: [
                ElevatedButton(
                  onPressed: _saveCurrentVersion,
                  child: const Text("儲存版本"),
                ),
                const SizedBox(width: 16),
                if (versionNames.isNotEmpty)
                  DropdownButton<String>(
                    hint: const Text("載入版本"),
                    items: versionNames.map((name) {
                      return DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _loadVersion(val);
                      }
                    },
                  )
              ],
            ),
            const SizedBox(height: 16),

            // 下方可選擇要 POST 的版本
            if (versionNames.isNotEmpty)
              DropdownButton<String>(
                hint: const Text("選擇版本以 POST"),
                value: _selectedVersion,
                items: versionNames.map((vName) {
                  return DropdownMenuItem(
                    value: vName,
                    child: Text(vName),
                  );
                }).toList(),
                onChanged: (newVal) {
                  setState(() {
                    _selectedVersion = newVal;
                  });
                },
              ),
            ElevatedButton(
              onPressed: _doPost,
              child: const Text("POST"),
            ),

            const SizedBox(height: 16),
            Text(_responseInfo),
          ],
        ),
      ),
    );
  }
}
// 首先，創建一個 LogEntry 類來儲存每次 POST 的詳細資訊
class LogEntry {
  final String url;
  final String headers;
  final String jsonData;
  final String versionName;
  final DateTime timestamp;
  final String responseStatus; // 可選儲存回應狀態

  LogEntry({
    required this.url,
    required this.headers,
    required this.jsonData,
    required this.versionName,
    required this.timestamp,
    this.responseStatus = '',
  });

  // 轉換成 Map 用於儲存
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'headers': headers,
      'jsonData': jsonData,
      'versionName': versionName,
      'timestamp': timestamp.toIso8601String(),
      'responseStatus': responseStatus,
    };
  }

  // 從 Map 創建 LogEntry
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      url: json['url'] ?? '',
      headers: json['headers'] ?? '',
      jsonData: json['jsonData'] ?? '',
      versionName: json['versionName'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      responseStatus: json['responseStatus'] ?? '',
    );
  }
}

// 新增一個 LogsService 類來管理日誌
class LogsService {
  static const String _storageKey = 'post_logs';
  
  // 獲取所有日誌
  static Future<List<LogEntry>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logsString = prefs.getString(_storageKey);
    if (logsString == null || logsString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(logsString);
      return decoded.map((item) => LogEntry.fromJson(item)).toList();
    } catch (e) {
      debugPrint('解析日誌失敗: $e');
      return [];
    }
  }
  
  // 添加新日誌
  static Future<void> addLog(LogEntry log) async {
    final List<LogEntry> currentLogs = await getLogs();
    currentLogs.insert(0, log); // 新紀錄放在最前面
    
    // 限制日誌數量，避免過多
    if (currentLogs.length > 100) {
      currentLogs.removeRange(100, currentLogs.length);
    }
    
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(currentLogs.map((log) => log.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
  
  // 清除所有日誌
  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

// 日誌頁面
class LogsPage extends StatefulWidget {
  const LogsPage({Key? key}) : super(key: key);
  
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<LogEntry> _logs = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await LogsService.getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }
  
  Future<void> _clearLogs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認清除'),
        content: const Text('確定要清除所有日誌嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await LogsService.clearLogs();
              _loadLogs();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日誌已清除'))
              );
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POST 日誌'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: '重新載入',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearLogs,
            tooltip: '清除全部',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('暫無日誌記錄'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);
                    
                    return ExpansionTile(
                      title: Text('${log.versionName} - $timestamp'),
                      subtitle: Text(log.url),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('URL: ${log.url}'),
                              const SizedBox(height: 8),
                              Text('版本: ${log.versionName}'),
                              const SizedBox(height: 8),
                              const Text('Headers:'),
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black12,
                                width: double.infinity,
                                child: Text(const JsonEncoder.withIndent('  ').convert(
                                    jsonDecode(log.headers))),
                              ),
                              const SizedBox(height: 8),
                              const Text('JSON Data:'),
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black12,
                                width: double.infinity,
                                child: Text(const JsonEncoder.withIndent('  ').convert(
                                    jsonDecode(log.jsonData))),
                              ),
                              if (log.responseStatus.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('回應:'),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  color: Colors.black12,
                                  width: double.infinity,
                                  child: Text(log.responseStatus),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}