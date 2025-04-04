import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'pages/file_list_Item.dart';
import 'pages/home_page.dart';
import 'pages/upload_queue_page.dart';
import 'pages/download_queue_page.dart';
import 'services/upload_service.dart';
import 'services/download_service.dart';
import 'config.dart';

// 条件导入
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化默认配置
  await MinioConfig.initDefaultConfig();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UploadService()),
        ChangeNotifierProvider(create: (context) => DownloadService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MinIO 文件管理器',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = HomePage(
          onPageChange: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
        );
        break;
      case 1:
        page = UploadQueuePage();
        break;
      case 2:
        page = DownloadQueuePage();
        break;
      default:
        throw UnimplementedError('Invalid index: $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                extended: constraints.maxWidth > 600,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.file_copy),
                    label: Text('文件'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.upload),
                    label: Text('上传队列'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.download),
                    label: Text('下载队列'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.inversePrimary,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}
