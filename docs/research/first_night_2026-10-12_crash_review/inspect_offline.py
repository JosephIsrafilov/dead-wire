"""Offline, read-only dump/PE inspection; raw stack candidates are NOT an unwound stack."""
import hashlib, json, struct
from pathlib import Path

ENGINE = Path('C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe')
DUMPS = Path('C:/Users/YUSIF/AppData/Local/CrashDumps')
OUT = Path(__file__).parent / 'offline_dump_analysis.json'

def u(data, fmt, offset):
    return struct.unpack_from('<' + fmt, data, offset)

def string(data, rva):
    n, = u(data, 'I', rva)
    return data[rva+4:rva+4+n].decode('utf-16-le', errors='replace')

def pe_info(data):
    pe, = u(data, 'I', 0x3c)
    assert data[pe:pe+4] == b'PE\0\0'
    machine, count, timestamp, symptr, symcount, optsize, flags = u(data, 'HHIIIHH', pe+4)
    opt = pe+24
    imagebase, = u(data, 'Q', opt+24)
    imagesize, = u(data, 'I', opt+56)
    sections=[]
    for i in range(count):
        at=opt+optsize+i*40
        name=data[at:at+8].rstrip(b'\0').decode(errors='replace')
        vsize, va, rawsize, rawptr = u(data, 'IIII', at+8)
        sections.append(dict(name=name,va=va,vsize=vsize,rawsize=rawsize,rawptr=rawptr))
    def file_offset(rva):
        for s in sections:
            if s['va'] <= rva < s['va']+s['rawsize']:
                return s['rawptr']+rva-s['va']
        return None
    debugrva, debugsize=u(data,'II',opt+112+6*8)
    records=[]
    at=file_offset(debugrva)
    if at is not None:
        for i in range(debugsize//28):
            _,ts,major,minor,kind,size,addr,ptr=u(data,'IIHHIIII',at+i*28)
            record=data[ptr:ptr+size]
            item=dict(kind=kind,size=size,signature=record[:4].hex())
            if record[:4] == b'RSDS':
                item.update(guid_raw=record[4:20].hex(),age=u(record,'I',20)[0],pdb_path=record[24:].rstrip(b'\0').decode(errors='replace'))
            records.append(item)
    return dict(machine=hex(machine),timestamp=timestamp,imagebase=hex(imagebase),imagesize=imagesize,symbol_pointer=symptr,symbol_count=symcount,sections=sections,debug_records=records),file_offset

def inspect_dump(p, engine, pe, rva_to_file):
    data=p.read_bytes()
    signature,version,count,directory,checksum,timestamp,flags=u(data,'IIIIIIQ',0)
    assert signature==0x504D444D
    streams={}
    for i in range(count):
        kind,size,rva=u(data,'III',directory+i*12)
        streams[kind]=(size,rva)
    modules=[]
    _,rva=streams[4]
    for i in range(u(data,'I',rva)[0]):
        at=rva+4+i*108
        base,size,checksum,ts,name=u(data,'QIIII',at)
        cvsize,cvrva=u(data,'II',at+76)
        modules.append(dict(base=base,size=size,timestamp=ts,name=string(data,name),cv=data[cvrva:cvrva+cvsize].hex()))
    def locate(addr):
        for m in modules:
            if m['base'] <= addr < m['base']+m['size']:
                return Path(m['name']).name+'+'+hex(addr-m['base'])
        return None
    _,rva=streams[6]
    thread=u(data,'I',rva)[0]
    code,exflags,exrec,addr,paramcount,_=u(data,'IIQQII',rva+8)
    params=u(data,'15Q',rva+40)[:paramcount]
    ctxsize,ctxrva=u(data,'II',rva+160)
    regs={}
    if ctxsize>=256:
        names=['rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15','rip']
        regs=dict(zip(names,u(data,'17Q',ctxrva+120)))
    ranges=[]
    if 5 in streams:
        _,rva=streams[5]
        for i in range(u(data,'I',rva)[0]):
            start,size,memrva=u(data,'QII',rva+4+i*16)
            ranges.append((start,size,memrva))
    if 3 in streams:
        _,rva=streams[3]
        for i in range(u(data,'I',rva)[0]):
            at=rva+4+i*48
            if u(data,'I',at)[0]==thread:
                start,size,memrva=u(data,'QII',at+24)
                ranges.append((start,size,memrva))
    def readmem(addr,size):
        for start,n,r in ranges:
            if start<=addr and addr+size<=start+n:
                return data[r+addr-start:r+addr-start+size]
        return None
    candidates=[]
    sp=regs.get('rsp',0)
    for off in range(0,1024,8):
        raw=readmem(sp+off,8)
        if raw is None: break
        value=u(raw,'Q',0)[0]
        loc=locate(value)
        if loc:candidates.append(dict(stack_offset=hex(off),address=hex(value),module_offset=loc))
    m=next(m for m in modules if m['base']<=addr<m['base']+m['size'])
    relative=addr-m['base']
    exact=m['timestamp']==pe['timestamp'] and m['size']==pe['imagesize'] and m['name'].endswith(ENGINE.name)
    fileat=rva_to_file(relative) if exact else None
    instruction_bytes=engine[max(0,fileat-32):fileat+64].hex() if fileat is not None else None
    memory={}
    for name in ('rcx','rbx','rdx','rax','rdi','rsi'):
        raw=readmem(regs.get(name,0),64)
        memory[name]=raw.hex() if raw is not None else None
    return dict(name=p.name,sha256=hashlib.sha256(data).hexdigest(),header_timestamp=timestamp,flags=hex(flags),streams=sorted(streams),thread=thread,exception_code=hex(code),exception_address=hex(addr),exception_module=locate(addr),parameters=[hex(x) for x in params],registers={k:hex(v) for k,v in regs.items()},engine_module=m,matching_local_PE_timestamp_and_size=exact,instruction_file_offset=hex(fileat) if fileat is not None else None,instruction_window_start_relative=hex(relative-32),instruction_window_hex=instruction_bytes,memory_at_registers=memory,raw_stack_candidates_NOT_call_stack=candidates)

engine=ENGINE.read_bytes()
pe,rva_to_file=pe_info(engine)
report=dict(engine_path=str(ENGINE),engine_sha256=hashlib.sha256(engine).hexdigest(),pe=pe,dumps=[inspect_dump(p,engine,pe,rva_to_file) for p in sorted(DUMPS.glob('Godot_v4.7.1-stable_win64.exe.*.dmp'))])
OUT.write_text(json.dumps(report,indent=2),encoding='utf8')
print('Three dump exception contexts saved')

# Function boundaries from Windows x64 exception directory; RIP string references
# are byte-pattern candidates, not a full instruction decode.
pdata=next(s for s in pe['sections'] if s['name']=='.pdata')
functions=[u(engine,'III',pdata['rawptr']+i*12) for i in range(pdata['vsize']//12)]
entries=[]
for target in (0x547af6,0x5ffb1,0x248e05d,0x5255f,0x3e529b5,0x3e39378):
    entry=next((e for e in functions if e[0]<=target<e[1]),None)
    if not entry:continue
    start,end,unwind=entry
    at=rva_to_file(unwind)
    header=engine[at:at+4]
    n=header[2]
    codes=engine[at+4:at+4+n*2]
    strings=[]
    for rel in range(start,end-7):
        pos=rva_to_file(rel)
        if pos is None:continue
        if engine[pos:pos+2] in (b'\x48\x8d',b'\x4c\x8d') and engine[pos+2]&0xc7==5:
            dest=rel+7+u(engine,'i',pos+3)[0]
            off=rva_to_file(dest)
            if off is None:continue
            value=engine[off:off+600].split(b'\0',1)[0]
            if len(value)>=4 and all(c in b'\t\r\n' or 32<=c<127 for c in value):
                strings.append(dict(instruction_rva=hex(rel),string_rva=hex(dest),text=value.decode()))
    entries.append(dict(target=hex(target),start=hex(start),end=hex(end),unwind_rva=hex(unwind),unwind_header=header.hex(),unwind_codes=codes.hex(),rip_string_candidates=strings))
report['function_metadata']=entries
OUT.write_text(json.dumps(report,indent=2),encoding='utf8')
print('PE function metadata saved')

# Bounded AMD64 virtual unwind for these PE frames only (no symbols).
# Stop rather than guess on unsupported version/opcode/chained info.
def unwind_dump(p, d):
    data=p.read_bytes()
    _,_,count,directory=u(data,'IIII',0)
    streams={u(data,'III',directory+i*12)[0]:u(data,'III',directory+i*12)[1:] for i in range(count)}
    ranges=[]
    if 5 in streams:
        _,at=streams[5]
        for i in range(u(data,'I',at)[0]):ranges.append(u(data,'QII',at+4+i*16))
    _,at=streams[3]
    for i in range(u(data,'I',at)[0]):
        a=at+4+i*48
        if u(data,'I',a)[0]==d['thread']:ranges.append(u(data,'QII',a+24))
    def read(addr,n):
        for base,size,rva in ranges:
            if base<=addr and addr+n<=base+size:return data[rva+addr-base:rva+addr-base+n]
        raise ValueError('Stack memory missing at '+hex(addr))
    enginebase=d['engine_module']['base']
    names=['rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15']
    regs={k:int(v,16) for k,v in d['registers'].items()}
    frames=[]
    try:
        for frame in range(16):
            rip=regs['rip']; sp=regs['rsp']; rel=rip-enginebase
            entry=next((e for e in functions if e[0]<=rel<e[1]),None)
            if entry is None:raise ValueError('Not in engine function table at '+hex(rip))
            begin,end,uw=entry
            at=rva_to_file(uw); hdr=engine[at:at+4]
            version=hdr[0]&7; flags=hdr[0]>>3; n=hdr[2]; framereg=hdr[3]&15; frameoff=hdr[3]>>4
            if version!=1 or flags&4:raise ValueError('Unsupported unwind version/chain')
            cursor=0
            while cursor<n:
                offset,packed=engine[at+4+cursor*2:at+6+cursor*2]
                op=packed&15; info=packed>>4; cursor+=1
                active=(rel-begin>=hdr[1] or rel-begin>=offset)
                if op==0:
                    if active:regs[names[info]]=u(read(regs['rsp'],8),'Q',0)[0]; regs['rsp']+=8
                elif op==1:
                    slots=1 if info==0 else 2
                    amount=u(engine,'H' if info==0 else 'I',at+4+cursor*2)[0]*(8 if info==0 else 1)
                    cursor+=slots
                    if active:regs['rsp']+=amount
                elif op==2:
                    if active:regs['rsp']+=info*8+8
                elif op==3:
                    if active:regs['rsp']=regs[names[framereg]]-frameoff*16
                elif op in (4,5):
                    slots=1 if op==4 else 2
                    offset2=u(engine,'H' if op==4 else 'I',at+4+cursor*2)[0]*(8 if op==4 else 1)
                    cursor+=slots
                    if active:regs[names[info]]=u(read(regs['rsp']+offset2,8),'Q',0)[0]
                elif op in (8,9):cursor+=1 if op==8 else 2
                else:raise ValueError('Unsupported unwind opcode '+str(op))
            ra=u(read(regs['rsp'],8),'Q',0)[0]
            returnrel=ra-enginebase
            prev=rva_to_file(returnrel-8)
            preceding=engine[prev:prev+8].hex() if prev is not None else None
            frames.append(dict(rip=hex(rip),rva=hex(rel),function_begin_rva=hex(begin),rsp=hex(sp),return_slot=hex(regs['rsp']),return_rva=hex(returnrel),return_address=hex(ra),preceding_return_bytes=preceding))
            regs['rsp']+=8;regs['rip']=ra
    except ValueError as exc:stop=str(exc)
    else:stop='frame limit'
    return dict(frames=frames,stop=stop,caveat='Unsymbolized bounded AMD64 metadata unwind; review call sites, not a debugger stack.')
for d in report['dumps']:
    d['bounded_unwind']=unwind_dump(DUMPS/d['name'],d)
OUT.write_text(json.dumps(report,indent=2),encoding='utf8')
print('Bounded unwinds saved: '+str(len(report['dumps'])))
