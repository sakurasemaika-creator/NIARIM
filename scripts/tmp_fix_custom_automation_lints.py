from pathlib import Path

p = Path('lib/engine/custom_automation_executor.dart')
s = p.read_text()
s = s.replace(
    "              if (activeLayerId == null) throw StateError('No active layer');",
    "              if (activeLayerId == null) {\n                throw StateError('No active layer');\n              }",
)
p.write_text(s)

p = Path('lib/services/filter_service.dart')
s = p.read_text()
s = s.replace(
    "      if (_currentFilterId == id) _currentFilterId = visibleFilters.firstOrNull?.id;",
    "      if (_currentFilterId == id) {\n        _currentFilterId = visibleFilters.firstOrNull?.id;\n      }",
)
p.write_text(s)
