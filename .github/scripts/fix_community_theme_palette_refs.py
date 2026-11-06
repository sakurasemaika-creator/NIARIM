from pathlib import Path
import re

card = Path('lib/screens/community/widgets/community_work_card.dart')
s = card.read_text()
needle = "];\n\nclass CommunityWorkCard"
helper = "];\n\nList<Color> communityThumbnailGradient(ColorScheme scheme, int index) {\n  final gradients = communityThumbnailGradients(scheme);\n  return gradients[index % gradients.length];\n}\n\nclass CommunityWorkCard"
if 'List<Color> communityThumbnailGradient(' not in s:
    s = s.replace(needle, helper, 1)
card.write_text(s)

rx = re.compile(
    r'kCommunityThumbnailGradients\[work\s*\.thumbnailColorIndex\s*%\s*kCommunityThumbnailGradients\.length\]',
    re.MULTILINE,
)
for file in [
    'lib/screens/community/community_work_detail_screen.dart',
    'lib/screens/community/widgets/community_floating_preview.dart',
    'lib/screens/community/widgets/community_shorts_viewer.dart',
]:
    p = Path(file)
    s = p.read_text()
    s = rx.sub(
        'communityThumbnailGradient(Theme.of(context).colorScheme, work.thumbnailColorIndex)',
        s,
    )
    s = s.replace(
        "import 'community_work_card.dart' show kCommunityThumbnailGradients;",
        "import 'community_work_card.dart' show communityThumbnailGradient;",
    )
    p.write_text(s)
