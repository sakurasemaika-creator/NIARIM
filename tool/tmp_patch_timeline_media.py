from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


# Persist audio source offset in .niapro while keeping old projects compatible.
p = Path("lib/engine/niapro_serializer.dart")
s = p.read_text()
s = replace_once(
    s,
    "            'fadeOut': a.fadeOut,\n            'trackRow': a.trackRow,",
    "            'fadeOut': a.fadeOut,\n"
    "            'sourceStartFrame': a.sourceStartFrame,\n"
    "            'trackRow': a.trackRow,",
    "serialize audio source offset",
)
s = replace_once(
    s,
    "          fadeOut: (m['fadeOut'] as num?)?.toDouble() ?? 0.0,\n"
    "          trackRow: m['trackRow'] as int? ?? 0,",
    "          fadeOut: (m['fadeOut'] as num?)?.toDouble() ?? 0.0,\n"
    "          sourceStartFrame: m['sourceStartFrame'] as int? ?? 0,\n"
    "          trackRow: m['trackRow'] as int? ?? 0,",
    "deserialize audio source offset",
)
p.write_text(s)

p = Path("lib/screens/timeline/timeline_screen.dart")
s = p.read_text()

# Audio import accepts both normal audio files and video containers. Imported
# video containers are deliberately stored as MaterialType.audio and therefore
# never create a video layer/preview; only their audio is used on the audio row.
old_picker = '''    final fileType = switch (trackType) {
      _ClipTrackType.audio => FileType.audio,
      _ClipTrackType.video => FileType.video,
      _ClipTrackType.image => FileType.image,
    };
    final result = await FilePicker.platform.pickFiles(type: fileType);'''
new_picker = '''    final FilePickerResult? result;
    if (trackType == _ClipTrackType.audio) {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac',
          'mp4', 'mov', 'mkv', 'webm', 'm4v',
        ],
      );
    } else {
      final fileType = switch (trackType) {
        _ClipTrackType.audio => FileType.audio,
        _ClipTrackType.video => FileType.video,
        _ClipTrackType.image => FileType.image,
      };
      result = await FilePicker.platform.pickFiles(type: fileType);
    }'''
s = replace_once(s, old_picker, new_picker, "audio/video picker")

# Keep the source offset whenever an audio clip is updated, restored, or
# duplicated. This is required by both split and range-cut operations.
s = replace_once(
    s,
    "          fadeOut: clip.fadeOut,\n        ),\n      );",
    "          fadeOut: clip.fadeOut,\n"
    "          sourceStartFrame: clip.useStart,\n"
    "          trackRow: clip.trackRow,\n"
    "        ),\n      );",
    "persist audio clip offset",
)
s = replace_once(
    s,
    "          fadeOut: a.fadeOut,\n          useEnd: a.lengthFrames - 1,",
    "          fadeOut: a.fadeOut,\n"
    "          useStart: a.sourceStartFrame,\n"
    "          useEnd: a.sourceStartFrame + a.lengthFrames - 1,",
    "restore audio clip offset",
)
s = replace_once(
    s,
    "          fadeOut: clip.fadeOut,\n          trackRow: targetRow,\n        ),",
    "          fadeOut: clip.fadeOut,\n"
    "          sourceStartFrame: clip.useStart,\n"
    "          trackRow: targetRow,\n        ),",
    "duplicate audio model offset",
)
s = replace_once(
    s,
    "              fadeOut: clip.fadeOut,\n              useEnd: clip.lengthFrames - 1,",
    "              fadeOut: clip.fadeOut,\n"
    "              useStart: clip.useStart,\n"
    "              useEnd: clip.useStart + clip.lengthFrames - 1,",
    "duplicate audio UI offset",
)

# The enum gained extra presets before timeline labels did. Keep this existing
# screen analyzable until localized labels are added in the dedicated l10n task.
s = replace_once(
    s,
    "    AuroraHologramPreset.silverFoil =>\n      l10n.filterAuroraHologramPresetSilverFoil,\n  };",
    "    AuroraHologramPreset.silverFoil =>\n      l10n.filterAuroraHologramPresetSilverFoil,\n    _ => p.name,\n  };",
    "aurora preset fallback",
)
p.write_text(s)

# Waveform generation must explicitly select the first audio stream so video
# containers imported as audio do not accidentally feed their video stream to
# showwavespic.
p = Path("lib/engine/audio_waveform_service.dart")
s = p.read_text()
s = replace_once(
    s,
    "        '-y -i \"${srcFile.path}\" -filter_complex '\n"
    "        '\"showwavespic=s=${renderWidth}x$renderHeight:colors=white\" '\n"
    "        '-frames:v 1 \"${outFile.path}\"',",
    "        '-y -i \"${srcFile.path}\" -filter_complex '\n"
    "        '\"[0:a:0]showwavespic=s=${renderWidth}x$renderHeight:colors=white[wave]\" '\n"
    "        '-map \"[wave]\" -frames:v 1 \"${outFile.path}\"',",
    "waveform audio stream selection",
)
p.write_text(s)
