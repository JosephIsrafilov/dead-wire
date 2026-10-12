import sys,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'local_deps'))
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86 import X86_OP_MEM,X86_REG_RIP
out=Path(__file__).parent
report=json.loads((out/'offline_dump_analysis.json').read_text())
blob=Path(report['engine_path']).read_bytes()
def off(rva):
    for s in report['pe']['sections']:
        if s['va']<=rva<s['va']+s['rawsize']:return s['rawptr']+rva-s['va']
    return None
md=Cs(CS_ARCH_X86,CS_MODE_64);md.detail=True
chunks=[]
for start,end in ((0x5474d0,0x547aa0),(0x547aa0,0x547eb3),(0x3e39240,0x3e39487),(0x5fcc0,0x607f4)):
    chunks.append('\n### '+hex(start)+'..'+hex(end))
    for i in md.disasm(blob[off(start):off(end)],start):
        text=f'{i.address:08x}  {i.bytes.hex():24s} {i.mnemonic} {i.op_str}'
        for op in i.operands:
            if op.type==X86_OP_MEM and op.mem.base==X86_REG_RIP:
                target=i.address+i.size+op.mem.disp
                pos=off(target)
                if pos is not None:
                    s=blob[pos:pos+180].split(b'\0',1)[0]
                    if len(s)>3 and all(c in b'\r\n\t' or 32<=c<127 for c in s):text+=' ; '+s.decode()
        chunks.append(text)
(out/'disassembly.txt').write_text('\n'.join(chunks),encoding='utf8')
print('Saved disassembly.txt; '+str(len(chunks))+' lines')
