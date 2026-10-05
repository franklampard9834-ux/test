# 농장 애드온 프롭 원본

| 원본 | 결과 모델 |
|---|---|
| `beef.smd` | `farm/models/farm/beef.mdl` |
| `feeder_empty.smd` | `farm/models/farm/feeder_empty.mdl` |
| `feeder_full.smd` | `farm/models/farm/feeder_full.mdl` |

## 다시 컴파일하기

`tools/smd2mdl.py`는 정적 프롭만 만드는 간이 컴파일러입니다. 본 1개, 재질 1개, 상자 충돌만 지원합니다.
studiomdl 없이 리눅스에서도 돌아갑니다(Python 3 + numpy).

```
python3 farm_src/tools/smd2mdl.py farm_src/beef.smd farm/models \
    --name farm/beef.mdl --material beef --cdmaterials models/farm/ --surfaceprop flesh --mass 3
python3 farm_src/tools/smd2mdl.py farm_src/feeder_empty.smd farm/models \
    --name farm/feeder_empty.mdl --material feeder_empty --cdmaterials models/farm/ --surfaceprop metal --mass 80
python3 farm_src/tools/smd2mdl.py farm_src/feeder_full.smd farm/models \
    --name farm/feeder_full.mdl --material feeder_full --cdmaterials models/farm/ --surfaceprop metal --mass 80
```

같은 설정의 `*.qc`도 있어서, Crowbar(studiomdl)로 컴파일해도 같은 모델이 나옵니다.

## 메모

- 메시는 바닥이 원점(z=0)에 오도록 옮겨 두었습니다.
- 충돌은 모델을 감싸는 상자 하나입니다.
- 텍스처는 PNG를 DXT1 VTF로 변환했습니다(소고기 1024, 사료통 2048).
- `original/`에는 처음 받은 SMD와 PNG가 그대로 있습니다.
