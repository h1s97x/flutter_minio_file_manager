import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:minio/models.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';

class Prefix {
  bool? isPrefix;
  String? key;
  String? prefix;

  Prefix({this.key, this.prefix, this.isPrefix});
}

class MinioService {
  /// 单例模式确保全局唯一客户端
  static final MinioService _instance = MinioService._internal();
  factory MinioService() => _instance;
  MinioService._internal();

  /// maximum object size (5TB)
  final maxObjectSize = 5 * 1024 * 1024 * 1024 * 1024;

  late Minio _client;
  String bucketName = 'flutter-test';
  late String prefix;
  
  // 进度流控制器
  final _uploadProgressControllers = <String, StreamController<double>>{};
  final _downloadProgressControllers = <String, StreamController<double>>{};

  Future<void> initialize() async {
    await _loadConfiguration();
    await _ensureBucketExists();
  }

  Future<void> _loadConfiguration() async {
    final config = await MinioConfig.loadConfig();
    _client = Minio(
      endPoint: config['endpoint'],
      port: config['port'],
      accessKey: config['accessKey'],
      secretKey: config['secretKey'],
      useSSL: config['useSSL'],
      region: config['region'],
    );
    bucketName = config['bucket'];
  }

  Future<void> _ensureBucketExists() async {
    if (!await _client.bucketExists(bucketName)) {
      await _client.makeBucket(bucketName);
    }
  }

  Future<MinioByteStream> getObject(String filename) async {
    try {
      final stream = await _client.getObject(bucketName, filename);
      return stream; // 明确返回值
    } catch (e) {
      throw Exception('Failed to get object: $e'); // 捕获并抛出异常
    }
  }

  Future<StatObjectResult> statObject(String filename) async {
    try {
      final stat = await _client.statObject(bucketName, filename);
      return stat; // 明确返回值
    } catch (e) {
      throw Exception('Failed to get object: $e'); // 捕获并抛出异常
    }
  }

  Future<List<String>> getFiles() async {
    final files = <String>[];
    await for (var result in _client.listObjects(bucketName)) {
      for (var object in result.objects) {
        if (object.key != null) {
          files.add(object.key!);
        }
      }
    }
    return files;
  }

  Future<Map<dynamic, dynamic>> getBucketObjects(
      String bucketName, String prefix) async {
    final objects = this
        ._client
        .listObjectsV2(this.bucketName, prefix: this.prefix, recursive: false);
    final map = new Map();
    await for (var obj in objects) {
      final prefixs = obj.prefixes.map((e) {
        final index = e.lastIndexOf('/') + 1;
        final prefix = e.substring(0, index);
        final key = e;
        return Prefix(key: key, prefix: prefix, isPrefix: true);
      }).toList();

      map['prefixes'] = prefixs;
      map['objests'] = obj.objects;
    }
    return map;
  }

  Future<List<Bucket>> getListBuckets() async {
    return this._client.listBuckets();
  }

  Future<bool> buckerExists(String bucket) async {
    return this._client.bucketExists(bucket);
  }

  Future<void> downloadFile(String filename, {String? savePath}) async {
    savePath ??= await _getDefaultSavePath(filename);
    final file = File(savePath);
    
    // 获取文件大小
    final stat = await statObject(filename);
    final totalSize = stat.size ?? 0;
    
    // 创建进度控制器
    final controller = StreamController<double>.broadcast();
    _downloadProgressControllers[filename] = controller;
    
    try {
      // 获取对象流
      final stream = await getObject(filename);
      final fileSink = file.openWrite();
      int downloadedSize = 0;
      
      // 处理下载流并更新进度
      await for (var data in stream) {
        fileSink.add(data);
        downloadedSize += data.length;
        final progress = downloadedSize / totalSize;
        controller.add(progress);
      }
      
      await fileSink.close();
    } finally {
      // 完成后关闭控制器
      await controller.close();
      _downloadProgressControllers.remove(filename);
    }
  }

