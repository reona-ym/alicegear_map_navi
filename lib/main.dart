import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:searchable_dropdown/searchable_dropdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

const String KEY_SELECTED_VALUE = "SELECTED_VALUE";
const String DEFALUT_MAP = "hermes";

const String CHANNEL_ID = 'MapNaviID';
const String CHANNEL_NAME = 'MapNavi';
const String CHANNEL_DESCRIPTION = 'Map Navigation';

void main() => runApp(MainApp());

class MappingJson {
  String version;
  String author;
  Map<String,dynamic> keyVal;
}

// MainApp - 基底となるクラス
// 呼ばれるとbuildを使用して自信を描画する
class MainApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // タイトル
      title: 'Navi',
      // テーマ
      theme: ThemeData(
        // タイトルバーの色
        primarySwatch: Colors.pink,
      ),


      home: MainPanel(title: '宙域 Navi'),

      debugShowCheckedModeBanner: false
    );
  }
}


// MainAppのhomeに表示するwidget
class MainPanel extends StatefulWidget {
  MainPanel({Key key, this.title}) : super(key: key);

  // クラスメソッド
  final String title;

  @override
  _MainPanel createState() => _MainPanel();
}

class _MainPanel extends State<MainPanel> {
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  NotificationDetails _notificationDetails;
  SearchableDropdown mapSelectDropdown;

  MappingJson mappingJson = new MappingJson();
  List<DropdownMenuItem> items = [];
  String selectedValue = DEFALUT_MAP;


  // 通知領域をタップした際に呼ばれる
  Future onSelectNotification(String payload) async {
    this.setState(() {
      _saveSelectedValue(payload);
      selectedValue = payload;
    });
  }

  Future _loadSelectedValue() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    this.setState(() {
      String value = prefs.getString(KEY_SELECTED_VALUE);
      if (value != null && mappingJson != null && mappingJson.keyVal != null && 0 < mappingJson.keyVal.length) {
        String _name = mappingJson.keyVal[value];
        if (List.generate(items.length, (i) => items[i].value).contains(_name)) {      
              selectedValue = value;
        }
      } 
    });
  }

  Future _saveSelectedValue(String value) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.setString(KEY_SELECTED_VALUE, value);
  }

  Future _parseJson() async {
    String loadData = await rootBundle.loadString('json/mapping.json');
    final jsonResponse = json.decode(loadData);

    await jsonResponse.forEach((key,value) {
      switch (key) {
        case "version":
          mappingJson.version = value;
          break;
        case "author":
          mappingJson.author = value;
          break;
        case "maplist":
          mappingJson.keyVal = new Map<String,dynamic>.from(value);
          break;
        default:
          break;
      }
    });

    await Future.forEach(mappingJson.keyVal.entries, (MapEntry<String, dynamic> map) async {
        items.add(new DropdownMenuItem(
            child: new Text(map.value.toString()),
            value: map.value.toString()
        ));
    });

    items.sort((a, b) => a.value.toString().compareTo(b.value.toString()));
  }

  // 初期化処理
  @override
  void initState() {
    super.initState();

    _loadSelectedValue();

    var initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS     = IOSInitializationSettings();
    var initializationSettings        = InitializationSettings(
                                          initializationSettingsAndroid
                                        , initializationSettingsIOS);

    // 表示時の定義と通知領域をタップした際の処理を定義する
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    _parseJson();
  }

  // 通知を表示させる処理
  Future sendNotification(dynamic selected) async {

    String _name = mappingJson.keyVal[selected];

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
          CHANNEL_ID,
          CHANNEL_NAME,
          CHANNEL_DESCRIPTION,
          importance: Importance.Max,
          priority: Priority.Max,
          enableVibration: false,
          setAsGroupSummary: false,
          style: AndroidNotificationStyle.BigPicture,
          styleInformation:
              BigPictureStyleInformation(
                  selected,
                  BitmapSource.Drawable,
                  hideExpandedLargeIcon: false,),
          
          );

    var iOSPlatformChannelSpecifics = IOSNotificationDetails();

    _notificationDetails = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(623, _name,
        '', _notificationDetails, payload: selected);
  }

  @override
  Widget build(BuildContext context) {

    String _name = mappingJson.keyVal[selectedValue];

    mapSelectDropdown = SearchableDropdown(
      items: items,
      value: _name,
      hint: new Text(
        'マップ選択'
      ),
      searchHint: new Text(
        'マップ選択',
        style: new TextStyle(
            fontSize: 20
        ),
      ),
      onChanged: (value) {
        setState(() {
          var key = mappingJson.keyVal.keys.
              firstWhere((k) => mappingJson.keyVal[k] == value, orElse: () => DEFALUT_MAP);
          _saveSelectedValue(key);
          selectedValue = key;
          sendNotification(key);
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            mapSelectDropdown,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {sendNotification(selectedValue);},
        tooltip: '通知に表示',
        child: Icon(Icons.event_note),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}