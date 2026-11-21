import json
from pathlib import Path
p=Path('audit-dashboard/feature-audit-manifest.json')
data=json.loads(p.read_text())
visual_ids={
'brush.opacity','brush.pressure.opacity','brush.pressure.size','brush.fade',
'ruler.line','ruler.circle','ruler.ellipse','ruler.radial',
'effect.blur','autofill','layer.opacity','layer.blendmodes','layer.mesh',
'animation.onion','animation.camera','animation.keyframe','animation.fade'
}
nonvisual_ids={'animation.frame_duplicate','animation.frame_delete','animation.frame_reorder','save.project'}
all_ids=visual_ids|nonvisual_ids
for f in data['features']:
    if f['id'] not in all_ids:
        continue
    f['final_pass']=True
    if f['id'] in visual_ids:
        f['visual']=True
        f['evidence_note']='Final remaining audit: One-shot Final Remaining Audit #1 passed full functional/service/camera suite; #3 passed dedicated strict progression/constraint tests where required; generated evidence images were visually reviewed.'
    else:
        f['evidence_note']='Final remaining audit: functional/service behavior verified by successful executable state-transition or disk round-trip tests in One-shot Final Remaining Audit #1/#3.'
remaining=[f['id'] for f in data['features'] if not f.get('device_required',False) and not f.get('final_pass',False)]
if remaining:
    raise SystemExit('Non-device final_pass still false: '+', '.join(remaining))
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('Finalized',len(all_ids),'features; non-device remaining=0')
