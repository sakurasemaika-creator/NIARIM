from pathlib import Path
import re

ROOT = Path('test')


def brush_calls(text, needle='Brush('):
    out=[]; pos=0
    while True:
        start=text.find(needle,pos)
        if start<0: break
        depth=0; i=start+len(needle)-1; quote=None; esc=False
        while i<len(text):
            ch=text[i]
            if quote:
                if esc: esc=False
                elif ch=='\\': esc=True
                elif ch==quote: quote=None
            else:
                if ch in ('"', "'"): quote=ch
                elif ch=='(': depth+=1
                elif ch==')':
                    depth-=1
                    if depth==0:
                        out.append((start,i+1)); break
            i+=1
        pos=i+1
    return out


def direct_args(block):
    lines=block.splitlines(keepends=True)
    depth=0; args={}
    for idx,line in enumerate(lines):
        stripped=line.lstrip()
        m=re.match(r'(\w+)\s*:\s*(.*?),\s*$', stripped)
        if depth==1 and m:
            args[m.group(1)]=(idx,m.group(2).strip())
        depth += line.count('(')-line.count(')')
    return lines,args


def static_int(v):
    return int(v) if re.fullmatch(r'-?\d+', v or '') else None


def migrate(block):
    lines,args=direct_args(block)
    keys={'pressureMode','pressureStrength','blurRadius','mixingMode','mixingRate','edgeJitter','edgeJitterStrength'}
    present=keys & set(args)
    if not present: return block

    mode=None
    if 'pressureMode' in args:
        m=re.fullmatch(r'PressureMode\.(\w+)', args['pressureMode'][1])
        if not m: return block
        mode=m.group(1)
    strength=static_int(args.get('pressureStrength',(None,'100'))[1])
    blur=static_int(args.get('blurRadius',(None,'0'))[1])
    mix_rate=static_int(args.get('mixingRate',(None,'0'))[1])
    edge_strength=static_int(args.get('edgeJitterStrength',(None,'50'))[1])
    mix_mode=None
    if 'mixingMode' in args:
        m=re.fullmatch(r'BrushMixingMode\.(\w+)', args['mixingMode'][1])
        if not m: return block
        mix_mode=m.group(1)
    edge_val=args.get('edgeJitter',(None,'false'))[1]
    if edge_val not in ('true','false'): return block
    edge=edge_val=='true'
    if any(v is None for v in (strength,blur,mix_rate,edge_strength)): return block
    mode=mode or 'off'; mix_mode=mix_mode or 'off'
    weak=max(0,min(100,100-strength))
    size_enabled=mode in ('size','sizeAndOpacity')
    opacity_enabled=mode in ('opacity','sizeAndOpacity')
    mixing_enabled=mix_mode!='off' and mix_rate>0

    # delete direct obsolete argument lines
    drop={idx for key,(idx,_) in args.items() if key in keys}
    lines=[line for i,line in enumerate(lines) if i not in drop]
    block=''.join(lines)

    needs_profile=(size_enabled or opacity_enabled or blur>0 or edge or mixing_enabled)
    if not needs_profile: return block

    indent='  '
    # infer indentation from a direct fadeMode line
    for line in lines:
        if re.match(r'\s*fadeMode:', line):
            indent=line[:len(line)-len(line.lstrip())]; break
    profile=(
        f"{indent}pressureOn: const BrushPressureOnSettings(\n"
        f"{indent}  size: PressureRangeSetting(enabled: {str(size_enabled).lower()}, weak: {weak if size_enabled else 50}, strong: 100),\n"
        f"{indent}  opacity: PressureRangeSetting(enabled: {str(opacity_enabled).lower()}, weak: {weak if opacity_enabled else 50}, strong: 100),\n"
        f"{indent}  blur: PressureRangeSetting(enabled: {str(blur>0).lower()}, weak: {blur}, strong: {blur}),\n"
        f"{indent}  edgeJitter: PressureRangeSetting(enabled: {str(edge).lower()}, weak: {edge_strength}, strong: {edge_strength}),\n"
        f"{indent}  mixing: PressureMixingOnSetting(enabled: {str(mixing_enabled).lower()}, mode: BrushMixingMode.{mix_mode if mix_mode!='off' else 'simple'}, weakRate: {mix_rate}, strongRate: {mix_rate}),\n"
        f"{indent}),\n"
        f"{indent}pressureOff: const BrushPressureOffSettings(\n"
        f"{indent}  blur: FixedBrushSetting(enabled: {str(blur>0).lower()}, value: {blur}),\n"
        f"{indent}  edgeJitter: FixedBrushSetting(enabled: {str(edge).lower()}, value: {edge_strength}),\n"
        f"{indent}  mixing: PressureMixingOffSetting(enabled: {str(mixing_enabled).lower()}, mode: BrushMixingMode.{mix_mode if mix_mode!='off' else 'simple'}, rate: {mix_rate}),\n"
        f"{indent}),\n"
    )
    m=re.search(r'^\s*fadeMode:', block, re.M)
    if not m: return block
    return block[:m.start()] + profile + block[m.start():]


for p in ROOT.rglob('*.dart'):
    s=p.read_text()
    original=s
    for start,end in reversed(brush_calls(s)):
        s=s[:start]+migrate(s[start:end])+s[end:]
    if s!=original:
        p.write_text(s)
