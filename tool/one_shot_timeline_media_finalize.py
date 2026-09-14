from pathlib import Path
import re

p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()

picker = re.compile(
    r"(?P<i>\s*)final fileType = switch \(trackType\) \{\s*"
    r"_ClipTrackType\.audio => FileType\.audio,\s*"
    r"_ClipTrackType\.video => FileType\.video,\s*"
    r"_ClipTrackType\.image => FileType\.image,\s*"
    r"\};\s*final result = await FilePicker\.platform\.pickFiles\(type: fileType\);"
)
m = picker.search(s)
if not m:
    raise SystemExit('audio picker marker not found exactly once/current source already changed')
i = m.group('i')
lines = [
    f"{i}final allowedExtensions = trackType == _ClipTrackType.audio",
    f"{i}    ? const <String>['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'aiff', 'wma', 'mp4', 'm4v', 'mov', 'mkv', 'webm']",
    f"{i}    : null;",
    f"{i}final fileType = switch (trackType) {{",
    f"{i}  _ClipTrackType.audio => FileType.custom,",
    f"{i}  _ClipTrackType.video => FileType.video,",
    f"{i}  _ClipTrackType.image => FileType.image,",
    f"{i}}};",
    f"{i}final result = await FilePicker.platform.pickFiles(",
    f"{i}  type: fileType,",
    f"{i}  allowedExtensions: allowedExtensions,",
    f"{i});",
]
s = s[:m.start()] + '\n'.join(lines) + s[m.end():]

cb = re.compile(
    r'(?P<i>\s*)onDuplicate: \(\) => _duplicateClip\(clip\),\s*'
    r'onChanged: \(\) => setState\(\(\) \{\}\),'
)
m = cb.search(s)
if not m:
    raise SystemExit('clip callback block not found')
i = m.group('i')
repl = (
    f"{i}onDuplicate: () => _duplicateClip(clip),\n"
    f"{i}onChanged: () {{\n"
    f"{i}  setState(() {{}});\n"
    f"{i}  _syncMediaPlayback();\n"
    f"{i}}},\n"
    f"{i}isPlaying: () => _isPlaying,\n"
    f"{i}onTogglePlay: _togglePlay,"
)
s = s[:m.start()] + repl + s[m.end():]

at = s.find('class _ClipDetailSheet extends StatefulWidget')
if at < 0:
    raise SystemExit('clip detail sheet not found')
head, tail = s[:at], s[at:]
tail, n = re.subn(
    r'(\s*final VoidCallback onChanged;)',
    r'\1\n  final ValueGetter<bool> isPlaying;\n  final VoidCallback onTogglePlay;',
    tail,
    count=1,
)
if n != 1:
    raise SystemExit('clip detail fields marker failed')
tail, n = re.subn(
    r'required this\.onChanged,',
    'required this.onChanged,\n    required this.isPlaying,\n    required this.onTogglePlay,',
    tail,
    count=1,
)
if n != 1:
    raise SystemExit('clip detail constructor marker failed')
mark = re.search(r'(?P<i>\s*)IconButton\(\s*icon: const Icon\(Icons\.copy\),', tail)
if not mark:
    raise SystemExit('copy action marker not found')
i = mark.group('i')
play = (
    f"{i}if (_c.trackType == _ClipTrackType.audio || _c.trackType == _ClipTrackType.video)\n"
    f"{i}  IconButton(\n"
    f"{i}    icon: Icon(widget.isPlaying() ? Icons.pause : Icons.play_arrow),\n"
    f"{i}    tooltip: widget.isPlaying() ? l10n.commonPause : l10n.commonPlay,\n"
    f"{i}    onPressed: () {{ widget.onTogglePlay(); setState(() {{}}); }},\n"
    f"{i}  ),\n"
)
tail = tail[:mark.start()] + play + tail[mark.start():]
p.write_text(head + tail)
