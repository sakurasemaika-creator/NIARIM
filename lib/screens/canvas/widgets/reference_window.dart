import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/theme_service.dart';

/// 資料ウィンドウ（アニメ制作では三面図・キャラクター設定表・背景資料などを
/// 見ながら作業することがほとんどのため、任意の参考画像を常に表示できる
/// ウィンドウを用意した）。他のツールオプション系パネルとは独立して
/// 動作する（ツールを切り替えても閉じない・パネル外タップでも閉じない）。
///
/// [pinned]がfalse（スマホ表示の既定）の場合はタイトルバーのドラッグで
/// 自由に位置移動できるフローティングウィンドウになる。[pinned]がtrue
/// （PC/DeXモード）の場合は、画面右上の固定位置に常駐する「固定表示」
/// になり、位置ドラッグは行えない（誤操作で行方不明になるのを防ぎ、他の
/// 常設ドッキングパネルと同じ感覚で扱えるようにする）。どちらの場合も
/// 右下角のハンドルでのサイズ変更はできる。
class ReferenceWindow extends StatefulWidget {
  final VoidCallback onClose;
  final bool pinned;
  const ReferenceWindow({super.key, required this.onClose, this.pinned = false});

  @override
  State<ReferenceWindow> createState() => _ReferenceWindowState();
}

class _ReferenceWindowState extends State<ReferenceWindow> {
  Offset _position = const Offset(16, 72);
  Size _size = const Size(220, 240);
  Uint8List? _imageBytes;
  bool _loading = false;

  Future<void> _pickImage() async {
    setState(() => _loading = true);
    try {
      // withData: trueでバイト列も取得する。Web版はdart:ioのFileが使えず
      // pathも常にnullになるため、bytesが無い場合のみpath経由で読み込む
      // （自動塗りサムネイル調整で発生した「Web版で読み込み中のまま
      // 止まる」不具合と同じ轍を踏まないための対応）。
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      var bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes != null && mounted) setState(() => _imageBytes = bytes);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeService>().current;
    final scheme = Theme.of(context).colorScheme;
    // 固定表示（PC/DeXモード）は画面右上の一定位置に常駐させる
    // （ツールバー・トップバーと重ならない位置）。フローティング表示
    // （スマホ）は_positionで管理する自由な位置を使う。
    return Positioned(
      left: widget.pinned ? null : _position.dx,
      right: widget.pinned ? 12 : null,
      top: widget.pinned ? 64 : _position.dy,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        color: theme.panelBgColor,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: SizedBox(
          width: _size.width,
          height: _size.height,
          child: Column(
            children: [
              // タイトルバー：ドラッグで位置移動（固定表示中は移動不可）。
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: widget.pinned
                    ? null
                    : (d) => setState(() => _position += d.delta),
                child: Container(
                  color: theme.menuBgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_customize_outlined, size: 14, color: theme.textColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l10n.referenceWindowTitle,
                            style: TextStyle(fontSize: 11, color: theme.textColor, fontWeight: FontWeight.w600, fontFamily: 'Kuramubon'),
                            overflow: TextOverflow.ellipsis),
                      ),
                      InkWell(
                        onTap: _pickImage,
                        child: Icon(Icons.add_photo_alternate_outlined, size: 16, color: theme.textColor),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: widget.onClose,
                        child: Icon(Icons.close, size: 16, color: theme.textColor),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: scheme.surfaceContainerHighest,
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _imageBytes == null
                          ? Center(
                              child: TextButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                                label: Text(l10n.referenceWindowSelectImageButton, style: const TextStyle(fontSize: 12)),
                              ),
                            )
                          // InteractiveViewerでピンチ拡大・パンできるようにし、
                          // 資料の細部（線の入り方等）まで確認できるようにする。
                          : ClipRect(
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 6,
                                child: Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity),
                              ),
                            ),
                ),
              ),
              // 右下角のリサイズハンドル。
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
                    child: Icon(Icons.open_in_full, size: 12, color: theme.textColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
