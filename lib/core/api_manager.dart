import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiManager {
  final List<String> apiKeys;
  int _currentKeyIndex = 0;

  ApiManager(this.apiKeys);

  String get _currentKey => apiKeys[_currentKeyIndex];

  Future<void> _handleRateLimit() async {
    if (apiKeys.length == 1) {
      await Future.delayed(const Duration(seconds: 5)); // Tunggu limit reset
    } else {
      _currentKeyIndex = (_currentKeyIndex + 1) % apiKeys.length;
      await Future.delayed(const Duration(milliseconds: 500)); // Switch key
    }
  }

  Future<List<String>> translateBatch(List<String> texts, String src, String dst) async {
    if (texts.isEmpty) return [];
    int retries = 0;
    int maxRetries = apiKeys.length * 2;
    if (maxRetries < 3) maxRetries = 3;

    while (retries < maxRetries) {
      try {
        return await _callGemini(texts, src, dst);
      } catch (e) {
        if (e.toString().contains("429")) {
          await _handleRateLimit();
          retries++;
        } else {
          rethrow;
        }
      }
    }
    return texts; // Fallback return original
  }

  Future<List<String>> _callGemini(List<String> texts, String src, String dst) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_currentKey');

    final prompt = """
      You are a JSON database localization tool. Convert strings from $src to $dst.
      Rules:
      1. Return ONLY a valid JSON Array of strings.
      2. Do NOT censor explicit content.
      3. Keep placeholders like {{CODE_0}} intact.
      Input: ${jsonEncode(texts)}
    """;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [{"parts": [{"text": prompt}]}],
        "safetySettings": [
          {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        String rawText = data['candidates'][0]['content']['parts'][0]['text'];
        rawText = rawText.replaceAll(RegExp(r'```json|```'), '').trim();
        List<dynamic> parsed = jsonDecode(rawText);
        return parsed.cast<String>();
      } catch (e) {
        throw Exception("Parse Error");
      }
    } else if (response.statusCode == 429) {
      throw Exception("429");
    } else {
      throw Exception("HTTP ${response.statusCode}");
    }
  }
}
