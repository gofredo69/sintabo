import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'prompt_templates.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  Future<Map<String, dynamic>?> scanAndAnalyze() async {
    // 1. Pick the Image
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image == null) return null;

    // 2. Extract Raw Text using ML Kit
    final inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    if (recognizedText.text.trim().isEmpty) return null;

    // 3. Prepare the Groq Request
    final String prompt = SintaboPrompts.receiptAnalysis(recognizedText.text);

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', // Groq's current powerhouse
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1, // Keep it precise for JSON
          'response_format': {'type': 'json_object'} // This is the "Magic" line
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        
        // Debug Log: Check your console for this!
        print("Sintabo Groq Success: $content");
        return jsonDecode(content) as Map<String, dynamic>;
      } else {
        print("Groq API Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Sintabo OCR Service Error: $e");
      return null;
    }
  }

  void dispose() => _textRecognizer.close();
}