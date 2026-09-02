#!/usr/bin/env python3
from pathlib import Path
p = Path('test/functional_audit_batch20_test.dart')
text = p.read_text(encoding='utf-8')
old = "import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/models/project.dart';\n"
new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
if text.count(old) != 1:
    raise SystemExit('guard failed for batch20 imports')
p.write_text(text.replace(old, new), encoding='utf-8', newline='\n')
print('patched batch20 imports')
