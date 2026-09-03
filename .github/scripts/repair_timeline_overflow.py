from pathlib import Path

p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()
old = '                      _buildPreviewWithHandle(outerConstraints.maxHeight),'

if old in s:
    s = s.replace(
        old,
        '''                      Flexible(
                        flex: 3,
                        fit: FlexFit.loose,
                        child: _buildPreviewWithHandle(
                          outerConstraints.maxHeight,
                        ),
                      ),''',
        1,
    )
    marker = '  Widget _buildPreviewWithHandle(double maxAvailableHeight) {'
    start = s.index(marker)
    end = s.index('\n  /// プレビューと再生バーの間のシークバー。', start)
    block = s[start:end]
    old_return = '    return Column(\n      mainAxisSize: MainAxisSize.min,\n'
    if old_return not in block:
        raise SystemExit('preview Column return not found')
    block = block.replace(
        old_return,
        '''    return LayoutBuilder(
      builder: (context, constraints) {
        final allocatedPreviewHeight = constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight - 22.0)
            : maxPreviewHeight;
        final visiblePreviewHeight = math.min(
          previewHeight,
          allocatedPreviewHeight,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
''',
        1,
    )
    if '          height: previewHeight,' not in block:
        raise SystemExit('preview height pattern changed')
    block = block.replace(
        '          height: previewHeight,',
        '          height: visiblePreviewHeight,',
        1,
    )
    trimmed = block.rstrip()
    if not trimmed.endswith('    );'):
        raise SystemExit('unexpected preview function ending')
    trimmed = trimmed[:-len('    );')] + '        );\n      },\n    );'
    s = s[:start] + trimmed + '\n' + s[end:]
    p.write_text(s)
    print('applied timeline overflow repair')
elif 'visiblePreviewHeight' in s:
    print('timeline overflow repair already applied')
else:
    raise SystemExit('known repair pattern no longer matches; diagnosis required')
