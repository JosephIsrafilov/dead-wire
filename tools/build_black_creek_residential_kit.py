"""Playable Hargrove common rooms, millwork and residential kit (Blender metres)."""
import math

import build_hargrove_architecture_blender as a

box, beam, mesh, lathe, kit = a.box, a.beam, a.mesh, a.lathe, a.kit


def register():
    for n,c in {'Wain':'7D674E','WainDark':'6F5A44','HallPlaster':'A49A84','PaperStripe':'968C73','IronTrim':'35332F','Tin':'736E5E',
                'LinenCloth':'B8AA8D','Wax':'C4AB79','LeatherTrim':'4D382C','TrunkCanvas':'746750',
                'Mirror':'728380','Needle':'344D42','NeedleD':'263E37','NeedleL':'4C6251',
                'Bark':'544438','Cabin':'867057','CabinDark':'6C5846'}.items():
        a.palette(n,c,.38 if n=='Mirror' else .87,.20 if n in ('IronTrim','Tin','Mirror') else 0)


def inner_wall(axis, start, end, fixed, base, top, apertures=(), side=1, two_faces=False, striped=False):
    cuts=sorted({base,top,*[z for _,_,u,v in apertures for z in (u,v)]})
    for lo,hi in zip(cuts,cuts[1:]):
        holes=[(u-w/2,u+w/2) for u,w,s,t in apertures if s < hi-.001 and t > lo+.001]
        for lo_x,hi_x in a.spans(start,end,holes):
            a.slab('PaperFaded' if striped else 'HallPlaster',axis,lo_x,hi_x,fixed,lo,hi,.15)
    for side in (-1,1) if two_faces else (side,):
        f=fixed+side*.082
        holes=[(u-w/2,u+w/2) for u,w,s,_ in apertures if s<base+.84-.001]
        for u,v in a.spans(start,end,holes):
            a.slab('Wain',axis,u,v,f,base+.035,base+.84,.020)
            count=math.ceil((v-u)/.098)
            for j in range(1,count):
                x=u+j*(v-u)/count
                a.slab('WainDark',axis,x-.004,x+.004,f+side*.013,base+.10,base+.808,.008)
            a.slab('DeskD',axis,u,v,f+side*.022,base+.011,base+.115,.030)
            a.slab('Apron',axis,u,v,f+side*.026,base+.807,base+.858,.036)
        a.slab('Apron',axis,start,end,f+side*.028,top-.094,top-.014,.050)
        if striped:
            for lo,hi in zip(cuts,cuts[1:]):
                lo,hi=max(lo,base+.853),min(hi,top-.09)
                if hi-lo<.005: continue
                holes=[(u-w/2,u+w/2) for u,w,s,t in apertures if s < hi-.001 and t > lo+.001]
                for u,v in a.spans(start,end,holes):
                    for j in range(math.ceil((u-start)/.184),math.ceil((v-start)/.184)):
                        x=start+j*.184
                        if u+.018<x<v-.021:
                            a.slab('PaperStripe',axis,x-.013,x+.013,f-side*.004,lo,hi,.003)


def plank_floor(x0,x1,y0,y1,z):
    n=math.ceil((x1-x0)/.176)
    w=(x1-x0)/n
    for j in range(n):
        x=x0+(j+.5)*w
        split=y0+(y1-y0)*(.26+(j%8)*.062)
        for lo,hi in ((y0,split),(split,y1)):
            box(kit.RNG.choices(['Fir','FirD','FirL'],[9,3,2])[0],(x,(lo+hi)/2,z-.045),(w-.004,hi-lo-.006,.09))


def ceiling(x0,x1,y0,y1,z):
    box('Plaster',((x0+x1)/2,(y0+y1)/2,z+.035),(x1-x0,y1-y0,.07))
    for j in range(1, math.ceil((y1-y0)/.69)):
        y=y0+j*.69
        box('WainDark',((x0+x1)/2,y,z-.034),(x1-x0,.091,.072))


