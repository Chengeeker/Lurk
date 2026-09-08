import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/display_mode_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/haptic_feedback_util.dart';

class DisplayModeSettingsPage extends ConsumerStatefulWidget {
  const DisplayModeSettingsPage({super.key});

  @override
  ConsumerState<DisplayModeSettingsPage> createState() => _DisplayModeSettingsPageState();
}

class _DisplayModeSettingsPageState extends ConsumerState<DisplayModeSettingsPage> {
  List<DisplayMode> _modes = [];
  int _selectedModeId = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModes();
  }

  Future<void> _loadModes() async {
    final storage = ref.read(storageServiceProvider);
    final savedId = storage.getInt(DisplayModeService.keyDisplayModeId);
    final modes = await DisplayModeService.getSupportedModes();

    if (mounted) {
      setState(() {
        _modes = modes;
        _selectedModeId = savedId;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectMode(int modeId) async {
    HapticFeedbackUtil.light();
    final storage = ref.read(storageServiceProvider);
    await storage.setInt(DisplayModeService.keyDisplayModeId, modeId);
    await DisplayModeService.applyModeById(modeId);

    if (mounted) {
      setState(() {
        _selectedModeId = modeId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedbackUtil.light();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          '屏幕帧率设置',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      '没有生效？重启app试试',
                      style: TextStyle(
                        color: colorScheme.primary.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildModeTile(
                          title: '自动',
                          modeId: 0,
                          colorScheme: colorScheme,
                        ),
                        for (var i = 0; i < _modes.length; i++) ...[
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: theme.dividerColor.withValues(alpha: 0.06),
                          ),
                          _buildModeTile(
                            title: '#${_modes[i].id} ${_modes[i].width}x${_modes[i].height} @ ${_modes[i].refreshRate.toInt()}Hz',
                            modeId: _modes[i].id,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModeTile({
    required String title,
    required int modeId,
    required ColorScheme colorScheme,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedModeId == modeId;

    return InkWell(
      onTap: () => _selectMode(modeId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : theme.dividerColor.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
