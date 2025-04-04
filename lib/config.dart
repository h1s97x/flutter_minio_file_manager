import 'package:shared_preferences/shared_preferences.dart';

/// MinIO 对象存储配置文件管理类
class MinioConfig {
  // 默认静态配置
  static const int maxConcurrent = 3; // 队列并发数

  // 用户可修改配置键名
  static const String _endPoint = "localhost";
  static const int port = 9000;
  static const String _accessKey = "O8BG1cDoriXdNUutHxcP";
  static const String _secretKey = "Y9axqskjGVtGwYiiAF5Y3frQ0zjrdGeirfG4dmzt";
  static const bool useSSL = false;
  static const String _bucketName = "flutter-test";
  static const String region = "us-east-1";

  // 添加公共getter方法
  static String get endPoint => _endPoint;
  static String get accessKey => _accessKey;
  static String get secretKey => _secretKey;

  /// 加载用户配置（优先使用用户自定义值）
  static Future<Map<String, dynamic>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "endpoint": prefs.getString(_endPoint) ?? "localhost",
      "port": port,
      "useSSL": useSSL,
      "accessKey": prefs.getString(_accessKey) ?? "",
      "secretKey": prefs.getString(_secretKey) ?? "",
      "bucket": prefs.getString(_bucketName) ?? "flutter-test",
      "region": region,
      // "maxUploads": maxConcurrent,
      // "maxDownloads": maxConcurrent,
    };
  }

  /// 保存用户可修改的配置项
  static Future<void> saveConfig({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_endPoint, endpoint),
      prefs.setString(_accessKey, accessKey),
      prefs.setString(_secretKey, secretKey),
      prefs.setString(_bucketName, bucket),
    ]);
  }

  /// 配置验证（连接前必调用）
  static bool validateConfig(Map<String, dynamic> config) {
    return config["accessKey"]!.isNotEmpty && config["secretKey"]!.isNotEmpty;
  }

  /// 初始化默认配置（首次运行使用）
  static Future<void> initDefaultConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_endPoint)) {
      await saveConfig(
        endpoint: "localhost",
        accessKey: "O8BG1cDoriXdNUutHxcP",
        secretKey: "Y9axqskjGVtGwYiiAF5Y3frQ0zjrdGeirfG4dmzt",
        bucket: "flutter-test",
      );
    }
  }
}

// class FileStorgeConfig {
//   static const String storageBucket = 'flutter-test'; // 存储桶名称
//   static const String fileHashBucket = 'fileHash'; // 文件哈希桶名称
//   static const String fileInfoBucket = 'fileInfo'; // 文件信息桶名称
// }
