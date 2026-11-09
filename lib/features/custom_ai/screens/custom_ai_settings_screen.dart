import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../models/custom_ai_settings.dart';
import '../providers/custom_ai_provider.dart';

/// 自定义 AI 与 Deepgram 转录配置页面
class CustomAiSettingsScreen extends ConsumerStatefulWidget {
  const CustomAiSettingsScreen({super.key});

  @override
  ConsumerState<CustomAiSettingsScreen> createState() =>
      _CustomAiSettingsScreenState();
}

class _CustomAiSettingsScreenState
    extends ConsumerState<CustomAiSettingsScreen> {
  late final TextEditingController _openAiBaseUrlController;
  late final TextEditingController _openAiApiKeyController;
  late final TextEditingController _openAiModelController;
  late final TextEditingController _deepgramApiKeyController;
  late final TextEditingController _deepgramModelController;

  bool _openAiEnabled = true;
  bool _deepgramEnabled = true;
  bool _obscureOpenAiKey = true;
  bool _obscureDeepgramKey = true;

  bool _isTestingOpenAi = false;
  bool _isTestingDeepgram = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(customAiSettingsProvider);
    _openAiEnabled = settings.openAiEnabled;
    _openAiBaseUrlController =
        TextEditingController(text: settings.openAiBaseUrl);
    _openAiApiKeyController =
        TextEditingController(text: settings.openAiApiKey);
    _openAiModelController = TextEditingController(text: settings.openAiModel);

    _deepgramEnabled = settings.deepgramEnabled;
    _deepgramApiKeyController =
        TextEditingController(text: settings.deepgramApiKey);
    _deepgramModelController =
        TextEditingController(text: settings.deepgramModel);
  }

  @override
  void dispose() {
    _openAiBaseUrlController.dispose();
    _openAiApiKeyController.dispose();
    _openAiModelController.dispose();
    _deepgramApiKeyController.dispose();
    _deepgramModelController.dispose();
    super.dispose();
  }

  void _saveCurrentSettings() {
    ref.read(customAiSettingsProvider.notifier).updateSettings(
          CustomAiSettings(
            openAiEnabled: _openAiEnabled,
            openAiBaseUrl: _openAiBaseUrlController.text.trim(),
            openAiApiKey: _openAiApiKeyController.text.trim(),
            openAiModel: _openAiModelController.text.trim(),
            deepgramEnabled: _deepgramEnabled,
            deepgramApiKey: _deepgramApiKeyController.text.trim(),
            deepgramModel: _deepgramModelController.text.trim(),
          ),
        );
  }

  Future<void> _testOpenAi() async {
    _saveCurrentSettings();
    setState(() => _isTestingOpenAi = true);
    try {
      final result =
          await ref.read(customAiSettingsProvider.notifier).testOpenAi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $result'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('❌ AI 连接测试失败'),
          content: SelectableText(
            '请检查 Base URL、API 密钥或模型名称是否正确：\n\n$e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestingOpenAi = false);
    }
  }

  Future<void> _testDeepgram() async {
    _saveCurrentSettings();
    setState(() => _isTestingDeepgram = true);
    try {
      final result =
          await ref.read(customAiSettingsProvider.notifier).testDeepgram();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $result'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('❌ Deepgram 测试失败'),
          content: SelectableText(
            '请检查 Deepgram API Key 是否正确有效：\n\n$e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestingDeepgram = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      onPopInvokedWithResult: (_, __) => _saveCurrentSettings(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('自定义 AI 与转录'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: '保存',
              onPressed: () {
                _saveCurrentSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('配置已保存'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            // 会员权限说明卡片
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '永久高级特权已激活',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '已移除所有内购与额度限制，搭配自定义 API 自由使用。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // ── 第一部分：OpenAI 兼容接口 ──
            Text(
              '大语言模型 (OpenAI 兼容)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用自定义 AI'),
                      subtitle: const Text('接管句子翻译、解析、意群拆分与 AI 对话'),
                      value: _openAiEnabled,
                      onChanged: (val) {
                        setState(() => _openAiEnabled = val);
                        _saveCurrentSettings();
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: AppSpacing.s),
                    TextField(
                      controller: _openAiBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        hintText: 'https://api.openai.com/v1',
                        helperText: '支持 OpenAI, DeepSeek, OneAPI, Ollama 等',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _saveCurrentSettings(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextField(
                      controller: _openAiModelController,
                      decoration: const InputDecoration(
                        labelText: '模型名称 (Model ID)',
                        hintText: 'gpt-4o-mini 或 deepseek-chat',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _saveCurrentSettings(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextField(
                      controller: _openAiApiKeyController,
                      obscureText: _obscureOpenAiKey,
                      decoration: InputDecoration(
                        labelText: 'API 密钥 (API Key)',
                        hintText: 'sk-...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureOpenAiKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureOpenAiKey = !_obscureOpenAiKey;
                            });
                          },
                        ),
                      ),
                      onChanged: (_) => _saveCurrentSettings(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _isTestingOpenAi ? null : _testOpenAi,
                        icon: _isTestingOpenAi
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bolt_outlined),
                        label: Text(
                          _isTestingOpenAi ? '正在测试连接...' : '测试 AI 连接',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // ── 第二部分：Deepgram 云端转写 ──
            Text(
              '语音转写服务 (Deepgram)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用 Deepgram 转录'),
                      subtitle: const Text('长音频自动识别、断句与单词级毫秒时间戳'),
                      value: _deepgramEnabled,
                      onChanged: (val) {
                        setState(() => _deepgramEnabled = val);
                        _saveCurrentSettings();
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: AppSpacing.s),
                    TextField(
                      controller: _deepgramModelController,
                      decoration: const InputDecoration(
                        labelText: 'Deepgram 模型',
                        hintText: 'nova-2',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _saveCurrentSettings(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextField(
                      controller: _deepgramApiKeyController,
                      obscureText: _obscureDeepgramKey,
                      decoration: InputDecoration(
                        labelText: 'Deepgram API Key',
                        hintText: '填入你的 Deepgram 密钥',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureDeepgramKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureDeepgramKey = !_obscureDeepgramKey;
                            });
                          },
                        ),
                      ),
                      onChanged: (_) => _saveCurrentSettings(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed:
                            _isTestingDeepgram ? null : _testDeepgram,
                        icon: _isTestingDeepgram
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mic_none_outlined),
                        label: Text(
                          _isTestingDeepgram
                              ? '正在验证 Deepgram Key...'
                              : '测试 Deepgram 连接',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
