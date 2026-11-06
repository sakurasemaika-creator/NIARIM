from pathlib import Path

# The model/service/provider/premium gate are already landed on dev_branch, while the
# older integration patch also tries to add them. In the ephemeral Actions checkout,
# temporarily remove only those exact additions so the legacy screen-integration
# script can re-apply them together with Canvas/Timeline wiring. The final diff keeps
# these existing pieces unchanged.
p = Path('lib/services/premium_service.dart')
s = p.read_text()
s = s.replace('  customAutomation,\n', '', 1)
p.write_text(s)

p = Path('lib/app_bootstrap.dart')
s = p.read_text()
s = s.replace("import 'services/custom_automation_service.dart';\n", '', 1)
s = s.replace(
    '  final customAutomationService = CustomAutomationService();\n  await customAutomationService.init();\n',
    '',
    1,
)
s = s.replace(
    '    ChangeNotifierProvider.value(value: customAutomationService),\n',
    '',
    1,
)
p.write_text(s)
print('prepared partially landed custom automation base for legacy integration patch')
