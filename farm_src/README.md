# 농장 애드온 프롭 원본

`*.qc`를 Crowbar로 컴파일하면 `farm/models/farm/`에 들어갈 모델이 나옵니다.
텍스처(`farm/materials/models/farm/*.vtf`)는 이미 변환되어 있습니다.

| QC | 결과 모델 |
|---|---|
| `beef.qc` | `models/farm/beef.mdl` |
| `feeder_empty.qc` | `models/farm/feeder_empty.mdl` |
| `feeder_full.qc` | `models/farm/feeder_full.mdl` |

- 메시는 바닥이 원점(z=0)에 오도록 옮겨 두었습니다.
- 충돌 모델은 단순화했습니다. 소고기는 볼록 껍질, 사료통은 상자 모양입니다.
- `original/`에는 처음 받은 SMD와 PNG가 그대로 있습니다.
