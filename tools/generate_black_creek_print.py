"""Rasterize original fictional Black Creek lithographs, letterpress and painted signs."""
import calendar
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageColor, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/town_v2/print'
FONTS = ROOT / 'assets/fonts'
FACES = dict(bold='oldstandard/OldStandardTT-Bold.ttf', body='imfell/IMFeENrm28P.ttf',
             hand='cedarville/Cedarville-Cursive.ttf', display='rye/Rye-Regular.ttf')
RNG = random.Random(18900414)
INK, RED, GOLD, PAPER = '#372b20', '#833c32', '#d5a962', '#d6c69f'


def font(face, size):
    path = FONTS / FACES[face]
    return ImageFont.truetype(str(path if path.exists() else FONTS / FACES['bold']), size)


def ground(size, color, boards=False):
    w, h = size
    img = Image.new('RGB', size, color)
    d = ImageDraw.Draw(img)
    if boards:
        rgb = ImageColor.getrgb(color)
        for y in range(0, h, 33):
            offset = RNG.randrange(-11, 12)
            d.rectangle((0, y, w, y+31), fill=tuple(max(0, c+offset) for c in rgb))
            d.line((0, y+32, w, y+32), fill=tuple(max(0, c-16) for c in rgb))
            for _ in range(w//3):
                x, yy = RNG.randrange(w), y+RNG.randrange(31)
                d.line((x, yy, x+RNG.randrange(3, 67), yy), fill=tuple(max(0, c+offset-9) for c in rgb))
    return img


def age(img, wood=False):
    w, h = img.size
    data = img.load()
    clouds = Image.new('L', (max(3, w//28), max(3, h//28)))
    clouds.putdata([RNG.randrange(256) for _ in range(clouds.width*clouds.height)])
    cloud = clouds.resize((w, h), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(1.1)).load()
    for y in range(h):
        for x in range(w):
            edge = max(0, abs(x*2/w-1)**7 + abs(y*2/h-1)**7 - .34)
            n = RNG.randrange(-5, 6) + (cloud[x,y]-128)*.10 - edge*(11 if wood else 20)
            if wood and RNG.random() < .010:
                n -= 18
            data[x,y] = tuple(max(0, min(255, int(c+n))) for c in data[x,y])
    return img


def text(d, x, y, string, size, width, color=INK, face='bold', shadow=None):
    f = font(face, size)
    while f.getlength(string) > width and size > 5:
        size -= 1
        f = font(face, size)
    if shadow:
        d.text((x+2, y+2), string, font=f, fill=shadow, anchor='mm')
    d.text((x, y), string, font=f, fill=color, anchor='mm')


def border(d, w, h, color, inset=8):
    for n in (inset, inset+4):
        d.rounded_rectangle((n,n,w-1-n,h-1-n), radius=8, outline=color, width=1)
    for x in (inset+13, w-inset-14):
        for y in (inset+13, h-inset-14):
            d.polygon([(x-7,y),(x,y-4),(x+7,y),(x,y+4)], outline=color)


def sign(stem, title, sub, size, bg, ink=GOLD, boards=True):
    w, h = size
    im = ground(size, bg, boards)
    d = ImageDraw.Draw(im)
    border(d, w, h, ink, 5)
    text(d,w/2,h*(.40 if sub else .50),title,round(h*.39),w*.89,ink,'display',RED if boards else None)
    if sub:
        subtitle_scale = .28 if stem == 'depot' else .18
        text(d,w/2,h*.73,sub,round(h*subtitle_scale),w*.86,ink)
    for x in (10, w-11):
        d.ellipse((x-2,h//2-2,x+2,h//2+2), fill='#463429')
    age(im, boards).save(OUT / f'{stem}.png', optimize=True)


def train(d, x, y):
    # Five-ink lithographic plate: sky, relief, pine, rails and vignette engine.
    d.rectangle((x,y,x+210,y+169), fill='#95a4a0')
    d.ellipse((x+135,y+12,x+179,y+56), fill='#d1b274')
    d.polygon([(x,y+78),(x+43,y+17),(x+91,y+76),(x+131,y+32),(x+210,y+94),
               (x+210,y+169),(x,y+169)], fill='#697b76')
    d.polygon([(x+29,y+37),(x+43,y+17),(x+61,y+42),(x+48,y+35),(x+39,y+42)], fill='#d0c6a8')
    d.polygon([(x,y+124),(x+69,y+89),(x+105,y+106),(x+172,y+63),(x+210,y+78),(x+210,y+169),
               (x,y+169)], fill='#545e47')
    for i in range(28):
        px=x+RNG.randrange(210); py=y+RNG.randrange(85,140); s=RNG.randrange(9,24)
        d.polygon([(px-s//4,py),(px,py-s),(px+s//4,py)], fill=RNG.choice(['#354e44','#475d49','#53634d']))
    d.polygon([(x,y+154),(x+190,y+124),(x+210,y+133),(x+35,y+169),(x,y+169)], fill='#a98151')
    for i in range(11):
        d.line((x+i*17,y+161-i*3,x+i*17+11,y+169-i*3), fill=INK, width=2)
    d.line((x,y+159,x+210,y+124),fill=INK,width=2)
    d.line((x+20,y+169,x+210,y+132),fill=INK,width=2)
    for i in range(9):
        sx=x+158+i*5; sy=y+80-i*5
        d.ellipse((sx-9-i,sy-5-i,sx+9+i,sy+5+i),fill='#c0bba0')
    d.rectangle((x+42,y+101,x+82,y+138),fill='#63382d',outline=INK,width=2)
    d.rectangle((x+84,y+85,x+121,y+138),fill='#372e26')
    d.rounded_rectangle((x+109,y+100,x+173,y+130),radius=10, fill='#293a37',outline=INK,width=2)
    for i in (0,1,2):
        d.line((x+123+10*i,y+103,x+123+10*i,y+127),fill='#ab8050',width=1)
    d.polygon([(x+151,y+101),(x+175,y+101),(x+175,y+80),(x+181,y+74),(x+146,y+74),(x+152,y+82)],fill=INK)
    d.rectangle((x+91,y+90,x+113,y+108),fill='#b0955c',outline=INK,width=3)
    d.line((x+82,y+84,x+123,y+84),fill='#9b6846',width=4)
    d.polygon([(x+161,y+132),(x+181,y+128),(x+193,y+143),(x+167,y+144)],fill='#673831')
    for px, rad in ((51,7),(71,7),(97,12),(122,13),(151,10)):
        cy=y+138
        d.ellipse((x+px-rad,cy-rad,x+px+rad,cy+rad),fill=INK,outline='#ab8050',width=2)
        for i in range(6):
            a=i*math.tau/6
            d.line((x+px,cy,x+px+(rad-2)*math.cos(a),cy+(rad-2)*math.sin(a)),fill='#ab8050')
    d.line((x+96,y+140,x+151,y+140), fill='#c2a572',width=2)


def wall_calendar():
    im=ground((256,384),PAPER); d=ImageDraw.Draw(im)
    border(d,256,384,'#69453b',8)
    text(d,128,30,'BLACK CREEK & WESTERN RY.',23,227,RED,'display')
    text(d,128,53,'THE SCENIC LINE OF COLORADO',11,216,'#3e5248')
    train(d,23,65)
    d.rectangle((21,63,234,235),outline=RED,width=2)
    text(d,128,247,'— THROUGH THE SAN JUAN —',11,206)
    age(im).save(OUT/'calendar_april_1890.png')
    im=ground((320,214),PAPER); d=ImageDraw.Draw(im); border(d,320,214,'#814f3c',5)
    text(d,160,26,'APRIL   1890',27,250,RED,'display')
    for i, label in enumerate(('SUN','MON','TUE','WED','THU','FRI','SAT')):
        x=37+i*41
        text(d,x,55,label,12,38,RED if i==0 else INK)
        d.line((x-20,65,x-20,186),fill='#a59374')
    for row, week in enumerate(calendar.Calendar(6).monthdayscalendar(1890,4)):
        y=77+row*24
        d.line((17,y-12,304,y-12),fill='#a59374')
        for col, day in enumerate(week):
            if day:
                x=37+col*41
                text(d,x,y,str(day),19,32,RED if col==0 or day==14 else INK)
                if day==14: d.ellipse((x-14,y-10,x+15,y+11),outline=RED,width=2)
    d.polygon(((298,208),(313,193),(313,208)),fill='#b6a47d')
    text(d,160,197,'Oct. 14, 1885',16,145,'#684b3d','hand')
    age(im).save(OUT/'calendar_pad.png')


def papers():
    for stem, rows in {
        'landlady_note': ['Mr. Ward,','Hot water downstairs.', 'Kindly leave the key.', '— Mrs. Hargrove'],
        'notebook': ['E. Ward', 'April 14. Black Creek.', 'Night orders —', 'What did I hear?'],
    }.items():
        im=ground((256,192),PAPER); d=ImageDraw.Draw(im)
        for i,s in enumerate(rows):
            y=33+i*39
            d.line((15,y+14,241,y+14),fill='#ae9d7e')
            text(d,128,y,s,32,221,'#453b32','hand')
        if stem=='notebook':
            d.line((128,7,128,186),fill='#b9a484',width=2)
        age(im).save(OUT/f'{stem}.png')
    copy=('The grade east of the station remains open. Freight for the upper workings is to be held at the depot '
          'until the road is clear. The afternoon train will wait for the southern mail. The company requests '
          'that visitors keep to the public platform near the ticket window. Spring water is high at the bridge.')
    for i, headline in enumerate(('THE DIVISION ORDERS','SNOW UPON THE PASS')):
        im=ground((384,512),PAPER); d=ImageDraw.Draw(im)
        text(d,192,30,'The Black Creek Chronicle',31,361)
        d.line((12,47,372,47),fill=INK,width=2)
        text(d,192,59,'VOL. VIII.   BLACK CREEK, COLO.   APRIL 14, 1890.   FIVE CENTS.',11,356)
        d.line((12,69,372,69),fill=INK)
        text(d,192,91,headline,25,352,INK,'display')
        for col in range(3):
            x=13+col*122; y=117; line=''; f=font('body',9)
            if col: d.line((x-5,y,x-5,500),fill='#82745c')
            if col==i:
                d.rectangle((x,y,x+107,y+63),fill='#a99b7f',outline=INK)
                for l in range(20):
                    d.line((x+l*5,y+62,x+52+l*2,y+max(4,abs(l-9)*4)),fill='#59645a')
                y+=75
            for word in ((copy+' ')*5).split():
                if f.getlength(line+' '+word)>111:
                    d.text((x,y),line,font=f,fill=INK); y+=11; line=word
                    if y>494: break
                else: line=(line+' '+word).strip()
        age(im).save(OUT/('newspaper.png' if not i else 'newspaper_2.png'))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wall_calendar()
    papers()
    wallpaper=ground((256,256),'#673d36'); d=ImageDraw.Draw(wallpaper)
    for x,y in ((64,64),(192,192),(64,192),(192,64)):
        d.regular_polygon((x,y,49),4,outline='#856246')
        for i in range(8):
            a=i*math.tau/8; xx=x+math.cos(a)*21; yy=y+math.sin(a)*21
            d.ellipse((xx-5,yy-6,xx+5,yy+6),outline='#99704b',width=2)
            d.line((x,y,xx,yy),fill='#99704b')
        d.ellipse((x-6,y-6,x+6,y+6),fill='#ad8153')
    age(wallpaper).save(OUT/'damask.png')
    for stem,title,sub,w,h,bg,fg in [
        ('copper_mule','THE COPPER MULE','EST. 1882  •  CHOICE WINES & CIGARS',512,110,'#442722',GOLD),
        ('saloon','SALOON','THE COPPER MULE',256,110,'#502a24',GOLD),
        ('billiards','BILLIARDS','·  FARO  ·  BAR  ·',256,128,'#283338',GOLD),
        ('assay','BLACK CREEK & WESTERN RY.','ASSAY & DIVISION OFFICE',512,104,'#322f2b',GOLD),
        ('paymaster','PAYMASTER','SURVEYOR',240,106,'#303937',GOLD),
        ('miller','MILLER & SONS','GENERAL MERCHANDISE',512,112,'#5e4426','#ead09b'),
        ('post','U.S. POST OFFICE','BLACK CREEK',256,100,'#343d31','#e1c4a0'),
        ('miller_ghost','FLOUR · BACON','COAL OIL · BOOTS',512,152,'#786146','#bca982'),
        ('depot','BLACK CREEK','ELEV. 8,850 FT.',384,116,'#582f28','#efd18a'),
        ('western_union','WESTERN UNION','TELEGRAPH',256,111,'#294760','#eadbbb'),
        ('clinic','DR. ARTHUR CRANE, M.D.','PHYSICIAN & SURGEON',256,86,'#786746','#211c19'),
        ('closed','CLOSED','NOV. 1885',160,116,PAPER,INK),
        ('chronicle','THE BLACK CREEK CHRONICLE','JOB PRINTING',512,110,'#344236','#e1c4a0'),
        ('printer','PRINTER','JOB WORK',224,110,'#3c4739','#e1c4a0'),
        ('blacksmith','KOWALSKI','LIVERY & BLACKSMITH',384,106,'#49463c','#d2bc96'),
        ('shoeing','SHOEING','REPAIRS',224,104,'#3b3d36','#cfb58d'),
        ('beer','BEER  5¢','ON DRAUGHT  •  THE COPPER MULE',192,144,'#cbad73',RED),
        ('silver_spur','THE SILVER SPUR','AT THE COPPER MULE',192,144,'#c5ae83',RED),
        ('whiskey','OLD MULE','STRAIGHT RYE WHISKEY',128,96,'#bba17b',RED),
        ('wanted','WANTED','ENQUIRE AT THE CALABOOSE',192,144,'#bdac87',INK),
        ('quarantine','QUARANTINE','MJ SPUR   •   JUNE 1885',288,120,'#612f27','#dbc194'),
    ]:
        sign(stem,title,sub,(w,h),bg,fg,stem not in {'beer','silver_spur','wanted','clinic','closed','whiskey'})
    im=ground((320,288),'#302f2a'); d=ImageDraw.Draw(im); border(d,320,288,'#a98665')
    text(d,160,34,'The Copper Mule',34,275,'#cfc1a3','hand')
    for i, s in enumerate(('Beer on draught  .....   5¢','Rye whiskey  ........  10¢','Cigars  ...............   5¢','Ask for the Silver Spur')):
        text(d,160,82+i*43,s,25,274,'#cfc1a3','hand')
    age(im).save(OUT/'menu.png')
    im=ground((384,304),'#524637',True)
    for i,(x,y,title) in enumerate(((28,22,'TRAIN ORDERS'),(208,17,'WANTED'),(38,158,'FREIGHT'),(215,160,'NOTICE'))):
        card=ground((143,120),('#ddcba3','#c0ad83','#ba9569','#d2bd9a')[i]); d=ImageDraw.Draw(card)
        border(d,143,120,'#7e6650',4); text(d,72,24,title,16,119,RED)
        for j,s in enumerate(('Black Creek & Western', 'April 14th, 1890', 'By order of the agent.')):
            text(d,72,50+j*17,s,11,125,INK,'body')
        card=age(card).convert('RGBA').rotate((-4,5,3,-5)[i],resample=Image.Resampling.BICUBIC,expand=True)
        im.paste(card,(x,y),card)
    im.save(OUT/'depot_notices.png')


if __name__=='__main__':
    main()
