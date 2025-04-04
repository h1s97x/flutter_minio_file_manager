import 'dart:async';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:minio/minio.dart';
import '../services/minio_service.dart';
import '../config.dart';
import 'package:intl/intl.dart';
import '../models/file_task.dart';

/// 下载文件记录
class DownloadRecord {
  String fileName;
  String downloadStatus;
  String downloadMessage;
  String downloadTime;
  double downloadProgress;

  DownloadRecord({
    required this.fileName,
    required this.downloadStatus,
    required this.downloadMessage,
    required this.downloadTime,
    this.downloadProgress = 0.0,
  });
}

/// 文件下载服务
class DownloadService extends ChangeNotifier {
  // 单例模式
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  String? _downloadPath;
  Map<String, String> _downloadProgress = {};
  final List<FileTask> _downloadQueue = [];
  int _activeDownloads = 0;
  final int _maxConcurrent = MinioConfig.maxConcurrent;
  final List<DownloadRecord> _downloadRecords = [];
  
  List<DownloadRecord> get downloadRecords => _downloadRecords;

  void updateProgress(String fileName, String progress) {
    _downloadProgress[fileName] = progress;
    notifyListeners();
  }

  String getProgress(String fileName) {
    return _downloadProgress[fileName] ?? "0.0";
  }

  Future<String?> getDownloadPath() async {
    if (_downloadPath != null) {
      return _downloadPath;
    }

    if (kIsWeb) {
      return null; // Web平台不需要下载路径
    }

    // 获取默认下载路径
    final directory = await getApplicationDocumentsDirectory();
    _downloadPath = directory.path;
    return _downloadPath;
  }

  Future<String?> selectFolder() async {
    // Web平台不支持选择目录
    if (kIsWeb) {
      return "web_download";
    }
    
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      _downloadPath = selectedDirectory;
      notifyListeners();
    }
    return selectedDirectory;
  }

  /// 将文件加入下载队列
  void enqueueDownload(String fileName) async {
    await getDownloadPath(); // 确保下载路径已设置
    
    final task = FileTask.createDownloadTask(
      fileName: fileName,
      onCompleted: () {
        print("Download completed: $fileName");
      },
      onProgress: (progress) {
        print("Download progress: $progress");
      },
      onError: (error) {
        print("Download error: $error");
      },
    );
    
    _downloadQueue.add(task);
    _processQueue();
  }

  void _processQueue() {
    while (_activeDownloads < _maxConcurrent && _downloadQueue.isNotEmpty) {
      final task = _downloadQueue.removeAt(0);
      _activeDownloads++;
      _startDownload(task);
    }
  }

  Future<void> _startDownload(FileTask task) async {
    String fileName = task.filePath;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    DownloadRecord downloadHistory = DownloadRecord(
      fileName: fileName,
      downloadStatus: "正在下载",
      downloadMessage: "",
      downloadTime: formattedDate,
      downloadProgress: 0.0,
    );

    addRecord(downloadHistory);
    notifyListeners(); // 确保立即显示下载记录

    try {
      // 监听下载进度
      MinioService().downloadProgress(fileName).listen((progress) {
        updateFileProgress(fileName, progress);
        if (task.onProgress != null) {
          task.onProgress!('${(progress * 100).toStringAsFixed(2)}%');
        }
      });

      if (kIsWeb) {
        // Web平台特殊处理
        await _downloadFileForWeb(fileName, (progress) {
          updateFileProgress(fileName, progress);
          if (task.onProgress != null) {
            task.onProgress!('${(progress * 100).toStringAsFixed(2)}%');
          }
        });
        
        downloadHistory.downloadStatus = "成功";
        downloadHistory.downloadMessage = "文件下载成功";
        downloadHistory.downloadProgress = 1.0;
        
        if (task.onCompleted != null) {
          task.onCompleted!();
        }
      } else {
        // 移动端或桌面端下载
        if (_downloadPath == null) {
          throw Exception("下载路径未设置");
        }
        
        final filePath = path.join(_downloadPath!, fileName);
        final file = File(filePath);

        // 确保目录存在
        final dir = path.dirname(filePath);
        await Directory(dir).create(recursive: true);

        final stream = await MinioService().getObject(fileName);
        final sink = file.openWrite();
        
        try {
          await stream.pipe(sink);
          await sink.flush();
          await sink.close();
          
          downloadHistory.downloadStatus = "成功";
          downloadHistory.downloadMessage = "文件下载成功: $filePath";
          downloadHistory.downloadProgress = 1.0;
          
          if (task.onCompleted != null) {
            task.onCompleted!();
          }
        } catch (e) {
          await sink.close();
          downloadHistory.downloadStatus = "失败";
          downloadHistory.downloadMessage = "文件下载失败: $e";
          
          if (task.onError != null) {
            task.onError!(e.toString());
          }
        }
      }
    } catch (e) {
      print('下载过程中出错: $e');
      downloadHistory.downloadStatus = "失败";
      downloadHistory.downloadMessage = "文件下载失败: $e";
      
      if (task.onError != null) {
        task.onError!(e.toString());
      }
    }

    _downloadCompleted();
    notifyListeners();
  }

  // Web平台专用下载方法
  Future<void> _downloadFileForWeb(String fileName, Function(double) onProgress) async {
    if (!kIsWeb) return;
    
    try {
      print('准备下载Web文件: $fileName');
      
      // 获取预签名URL
      final url = await MinioService().getPresignedUrl(fileName);
      print('获取到预签名URL: $url');
      
      // 模拟下载进度
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(Duration(milliseconds: 200));
        final progress = i / 10;
        onProgress(progress);
      }
      
      // 使用浏览器下载
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      print('文件下载完成: $fileName');
    } catch (e) {
      print('Web下载文件失败: $e');
      rethrow;
    }
  }

  void _downloadCompleted() {
    _activeDownloads--;
    _processQueue();
  }

  void addRecord(DownloadRecord record) {
    // 检查是否已存在相同文件名的记录
    final existingIndex = _downloadRecords.indexWhere((r) => r.fileName == record.fileName);
    
    if (existingIndex >= 0) {
      // 更新现有记录
      _downloadRecords[existingIndex] = record;
    } else {
      // 添加新记录
      _downloadRecords.add(record);
    }
    
    notifyListeners();
  }

  void clearRecords() {
    _downloadRecords.clear();
    notifyListeners();
  }

  Future<void> setDownloadPath(String path) async {
    _downloadPath = path;
  }

  void updateFileProgress(String fileName, double progress) {
    for (var file in _downloadRecords) {
      if (file.fileName == fileName) {
        file.downloadProgress = progress;
        notifyListeners();
        break;
      }
    }
  }
} 