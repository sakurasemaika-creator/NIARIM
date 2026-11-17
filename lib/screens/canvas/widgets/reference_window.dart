import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/theme_service.dart';
import '../../../widgets/docked_panel_scope.dart';

/// Owns the image for the canvas session. Dock moves and folds may rebuild the
/// view while the picker is still open.
class ReferenceImageController extends ChangeNotifier {
  Uint8List? _bytes;
  bool _loading = false;
  bool _disposed = false;

  Future<void> pickImage() async {
    if (_loading || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty || _disposed) return;
      final picked = result.files.first;
      var bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes != null && !_disposed) _bytes = bytes;
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The desktop dock hosts the image area directly. The phone layout supplies
/// its own floating frame and resize handle.
class ReferenceWindow extends StatefulWidget {
  const ReferenceWindow({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final ReferenceImageController controller;
  final VoidCallback onClose;

  @override
  State<ReferenceWindow> createState() => _ReferenceWindowState();
}

class _ReferenceWindowState extends State<ReferenceWindow> {
  Offset _position = const Offset(16, 72);
  Size _size = const Size(220, 240);

  @override
  Widget build(BuildContext context) {
    final docked = DockedPanelScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeService>().current;
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bytes = controller._bytes;
        final content = ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: SizedBox.expand(
            child: controller._loading
                ? const Center(child: CircularProgressIndicator())
                : bytes == null
                ? Center(
                    child: TextButton.icon(
                      onPressed: controller.pickImage,
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                      ),
                      label: Text(
                        l10n.referenceWindowSelectImageButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 6,
                    child: SizedBox.expand(
                      child: Image.memory(
                        bytes,
                        key: const ValueKey('referenceImage'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          ),
        );

        if (docked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bytes != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: l10n.referenceWindowSelectImageButton,
                    visualDensity: VisualDensity.compact,
                    onPressed: controller._loading
                        ? null
                        : controller.pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                ),
              Expanded(child: content),
            ],
          );
        }

        return Positioned(
          key: const ValueKey('referenceFloatingWindow'),
          left: _position.dx,
          top: _position.dy,
          child: Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            color: theme.panelBgColor,
            child: SizedBox(
              width: _size.width,
              height: _size.height,
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => setState(() => _position += d.delta),
                    child: Container(
                      color: theme.menuBgColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dashboard_customize_outlined,
                            size: 14,
                            color: theme.textColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.referenceWindowTitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: controller._loading
                                ? null
                                : controller.pickImage,
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 16,
                              color: theme.textColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: widget.onClose,
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: content),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) => setState(() {
                        _size = Size(
                          (_size.width + d.delta.dx).clamp(160.0, 520.0),
                          (_size.height + d.delta.dy).clamp(140.0, 520.0),
                        );
                      }),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Icon(
                          Icons.open_in_full,
                          size: 12,
                          color: theme.textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
