# 음악 분석 문서

자작곡 BGM의 DSP 분석 기록. 측정 도구: `tools/analyze_audio.py` + ffmpeg ebur128.

| 곡 | 연도 | 조성 | BPM | 라우드니스 | 문서 |
|---|---|---|---|---|---|
| 피눈물의 제단 (천공의 끝) | 2011 | F#단조 | 118 | -10.5 LUFS | [blood-tears-altar-analysis.md](blood-tears-altar-analysis.md) |
| Inn (Port) | 2013 | D단조/F장조 | 130(체감 65) | -8.2 LUFS | [inn-analysis.md](inn-analysis.md) |
| Insatiable desires (끝 없는 욕망) | 2013 | A단조(프리지안 색채) | 47 | -14.4 LUFS | [insatiable-desires-analysis.md](insatiable-desires-analysis.md) |
| Bless (Arrange) | 2014 | F장조/A단조 | ~96(루바토) | -13.3 LUFS | [bless-analysis.md](bless-analysis.md) |

게임에서 여러 곡을 함께 쓸 때의 레벨 보정값은 [inn-analysis.md](inn-analysis.md)의
비교표 참조. 각 문서에는 그리드 정밀 루프 포인트(인트로/본편 경계)가 기록되어 있다.

관찰되는 작곡가의 지문: 반음 쌍의 프리지안 색채(Bless의 A–B♭, Insatiable desires의 E–F),
그리드 정밀 형식(인트로/본편이 마디 단위로 정확히 떨어짐), 곡 성격에 따라 달리 선택하는
마스터 강도(-8.2 ~ -14.4 LUFS).
