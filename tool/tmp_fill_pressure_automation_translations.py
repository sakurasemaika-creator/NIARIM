from pathlib import Path

TRANSLATIONS = {
    'lib/l10n/app_es.arb': {
        'brushSettingsPressureHardnessLabel': 'Dureza de presión',
        'customAutomationRunAction': 'Ejecutar',
        'customAutomationFavoriteAction': 'Añadir a favoritos',
        'customAutomationUnfavoriteAction': 'Quitar de favoritos',
    },
    'lib/l10n/app_fr.arb': {
        'brushSettingsPressureHardnessLabel': 'Dureté de pression',
        'customAutomationRunAction': 'Exécuter',
        'customAutomationFavoriteAction': 'Ajouter aux favoris',
        'customAutomationUnfavoriteAction': 'Retirer des favoris',
    },
    'lib/l10n/app_ko.arb': {
        'brushSettingsPressureHardnessLabel': '필압 경도',
        'customAutomationRunAction': '실행',
        'customAutomationFavoriteAction': '즐겨찾기에 추가',
        'customAutomationUnfavoriteAction': '즐겨찾기에서 제거',
    },
    'lib/l10n/app_zh.arb': {
        'brushSettingsPressureHardnessLabel': '压感硬度',
        'customAutomationRunAction': '运行',
        'customAutomationFavoriteAction': '添加到收藏',
        'customAutomationUnfavoriteAction': '从收藏中移除',
    },
    'lib/l10n/app_zh_Hant.arb': {
        'brushSettingsPressureHardnessLabel': '壓感硬度',
        'customAutomationRunAction': '執行',
        'customAutomationFavoriteAction': '加入收藏',
        'customAutomationUnfavoriteAction': '從收藏中移除',
    },
}


def append_message(text: str, key: str, value: str) -> str:
    if f'"{key}"' in text:
        return text
    stripped = text.rstrip()
    if not stripped.endswith('}'):
        raise SystemExit('invalid ARB ending')
    body = stripped[:-1].rstrip()
    if not body.endswith(','):
        body += ','
    return body + f'\n  "{key}": "{value}"\n}}\n'


for path, messages in TRANSLATIONS.items():
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    for key, value in messages.items():
        text = append_message(text, key, value)
    p.write_text(text, encoding='utf-8')