def common():
    # Common floor at z=0, the rentable floor 2.71 m higher. Y+ faces Creek Avenue.
    plank_floor(-3.87,3.87,-4.24,4.24,0)
    ceiling(-3.87,-1.55,-4.24,4.24,2.61)
    ceiling(-.27,3.87,-4.24,4.24,2.61)
    ceiling(-1.55,-.27,-4.24,-1.34,2.61)
    ceiling(-1.55,-.27,3.23,4.24,2.61)
    for axis,lo,hi,fixed,coords in [
        ('X',-3.95,3.95,4.30,[1.98]),('X',-3.95,3.95,-4.30,[2.40]),
        ('Y',-4.30,4.30,3.95,[-2.67,2.28]),('Y',-4.30,4.30,-3.95,[-.82,2.51])]:
        d=(-1.46,1.22) if fixed==4.30 else None
        holes=a.openings(coords,0,d)
        if fixed==-4.30: holes+=a.openings([],0,(-1.86,1.10))
        inner_wall(axis,lo,hi,fixed,0,2.61,holes,-1 if fixed>0 else 1)
        for u in coords: a.sash(axis,u,fixed,0,False)
    a.door('X',-1.46,4.30,0,1.22,True)
    # The common dining room opens off the forward hall; kitchen opens behind the stair.
    inner_wall('Y',-1.34,4.30,-.23,0,2.61,a.openings([],0,(3.15,1.31)),1,True)
    inner_wall('X',-3.95,-1.60,1.46,0,2.61,a.openings([],0,(-2.53,1.15)),1,True)
    plank_floor(-3.84,-.10,-6.82,-4.30,-.13)
    ceiling(-3.84,-.10,-6.82,-4.30,2.12)
    for x in (-3.84,-.10): inner_wall('Y',-6.82,-4.30,x,-.13,2.21,(),-1 if x>-.2 else 1)
    inner_wall('X',-3.84,-.10,-6.82,-.13,2.21,a.openings([-2.73],-.21,(-.92,1.12)),1)
    a.sash('X',-2.73,-6.82,-.21,False)
    a.door('X',-.92,-6.82,-.13,1.12,True)
    # Straight closed-stringer flight from front to rear, with real exposed treads.
    for i in range(16):
        top=(i+1)*2.71/16
        y=3.15-i*.282
        box('Fir',( -.91,y,top-.026),(1.28,.289,.052))
        box('FirD',(-.91,y+.137,top-.106),(1.24,.035,.14))
    for x in (-1.56,-.26):
        beam('FirD',(x,3.33,.20),(x,-1.30,2.71),.109,.215)
        beam('DeskD',(x,3.22,.98),(x,-1.25,3.61),.079,.074)
        for i in (0,3,6,9,12,15):
            top=(i+1)*2.71/16
            y=3.15-i*.282
            box('Apron',(x,y,top+.416),(.047,.052,.832))
    # Upstairs layout: cross-landing at the rear of the flight, three bays, terminal window.
    plank_floor(-3.85,3.85,-4.24,-1.24,2.71)
    plank_floor(.46,3.85,-1.24,-.10,2.71)
    plank_floor(-3.85,-1.55,-1.24,4.24,2.71)
    plank_floor(-.27,.46,-1.24,4.24,2.71)
    plank_floor(-1.55,-.27,3.30,4.24,2.71)
    ceiling(-3.88,3.88,-4.25,4.25,5.33)
    # The NE room is emitted separately; the accessible opening is preserved in both halves.
    inner_wall('X',.49,3.85,-.10,2.71,5.33,a.openings([],2.71,(1.88,1.12)),-1)
    inner_wall('Y',-.10,4.24,.43,2.71,5.33,(),-1)
    inner_wall('X',-3.85,-1.55,-1.20,2.71,5.33,a.openings([],2.71,(-2.56,1.10)),-1)
    a.door('X',-2.56,-1.20,2.71,1.10,False)
    inner_wall('X',-3.85,3.85,-2.28,2.71,5.33,a.openings([],2.71,(-.03,1.12)) ,1)
    a.door('X',-.03,-2.28,2.71,1.12,True)
    # Details beyond closed doors are blocked, not presented as enterable this phase.
    for x,side,lo,hi,u in [(-3.95,1,-4.24,4.24,1.97),(3.95,-1,-4.24,-.10,-1.65)]:
        inner_wall('Y',lo,hi,x,2.71,5.33,a.openings([u],2.71),side)
        a.sash('Y',u,x,2.71,False)
    inner_wall('X',-3.95,.49,4.30,2.71,5.33,a.openings([-2.48],2.71),-1)
    a.sash('X',-2.48,4.30,2.71,False)
    inner_wall('X',-3.95,3.95,-4.30,2.71,5.33,a.openings([-2.27,2.24],2.71),1)
    for u in (-2.27,2.24): a.sash('X',u,-4.30,2.71,False)
    for x in (-1.56,-.26):
        for i in range(21):
            y=-1.14+i*.209
            box('Apron',(x,y,3.13),(.048,.047,.84))
        box('DeskD',(x,.962,3.56),(.075,4.19,.074))
    # Coat pegs, resident register and a wool runner mark the entry without signage clutter.
    peg_rail(-3.839,3.36,1.65,axis='Y')
    box('DeskD',(-3.835,2.52,1.67),(.078,.63,.58))
    box('LinenCloth',(-3.789,2.52,1.67),(.026,.52,.46))
    for j in range(16):
        box('TrunkCanvas',(-1.48,3.65-j*.049,.009),(.75,.048,.017))
    # Shared table, benches, stove and kitchen preparation surface.
    box('Desk',(1.96,.15,.75),(1.46,2.43,.07))
    for x in (1.37,2.55):
        for y in (-.88,1.18): box('DeskD',(x,y,.36),(.10,.10,.72))
    for x in (.89,3.02):
        box('FirD',(x,.15,.415),(.31,1.90,.079))
        for y in (-.61,.88): box('DeskD',(x,y,.20),(.12,.24,.4))
    stove(3.58,.29)
    box('Desk',(-2.35,-6.18,.77),(2.76,.59,.07))
    for x in (-3.57,-1.13):
        for y in (-6.39,-5.98): box('DeskD',(x,y,.36),(.102,.099,.74))
    kit.flush('hargrove_common_1890')


