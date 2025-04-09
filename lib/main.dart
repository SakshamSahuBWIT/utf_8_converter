import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart'; // Add excel package

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Converter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FileConverterPage(),
    );
  }
}

class FileConverterPage extends StatefulWidget {
  const FileConverterPage({super.key});

  @override
  State<FileConverterPage> createState() => _FileConverterPageState();
}

class _FileConverterPageState extends State<FileConverterPage> {
  Uint8List? _convertedFileBytes;
  String? _fileName;
  bool _isProcessing = false;

  Future<void> _pickAndConvertFile() async {
    try {
      setState(() => _isProcessing = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        Uint8List fileBytes = result.files.single.bytes!;
        String originalFileName = result.files.single.name;

        List<List<dynamic>> csvData;

        if (originalFileName.endsWith('.csv')) {
          // Handle CSV
          String fileContent;
          try {
            fileContent = utf8.decode(fileBytes);
          } on FormatException {
            fileContent = latin1.decode(fileBytes); // Fallback to Latin-1
          }
          csvData = const CsvToListConverter().convert(fileContent);
        } else if (originalFileName.endsWith('.xlsx')) {
          // Handle XLSX
          var excel = Excel.decodeBytes(fileBytes);
          csvData = [];

          // Assume we're converting the first sheet
          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table];
            if (sheet != null) {
              for (var row in sheet.rows) {
                csvData.add(
                  row.map((cell) => cell?.value?.toString() ?? '').toList(),
                );
              }
            }
            break; // Only process the first sheet
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported file format')),
          );
          setState(() => _isProcessing = false);
          return;
        }

        // Convert to CSV with UTF-8 encoding
        String csvString = const ListToCsvConverter().convert(csvData);
        _convertedFileBytes = utf8.encode(csvString);
        _fileName = 'converted_${originalFileName.split('.').first}.csv';

        setState(() => _isProcessing = false);
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing file: $e')));
    }
  }

  void _downloadFile() {
    if (_convertedFileBytes != null && _fileName != null) {
      final blob = html.Blob([_convertedFileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor =
          html.AnchorElement(href: url)
            ..setAttribute('download', _fileName!)
            ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Converter to UTF-8')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isProcessing ? null : _pickAndConvertFile,
              child: const Text('Upload XLSX or CSV File'),
            ),
            const SizedBox(height: 20),
            if (_isProcessing) const CircularProgressIndicator(),
            if (_convertedFileBytes != null && !_isProcessing)
              ElevatedButton(
                onPressed: _downloadFile,
                child: const Text('Download UTF-8 CSV'),
              ),
          ],
        ),
      ),
    );
  }
}
