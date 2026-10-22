# SPDX-License-Identifier: CC0-1.0
"""Original, deterministic modal synthesis. No recordings or steel samples are used."""
from pathlib import Path
import math,random,wave,struct,hashlib,json,shutil
root=Path(__file__).resolve().parent.parent
rate=44100
presets={'Wood':(520,1170,2370),'Plastic':(860,1730,3210),'Rails':(1480,2970,4930)}
results=[]
def render(name, modes, loop):
    seconds=3 if loop else .12
    count=int(rate*seconds);rng=random.Random(7041+sum(ord(x) for x in name))
    # Deterministic roughness excites short modal responses. Loop impulses and kernels wrap circularly.
    values=[0.0]*count
    events=[(int(i*rate*.013 + rng.random()*rate*.006)%count, .2+rng.random()*.6) for i in range(int(seconds/.013))] if loop else [(0,1),(int(.018*rate),.2)]
    kernelcount=int(rate*(.025 if loop else .09))
    kernel=[]
    for i in range(kernelcount):
        t=i/rate
        ceramic=sum(math.sin(2*math.pi*freq*t)*math.exp(-t*(160+j*70))/(j+1) for j,freq in enumerate(modes))
        kernel.append(ceramic * (1-math.exp(-t*2300)))
    for index,gain in events:
        for j,k in enumerate(kernel):
            at=index+j
            if loop:at%=count
            elif at>=count:break
            values[at]+=gain*k
    mean=sum(values)/count
    peak=max(abs(v-mean) for v in values)
    scale=.24 if loop else .17
    data=struct.pack('<'+'h'*count,*[round((v-mean)/peak*scale*32767) for v in values])
    path=root/'Clips'/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data)
    results.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'pcm_sha256':hashlib.sha256(data).hexdigest(),'type':'original procedural modal synthesis','recording':False,'loop':loop,'frequencies_hz':modes,'sample_rate':rate})
for surface,modes in presets.items():
    render('Ceramic_'+surface,modes,True)
    render('Seam_'+surface,modes,False)
if Path(__file__).resolve() != (root/'Sources~'/'synthesize-ceramic.py').resolve():
    shutil.copy2(Path(__file__),root/'Sources~'/'synthesize-ceramic.py')
(root/'Sources~'/'synthesis.json').write_text(json.dumps({'description':'Distinct acoustic starting points for ceramic balls and subtle material-boundary sounds. Original offline synthesis, not Powerball recordings and not modified steel recordings. Replace with measured recordings when available. Generated PCM is dedicated to the public domain under CC0-1.0.','clips':results},indent=2)+'\n',encoding='utf8')
print(json.dumps({'generated':len(results),'sample_rate':rate,'channels':1}))
