import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiManager {
  final List<String> apiKeys;
  int _currentKeyIndex = 0;

  ApiManager(this.apiKeys);

  String get _currentKey => apiKeys[_currentKeyIndex];

  Future<void> _handleRateLimit() async {
    if (apiKeys.length == 1) {
      print("Limit reached. Waiting 5s...");
      await Future.delayed(const Duration(seconds: 5));
    } else {
      _currentKeyIndex = (_currentKeyIndex + 1) % apiKeys.length;
      print("Rotating Key to Index: $_currentKeyIndex");
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<List<String>> translateBatch(List<String> texts, String src, String dst) async {
    if (texts.isEmpty) return [];
    int retries = 0;
    int maxRetries = (apiKeys.length * 2).clamp(3, 10);
    while (retries < maxRetries) {
      try {
        return await _callGemini(texts, src, dst);
      } catch (e) {
        if (e.toString().contains("429") || e.toString().contains("503")) {
          await _handleRateLimit();
          retries++;
        } else {
          print("API Error: $e");
          return texts;
        }
      }
    }
    return texts;
  }

  Future<List<String>> _callGemini(List<String> texts, String src, String dst) async {
    final String model = "gemini-2.0-flash";
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${_currentKey.trim()}');
    final prompt = """
      You are a specialized JSON translator.
      Task: Translate the following array of strings from $src to $dst.
      Rules:
      1. Output MUST be a valid JSON Array of strings.
      2. Maintain exact array length.
      3. Do not translate text inside {{...}} or codes like \\N[1].
      Input Data:
      ${jsonEncode(texts)}
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
        ],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.3}
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        String rawText = data['candidates'][0]['content']['parts'][0]['text'];
        rawText = rawText.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();
        List<dynamic> parsed = jsonDecode(rawText);
        if (parsed.length != texts.length) {
          print("Length Mismatch. Input: ${texts.length} vs Output: ${parsed.length}");
          return texts;
        }
        return parsed.cast<String>();
      } catch (e) {
        print("Parse Error Body: ${response.body}");
        throw Exception("Gagal parsing JSON output Gemini");
      }
    } else {
      print("API Error (${response.statusCode}): ${response.body}");
      throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
    }
  }
}
