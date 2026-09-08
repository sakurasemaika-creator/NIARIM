#!/usr/bin/env python3
import json
from pathlib import Path

translations = {
    'app_es.arb': {
        'customAutomationReturnToRecording': 'Volver al registro de operaciones',
        'customAutomationStopConfirmQuit': 'Dejar de registrar',
        'customAutomationPremiumHint': 'Solo para miembros Premium: permite registrar, editar, distribuir y volver a ejecutar operaciones.',
        'customAutomationYes': 'Sí',
        'customAutomationNo': 'No',
        'filterNameInkPool': 'Acumulación de tinta',
        'filterInkPoolColor': 'Color',
        'filterInkPoolRange': 'Rango',
        'filterInkPoolCenterWidth': 'Grosor central',
        'filterInkPoolLayerNameSuffix': '{name} Acumulación de tinta',
    },
    'app_fr.arb': {
        'customAutomationReturnToRecording': 'Revenir à l’enregistrement des actions',
        'customAutomationStopConfirmQuit': 'Arrêter l’enregistrement',
        'customAutomationPremiumHint': 'Réservé aux membres Premium : permet d’enregistrer, de modifier, de distribuer et de réexécuter des actions.',
        'customAutomationYes': 'Oui',
        'customAutomationNo': 'Non',
        'filterNameInkPool': 'Accumulation d’encre',
        'filterInkPoolColor': 'Couleur',
        'filterInkPoolRange': 'Plage',
        'filterInkPoolCenterWidth': 'Épaisseur centrale',
        'filterInkPoolLayerNameSuffix': '{name} Accumulation d’encre',
    },
    'app_ko.arb': {
        'customAutomationReturnToRecording': '작업 기록으로 돌아가기',
        'customAutomationStopConfirmQuit': '기록 그만두기',
        'customAutomationPremiumHint': 'Premium 회원 전용으로 작업을 기록·편집·배포·재실행할 수 있습니다.',
        'customAutomationYes': '예',
        'customAutomationNo': '아니요',
        'filterNameInkPool': '먹물 고임',
        'filterInkPoolColor': '색상',
        'filterInkPoolRange': '범위',
        'filterInkPoolCenterWidth': '중앙 두께',
        'filterInkPoolLayerNameSuffix': '{name} 먹물 고임',
    },
    'app_zh.arb': {
        'customAutomationReturnToRecording': '返回操作记录',
        'customAutomationStopConfirmQuit': '停止记录',
        'customAutomationPremiumHint': '仅限 Premium 会员，可记录、编辑、分发并重新执行操作。',
        'customAutomationYes': '是',
        'customAutomationNo': '否',
        'filterNameInkPool': '积墨',
        'filterInkPoolColor': '颜色',
        'filterInkPoolRange': '范围',
        'filterInkPoolCenterWidth': '中央宽度',
        'filterInkPoolLayerNameSuffix': '{name} 积墨',
    },
    'app_zh_Hant.arb': {
        'customAutomationReturnToRecording': '返回操作記錄',
        'customAutomationStopConfirmQuit': '停止記錄',
        'customAutomationPremiumHint': '僅限 Premium 會員，可記錄、編輯、分發並重新執行操作。',
        'customAutomationYes': '是',
        'customAutomationNo': '否',
        'filterNameInkPool': '積墨',
        'filterInkPoolColor': '顏色',
        'filterInkPoolRange': '範圍',
        'filterInkPoolCenterWidth': '中央寬度',
        'filterInkPoolLayerNameSuffix': '{name} 積墨',
    },
}

meta = {
    'placeholders': {
        'name': {'type': 'String'},
    },
}

for filename, entries in translations.items():
    path = Path('lib/l10n') / filename
    data = json.loads(path.read_text(encoding='utf-8'))
    for key, value in entries.items():
        if key in data:
            continue
        data[key] = value
    data.setdefault('@filterInkPoolLayerNameSuffix', meta)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8',
    )
