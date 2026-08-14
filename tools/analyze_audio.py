#!/usr/bin/env python3
"""BGM 신호 분석 도구 — 사용법: python3 tools/analyze_audio.py [오디오 파일]

ffmpeg와 numpy가 필요하다. 레벨/다이내믹스, 대역 분포, 크로마 기반 조성 추정,
템포 추정, 구간별 RMS를 출력하고 /tmp/bless_analysis.png에 스펙트로그램을 저장한다.
"""
import sys
import subprocess, numpy as np

SR = 44100
raw = subprocess.run(["ffmpeg","-v","quiet","-i",sys.argv[1] if len(sys.argv) > 1 else "resources/audio/bless.ogg",
                      "-f","f32le","-acodec","pcm_f32le","-ar",str(SR),"-"],
                     capture_output=True).stdout
x = np.frombuffer(raw, dtype=np.float32).reshape(-1,2)
L, R = x[:,0], x[:,1]
mono = x.mean(axis=1)
dur = len(mono)/SR
print(f"duration {dur:.1f}s  samples {len(mono)}")

# --- 레벨/다이내믹스 ---
peak = np.abs(x).max()
rms = np.sqrt((mono**2).mean())
print(f"peak {20*np.log10(peak):.2f} dBFS   rms {20*np.log10(rms):.2f} dBFS   crest {20*np.log10(peak/rms):.1f} dB")
clip = int((np.abs(x) > 0.999).sum())
print(f"clipped samples: {clip}")

# 스테레오 상관/폭
corr = np.corrcoef(L, R)[0,1]
side = (L-R)/2; mid=(L+R)/2
width = np.sqrt((side**2).mean())/max(1e-12, np.sqrt((mid**2).mean()))
print(f"stereo corr {corr:.3f}   side/mid {width:.3f}")

# --- 1초 RMS 곡선 (구조) ---
win = SR
n = len(mono)//win
env = np.array([np.sqrt((mono[i*win:(i+1)*win]**2).mean()) for i in range(n)])
env_db = 20*np.log10(np.maximum(env, 1e-9))
print("\nRMS envelope (dBFS, 1s):")
for i in range(0, n, 5):
    seg = env_db[i:i+5]
    print(f"  {i:3d}s " + " ".join(f"{v:6.1f}" for v in seg))

# --- STFT ---
NF, HOP = 4096, 1024
frames = 1 + (len(mono)-NF)//HOP
Wf = np.hanning(NF)
idx = np.arange(NF)[None,:] + HOP*np.arange(frames)[:,None]
S = np.abs(np.fft.rfft(mono[idx]*Wf, axis=1))
freqs = np.fft.rfftfreq(NF, 1/SR)

# 주파수 대역 에너지 비율
def band(lo,hi):
    m = (freqs>=lo)&(freqs<hi)
    return (S[:,m]**2).sum()
tot = (S**2).sum()
for name,lo,hi in [("sub <60",20,60),("low 60-250",60,250),("lowmid 250-800",250,800),
                   ("mid 0.8-2.5k",800,2500),("high 2.5-8k",2500,8000),("air >8k",8000,20000)]:
    print(f"band {name:15s} {band(lo,hi)/tot*100:5.1f}%")

# --- 크로마 / 조성 추정 (Krumhansl-Kessler) ---
mask = (freqs>=55)&(freqs<=4200)
fbin = freqs[mask]
pc = (np.round(12*np.log2(fbin/440.0))+9).astype(int) % 12
chroma_t = np.zeros((frames,12))
Sm = S[:,mask]**2
for k in range(12):
    chroma_t[:,k] = Sm[:, pc==k].sum(axis=1)
chroma = chroma_t.sum(axis=0); chroma /= chroma.max()
names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
order = np.argsort(chroma)[::-1]
print("\nchroma:", " ".join(f"{names[i]}:{chroma[i]:.2f}" for i in order))

