import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../models/file_item.dart';

class FileListItem extends StatelessWidget {
  final String fileName;
  final Function() onDownload;
  final Function() onDelete;

  const FileListItem({
    Key? key,
    required this.fileName,
    required this.onDownload,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileType = _getFileType(fileName);
    final icon = _getFileIcon(fileType);
    final fileSize = ''; // 这里可以添加文件大小信息

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: icon,
        title: Text(
          fileName,
          style: TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              fileType.toUpperCase(),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (fileSize.isNotEmpty) ...[
              SizedBox(width: 8),
              Text(
                fileSize,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, color: Colors.blue),
              tooltip: '下载',
              onPressed: onDownload,
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              tooltip: '删除',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('确认删除'),
          content: Text('确定要删除文件 "$fileName" 吗？此操作不可撤销。'),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                '删除',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onDelete();
              },
            ),
          ],
        );
      },
    );
  }

  String _getFileType(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '未知';
  }

  Icon _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'doc':
      case 'docx':
        return Icon(Icons.description, color: Colors.blue);
      case 'xls':
      case 'xlsx':
        return Icon(Icons.table_chart, color: Colors.green);
      case 'ppt':
      case 'pptx':
        return Icon(Icons.slideshow, color: Colors.orange);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icon(Icons.image, color: Colors.purple);
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icon(Icons.music_note, color: Colors.pink);
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Icon(Icons.movie, color: Colors.indigo);
      case 'zip':
      case 'rar':
      case '7z':
        return Icon(Icons.archive, color: Colors.brown);
      case 'txt':
        return Icon(Icons.text_snippet, color: Colors.teal);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }
}
