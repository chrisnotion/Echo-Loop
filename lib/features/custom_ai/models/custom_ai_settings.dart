import 'dart:convert';

/// 自定义 AI 与 Deepgram 转录配置数据模型
class CustomAiSettings {
  /// 是否启用自定义 OpenAI 兼容接口
  final bool openAiEnabled;

  /// OpenAI 兼容 API 基础地址（如 https://api.openai.com/v1 或 https://api.deepseek.com/v1）
  final String openAiBaseUrl;

  /// OpenAI 兼容 API 密钥
  final String openAiApiKey;

  /// 模型名称（如 gpt-4o-mini, deepseek-chat 等）
  final String openAiModel;

  /// 是否启用自定义 Deepgram 转录
  final bool deepgramEnabled;

  /// Deepgram API 密钥
  final String deepgramApiKey;

  /// Deepgram 转写模型（如 nova-2, nova-3）
  final String deepgramModel;

  const CustomAiSettings({
    this.openAiEnabled = true,
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.openAiApiKey = '',
    this.openAiModel = 'gpt-4o-mini',
    this.deepgramEnabled = true,
    this.deepgramApiKey = '',
    this.deepgramModel = 'nova-2',
  });

  /// 是否有效配置了自定义 OpenAI（填了 API Key）
  bool get isOpenAiConfigured =>
      openAiEnabled &&
      openAiApiKey.trim().isNotEmpty &&
      openAiBaseUrl.trim().isNotEmpty;

  /// 是否有效配置了 Deepgram（填了 API Key）
  bool get isDeepgramConfigured =>
      deepgramEnabled && deepgramApiKey.trim().isNotEmpty;

  CustomAiSettings copyWith({
    bool? openAiEnabled,
    String? openAiBaseUrl,
    String? openAiApiKey,
    String? openAiModel,
    bool? deepgramEnabled,
    String? deepgramApiKey,
    String? deepgramModel,
  }) {
    return CustomAiSettings(
      openAiEnabled: openAiEnabled ?? this.openAiEnabled,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiModel: openAiModel ?? this.openAiModel,
      deepgramEnabled: deepgramEnabled ?? this.deepgramEnabled,
      deepgramApiKey: deepgramApiKey ?? this.deepgramApiKey,
      deepgramModel: deepgramModel ?? this.deepgramModel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openAiEnabled': openAiEnabled,
      'openAiBaseUrl': openAiBaseUrl,
      'openAiApiKey': openAiApiKey,
      'openAiModel': openAiModel,
      'deepgramEnabled': deepgramEnabled,
      'deepgramApiKey': deepgramApiKey,
      'deepgramModel': deepgramModel,
    };
  }

  factory CustomAiSettings.fromMap(Map<String, dynamic> map) {
    return CustomAiSettings(
      openAiEnabled: map['openAiEnabled'] as bool? ?? true,
      openAiBaseUrl: (map['openAiBaseUrl'] as String?)?.trim().isNotEmpty == true
          ? map['openAiBaseUrl'] as String
          : 'https://api.openai.com/v1',
      openAiApiKey: (map['openAiApiKey'] as String?) ?? '',
      openAiModel: (map['openAiModel'] as String?)?.trim().isNotEmpty == true
          ? map['openAiModel'] as String
          : 'gpt-4o-mini',
      deepgramEnabled: map['deepgramEnabled'] as bool? ?? true,
      deepgramApiKey: (map['deepgramApiKey'] as String?) ?? '',
      deepgramModel: (map['deepgramModel'] as String?)?.trim().isNotEmpty == true
          ? map['deepgramModel'] as String
          : 'nova-2',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CustomAiSettings.fromJson(String source) =>
      CustomAiSettings.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
