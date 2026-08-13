# 음악 분석 문서

자작곡 BGM의 DSP 분석 기록. 측정 도구: `tools/analyze_audio.py` + ffmpeg ebur128.

| 곡 | 연도 | 조성 | BPM | 라우드니스 | 문서 |
|---|---|---|---|---|---|
| 피눈물의 제단 (천공의 끝) | 2011 | F#단조 | 118 | -10.5 LUFS | [blood-tears-altar-analysis.md](blood-tears-altar-analysis.md) |
| Inn (Port) | 2013 | D단조/F장조 | 130(체감 65) | -8.2 LUFS | [inn-analysis.md](inn-analysis.md) |
| Bless (Arrange) | 2014 | F장조/A단조 | ~96(루바토) | -13.3 LUFS | [bless-analysis.md](bless-analysis.md) |

게임에서 여러 곡을 함께 쓸 때의 레벨 보정값은 [inn-analysis.md](inn-analysis.md)의
비교표 참조. 각 문서에는 그리드 정밀 루프 포인트(인트로/본편 경계)가 기록되어 있다.