def stove(x,y):
    for dx in (-.19,.19):
        for dy in (-.18,.18): box('IronTrim',(x+dx,y+dy,.105),(.085,.086,.21))
    lathe('IronTrim',x,y,[(.18,.24),(.25,.28),(.33,.24),(.67,.25),(.72,.28),(.75,.27)],12)
    box('IronTrim',(x,y+.237,.48),(.34,.079,.26))
    box('Tin',(x+.128,y+.28,.50),(.057,.036,.038))
    lathe('IronTrim',x,y,[(.735,.086),(2.61,.086)],10)
    box('StoneD',(x,y,.021),(.81,.75,.04))


def peg_rail(x,y,z,axis='Y'):
    if axis=='Y':
        box('DeskD',(x,y,z),(.042,.74,.106))
        for j in range(5): beam('Fir',(x+.022,y-.30+j*.15,z),(x+.090,y-.30+j*.15,z+.024),.027)
    else:
        box('DeskD',(x,y,z),(.74,.042,.106))
        for j in range(5): beam('Fir',(x-.30+j*.15,y+.022,z),(x-.30+j*.15,y+.090,z+.024),.027)


def room_details():
    # Quietly worn kit: the foot chest and chair stay clear of the central walk line.
    x,y=-1.04,-.42
    box('TrunkCanvas',(x,y,.211),(.80,.37,.39))
    box('LeatherTrim',(x,y,.030),(.83,.40,.048))
    box('LeatherTrim',(x,y,.389),(.83,.40,.045))
    for xx in (x-.31,x+.31):
        box('LeatherTrim',(xx,y,.419),(.062,.38,.031))
        box('LeatherTrim',(xx,y-.194,.215),(.062,.038,.36))
        box('BrassAged',(xx,y-.22,.339),(.068,.021,.049))
    peg_rail(-1.58,-1.46,1.68)
    box('DeskD',(1.565,-1.62,1.49),(.076,.37,.48))
    box('Mirror',(1.517,-1.62,1.49),(.018,.29,.39))
    beam('DeskD',(1.40,-1.90,1.096),(1.40,-1.62,1.096),.028)
    for i in range(5):
        box('LinenCloth',(1.407+(i%2)*.012,-1.87+i*.047,.984-i*.006),(.033,.044,.238))

    chair(.84,.02)
    # Candle support next to the headboard, clear of the mattress and its quilt.
    box('Desk',(.01,1.79,.572),(.42,.36,.06))
    for xx in (-.17,.19):
        for yy in (1.66,1.92): box('DeskD',(xx,yy,.284),(.042,.041,.57))
    # A pocket watch laid next to the chamberstick, with a worn brass bezel.
    lathe('BrassAged',.142,1.705,[(.603,.028),(.606,.031),(.616,.031),(.618,.028)],12)
    lathe('LinenCloth',.142,1.705,[(.618,.024),(.619,.024)],12)
    box('IronTrim',(.143,1.711,.620),(.002,.014,.001),math.radians(-19))
    box('IronTrim',(.148,1.703,.620),(.012,.002,.001),math.radians(-16))
    lathe('BrassAged',.142,1.739,[(.606,.005),(.616,.005)],8)
    # The old stove below vents through the building's brick stack; no decorative glowing fire.
    x,y=1.41,-1.91
    lathe('IronTrim',x,y,[(0,.081),(2.62,.081)],10)
    for z in (.12,1.03,2.49): lathe('Tin',x,y,[(z,.089),(z+.04,.089)],10)
    kit.flush('hargrove_room04_details')


