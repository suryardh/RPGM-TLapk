import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'api_manager.dart';
import 'db_helper.dart';
import 'file_processor.dart';

class TranslatorService {
  final ApiManager apiManager;
  final FileProcessor processor = FileProcessor();
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  TranslatorService(List<String> keys) : apiManager = ApiManager(keys);

  Stream<Map<String, dynamic>> processGame(String folderPath, Map<String, bool> scope) async* {
    Directory gameDir = Directory(folderPath);
    Directory tempDir = await getTemporaryDirectory();
    Directory outputDir = Directory('${tempDir.path}/translated_data');
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync();

    List<File> files = gameDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    
    if (!scope['Story']!) files.removeWhere((f) => f.path.contains('Map') || f.path.contains('CommonEvents'));
    if (!scope['Items']!) files.removeWhere((f) => f.path.contains('Items') || f.path.contains('Skills') || f.path.contains('Weapons'));
    if (!scope['System']!) files.removeWhere((f) => f.path.contains('System') || f.path.contains('States'));

    int total = files.length;
    String gameTitle = "Unknown"; 

    for (int i = 0; i < total; i++) {
      File file = files[i];
      String fileName = file.uri.pathSegments.last;
      
      yield {"status": "processing", "log": fileName, "progress": i / total};
      
      try {
        String content = await file.readAsString();
        if (fileName == 'System.json' && content.contains('gameTitle')) {
           // Simple regex extract title
           final match = RegExp(r'"gameTitle"\s*:\s*"([^"]+)"').firstMatch(content);
           if (match != null) gameTitle = match.group(1) ?? "Game";
        }

        var extracted = await processor.prepareFile(content);
        List<String> finalTexts = [];
        List<String> batchToSend = [];
        List<int> batchIndices = [];

        for (int j = 0; j < extracted.textsToTranslate.length; j++) {
          String src = extracted.textsToTranslate[j];
          String? cached = await dbHelper.checkCache(src, "JP-ID");
          if (cached != null) {
            finalTexts.add(cached);
          } else {
            finalTexts.add("");
            batchToSend.add(src);
            batchIndices.add(j);
          }
        }

        if (batchToSend.isNotEmpty) {
          int batchSize = 50; 
          for (int k = 0; k < batchToSend.length; k += batchSize) {
             int end = (k + batchSize < batchToSend.length) ? k + batchSize : batchToSend.length;
             List<String> chunk = batchToSend.sublist(k, end);
             
             try {
               List<String> results = await apiManager.translateBatch(chunk, "Japanese", "Indonesian");
               for (int r = 0; r < results.length; r++) {
                 int originalIdx = batchIndices[k + r];
                 finalTexts[originalIdx] = results[r];
                 dbHelper.saveCache(chunk[r], results[r], "JP-ID");
               }
             } catch (e) {
               print("API Error: $e");
             }
          }
        }

        String finalJson = await processor.rebuildFile(extracted.jsonStructure, finalTexts, extracted.placeholders);
        File('${outputDir.path}/$fileName').writeAsStringSync(finalJson);
      } catch (e) {
        print("Skip file $fileName: $e");
      }
    }

    // ZIPPING
    yield {"status": "zipping", "log": "Compressing...", "progress": 1.0};
    
    var encoder = ZipFileEncoder();
    String zipName = "JP-ID Batch $gameTitle.zip";
    // Simpan di Downloads (Path public aman di Android)
    Directory? downloadDir = Directory('/storage/emulated/0/Download');
    if (!downloadDir.existsSync()) downloadDir = gameDir; // Fallback

    String zipPath = "${downloadDir.path}/$zipName";
    
    try {
      encoder.create(zipPath);
      encoder.addDirectory(outputDir);
      encoder.close();
      yield {"status": "completed", "log": "Saved to Downloads", "path": zipPath};
    } catch (e) {
      yield {"status": "error", "log": "Zip Error: $e"};
    }
  }
}
