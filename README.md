# BotCP — Bot Control Panel

A World of Warcraft addon for controlling [PlayerBots](https://github.com/mod-playerbots/mod-playerbots) through a graphical UI panel instead of chat commands. Built for **AzerothCore 3.3.5a (WotLK)**.

## Features

- **Bot Roster** — list of all your bots with online/offline status, class icons, and one-click selection
- **Control Panel** — per-bot toolbar with buttons for movement, actions, formations, strategies, and more
- **Visual State Feedback** — every toggle button reflects its real state: Active (green), Inactive (gray), Pending (pulsing yellow), Unknown (dark)
- **Party Mode** — send commands to all bots at once via party chat
- **Class-Specific Strategies** — dynamic toolbar that adapts to the selected bot's class (Druid forms, Mage specs, Warrior stances, etc.)
- **Minimap Button** — quick access to the roster panel
- **WoW-Native Styling** — Blizzard dialog frames, standard textures, no custom art required

## Toolbar Categories

| Toolbar | Description |
|---------|-------------|
| Movement | Follow, Stay, Guard, Grind, Flee, Passive |
| Actions | Attack, Tank Attack, Stats, Summon, Revive, Release |
| Formation | Near, Melee, Line, Circle, Arrow, Far, Chaos |
| Loot Strategy | Normal, All, Gray, Disenchant, Skill |
| RTI Target | Skull, Cross, Circle, Star, Square, Triangle, Diamond, Moon |
| Attack Type | Tank AOE, Tank Assist, DPS Assist, Caster AOE |
| Generic | Potions, Food, Cast Time, Conserve Mana, Buff, Attack Weak, Threat |
| Save Mana | Levels 1–5 (exclusive) |
| Class | Dynamic per-class combat strategies |

## Installation

1. Download or clone this repository
2. Copy the `BotCP` folder into your `Interface\AddOns\` directory
3. Restart World of Warcraft or reload the UI (`/reload`)

```
WoW\Interface\AddOns\BotCP\
├── BotCP.toc
├── Core.lua
├── Libs\Util.lua
├── Modules\Constants.lua
├── Modules\CommandEngine.lua
├── Modules\ResponseParser.lua
├── Modules\StateManager.lua
├── Modules\BotRoster.lua
├── UI\Widgets.lua
├── UI\MinimapButton.lua
├── UI\RosterFrame.lua
├── UI\ToolbarDefs.lua
└── UI\ControlFrame.lua
```

## Usage

Type `/botcp` or `/bcp` in the chat to toggle the roster panel.

Click a bot in the roster to open the control panel with all available toolbars.

### Slash Commands

| Command | Description |
|---------|-------------|
| `/botcp` | Toggle roster panel |
| `/botcp show` | Show roster panel |
| `/botcp hide` | Hide all panels |
| `/botcp add <name>` | Add bot to known list |
| `/botcp remove <name>` | Remove bot from known list |
| `/botcp login <name>` | Login a specific bot |
| `/botcp logout <name>` | Logout a specific bot |
| `/botcp help` | Show command list |

## Compatibility

- **Client**: World of Warcraft 3.3.5a (Wrath of the Lich King)
- **Server**: [AzerothCore](https://www.azerothcore.org/) with [mod-playerbots](https://github.com/mod-playerbots/mod-playerbots)
- **Language**: English

## Related Projects

- [mod-playerbots](https://github.com/mod-playerbots/mod-playerbots) — the server module that powers bot characters
- [whipowill/wow-addon-playerbots](https://github.com/whipowill/wow-addon-playerbots) — original PlayerBots addon (fork of ike3's mangosbot-addon)
- [UnBot](https://github.com/dmk69/unbot-addon) — alternative bot control addon
- [MultiBot](https://github.com/Macx-Lio/MultiBot) — another bot control addon with per-bot button bars