def chair(x,y):
    box('Desk',(x,y,.445),(.38,.38,.051))
    for dx in (-.151,.151):
        for dy in (-.151,.151):
            lathe('DeskD',x+dx,y+dy,[(0,.025),(.38,.024),(.45,.030)],7)
            if dx<0: box('Desk',(x+dx,y,.655),(.040,.040,.410))
    box('Desk',(x-.151,y,.853),(.045,.369,.079))
    for j in (-1,0,1): box('Apron',(x-.151,y+j*.085,.681),(.032,.038,.244))


def lantern():
    # Tapered glazed cage, ventilating cap and separate lamp fount. Origin is cage base.
    box('IronTrim',(0,0,.021),(.21,.21,.042))
    box('IronTrim',(0,0,.242),(.278,.278,.032))
    for sx in (-1,1):
        for sy in (-1,1): beam('IronTrim',(sx*.091,sy*.091,.03),(sx*.132,sy*.132,.24),.012)
    for sign in (-1,1):
        for axis in (0,1):
            quad=[(-.089,sign*.09,.039),(.089,sign*.09,.039),(.130,sign*.131,.231),(-.130,sign*.131,.231)]
            if axis: quad=[(y,x,z) for x,y,z in quad]
            mesh('ClearChimney',quad,[(0,1,2,3)])
    mesh('IronTrim',[(-.146,-.146,.26),(.146,-.146,.26),(.146,.146,.26),(-.146,.146,.26),(0,0,.351)],
         [(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
    lathe('IronTrim',0,0,[(.343,.043),(.375,.035),(.395,.048),(.411,.037)],8)
    lathe('BrassAged',0,0,[(.042,.061),(.072,.064),(.086,.033),(.097,.028)],10)
    kit.flush('black_creek_oil_lantern')


def bracket():
    box('IronTrim',(0,0,.04),(.095,.039,.25))
    ps=[(0,.012,.135),(0,.051,.188),(0,.161,.222),(0,.260,.184),(0,.302,.065),(0,.302,-.005)]
    for p,q in zip(ps,ps[1:]): beam('IronTrim',p,q,.023)
    beam('IronTrim',(0,.023,-.051),(0,.233,.130),.015)
    kit.flush('black_creek_lantern_bracket')


def chamberstick():
    lathe('BrassAged',0,0,[(0,.048),(.006,.080),(.016,.097),(.026,.100),(.028,.091),(.018,.079),(.015,.022)],14)
    ps=[(.093,0,.020),(.125,0,.016),(.145,0,.036),(.135,0,.060),(.106,0,.064),(.093,0,.028)]
    for p,q in zip(ps,ps[1:]): beam('BrassAged',p,q,.012)
    lathe('BrassAged',0,0,[(.015,.029),(.037,.022),(.048,.023)],12)
    lathe('Wax',0,0,[(.045,.017),(.098,.018),(.114,.015)],10)
    box('Soot',(0,0,.119),(.005,.005,.015))
    kit.flush('black_creek_chamberstick')


def spruce():
    lathe('Bark',0,0,[(0,.16),(1.73,.112),(4.0,.069),(6,.026),(6.8,.004)],7)
    for layer in range(7):
        z=1.64+layer*.76
        radius=1.70-layer*.22
        for j in range(7):
            ang=j*math.tau/7+layer*.75+kit.RNG.uniform(-.16,.16)
            d=kit.RNG.uniform(.78,1.13)*radius
            u=math.cos(ang); v=math.sin(ang)
            verts=[(0,0,z+.33),(u*d*.51-v*d*.23,v*d*.51+u*d*.23,z-.04),
                (u*d,v*d,z-.22),(u*d*.51+v*d*.21,v*d*.51-u*d*.21,z-.11),
                (u*d*.43,v*d*.43,z+.34),(u*d*.26,v*d*.26,z-.30)]
            for k,face in enumerate(((0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5))):
                mesh(('Needle','NeedleL','Needle','NeedleD','NeedleD','Needle','NeedleD','NeedleD')[k],verts,[face])
    lathe('NeedleD',0,0,[(6.04,.28),(6.47,.18),(6.97,.012)],7)
    kit.flush('black_creek_spruce')


def cabin(name, w, d, ridge, paint):
    # Economical hill cottages, modest sash, shingles, insulated plinth and stove flue.
    box('Plinth',(0,0,.19),(w,d,.38))
    for j in range(math.ceil(w/.37)):
        x=-w/2+(j+.5)*w/math.ceil(w/.37)
        box(kit.RNG.choice(['Stone','StoneD']),(x,d/2+.027,.17),(w/math.ceil(w/.37)-.01,.09,.29))
    side=2.62
    front=d/2
    a.wall('X',-w/2,w/2,front,.38,side,a.openings([w*.25],.38,(-w*.24,1.04)))
    a.door('X',-w*.24,front,.38,1.04)
    a.sash('X',w*.25,front,.38,True,True)
    for x in (-w/2,w/2):
        box(paint,(x,0,1.49),(.15,d,2.24))
        for j in range(math.ceil(d/.19)):
            box('CabinDark',(x+math.copysign(.094,x),-d/2+(j+.5)*.19,1.49),(.045,.039,2.24))
    box(paint,(0,-d/2,1.49),(w,.15,2.24))
    for y in (-front,front):
        vs=[(-w/2,y,side),(w/2,y,side),(0,y,ridge)]
        if y>0: vs.reverse()
        mesh(paint,vs,[(0,1,2)])
    for s in (-1,1):
        a.roof_panel((0,0,ridge+.07),(s*(w/2+.29),0,side-.10),d+.58,(0,1,0))
        beam('Apron',(0,front+.29,ridge+.065),(s*(w/2+.29),front+.29,side-.10),.080)
    box('BrickD',(w*.23,-d*.19,ridge-.09),(.32,.35,1.16))
    box('StoneD',(w*.23,-d*.19,ridge+.51),(.39,.42,.085))
    for y,h in ((front+.56,.17),(front+.30,.34)):
        box('FirD',(-w*.24,y,h/2),(1.27,.31,h))
    kit.flush(name)


def build():
    common()
    room_details()
    lantern()
    bracket()
    chamberstick()
    spruce()
    cabin('black_creek_cottage_a',4.54,4.37,4.18,'Cabin')
    cabin('black_creek_cottage_b',4.88,4.58,4.53,'Batten')
