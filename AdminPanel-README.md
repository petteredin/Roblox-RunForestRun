# Admin Panel - Installationsguide

## Filstruktur

```
src/
  server/
    AdminServer.server.lua   → ServerScriptService (ServerScript)
    GameManager.lua           → ServerScriptService (ModuleScript)
  client/
    AdminClient.client.lua   → StarterPlayerScripts (LocalScript)
```

Alla filer synkas automatiskt via Rojo (`default.project.json` är uppdaterad).

## Installation

### 1. Lägg till ditt UserId i whitelisten

Du måste uppdatera **TVÅ filer** med ditt Roblox UserId:

**`src/server/AdminServer.server.lua`** (rad 19):
```lua
local ADMINS = {
    [123456789] = true,  -- Ditt UserId här
}
```

**`src/client/AdminClient.client.lua`** (rad 19):
```lua
local ADMIN_IDS = {
    [123456789] = true,  -- Samma UserId här
}
```

> Klient-listan styr ENBART om GUI:n visas. All säkerhet hanteras på servern.

### 2. Hitta ditt UserId

1. Gå till din Roblox-profil i webbläsaren
2. UserId finns i URL:en: `roblox.com/users/123456789/profile`

### 3. Synka med Rojo

```bash
rojo serve
```

Klicka "Connect" i Roblox Studio Rojo-plugin.

## Användning

1. Joina spelet som admin
2. Klicka **ADM**-knappen (nedre högra hörnet)
3. Panelen glider in från höger
4. Ange target-spelarens namn (lämna tomt = dig själv)
5. Välj kommando och klicka

## Kommandon

| Sektion | Knappar | Beskrivning |
|---------|---------|-------------|
| Credits | Add / Set | Lägg till eller sätt credits |
| Rebirth | Give +1 / Set | Ge eller sätt rebirth-nivå (0-10) |
| Event Coins | Add | Lägg till event coins |
| Speed | Set | Sätt hastighetsmultiplier |
| Spawn Brainrot | Server / Global | Spawna brainrot NPC |
| Spawn Wave | Server / Global | Trigga våg-event |
| Spawn Event | Server / Global | Trigga event |
| Kick Player | Kick | Kicka spelare med meddelande |

## Säkerhet

- Server-sidan validerar ALL input och alla behörigheter
- Klient-listan styr enbart GUI-visning
- Rate limiting: max 1 kommando per 0.5 sekunder
- Alla åtgärder loggas till DataStore "AdminLog"
- Kan inte kicka andra admins
