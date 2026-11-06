from pathlib import Path


def match_paren(s, open_idx):
    depth=0; quote=None; esc=False; i=open_idx
    while i < len(s):
        c=s[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
        else:
            if c in "'\"": quote=c
            elif c=='(': depth+=1
            elif c==')':
                depth-=1
                if depth==0: return i
        i+=1
    raise RuntimeError(f'unmatched paren at {open_idx}')


def remove_close_button(block):
    marker='commonClose'
    pos=block.find(marker)
    if pos < 0: return block, False
    # Find the nearest button constructor containing the close label.
    candidates=[]
    for name in ('TextButton(', 'OutlinedButton(', 'FilledButton(', 'ElevatedButton('):
        p=block.rfind(name, 0, pos)
        if p>=0: candidates.append((p,name))
    if not candidates: return block, False
    start,name=max(candidates)
    open_idx=start+len(name)-1
    end=match_paren(block, open_idx)+1
    if not (start <= pos <= end): return block, False
    # Include a trailing comma and surrounding horizontal whitespace only.
    j=end
    while j<len(block) and block[j] in ' \t': j+=1
    if j<len(block) and block[j]==',': j+=1
    return block[:start]+block[j:], True


def patch_alert_dialogs(path):
    s=path.read_text(encoding='utf-8'); out=[]; cursor=0; changed=0
    needle='AlertDialog('
    while True:
        start=s.find(needle,cursor)
        if start<0: break
        open_idx=start+len('AlertDialog')
        end=match_paren(s,open_idx)+1
        block=s[start:end]
        if 'commonClose' in block and 'popup-standard-close' not in block:
            new_block,removed=remove_close_button(block)
            if removed:
                insert_at=len(needle)
                header="\n        // popup-standard-close: compact top-right close affordance.\n        iconPadding: const EdgeInsets.fromLTRB(0, 4, 4, 0),\n        icon: Align(\n          alignment: Alignment.centerRight,\n          child: IconButton(\n            visualDensity: VisualDensity.compact,\n            iconSize: 18,\n            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,\n            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),\n            icon: const Icon(Icons.close),\n          ),\n        ),"
                new_block=new_block[:insert_at]+header+new_block[insert_at:]
                out.append(s[cursor:start]); out.append(new_block); cursor=end; changed+=1
            else:
                out.append(s[cursor:end]); cursor=end
        else:
            out.append(s[cursor:end]); cursor=end
    if changed:
        out.append(s[cursor:]); path.write_text(''.join(out),encoding='utf-8')
    return changed


def patch_premium():
    p=Path('lib/widgets/premium_lock_widget.dart'); s=p.read_text(encoding='utf-8')
    old="""      child: Column(\n        mainAxisSize: MainAxisSize.min,\n        children: ["""
    new="""      child: Stack(\n        children: [\n          Column(\n            mainAxisSize: MainAxisSize.min,\n            children: ["""
    if old not in s: return 0
    s=s.replace(old,new,1)
    old2="""          // ボタン行\n          Padding(\n            padding: const EdgeInsets.all(12),\n            child: Row(\n              children: [\n                Expanded(\n                  child: OutlinedButton(\n                    onPressed: onClose,\n                    child: Text(l10n.commonClose),\n                  ),\n                ),\n                const SizedBox(width: 12),\n                Expanded(\n                  child: FilledButton(\n                    onPressed: onRegister,\n                    child: Text(l10n.premiumBannerRegisterButton),\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ],\n      ),"""
    new2="""              // Primary action only; closing is handled by the compact top-right X.\n              Padding(\n                padding: const EdgeInsets.all(12),\n                child: SizedBox(\n                  width: double.infinity,\n                  child: FilledButton(\n                    onPressed: onRegister,\n                    child: Text(l10n.premiumBannerRegisterButton),\n                  ),\n                ),\n              ),\n            ],\n          ),\n          Positioned(\n            right: 4,\n            top: 4,\n            child: IconButton(\n              visualDensity: VisualDensity.compact,\n              iconSize: 18,\n              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,\n              onPressed: onClose,\n              icon: const Icon(Icons.close),\n            ),\n          ),\n        ],\n      ),"""
    if old2 not in s: raise RuntimeError('premium footer anchor not found')
    p.write_text(s.replace(old2,new2,1),encoding='utf-8'); return 1


total=patch_premium()
for p in Path('lib').rglob('*.dart'):
    total += patch_alert_dialogs(p)
print(f'PATCHED_POPUPS={total}')
if total < 5:
    raise SystemExit(f'expected multiple popup patches, got {total}')
