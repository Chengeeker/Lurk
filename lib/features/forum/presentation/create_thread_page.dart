import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lurk/core/widgets/lurk_frosted_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_toast.dart';
import 'forum_controller.dart';

const _maxThreadImages = 9;

class CreateThreadPage extends ConsumerStatefulWidget {
  final String forumName;

  const CreateThreadPage({super.key, required this.forumName});

  @override
  ConsumerState<CreateThreadPage> createState() => _CreateThreadPageState();
}

class _CreateThreadPageState extends ConsumerState<CreateThreadPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  int _uploadedImages = 0;
  int _totalImages = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxThreadImages - _images.length;
    if (remaining <= 0) {
      AppToast.show(context, '最多添加 $_maxThreadImages 张图片');
      return;
    }

    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 95,
      );
      if (!mounted || picked.isEmpty) return;

      final accepted = picked.take(remaining).toList(growable: false);
      setState(() => _images.addAll(accepted));
      if (accepted.length < picked.length) {
        AppToast.show(context, '单个主题最多添加 $_maxThreadImages 张图片');
      }
    } catch (_) {
      if (mounted) AppToast.show(context, '无法打开系统图片选择器', isError: true);
    }
  }

  void _removeImage(int index) {
    if (_isSubmitting) return;
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '请输入帖子标题', isError: true);
      return;
    }
    if (content.isEmpty && _images.isEmpty) {
      AppToast.show(context, '请输入帖子内容或添加图片', isError: true);
      return;
    }

    final account = ref.read(authStateProvider).activeAccount;
    if (account == null || !account.isLogin) {
      AppToast.show(context, '请先登录百度账号', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadedImages = 0;
      _totalImages = _images.length;
    });

    final controller = ref.read(
      forumControllerFamily(widget.forumName).notifier,
    );
    final result = await controller.createThread(
      title: title,
      content: content,
      images: List<XFile>.unmodifiable(_images),
      onImageUploadProgress: (completed, total) {
        if (!mounted) return;
        setState(() {
          _uploadedImages = completed;
          _totalImages = total;
        });
      },
    );
    if (!mounted) return;

    if (result.success) {
      setState(() => _isSubmitting = false);
      AppToast.show(context, '贴吧已接收发帖请求');
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _isSubmitting = false);
    AppToast.show(context, result.errorMsg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final forumTitle = widget.forumName.replaceFirst(RegExp(r'吧$'), '');
    final uploadLabel = _totalImages > 0
        ? _uploadedImages >= _totalImages
              ? '图片已上传，正在提交帖子…'
              : '正在上传图片 ${_uploadedImages + 1}/$_totalImages…'
        : '正在提交帖子…';

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        appBar: LurkFrostedAppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text('在「$forumTitle」吧发帖'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_isSubmitting) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    TextField(
                      controller: _titleController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '请输入帖子标题',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentController,
                      enabled: !_isSubmitting,
                      minLines: 7,
                      maxLines: 14,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: '正文',
                        hintText: '写下你想分享的内容，也可以只发图片',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          '图片',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_images.length}/$_maxThreadImages',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var index = 0; index < _images.length; index++)
                          _buildImagePreview(index, colorScheme),
                        if (_images.length < _maxThreadImages)
                          _buildAddImageButton(colorScheme),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '图片会先上传到贴吧，再随主题提交；单张图片会压缩到 1080 像素以内、5 MB 以内。',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline, height: 1.45),
                    ),
                  ],
                ),
              ),
              if (_isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    uploadLabel,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting ? '正在发布' : '发表主题'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddImageButton(ColorScheme colorScheme) {
    return InkWell(
      onTap: _isSubmitting ? null : _pickImages,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text('添加图片', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(int index, ColorScheme colorScheme) {
    return SizedBox(
      width: 92,
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_images[index].path), fit: BoxFit.cover),
            Positioned(
              top: 3,
              right: 3,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _isSubmitting ? null : () => _removeImage(index),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 17),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
