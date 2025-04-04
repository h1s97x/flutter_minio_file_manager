# MinIO 文件管理器

MinIO 文件管理器是一个基于 Flutter 开发的跨平台应用程序，旨在提供一个用户友好的界面来管理存储在 MinIO 对象存储服务中的文件。

## 功能特性

- 文件浏览和管理：查看和管理存储在 MinIO 服务器上的文件和文件夹。
- 文件上传：支持单个和批量文件上传，带有进度显示。
- 文件下载：支持文件下载功能，包括下载队列管理。
- 文件删除（支持批量删除）
- 跨平台支持：可在 Android、Web 和 Windows 平台上运行。

## 技术栈

- Flutter SDK: >=3.0.0 <4.0.0
- Dart
- MinIO SDK: ^3.5.7
- Provider (状态管理): ^6.0.5
- File Picker: ^5.3.2
- 其他依赖项可在 `pubspec.yaml` 文件中查看

## 开始使用

1. 确保你已经安装了 Flutter SDK 和 Dart。

2. 克隆此仓库：

   ```
   git clone [仓库URL]
   ```

3. 进入项目目录：

   ```
   cd flutter_minio_file_manager
   ```

4. 获取依赖：

   ```
   flutter pub get
   ```

5. 运行应用：

   ```
   flutter run
   ```

## 配置

在使用之前，请确保正确配置了 MinIO 服务器的连接信息。配置文件位于 `lib/config.dart`。


## 项目结构

```
lib/
├── models/         # 数据模型
├── pages/          # UI 页面
├── services/       # 业务逻辑和服务
├── utils/          # 工具函数
├── config.dart     # 配置文件
└── main.dart       # 应用入口
1. **服务层（Services）**：负责与MinIO服务器进行通信，处理文件的上传、下载、删除等操作。使用Provider或类似的库来管理应用的状态，比如当前的文件列表、上传下载队列的进度等。

2. **界面UI（pages）**：构建用户界面，如文件列表、上传/下载进度条等。

3. **工具类（Utils）**：可能包含一些辅助函数，如格式化文件大小、处理文件路径等。

4. **模型类（Models）**：定义数据模型，如文件项（FileItem）的结构。
```

### 核心服务

#### MinioService (lib/services/minio_service.dart)

负责与 MinIO 服务器的所有交互，包括文件上传、下载、列表获取等操作。

主要功能：

initialize(): 初始化 MinIO 客户端

getFiles(): 获取文件列表

uploadFile(String filename, String filePath): 上传文件

uploadWebFile(String filename, Uint8List bytes, Function(double) onProgress): Web 平台专用上传方法

downloadFile(String filename, String savePath): 下载文件

deleteFile(String filename): 删除文件

statObject(String filename): 获取文件信息

#### UploadService (lib/services/upload_service.dart)

管理文件上传队列和上传记录。

主要功能：

enqueueUpload(String filePath): 将文件加入上传队列

_processQueue(): 处理上传队列

_startUpload(FileTask task): 开始上传文件

_uploadFileForWeb(String fileName, String filePath, Function(double) onProgress): Web 平台专用上传方法

#### DownloadService (lib/services/download_service.dart)

管理文件下载队列和下载记录。

主要功能：

enqueueDownload(String fileName): 将文件加入下载队列

_processQueue(): 处理下载队列

_startDownload(FileTask task): 开始下载文件

_downloadFileForWeb(String fileName): Web 平台专用下载方法

### Web 平台专用服务

#### WebFilePicker (lib/services/web_file_picker.dart)

Web 平台专用的文件选择器，支持单文件和多文件选择。

主要功能：

pickFile(): 选择单个文件

pickFiles(): 选择多个文件

#### WebUploadHelper (lib/services/web_upload_helper.dart)

Web 平台专用的上传辅助工具，用于存储和管理文件字节数据。

主要功能：

saveFileBytes(Uint8List bytes, {String? fileName}): 保存文件字节

getFileBytes(String fileName): 获取文件字节

getLastFileBytes(): 获取最后保存的文件字节

clearFileBytes([String? fileName]): 清除文件字节

### 模型

#### FileItem (lib/models/file_item.dart)

表示文件列表中的文件项。

#### FileTask (lib/models/file_task.dart)

表示上传或下载任务。

### 页面

#### HomePage (lib/pages/home_page.dart)

主页面，显示文件列表，提供文件上传、下载、删除等操作。

主要功能：

_refreshObjects(): 刷新文件列表

_uploadFile(): 上传文件

_downloadFile(String fileName): 下载文件

_deleteFile(String fileName): 删除文件

_toggleMultiSelectMode(): 切换多选模式

_downloadSelectedFiles(): 下载选中的文件

_deleteSelectedFiles(): 删除选中的文件

#### UploadQueuePage (lib/pages/upload_queue_page.dart)

显示上传队列和上传记录。

#### DownloadQueuePage (lib/pages/download_queue_page.dart)

显示下载队列和下载记录。

#### FileListItem (lib/pages/file_list_Item.dart)

文件列表项组件，用于在文件列表中显示文件项。

### 配置

#### Config (lib/config.dart)

应用程序配置，包括 MinIO 服务器地址、访问密钥等。

### 工具

#### Utils (lib/utils/utils.dart)

通用工具函数，如文件大小格式化等。



## 存在的问题

上传队列无法显示，上传功能能够正常使用，使用队列调用方法时错误，所以重新写了方法。