maj = np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88])
minp= np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
best=[]
for k in range(12):
    best.append((np.corrcoef(np.roll(maj,k),chroma)[0,1], names[k]+" major"))
    best.append((np.corrcoef(np.roll(minp,k),chroma)[0,1], names[k]+" minor"))
best.sort(reverse=True)
print("key candidates:", ", ".join(f"{n}({c:.3f})" for c,n in best[:4]))

# 구간별 조성 (4분할)
q = frames//4
for qi in range(4):
    ch = chroma_t[qi*q:(qi+1)*q].sum(axis=0); ch/=ch.max()
    b=[]
    for k in range(12):
        b.append((np.corrcoef(np.roll(maj,k),ch)[0,1], names[k]+"maj"))
        b.append((np.corrcoef(np.roll(minp,k),ch)[0,1], names[k]+"min"))
    b.sort(reverse=True)
    t0,t1 = qi*dur/4, (qi+1)*dur/4
    top3 = np.argsort(ch)[::-1][:4]
    print(f"  {t0:5.1f}-{t1:5.1f}s  key {b[0][1]}({b[0][0]:.2f})  top notes: {' '.join(names[i] for i in top3)}")

# --- 템포 (spectral flux + 자기상관) ---
flux = np.maximum(0, np.diff(S, axis=0)).sum(axis=1)
flux -= flux.mean()
ac = np.correlate(flux, flux, "full")[len(flux)-1:]
fps = SR/HOP
lo,hi = int(fps*60/200), int(fps*60/50)
lag = np.argmax(ac[lo:hi])+lo
bpm = 60*fps/lag
conf = ac[lag]/ac[0]
print(f"\ntempo est: {bpm:.1f} BPM (autocorr conf {conf:.2f})")
peaks = []
acs = ac[lo:hi]
for i in range(2, len(acs)-2):
    if acs[i]>acs[i-1] and acs[i]>acs[i+1]:
        peaks.append((acs[i], 60*fps/(i+lo)))
peaks.sort(reverse=True)
print("bpm candidates:", ", ".join(f"{b:.1f}({a/ac[0]:.2f})" for a,b in peaks[:5]))

# --- 스펙트로그램 + 파형 이미지 (PIL) ---
from PIL import Image as PImage, ImageDraw
Sdb = 20*np.log10(np.maximum(S[:, freqs<8000], 1e-7))
Sdb = np.clip((Sdb - Sdb.max() + 70)/70, 0, 1)
h = 360
fmask_idx = np.where(freqs<8000)[0]
# 로그 주파수 축 리샘플
logf = np.geomspace(30, 8000, h)
bins = np.searchsorted(freqs[fmask_idx], logf)
img_arr = (Sdb[:, np.minimum(bins, Sdb.shape[1]-1)].T[::-1]*255).astype(np.uint8)
w = img_arr.shape[1]
spec = PImage.fromarray(img_arr, "L").resize((1000, h))
# 컬러맵 비슷하게
spec_rgb = PImage.merge("RGB", (spec, spec.point(lambda v: int(v*0.85)), spec.point(lambda v: 255-v//2 if v>40 else v)))
canvas = PImage.new("RGB", (1000, 520), (12,12,24))
canvas.paste(spec_rgb, (0,0))
d = ImageDraw.Draw(canvas)
# 파형
step = max(1, len(mono)//1000)
mid_y = 450
for px_i in range(1000):
    seg = mono[px_i*step:(px_i+1)*step]
    if len(seg):
        a = float(np.abs(seg).max())*60
        d.line([(px_i, mid_y-a),(px_i, mid_y+a)], fill=(120,190,255))
for s in range(0, int(dur)+1, 10):
    xx = int(s/dur*1000)
    d.line([(xx,0),(xx,520)], fill=(70,70,90))
    d.text((xx+3, 500), f"{s}s", fill=(200,200,210))
canvas.save("/tmp/bless_analysis.png")
print("\nspectrogram saved")
