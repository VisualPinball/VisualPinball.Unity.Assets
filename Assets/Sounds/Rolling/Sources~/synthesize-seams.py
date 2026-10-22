# SPDX-License-Identifier: CC0-1.0
"""Deterministic wood/plastic boundary sounds. Ceramic response pairs stay unassigned."""
from pathlib import Path
import math,wave,struct,hashlib,json
root=Path(__file__).resolve().parent.parent
rate=44100
presets={'Wood':(520,1170,2370),'Plastic':(860,1730,3210)}
results=[]
def render(name, modes):
    seconds=.12
    count=int(rate*seconds)
    # Two short excitations produce a subtle material-boundary response.
    values=[0.0]*count
    events=[(0,1),(int(.018*rate),.2)]
    kernelcount=int(rate*.09)
    kernel=[]
    for i in range(kernelcount):
        t=i/rate
        response=sum(math.sin(2*math.pi*freq*t)*math.exp(-t*(160+j*70))/(j+1) for j,freq in enumerate(modes))
        kernel.append(response * (1-math.exp(-t*2300)))
    for index,gain in events:
        for j,k in enumerate(kernel):
            at=index+j
            if at>=count:break
            values[at]+=gain*k
    mean=sum(values)/count
    peak=max(abs(v-mean) for v in values)
    scale=.17
    data=struct.pack('<'+'h'*count,*[round((v-mean)/peak*scale*32767) for v in values])
    path=root/'Clips'/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data)
    results.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'pcm_sha256':hashlib.sha256(data).hexdigest(),'type':'original procedural modal synthesis','recording':False,'loop':False,'frequencies_hz':modes,'sample_rate':rate})
for surface,modes in presets.items():
    render('Seam_'+surface,modes)
(root/'Sources~'/'synthesis.json').write_text(json.dumps({'description':'Optional wood/plastic material-boundary sounds for Steel responses. Original offline modal synthesis, not modified recordings. Ceramic response pairs remain unassigned until recordings are available. Generated PCM is dedicated to the public domain under CC0-1.0.','clips':results},indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({'generated':len(results),'sample_rate':rate,'channels':1}))
