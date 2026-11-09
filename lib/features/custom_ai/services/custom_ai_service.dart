import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import '../../../models/dictionary/dictionary_entry.dart';
import '../../../models/sense_group_result.dart';
import '../../../models/sentence_ai_result.dart';
import '../../../models/word_timestamp.dart';
import '../../../services/app_logger.dart';
import '../../../services/sentence_ai_api_client.dart';
import '../../../services/transcription_api_client.dart';
import '../../../utils/srt_generator.dart';
import '../../chatbot/models/chat_message.dart';
import '../../chatbot/services/ndjson_text_stream.dart';
import '../models/custom_ai_settings.dart';

/// 自定义 OpenAI 兼容与 Deepgram 服务实现类
class CustomAiService {
  final CustomAiSettings settings;
  final Dio _dio;

  CustomAiService(this.settings)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 90),
          ),
        );

  String _cleanJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```json')) {
      text = text.substring(7);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    return text.trim();
  }

  String _normalizeBaseUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// 测试 OpenAI 兼容 API 连通性
  static Future<String> testOpenAiConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final startTime = DateTime.now();
    var cleanBase = baseUrl.trim();
    if (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    final url = cleanBase.endsWith('/chat/completions')
        ? cleanBase
        : '$cleanBase/chat/completions';

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: {
        'model': model.trim().isEmpty ? 'gpt-4o-mini' : model.trim(),
        'messages': [
          {'role': 'user', 'content': 'Hello, reply with only the word OK.'}
        ],
        'max_tokens': 10,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${apiKey.trim()}',
          'Content-Type': 'application/json',
        },
      ),
    );

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final content =
        response.data?['choices']?[0]?['message']?['content']?.toString() ??
            '成功';
    return '连接成功 ($elapsed ms): $content';
  }

  /// 测试 Deepgram API 连通性
  static Future<String> testDeepgramConnection({
    required String apiKey,
  }) async {
    final startTime = DateTime.now();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final response = await dio.get<Map<String, dynamic>>(
      'https://api.deepgram.com/v1/projects',
      options: Options(
        headers: {
          'Authorization': 'Token ${apiKey.trim()}',
        },
      ),
    );

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final projects = response.data?['projects'] as List?;
    final count = projects?.length ?? 0;
    return 'Deepgram 校验通过 ($elapsed ms)，拥有 $count 个项目';
  }

  /// 发起通用 OpenAI Chat Completion 请求并返回文本
  Future<String> _callOpenAi({
    required List<Map<String, String>> messages,
    double temperature = 0.3,
    CancelToken? cancelToken,
  }) async {
    var cleanBase = _normalizeBaseUrl(settings.openAiBaseUrl);
    final url = cleanBase.endsWith('/chat/completions')
        ? cleanBase
        : '$cleanBase/chat/completions';

    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: {
        'model': settings.openAiModel,
        'messages': messages,
        'temperature': temperature,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${settings.openAiApiKey.trim()}',
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );

    final choices = response.data?['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('OpenAI 返回格式异常: choices 为空');
    }
    final message = choices.first['message'];
    return (message?['content'] as String?) ?? '';
  }

  /// 翻译句子（流式帧）
  Stream<SentenceTranslationStreamFrame> translateStream(
    String text, {
    String? previousText,
    String? nextText,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    AppLogger.log('CustomAI', '执行自定义 AI 翻译: $text');
    final lang = targetLanguage ?? 'zh-CN';
    final systemPrompt =
        'You are a professional language translator. Translate the given English sentence into $lang. '
        'Return ONLY a valid JSON object matching: {"translation": "译文内容"}. Do not add any explanation or markdown formatting.';

    var userContent = 'Translate this sentence:\n"$text"';
    if (previousText != null || nextText != null) {
      userContent += '\nContext:\n';
      if (previousText != null) userContent += 'Previous: "$previousText"\n';
      if (nextText != null) userContent += 'Next: "$nextText"\n';
    }

    final raw = await _callOpenAi(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      cancelToken: cancelToken,
    );

    SentenceTranslation translation;
    try {
      final json = jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
      translation = SentenceTranslation.fromJson(json);
    } catch (_) {
      // 容错：大模型直接返回了纯文本译文
      translation = SentenceTranslation(translation: raw.trim());
    }

    yield SentenceTranslationStreamFrame(
      translation: translation,
      isFinal: true,
    );
  }

  /// 解析句子（语法、词汇、听力解析流式帧）
  Stream<SentenceAnalysisStreamFrame> analyzeStream(
    String text, {
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    AppLogger.log('CustomAI', '执行自定义 AI 句子解析: $text');
    final lang = targetLanguage ?? 'zh-CN';
    final systemPrompt =
        'You are an expert English teacher. Analyze the English sentence for a student whose native language is $lang.\n'
        'Return ONLY a valid JSON object adhering to this schema:\n'
        '{\n'
        '  "grammar": [\n'
        '    {"point": "Grammar rule / Clause name", "note": "Explanation in $lang"}\n'
        '  ],\n'
        '  "vocabulary": [\n'
        '    {"term": "Key word or phrase", "note": "Meaning and usage in $lang"}\n'
        '  ],\n'
        '  "listening": [\n'
        '    {"phrase": "Word connection or reduction", "note": "Pronunciation/listening tip in $lang"}\n'
        '  ]\n'
        '}\n'
        'Output JSON only without markdown code blocks.';

    final raw = await _callOpenAi(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': text},
      ],
      cancelToken: cancelToken,
    );

    final json = jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
    final analysis = SentenceAnalysis.fromJson(json);

    yield SentenceAnalysisStreamFrame(
      analysis: analysis,
      isFinal: true,
    );
  }

  /// 意群切分流式帧
  Stream<SenseGroupsStreamFrame> senseGroupsStream(
    String text, {
    CancelToken? cancelToken,
  }) async* {
    AppLogger.log('CustomAI', '执行自定义 AI 意群切分: $text');
    final systemPrompt =
        'Split the given English sentence into natural sense groups (chunks) for audio shadowing practice.\n'
        'Return ONLY a valid JSON object matching:\n'
        '{\n'
        '  "medium": ["chunk 1", "chunk 2", ...],\n'
        '  "fine": ["fine chunk 1", "fine chunk 2", ...]\n'
        '}\n'
        'Rules:\n'
        '1. The concatenation of all medium chunks (joined by space) MUST accurately reconstruct the original sentence words.\n'
        '2. Output pure JSON without markdown codeblock formatting.';

    final raw = await _callOpenAi(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': text},
      ],
      cancelToken: cancelToken,
    );

    final json = jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
    final result = SenseGroupResult.fromJson(json);

    yield SenseGroupsStreamFrame(
      result: result,
      isFinal: true,
    );
  }

  /// AI 词典查词
  Stream<AiDictionaryStreamFrame> lookupWordStream(
    String word, {
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    AppLogger.log('CustomAI', '执行自定义 AI 词典查词: $word');
    final lang = targetLanguage ?? 'zh-CN';
    final systemPrompt =
        'You are an authoritative learner dictionary. Provide detailed lexicographical analysis for the English word/phrase "$word" in $lang.\n'
        'Return ONLY a valid JSON object matching:\n'
        '{\n'
        '  "headword": "$word",\n'
        '  "pronunciation": {"us": "/.../", "uk": "/.../"},\n'
        '  "meanings": [\n'
        '    {\n'
        '      "partOfSpeech": "n./v./adj.",\n'
        '      "definition": "English definition",\n'
        '      "translation": "释义 in $lang",\n'
        '      "examples": [{"en": "Example sentence", "zh": "例句翻译"}]\n'
        '    }\n'
        '  ],\n'
        '  "commonExpressions": [\n'
        '    {\n'
        '      "phrase": "Collocation or idiom",\n'
        '      "meaning": "含义 in $lang",\n'
        '      "examples": [{"en": "Example", "zh": "例句"}]\n'
        '    }\n'
        '  ],\n'
        '  "wordFamily": [{"word": "related form", "relation": "n/v/adj"}],\n'
        '  "forms": [{"form": "plural or past", "type": "plural/past"}],\n'
        '  "etymology": "Brief etymology or memory trick",\n'
        '  "learnerTips": ["Common mistake or nuance tip"]\n'
        '}\n'
        'Pure JSON only without markdown code blocks.';

    final raw = await _callOpenAi(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': word},
      ],
      cancelToken: cancelToken,
    );

    final json = jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
    final entry = DictionaryEntry.fromJson(json);

    yield AiDictionaryStreamFrame(
      entry: entry,
      isFinal: true,
    );
  }

  /// AI 对话助教
  Stream<ChatTextFrame> streamChat({
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    AppLogger.log('CustomAI', '执行自定义 AI 对话');
    final lang = targetLanguage ?? 'zh-CN';
    final systemPrompt =
        'You are an empathetic, expert English tutor inside the Echo Loop app. '
        'Assist the learner with vocabulary, grammar, pronunciation, and understanding. '
        'Learner native language: $lang. '
        'Context info: ${jsonEncode(context)}';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final m in history) {
      messages.add({
        'role': m.role.name == 'assistant' ? 'assistant' : 'user',
        'content': m.text,
      });
    }

    final reply = await _callOpenAi(
      messages: messages,
      temperature: 0.7,
      cancelToken: cancelToken,
    );

    yield ChatTextFrame(
      text: reply,
      isFinal: true,
    );
  }

  /// 直连 Deepgram 进行长音频云端转写
  Future<TranscriptResult> transcribeWithDeepgram({
    required String filePath,
    required String mimeType,
    required String language,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final fileLength = await file.length();
    final apiKey = settings.deepgramApiKey.trim();
    final model = settings.deepgramModel.trim().isNotEmpty
        ? settings.deepgramModel.trim()
        : 'nova-2';

    final queryLang = language.isEmpty ? 'en' : language;
    final uri = Uri.parse('https://api.deepgram.com/v1/listen').replace(
      queryParameters: {
        'model': model,
        'smart_format': 'true',
        'punctuate': 'true',
        'utterances': 'true',
        'language': queryLang,
      },
    );

    AppLogger.log('Deepgram', '向 Deepgram 提交转录: $uri, 大小: $fileLength bytes');

    final uploadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    final response = await uploadDio.postUri<Map<String, dynamic>>(
      uri,
      data: file.openRead(),
      options: Options(
        headers: {
          'Authorization': 'Token $apiKey',
          'Content-Type': mimeType.isNotEmpty ? mimeType : 'audio/m4a',
          'Content-Length': fileLength,
        },
      ),
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );

    final data = response.data;
    if (data == null || !data.containsKey('results')) {
      throw Exception('Deepgram 返回数据异常: $data');
    }

    final results = data['results'] as Map<String, dynamic>;
    final channels = results['channels'] as List;
    final alt = (channels.first as Map<String, dynamic>)['alternatives'][0]
        as Map<String, dynamic>;

    final fullText = (alt['transcript'] as String?) ?? '';

    // 单词级时间戳
    final wordsRaw = (alt['words'] as List?) ?? [];
    final words = wordsRaw.map((w) {
      final wordText = (w['punctuated_word'] ?? w['word'] ?? '') as String;
      final startMs = (((w['start'] as num?) ?? 0) * 1000).round();
      final endMs = (((w['end'] as num?) ?? 0) * 1000).round();
      return WordTimestamp(
        word: wordText,
        startTime: Duration(milliseconds: startMs),
        endTime: Duration(milliseconds: endMs),
      );
    }).toList();

    // 句子分段列表
    final utterancesRaw = (results['utterances'] as List?) ?? [];
    final List<TranscriptSentence> sentences;
    if (utterancesRaw.isNotEmpty) {
      sentences = utterancesRaw.map((u) {
        final text = (u['transcript'] as String?) ?? '';
        final startMs = (((u['start'] as num?) ?? 0) * 1000).round();
        final endMs = (((u['end'] as num?) ?? 0) * 1000).round();
        return TranscriptSentence(
          text: text.trim(),
          startTime: Duration(milliseconds: startMs),
          endTime: Duration(milliseconds: endMs),
        );
      }).toList();
    } else {
      sentences = [
        TranscriptSentence(
          text: fullText,
          startTime: Duration.zero,
          endTime: words.isNotEmpty ? words.last.endTime : Duration.zero,
        ),
      ];
    }

    return TranscriptResult(
      sentences: sentences,
      words: words,
      fullText: fullText,
    );
  }
}
