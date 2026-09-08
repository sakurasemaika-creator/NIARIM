from pathlib import Path
import json

root = Path('.')

# Premium feature flag.
p = root / 'lib/services/premium_service.dart'
s = p.read_text()
old = '''enum PremiumFeature {\n  endCardEdit,\n  watermark,\n  toneCurve,\n  levelAdjustment,\n  unlimitedDuration,\n}'''
new = '''enum PremiumFeature {\n  endCardEdit,\n  watermark,\n  toneCurve,\n  levelAdjustment,\n  unlimitedDuration,\n  customAutomation,\n}'''
if old not in s:
    raise SystemExit('PremiumFeature enum anchor not found')
p.write_text(s.replace(old, new))

# Manager sheet receives the recording-start frame so scope eligibility remains factual.
p = root / 'lib/widgets/custom_automation_manager_sheet.dart'
s = p.read_text()
s = s.replace(
'''  final VoidCallback onRecordingStarted;\n\n  const CustomAutomationManagerSheet({\n    super.key,\n    required this.surface,\n    required this.onExecute,\n    required this.onRecordingStarted,\n  });''',
'''  final VoidCallback onRecordingStarted;\n  final int? recordingStartFrame;\n\n  const CustomAutomationManagerSheet({\n    super.key,\n    required this.surface,\n    required this.onExecute,\n    required this.onRecordingStarted,\n    this.recordingStartFrame,\n  });''')
s = s.replace(
'''    context.read<CustomAutomationService>().beginDraft(name: name, surface: surface);''',
'''    context.read<CustomAutomationService>().beginDraft(\n      name: name,\n      surface: surface,\n      recordingStartFrame: recordingStartFrame,\n    );''')
p.write_text(s)

ja = {
  'customAutomationTitle': '自動操作',
  'customAutomationAdd': '自動操作を新規追加',
  'customAutomationNewTitle': '新しい自動操作',
  'customAutomationNameLabel': '名前',
  'customAutomationStartRecording': '操作記録開始',
  'customAutomationStopRecording': '操作記録停止',
  'customAutomationRunConfirmTitle': 'この自動操作を実行しますか？',
  'customAutomationCurrentFrame': 'この操作を現在のフレームに行う',
  'customAutomationAllFrames': 'この操作を全フレームに行う',
  'customAutomationRenameTitle': '自動操作名を変更',
  'customAutomationDeleteTitle': 'この自動操作を削除しますか？',
  'customAutomationImport': '読み込む',
  'customAutomationExport': '配布・書き出し',
  'customAutomationRerecord': '再記録',
  'customAutomationImportInvalid': '自動操作ファイルを読み込めませんでした',
  'customAutomationEmpty': '記録済みの自動操作はありません',
  'customAutomationStepCount': '{count} 手順',
  'customAutomationReturnToRecording': '操作記録に戻る',
  'customAutomationStopConfirmTitle': '自動操作の登録をやめますか？',
  'customAutomationStopConfirmQuit': 'やめる',
  'customAutomationStopConfirmContinue': '続ける',
  'customAutomationPremiumHint': 'プレミアム会員限定で、操作を記録・編集・配布・再実行できます。',
}
en = {
  'customAutomationTitle': 'Automation',
  'customAutomationAdd': 'New automation',
  'customAutomationNewTitle': 'New automation',
  'customAutomationNameLabel': 'Name',
  'customAutomationStartRecording': 'Start recording',
  'customAutomationStopRecording': 'Stop recording',
  'customAutomationRunConfirmTitle': 'Run this automation?',
  'customAutomationCurrentFrame': 'Run on the current frame',
  'customAutomationAllFrames': 'Run on all frames',
  'customAutomationRenameTitle': 'Rename automation',
  'customAutomationDeleteTitle': 'Delete this automation?',
  'customAutomationImport': 'Import',
  'customAutomationExport': 'Share / Export',
  'customAutomationRerecord': 'Re-record',
  'customAutomationImportInvalid': 'Could not import this automation file',
  'customAutomationEmpty': 'No recorded automations',
  'customAutomationStepCount': '{count} steps',
  'customAutomationReturnToRecording': 'Return to recording',
  'customAutomationStopConfirmTitle': 'Stop registering this automation?',
  'customAutomationStopConfirmQuit': 'Stop',
  'customAutomationStopConfirmContinue': 'Continue',
  'customAutomationPremiumHint': 'Premium only: record, edit, share, and replay your own actions.',
}

def patch_arb(path, values):
    data = json.loads(path.read_text())
    for key, value in values.items():
        data[key] = value
        if key == 'customAutomationStepCount':
            data['@customAutomationStepCount'] = {
                'placeholders': {'count': {'type': 'int'}}
            }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

patch_arb(root / 'lib/l10n/app_ja.arb', ja)
patch_arb(root / 'lib/l10n/app_en.arb', en)
