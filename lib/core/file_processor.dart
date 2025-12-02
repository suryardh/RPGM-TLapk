import 'dart:convert';
import 'package:flutter/foundation.dart';

class ExtractionResult {
  final List<String> textsToTranslate;
  final List<String> placeholders; 
  final dynamic jsonStructure;
  ExtractionResult(this.textsToTranslate, this.placeholders, this.jsonStructure);
}

class ReplacementInput {
  final dynamic jsonStructure;
  final List<String> translatedTexts;
  final List<String> originalPlaceholders;
  ReplacementInput(this.jsonStructure, this.translatedTexts, this.originalPlaceholders);
}

// --- GLOBAL FUNCTIONS FOR COMPUTE ---

ExtractionResult isolateExtract(String jsonContent) {
  var data = jsonDecode(jsonContent);
  List<String> collected = [];
  List<String> placeholders = [];
  final regExp = RegExp(r'\\[A-Za-z]+(\[\d+\])?|\\.'); 

  void traverse(dynamic obj) {
    if (obj is Map) {
      if (obj.containsKey('code')) {
        int code = obj['code'];
        if ((code == 401 || code == 405) && obj['parameters'][0] is String) {
          String raw = obj['parameters'][0];
          List<String> ph = [];
          String masked = raw.replaceAllMapped(regExp, (match) {
            ph.add(match.group(0)!);
            return "{{CODE_${ph.length - 1}}}";
          });
          collected.add(masked);
          placeholders.add(jsonEncode(ph));
        } else if (code == 102 && obj['parameters'][0] is List) {
          for (var choice in obj['parameters'][0]) {
             collected.add(choice); 
             placeholders.add("[]");
          }
        }
      } else {
        if (obj.containsKey('name') && obj['name'] is String && obj['name'].isNotEmpty) {
           collected.add(obj['name']);
           placeholders.add("[]");
        }
        if (obj.containsKey('description') && obj['description'] is String) {
           collected.add(obj['description']);
           placeholders.add("[]");
        }
        obj.values.forEach(traverse);
      }
    } else if (obj is List) {
      obj.forEach(traverse);
    }
  }

  traverse(data);
  return ExtractionResult(collected, placeholders, data);
}

String isolateReplace(ReplacementInput input) {
  var data = input.jsonStructure;
  int ptr = 0;

  void traverse(dynamic obj) {
    if (obj is Map) {
      if (obj.containsKey('code')) {
        int code = obj['code'];
        if ((code == 401 || code == 405) && obj['parameters'][0] is String) {
          if (ptr < input.translatedTexts.length) {
            String trans = input.translatedTexts[ptr];
            List<dynamic> ph = jsonDecode(input.originalPlaceholders[ptr]);
            for (int i = 0; i < ph.length; i++) {
              trans = trans.replaceAll("{{CODE_$i}}", ph[i]);
              trans = trans.replaceAll("{{CODE _$i}}", ph[i]);
            }
            obj['parameters'][0] = trans;
            ptr++;
          }
        }
      } else {
        if (obj.containsKey('name') && obj['name'] is String && obj['name'].isNotEmpty) {
           if (ptr < input.translatedTexts.length) obj['name'] = input.translatedTexts[ptr++];
        }
        if (obj.containsKey('description') && obj['description'] is String) {
           if (ptr < input.translatedTexts.length) obj['description'] = input.translatedTexts[ptr++];
        }
        obj.values.forEach(traverse);
      }
    } else if (obj is List) {
      obj.forEach(traverse);
    }
  }

  traverse(data);
  return jsonEncode(data);
}

class FileProcessor {
  Future<ExtractionResult> prepareFile(String content) async {
    return await compute(isolateExtract, content);
  }

  Future<String> rebuildFile(dynamic structure, List<String> trans, List<String> ph) async {
    return await compute(isolateReplace, ReplacementInput(structure, trans, ph));
  }
}
