# Junkyard Simulator

A Roblox game where you start out broke in a scrapyard, collect junk, sell it for cash and buy upgrades.

## Open it in Roblox Studio

**Easiest:** download `build/JunkyardSimulator.rbxlx`, open it in Roblox Studio and press **Play**.
The scrapyard map is built by the server when the game starts, so the Workspace looks empty in Edit mode. That's expected.

**Live sync with Rojo (for development):**
1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. Run `rojo serve` in this folder.
3. In Studio, open a new Baseplate, delete the `Baseplate` part, then click **Connect** in the Rojo plugin.

**To see and edit the map in Edit mode:** while you are *not* playtesting, paste this into Studio's command bar and press Enter:

```lua
require(game.ServerScriptService.Server.World.MapBuilder).build()
```

The map is then saved in your place, and the server skips rebuilding it.

**Saving progress:** turn on *Game Settings → Security → Enable Studio Access to API Services* to test DataStores in Studio. With it off, the game still runs but doesn't save.

## How to play

1. Your **Rusty Grabber** is equipped when you spawn. Press `1` to re-equip it if you put it away.
2. Walk up to a scrap pile and hold **E** to collect.
3. When your backpack is full, go to the green **SELL** station in the plaza.
4. Spend your cash at the blue **UPGRADE SHOP**.

| Scrap | Value | Base odds |
|---|---|---|
| Common Metal | $5 | 60% |
| Copper Wire | $15 | 25% |
| Electronic Parts | $40 | 12% |
| Rare Mechanical Parts | $150 | 3% |

Zones: **Front Heap** (starter area), **Car Graveyard** (x1.15 luck), **Back Lot** (x1.35 luck).

## Project layout

```
src/shared/   Config (all tuning numbers), Formulas (stats and weighted rolls), Remotes
src/server/   Main.server.luau, Services/ (Data, Tool, Scrap, Economy), World/ (MapBuilder)
src/client/   Main.client.luau, Effects, UI/ (Hud, Shop, Notifications, Theme)
tests/        Headless playtest against a mock engine (tests/run.sh)
```

To retune the economy (prices, drop weights, cooldowns, capacity, respawn time, tools), edit `src/shared/Config.luau`.

## Security model

The server owns all game state. The client can only:
- trigger ProximityPrompts. The server checks distance, cooldown, that the tool is equipped, free capacity and whether the pile is active.
- send an upgrade **id** to `PurchaseUpgrade`. The server looks up the price, checks that you are at the shop and can afford it, and rate-limits requests.

Cash, prices, inventory and upgrade effects are never read from the client. Saved data is sanitized when it loads.

## Development

```bash
rojo build default.project.json -o build/JunkyardSimulator.rbxlx   # rebuild the place file
tests/run.sh                                                       # headless playtest (needs Rust/cargo)
selene src                                                         # lint
```
