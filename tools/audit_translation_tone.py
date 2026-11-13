#!/usr/bin/env python3
import json
import re
from pathlib import Path

ARB_DIR = Path('lib/l10n')
TARGETS = {
    'en': ARB_DIR / 'app_en.arb',
    'es': ARB_DIR / 'app_es.arb',
    'fr': ARB_DIR / 'app_fr.arb',
    'ko': ARB_DIR / 'app_ko.arb',
    'zh': ARB_DIR / 'app_zh.arb',
    'zh_Hant': ARB_DIR / 'app_zh_Hant.arb',
}
SOURCE = ARB_DIR / 'app_ja.arb'

# Deliberately narrow list: only expressions that are clearly too casual/slangy
# for NIARIM's calm Japanese source tone. Ordinary friendly UI language is allowed.
# Do not flag words such as French "grave": it is also standard legal vocabulary
# (for example "négligence grave" = gross negligence).
BANNED = {
    'en': [r'\bgonna\b', r'\bwanna\b', r'\bgotta\b', r'\bkinda\b', r'\bsorta\b', r'\blol\b', r'\bomg\b', r'\bnope\b', r'\byep\b', r'\bsuper cool\b'],
    'es': [r'\bguay\b', r'\bcurro\b', r'\bchulo\b', r'\bflipante\b'],
    'fr': [r'\bouais\b', r'\bbosser\b', r'\btrop cool\b'],
    'ko': [r'ㅋㅋ', r'ㅎㅎ', r'대박', r'짱', r'꿀팁'],
    'zh': [r'牛逼', r'超赞', r'666', r'绝绝子', r'YYDS'],
    'zh_Hant': [r'超讚', r'666', r'絕絕子', r'YYDS'],
}


def values(path: Path):
    data = json.loads(path.read_text(encoding='utf-8'))
    return {k: v for k, v in data.items() if not k.startswith('@') and isinstance(v, str)}


def placeholders(text: str):
    # Walk balanced ICU expressions, including nested plural/select arms.
    # Selector values like zero{Empty} are literal copy, not placeholders.
    found = set()

    def closing(fragment, start):
        depth = 0
        for index in range(start, len(fragment)):
            if fragment[index] == '{':
                depth += 1
            elif fragment[index] == '}':
                depth -= 1
                if depth == 0:
                    return index
        return len(fragment)

    def parse(fragment):
        i = 0
        while i < len(fragment):
            if fragment[i] != '{':
                i += 1
                continue
            match = re.match(r'\{([A-Za-z_][A-Za-z0-9_]*)\s*(?=[},])', fragment[i:])
            if not match:
                i += 1
                continue
            found.add(match.group(1))
            position = i + match.end()
            if fragment[position] == '}':
                i = position + 1
                continue
            kind = re.match(r',\s*(?:plural|select|selectordinal)\s*,', fragment[position:])
            if kind:
                position += kind.end()
                while position < len(fragment):
                    while position < len(fragment) and fragment[position].isspace():
                        position += 1
                    if position >= len(fragment) or fragment[position] == '}':
                        break
                    choice = re.match(r'(?:=?[A-Za-z0-9_-]+)\s*\{', fragment[position:])
                    if not choice:
                        break
                    opening = position + choice.end() - 1
                    closing_index = closing(fragment, opening)
                    parse(fragment[opening + 1:closing_index])
                    position = closing_index + 1
            i = closing(fragment, i) + 1

    parse(text)
    return sorted(found)


source = values(SOURCE)
errors = []
for lang, path in TARGETS.items():
    translated = values(path)
    missing = sorted(set(source) - set(translated))
    extra = sorted(set(translated) - set(source))
    if missing:
        errors.append(f'{lang}: missing keys: {missing[:20]}')
    if extra:
        errors.append(f'{lang}: extra keys: {extra[:20]}')

    for key in sorted(set(source) & set(translated)):
        src = source[key]
        dst = translated[key]
        if placeholders(src) != placeholders(dst):
            errors.append(
                f'{lang}.{key}: placeholder mismatch {placeholders(src)} != {placeholders(dst)}'
            )
        for pattern in BANNED[lang]:
            if re.search(pattern, dst, flags=re.IGNORECASE):
                errors.append(f'{lang}.{key}: slang/casual expression matched {pattern!r}: {dst!r}')
        if re.search(r'!{2,}|\?{2,}|!\?|\?!', dst):
            errors.append(f'{lang}.{key}: excessive emphatic punctuation: {dst!r}')

# Store copy is part of the same tone contract.
store = Path('store/aso/metadata.json')
if store.exists():
    raw = store.read_text(encoding='utf-8')
    checks = {
        'en': BANNED['en'],
        'es': BANNED['es'],
        'fr': BANNED['fr'],
        'ko': BANNED['ko'],
        'zh': BANNED['zh'],
        'zh_Hant': BANNED['zh_Hant'],
    }
    for lang, patterns in checks.items():
        for pattern in patterns:
            if re.search(pattern, raw, flags=re.IGNORECASE):
                errors.append(f'store metadata: {lang} slang/casual expression matched {pattern!r}')

if errors:
    print('Translation tone audit failed:')
    for error in errors:
        print(f'- {error}')
    raise SystemExit(1)

print(f'Translation tone audit passed: Japanese source + {len(TARGETS)} localized ARB files')
