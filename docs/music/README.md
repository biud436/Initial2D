# 음악 분석 문서

자작곡 BGM의 DSP 분석 기록. 측정 도구: `tools/analyze_audio.py` + ffmpeg ebur128.

| 곡 | 연도 | 조성 | BPM | 라우드니스 | 문서 |
|---|---|---|---|---|---|
| 피눈물의 제단 (천공의 끝) | 2011 | F#단조 | 118 | -10.5 LUFS | [blood-tears-altar-analysis.md](blood-tears-altar-analysis.md) |
| Inn (Port) | 2013 | D단조/F장조 | 130(체감 65) | -8.2 LUFS | [inn-analysis.md](inn-analysis.md) |
| Insatiable desires (끝 없는 욕망) | 2013 | A단조(프리지안 색채) | 47 | -14.4 LUFS | [insatiable-desires-analysis.md](insatiable-desires-analysis.md) |
| Bless (Arrange) | 2014 | F장조/A단조 | ~96(루바토) | -13.3 LUFS | [bless-analysis.md](bless-analysis.md) |
| 기억 속으로 (보컬 발라드 — 게임곡 아님) | 미상 | A단조 → 말미 D장조 전조 | ~65(루바토) | -7.1 LUFS | [into-memory-analysis.md](into-memory-analysis.md) |

게임에서 여러 곡을 함께 쓸 때의 레벨 보정값은 [inn-analysis.md](inn-analysis.md)의
비교표 참조. 각 문서에는 그리드 정밀 루프 포인트(인트로/본편 경계)가 기록되어 있다.

관찰되는 작곡가의 지문: 반음 쌍의 프리지안 색채(Bless의 A–B♭, Insatiable desires의 E–F),
그리드 정밀 형식(인트로/본편이 마디 단위로 정확히 떨어짐), 곡 성격에 따라 달리 선택하는
마스터 강도(-8.2 ~ -14.4 LUFS).

참고: 저자는 정규 음악 교육을 받지 않았고 자신만의 기준으로 작곡했다고 밝혔다.
문서들의 이론 용어는 결과물에 대한 사후적 기술이며, 여러 곡에서 반복 검출되는
지문들은 학습된 기법이 아니라 직관적 취향의 일관성이다.

특히 **도미넌트(V)를 희소 자원으로 다루는 일관된 태도**가 세 곡에서 세 가지 용법으로
나타난다: Inn은 프레이즈 끝마다 소량 배급(형식의 구두점), 피눈물의 제단은 클라이맥스까지
아꼈다가 한 번에 지불(보상), Insatiable desires는 지불의 영구 거부(제목의 구현).
각 문서의 코드 진행 항목에 상세 해설이 있다.

유일한 비게임곡인 "기억 속으로"는 형식 언어가 완전히 다르다(벌스-후렴 극작, 마지막 후렴
전조, 회상 코다). 단, 현존 파일이 심하게 손상된 마스터(+5dBTP, 클리핑 12.8만 샘플)라
**원본 발굴·복구 1순위**로 기록해 둔다.
