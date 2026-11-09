import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_ai_settings.dart';
import '../services/custom_ai_service.dart';

const _kOpenAiEnabled = 'custom_ai_openai_enabled';
const _kOpenAiBaseUrl = 'custom_ai_openai_base_url';
const _kOpenAiApiKey = 'custom_ai_openai_api_key';
const _kOpenAiModel = 'custom_ai_openai_model';
const _kDeepgramEnabled = 'custom_ai_deepgram_enabled';
const _kDeepgramApiKey = 'custom_ai_deepgram_api_key';
const _kDeepgramModel = 'custom_ai_deepgram_model';

/// 自定义 AI 设置控制器
class CustomAiSettingsNotifier extends Notifier<CustomAiSettings> {
  @override
  CustomAiSettings build() {
    _loadFromPrefs();
    return const CustomAiSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = CustomAiSettings(
      openAiEnabled: prefs.getBool(_kOpenAiEnabled) ?? true,
      openAiBaseUrl: prefs.getString(_kOpenAiBaseUrl) ?? 'https://api.openai.com/v1',
      openAiApiKey: prefs.getString(_kOpenAiApiKey) ?? '',
      openAiModel: prefs.getString(_kOpenAiModel) ?? 'gpt-4o-mini',
      deepgramEnabled: prefs.getBool(_kDeepgramEnabled) ?? true,
      deepgramApiKey: prefs.getString(_kDeepgramApiKey) ?? '',
      deepgramModel: prefs.getString(_kDeepgramModel) ?? 'nova-2',
    );
  }

  Future<void> updateSettings(CustomAiSettings newSettings) async {
    state = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOpenAiEnabled, newSettings.openAiEnabled);
    await prefs.setString(_kOpenAiBaseUrl, newSettings.openAiBaseUrl);
    await prefs.setString(_kOpenAiApiKey, newSettings.openAiApiKey);
    await prefs.setString(_kOpenAiModel, newSettings.openAiModel);
    await prefs.setBool(_kDeepgramEnabled, newSettings.deepgramEnabled);
    await prefs.setString(_kDeepgramApiKey, newSettings.deepgramApiKey);
    await prefs.setString(_kDeepgramModel, newSettings.deepgramModel);
  }

  /// 测试 OpenAI 连接
  Future<String> testOpenAi() async {
    return CustomAiService.testOpenAiConnection(
      baseUrl: state.openAiBaseUrl,
      apiKey: state.openAiApiKey,
      model: state.openAiModel,
    );
  }

  /// 测试 Deepgram 连接
  Future<String> testDeepgram() async {
    return CustomAiService.testDeepgramConnection(
      apiKey: state.deepgramApiKey,
    );
  }
}

final customAiSettingsProvider =
    NotifierProvider<CustomAiSettingsNotifier, CustomAiSettings>(
  CustomAiSettingsNotifier.new,
);

/// 自定义 AI 服务实例提供者
final customAiServiceProvider = Provider<CustomAiService>((ref) {
  final settings = ref.watch(customAiSettingsProvider);
  return CustomAiService(settings);
});
