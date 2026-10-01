# Entity Finder (Garry's Mod 애드온)

서버에 등록된 엔티티 클래스와 현재 맵의 엔티티를 스캔하고, 지정한 엔티티를 외곽선(halo)과 라벨로 화면에 표시하는 관리자/개발용 애드온입니다.

## 설치

`entity_finder` 폴더를 `garrysmod/addons/` 에 복사하고 서버(또는 싱글플레이)를 재시작합니다.

## 권한

서버 ConVar `entfinder_access`
- `0` 꺼짐
- `1` 관리자만 (기본값)
- `2` 모든 플레이어

싱글플레이에서는 항상 사용 가능합니다.

## 사용법

| 명령 | 설명 |
|---|---|
| `entfinder_menu` | GUI 열기 (검색, 더블클릭으로 추적 토글) |
| `entfinder_scan` | 맵 엔티티 클래스별 개수 |
| `entfinder_registered` | 설치된 SENT / SWEP / NPC 클래스 목록 |
| `entfinder_add <패턴>` | 추적 추가 (Lua 패턴, 예: `^npc_`, `prop_physics`) |
| `entfinder_remove <패턴>` / `entfinder_clear` / `entfinder_list` | 추적 관리 |

클라이언트 ConVar: `entfinder_draw`, `entfinder_maxdist` (기본 5000 유닛), `entfinder_halo`.
