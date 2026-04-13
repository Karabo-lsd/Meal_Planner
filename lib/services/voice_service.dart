import 'dart:io';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import 'api_client.dart';

class VoiceService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> transcribeAudio(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'voice_input.wav',
        ),
      });

      final response = await _dio.post(
        AppConfig.voiceTranscribe,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> processVoiceCommand(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'voice_command.wav',
        ),
      });

      final response = await _dio.post(
        AppConfig.voiceCommand,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> extractIngredientsFromVoice(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'ingredients_voice.wav',
        ),
      });

      final response = await _dio.post(
        AppConfig.voiceIngredients,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getVoiceSettings() async {
    try {
      final response = await _dio.get(AppConfig.voiceSettings);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateVoiceSettings(Map<String, dynamic> settings) async {
    try {
      final response = await _dio.put(AppConfig.voiceSettings, data: settings);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<String>> getSupportedLanguages() async {
    try {
      final response = await _dio.get('${AppConfig.voiceSettings}/languages');
      return List<String>.from(response.data ?? []);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> testVoiceProcessing(String testText) async {
    try {
      final response = await _dio.post(
        '${AppConfig.voiceSettings}/test',
        data: {'text': testText},
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return Exception(data['detail']);
      }
      return Exception('Server error: ${e.response!.statusCode}');
    } else {
      return Exception('Network error: ${e.message}');
    }
  }
}