  Future<String?> uploadFile(String filename, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      final fileSize = await file.length();
      
      // 创建进度控制器
      final progressController = _uploadProgressControllers[filename] ?? 
                                (_uploadProgressControllers[filename] = StreamController<double>.broadcast());
      
      // 执行上传
      final fileStream = file.openRead();
      int uploadedLength = 0;

      // 转换流以跟踪进度
      final transformedStream = fileStream.transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            uploadedLength += data.length;
            final progress = uploadedLength / fileSize;
            progressController.add(progress);
            sink.add(Uint8List.fromList(data));
          },
        ),
      );
      

      final etag = await _client.putObject(
        bucketName, 
        filename, 
        transformedStream.cast<Uint8List>(),
        onProgress: (bytes) {
          final progress = bytes / fileSize;
          progressController.add(progress);
        }
      );
      
      // 上传完成，发送100%进度
      progressController.add(1.0);
      
      return etag;
    } catch (e) {
      print('上传文件失败: $e');
      rethrow;
    }
  }

  Future<bool> deleteFile(String fileName) async {
    try {
      // 检查文件是否存在
      var metaData = await _client.statObject(this.bucketName, fileName);

      // 如果文件存在，删除文件
      await _client.removeObject(this.bucketName, fileName);

      // 根据元数据删除哈希桶中的对应项
      // var fileHash = metaData.metaData?['filehash'];
      // if (fileHash != null) {
      //   await _client.removeObject(
      //       FileStorgeConfig.fileHashBucket.toLowerCase(), fileHash);
      // }

      // 文件删除成功
      return true;
    } catch (e) {
      // 文件不存在或删除失败
      return false;
    }
  }

  Future<void> removeFile<T>(T filenames) async {
    final List<String> objects = filenames is String
        ? [filenames]
        : (filenames as List<dynamic>).map((e) => e.toString()).toList();
    return this._client.removeObjects(this.bucketName, objects);
  }

  Future<void> createBucket(String bucketName) {
    return this._client.makeBucket(bucketName);
  }

  Future<void> removeBucket(String bucketName) {
    return this._client.removeBucket(bucketName);
  }

  Future<dynamic> getPartialObject(
    String bucketName,
    String filename,
    String filePath, {
    void Function(int downloadSize, int fileSize)? onListen,
    void Function(int downloadSize, int fileSize)? onCompleted,
    void Function(StreamSubscription<List<int>> subscription)? onStart,
  }) async {
    final stat = await this._client.statObject(bucketName, filename);

    final dir = dirname(filePath);
    await Directory(dir).create(recursive: true);

    final partFileName = '$filePath.${stat.etag}.part.minio';
    final partFile = File(partFileName);
    IOSink partFileStream;
    var offset = 0;

    final rename = () => partFile.rename(filePath);

    if (await partFile.exists()) {
      final localStat = await partFile.stat();
      if (stat.size == localStat.size) return rename();
      offset = localStat.size;
      partFileStream = partFile.openWrite(mode: FileMode.append);
    } else {
      partFileStream = partFile.openWrite(mode: FileMode.write);
    }

    final dataStream =
        (await this._client.getPartialObject(bucketName, filename, offset))
            .asBroadcastStream(onListen: (sub) {
      if (onStart != null) {
        onStart(sub);
      }
    });

    Future.delayed(Duration.zero).then((_) {
      final listen = dataStream.listen((data) {
        // 确保 size 不为空
        final currentSize = partFile.statSync().size ?? 0;
        final totalSize = stat.size ?? 0;

        if (onListen != null) {
          onListen(currentSize, totalSize);
        }
      });
      listen.onDone(() {
        if (onListen != null) {
          final currentSize = partFile.statSync().size ?? 0;
          final totalSize = stat.size ?? 0;
          onListen(currentSize, totalSize);
        }
        listen.cancel();
      });
    });

    await dataStream.pipe(partFileStream);

    if (onCompleted != null) {
      final currentSize = partFile.statSync().size ?? 0;
      final totalSize = stat.size ?? 0;
      onCompleted(currentSize, totalSize);
    }

    final localStat = await partFile.stat();
    if (localStat.size != stat.size) {
      throw MinioError('Size mismatch between downloaded file and the object');
    }
    return rename();
  }

  // 获取上传进度流
  Stream<double> uploadProgress(String filename) {
    final controller = _uploadProgressControllers[filename] ?? 
                       (_uploadProgressControllers[filename] = StreamController<double>.broadcast());
    return controller.stream;
  }

  // 获取下载进度流
  Stream<double> downloadProgress(String filename) {
    final controller = _downloadProgressControllers[filename] ?? 
                       (_downloadProgressControllers[filename] = StreamController<double>.broadcast());
    return controller.stream;
  }

  // 获取默认保存路径
  Future<String> _getDefaultSavePath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$filename';
  }

  Future<String> getPresignedUrl(String fileName) async {
    try {
      // 生成一个有效期为1小时的预签名URL
      final url = await _client.presignedGetObject(bucketName, fileName, expires: 3600);
      return url;
    } catch (e) {
      print('获取预签名URL失败: $e');
      rethrow;
    }
  }

  Future<String?> uploadWebFile(String filename, Uint8List bytes, Function(double) onProgress) async {
    try {
      final fileSize = bytes.length;
      
      // 创建进度控制器
      final progressController = _uploadProgressControllers[filename] ?? 
                                (_uploadProgressControllers[filename] = StreamController<double>.broadcast());
      
      // 打印调试信息
      print('开始上传Web文件: $filename, 大小: $fileSize 字节');
      
      // 确保桶存在
      await _ensureBucketExists();
      
      // 执行上传
      final etag = await _client.putObject(
        bucketName, 
        filename, 
        Stream.value(bytes),
        onProgress: (uploadedBytes) {
          final progress = uploadedBytes / fileSize;
          print('上传进度: ${(progress * 100).toStringAsFixed(2)}%');
          progressController.add(progress);
          onProgress(progress);
        }
      );
      
      // 上传完成，发送100%进度
      progressController.add(1.0);
      onProgress(1.0);
      
      print('Web文件上传完成: $filename, etag: $etag');
      return etag;
    } catch (e) {
      print('上传Web文件失败: $e');
      rethrow;
    }
  }
}
