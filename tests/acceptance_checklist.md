# WolfGodot Acceptance Test Checklist
# Manual testing checklist for gameplay verification

## Instructions
Run through each map and check off items as you verify them.
Mark with [x] when passed, [!] when failed with notes.

---

## Episode 1: Escape from Wolfenstein

### E1M1 - Floor 1
- [ ] Player spawns at correct location
- [ ] Movement (WASD) works correctly
- [ ] Mouse look works
- [ ] Doors open when approached
- [ ] Guards spawn and patrol
- [ ] Guards notice player and attack
- [ ] Player weapon fires
- [ ] Enemies take damage and die
- [ ] Ammo pickups add ammo
- [ ] Health pickups heal (when needed)
- [ ] Gold key opens gold door
- [ ] Treasure pickups add score
- [ ] Level exit works

Notes:
____________________________________________

### E1M2 - Floor 2
- [ ] All tests from E1M1
- [ ] Push walls work (secret areas)
- [ ] Multiple enemy types appear
- [ ] Elevators work

Notes:
____________________________________________

---

## Core Gameplay Functions

### Weapons
- [ ] Knife: melee attack works
- [ ] Pistol: fires, uses 1 ammo
- [ ] Machine Gun: rapid fire
- [ ] Chain Gun: high rate of fire
- [ ] Weapon switching (1-4 keys)

### Items
- [ ] Dog food: +4 HP (when < 100)
- [ ] Food: +10 HP
- [ ] First Aid: +25 HP
- [ ] Ammo clip: +8 ammo
- [ ] Extra life: +1 life, full heal
- [ ] Cross: +100 points
- [ ] Chalice: +500 points
- [ ] Bible: +1000 points
- [ ] Crown: +5000 points

### HUD
- [ ] Health display accurate
- [ ] Ammo display accurate
- [ ] Score updates correctly
- [ ] Lives display accurate
- [ ] Face changes with health
- [ ] Keys appear when collected

### Audio
- [ ] Door sounds
- [ ] Weapon sounds
- [ ] Enemy sounds
- [ ] Pickup sounds
- [ ] Death sounds

---

## Performance Criteria
- [ ] Maintains 60 FPS during normal gameplay
- [ ] No stuttering when opening doors
- [ ] No slowdown with 10+ enemies active
- [ ] Level loads in < 3 seconds

---

## Bugs Found
| Issue | Severity | Location | Notes |
|-------|----------|----------|-------|
| | | | |
| | | | |
| | | | |

---

## Sign-off
Tested by: ________________
Date: ________________
Version: ________________
Result: [ ] PASS  [ ] FAIL
