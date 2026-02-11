# CLAUDE.md - MyLootTraking WoW Classic TBC Addon

## 🎯 Résumé du projet

**MyLootTraking** est un addon World of Warcraft Classic TBC (The Burning Crusade) qui permet aux joueurs de créer et gérer des listes d'objets (loot wishlists) à récupérer en donjon, raid, sur des monstres ou via des quêtes. L'addon affiche la progression, alerte le joueur quand un objet drop, et fonctionne sur tous les personnages du compte.

- **Interface TOC** : `20504` (WoW Classic TBC)
- **API** : WoW Classic API (pas Retail). Utiliser `GetContainerNumSlots` et non `C_Container`, pas de `C_Item.GetItemInfo`, etc.
- **Langage** : Lua (API WoW native)
- **SavedVariables** : `MyLootTrakingDB` (account-wide), `MyLootTrakingCharDB` (per-character, réservé futur)

---

## 📁 Structure du projet

```
MyLootTraking/
├── MyLootTraking.toc          # Fichier de déclaration addon (Interface: 20504)
├── Core.lua                    # Namespace global MLT, init, événements principaux, couleurs, sons
├── Database.lua                # SavedVariables, CRUD listes/items, détection source, progression
├── Utils.lua                   # Helpers (strings, parsing itemLink, couleurs classe, widgets UI, dialogs, encode/decode)
├── LootDetection.lua           # Surveillance événements loot (CHAT_MSG_LOOT, LOOT_OPENED, BOSS_KILL, ENCOUNTER_END)
├── Statistics.lua              # Stats par boss/donjon, progression globale
├── Alerts.lua                  # Popups de notification (group drop, personal loot, dungeon entry)
├── TooltipHook.lua             # Hook GameTooltip + ItemRefTooltip, bouton Shift+RightClick
├── MinimapButton.lua           # Bouton minimap draggable (clic G/D + hover)
├── MiniTracker.lua             # Overlay compact toujours visible (sans fond de couleur)
├── MainFrame.lua               # Fenêtre détaillée avec panneaux listes + items + tri/filtre
├── SearchFrame.lua             # Interface de recherche d'items par nom ou ID
├── ConfigFrame.lua             # Panneau paramètres (alertes, tracker, général) + InterfaceOptions
├── SlashCommands.lua           # Commandes /mlt (add, list, track, search, config)
├── ImportExport.lua            # Import/export via string encodée + UI copier/coller
├── AtlasLootIntegration.lua    # Bouton "+" dans les frames AtlasLoot
├── README.md
└── Locales/
    ├── enUS.lua                # Locale de base (toutes les clés définies ici)
    ├── frFR.lua                # Traduction complète français
    ├── deDE.lua                # Traduction partielle allemand
    ├── esES.lua                # Traduction partielle espagnol
    ├── ruRU.lua                # Stub (fallback vers enUS)
    ├── koKR.lua                # Stub
    ├── zhCN.lua                # Stub
    ├── zhTW.lua                # Stub
    └── ptBR.lua                # Stub
```

---

## 🏗️ Architecture technique

### Namespace global
- Tout passe par `MLT` (le namespace addon via `local _, MLT = ...`)
- Accessible globalement via `_G["MyLootTraking"]`
- Les modules n'ont PAS de système de modules/classes formel, tout est attaché directement à la table `MLT`

### Système de localisation
- `MLT.L` contient toutes les chaînes traduites
- `enUS.lua` définit TOUTES les clés (c'est la locale de référence)
- Les autres locales ne surchargent que si `GetLocale()` correspond
- Les locales non remplies (ruRU, koKR, zhCN, zhTW, ptBR) font fallback sur enUS automatiquement

### Base de données (SavedVariables)
Structure de `MyLootTrakingDB` :
```lua
{
    lists = {                          -- Table de toutes les listes (clé = listID)
        ["list_1"] = {
            id = "list_1",
            name = "Pré-raid BiS",
            listType = "objective",     -- "character" ou "objective"
            character = nil,            -- Rempli si listType == "character" (ex: "Thrsjr - Firemaw")
            items = {                   -- Array ordonné
                {
                    itemID = 28795,
                    itemName = "Épée du Destin",
                    itemLink = "|cff...|Hitem:28795:...|h[...]|h|r",
                    itemQuality = 4,     -- 0=grey, 1=white, 2=green, 3=blue, 4=epic, 5=legendary
                    itemTexture = 12345,
                    source = {
                        type = "boss",   -- boss/dungeon/raid/quest/mob/vendor/crafted/pvp/unknown
                        bossName = "Prince Malchezaar",
                        instance = "Karazhan",
                        dropRate = 15.5,
                    },
                    obtained = false,
                    obtainedDate = nil,    -- timestamp quand obtenu
                    assignedTo = "Thrsjr - Firemaw",  -- nom complet du personnage
                    note = "Prio pour moi cette semaine",
                    addedAt = 1234567890,
                    sortOrder = 0,         -- pour le drag-and-drop
                },
            },
            createdAt = 1234567890,
            sortOrder = 0,
        },
    },
    characters = {                     -- Personnages connus du compte
        ["Thrsjr - Firemaw"] = {
            name = "Thrsjr",
            realm = "Firemaw",
            class = "WARRIOR",          -- Token en anglais majuscule
        },
    },
    statistics = {
        bossKills = {                  -- [bossName] = count
            ["Prince Malchezaar"] = 14,
        },
        dungeonRuns = {                -- [instanceName] = count
            ["Karazhan"] = 8,
        },
    },
    config = {
        enablePopup = true,
        enableSound = true,
        groupDropSound = "RaidWarning",
        personalLootSound = "LevelUp",
        dungeonEnterAlert = true,
        trackerMaxItems = 10,          -- Nombre d'items affichés dans le mini-tracker (configurable)
        trackerAlpha = 0.8,            -- Transparence du tracker (0.1 à 1.0)
        trackerScale = 1.0,            -- Échelle du tracker (0.5 à 2.0)
        trackerLocked = false,
        alertsLocked = false,
        trackerPoint = nil,            -- Position sauvegardée {point, relPoint, x, y}
        alertPoint = nil,
        showObtained = false,
        minimapPos = 220,              -- Angle du bouton minimap en degrés
    },
    nextListID = 1,                    -- Auto-incrémenté pour générer les listID
}
```

### Cache des items traqués
- `MLT.trackedItemCache` = table [itemID] → array d'entrées {listName, assignedTo, note}
- Reconstruit via `MLT:RebuildTrackedItemCache()` à chaque modification de liste
- Utilisé pour le lookup rapide dans les événements de loot et les tooltips

---

## ✨ Fonctionnalités détaillées (cahier des charges)

### 1. Listes d'objets
- **Deux types de listes** : "par personnage" (liée à un alt) et "par objectif" (ex: "Pré-raid BiS", "Set T4")
- **Données account-wide** : toutes les listes sont accessibles depuis n'importe quel personnage
- **Catégories** : "À obtenir" (toujours visible) et "Obtenus" (collapsible, masquable via toggle)
- **Réorganisation** : drag-and-drop pour changer l'ordre des items (pas de système de priorité haute/moyenne/basse)
- **Notes personnelles** : champ de texte libre par item

### 2. Ajout d'objets (3 méthodes)
1. **Commande slash** : `/mlt add [itemID ou itemLink]`
2. **Tooltip** : Shift+Right-Click sur un lien d'item dans le chat → menu déroulant de sélection de liste
3. **Recherche intégrée** : `/mlt search [nom]` → interface de recherche avec résultats + bouton "+"

### 3. Informations par objet
- Icône + nom (coloré selon la rareté WoW)
- Source : auto-détectée via tooltip scanning + modifiable manuellement
- Taux de drop (si connu)
- Statut obtenu/non obtenu
- Personnage assigné (affiché avec sa couleur de classe)
- Tooltip complète au survol (via SetHyperlink)

### 4. Système d'alertes (2 niveaux + 1 contextuelle)
- **Son A + popup orange** : quand un objet traqué droppe dans le groupe (LOOT_OPENED)
- **Son B + popup vert** : quand le joueur loote personnellement un objet traqué (CHAT_MSG_LOOT)
- **Alerte contextuelle bleue** à l'entrée d'un donjon/raid : résumé "X objets droppent ici" + clic pour détail
- Les positions des popups sont déplaçables et verrouillables
- Auto-mark obtained quand le joueur loote personnellement un item traqué

### 5. Mini-Tracker (overlay)
- Toujours visible, compact
- **Sans fond de couleur** (transparent, juste le texte et icônes)
- Nombre d'items configurable (slider 1-30)
- Transparence ajustable (slider 0.1-1.0)
- Scale ajustable (slider 0.5-2.0)
- Déplaçable librement, position sauvegardée
- Verrouillable
- Tooltip au survol de chaque item
- Clic droit → menu contextuel (marquer obtenu, note, lien chat, supprimer)

### 6. Fenêtre détaillée (MainFrame)
- Panneau gauche : navigateur de listes (avec icône type + progression "7/12 - 58%")
- Panneau droit : liste d'items avec toutes les infos
- **Tri** : ordre manuel (drag-and-drop), nom, source, statut, instance
- **Filtres** : tous, par personnage, par instance, par type de source
- Clic droit sur liste → renommer, import/export, supprimer (avec confirmation)
- Clic droit sur item → marquer obtenu, éditer note, lien chat, supprimer
- Bouton "Nouvelle liste" en haut du panneau gauche → choix type (personnage/objectif)
- ESC pour fermer
- Progression globale affichée dans la barre de titre

### 7. Statistiques
- Kills par boss : compteur via BOSS_KILL et ENCOUNTER_END
- Runs par donjon/raid : compteur via ENCOUNTER_END (success)
- Progression par liste : texte "7/12 - 58%" (PAS de barre de progression, juste du texte)
- Progression globale : même format, toutes listes confondues

### 8. Import/Export
- **Export** : génère une string copiable format `MLT:NomListe:itemID1,itemID2,itemID3`
- **Import** : coller une string → crée la liste avec tous les items
- **Pas de partage en temps réel** (pas de sync guilde/groupe)
- Interface dédiée avec zone de texte multiline, onglets Export/Import

### 9. Intégration AtlasLoot
- Bouton "+" sur chaque item dans l'interface AtlasLoot
- Hook les frames AtlasLoot au chargement (ou en lazy si AtlasLoot charge après)
- Clic → même menu de sélection de liste que les autres méthodes d'ajout

### 10. Bouton Minimap
- **Clic gauche** : ouvrir/fermer la fenêtre détaillée
- **Clic droit** : ouvrir/fermer les paramètres
- **Survol** : tooltip avec nombre d'objets à récupérer + progression globale
- Draggable autour de la minimap, position sauvegardée en degrés

### 11. Lien chat
- Cliquer sur un item dans la liste → ouvre la zone de chat avec le lien de l'item
- Possibilité de copier/coller dans le chat souhaité

### 12. Commandes slash
| Commande | Action |
|---|---|
| `/mlt` ou `/mlt help` | Afficher l'aide |
| `/mlt add [itemID\|itemLink]` | Ajouter un objet (ouvre menu de liste) |
| `/mlt list` | Toggle fenêtre détaillée |
| `/mlt track` | Toggle mini-tracker |
| `/mlt search [nom]` | Ouvrir l'interface de recherche |
| `/mlt config` | Toggle paramètres |

### 13. Paramètres (ConfigFrame)
Accessible via : `/mlt config`, clic droit minimap, Interface > Addons
- Section Alertes : enable popup, enable sound, alerte entrée donjon, verrouiller position alertes
- Section Tracker : max items (slider), transparence (slider), scale (slider), verrouiller position
- Section Général : afficher les obtenus, reset settings

### 14. Compatibilité
- **ElvUI** : l'addon DOIT être compatible ElvUI. Le style est épuré (pas de textures WoW lourdes). Vérification via `_G["ElvUI"]`
- **AtlasLoot** / **AtlasLootClassic** : intégration bouton "+"
- L'addon utilise des frames WoW standard (pas de libs externes type Ace3 ou LibDBIcon pour le moment)

### 15. Localisation
- Toutes les langues supportées par WoW : FR, EN, DE, ES, RU, KO, zhCN, zhTW, ptBR
- FR et EN sont entièrement traduits
- DE et ES sont partiellement traduits
- Les autres sont en stub (fallback enUS)

---

## ⚠️ Points d'attention pour le développement

### API WoW Classic TBC (20504)
- Utiliser `GetContainerNumSlots(bag)` et `GetContainerItemID(bag, slot)` (pas `C_Container`)
- Utiliser `GetItemInfo(itemID)` directement (pas `C_Item`)
- `Item:CreateFromItemID(id)` et `item:ContinueOnItemLoad(callback)` sont disponibles pour le chargement async
- `C_Timer.After(seconds, callback)` est disponible
- `IsInInstance()` retourne `_, instanceType` (party/raid/none/pvp/arena)
- `GetRealZoneText()` pour le nom de la zone
- `ENCOUNTER_END` fournit `encounterID, encounterName, difficultyID, groupSize, success`
- `BOSS_KILL` fournit `encounterID, encounterName`
- `CHAT_MSG_LOOT` fournit le message avec le lien d'item intégré
- `LOOT_ITEM_SELF` est une constante globale avec le pattern de loot personnel (varie par locale)
- `CreateFrame("Frame", name, parent, "BackdropTemplate")` — attention, en TBC Classic le BackdropTemplate peut ne pas exister, on utilise `frame:SetBackdrop()` directement
- `InterfaceOptions_AddCategory(panel)` pour l'intégration Blizzard options

### Erreurs connues / Risques
- **BackdropTemplate** : En TBC Classic, `SetBackdrop` est une méthode native des frames, pas besoin de BackdropTemplate mixin. Mais vérifier que `SetBackdrop` existe.
- **GetContainerNumSlots** : Utiliser cette API, PAS C_Container qui n'existe pas en TBC Classic
- **LOOT_OPENED scanning** : Les items dans la fenêtre de loot doivent être scannés via `GetNumLootItems()`, `GetLootSlotInfo(i)`, `GetLootSlotLink(i)`
- **Item cache** : `GetItemInfo` peut retourner nil si l'item n'est pas en cache → toujours gérer le cas async
- **Tooltip scanning pour source** : La détection automatique via tooltip est limitée et basique. C'est un best-effort.
- **AtlasLoot hook** : Les noms de frames AtlasLoot varient selon les versions. Le code tente plusieurs patterns mais peut nécessiter des ajustements.
- **UIDropDownMenu** : Utilisation du système standard WoW, peut avoir des conflits si trop de menus sont ouverts simultanément

### Ce qui manque / Améliorations futures possibles
- Le drag-and-drop dans MainFrame est implémenté de façon basique (via OnMouseDown/OnMouseUp). Un vrai système visuel avec preview serait mieux.
- La détection automatique de source est très basique (scan tooltip). Une table de lookup hardcodée des boss/instances TBC serait plus fiable.
- Les stubs de traduction (ruRU, koKR, etc.) ne contiennent aucune traduction réelle.
- Pas de système de sauvegarde/restauration en fichier texte implémenté (l'import/export via string est fait, mais pas l'écriture fichier qui est impossible dans WoW sans addon externe).
- Le filtre par personnage et par instance dans MainFrame n'a que le dropdown créé, mais la logique de filtrage dans RefreshItemPanel ne filtre pas encore réellement les items.
- Pas de tests unitaires.
- La recherche ne fonctionne que sur les items déjà dans les listes ou par ID exact. Une recherche serveur n'est pas possible via l'API WoW.

---

## 🔧 Commandes utiles pour tester

```
-- En jeu, après installation :
/mlt                    -- Aide
/mlt add 28795          -- Ajouter un item par ID
/mlt list               -- Ouvrir la fenêtre
/mlt track              -- Toggle tracker
/mlt search Épée        -- Rechercher
/mlt config             -- Paramètres

-- Debug / Reset :
/script MyLootTrakingDB = nil; ReloadUI()     -- Reset complet
/script print(MyLootTraking.version)          -- Vérifier chargement
/reload                                        -- Recharger l'addon
```

---

## 📐 Conventions de code

- **Namespace** : tout sur `MLT` (pas de variables globales sauf `MyLootTraking` et les noms de frames)
- **Noms de frames globaux** : préfixe `MLT` (ex: `MLTMainFrame`, `MLTMiniTracker`, `MLTAlertFrame`)
- **Localisation** : toujours utiliser `MLT.L["KEY"]` pour les chaînes affichées
- **Méthodes** : `MLT:MethodName()` (OOP style avec `:`)
- **Events** : `MLT:EVENT_NAME(...)` appelé automatiquement par le handler dans Core.lua
- **Init** : chaque module expose une méthode `MLT:InitModuleName()` appelée dans `PLAYER_LOGIN`
- **Refresh UI** : appeler `MLT:RefreshAllUI()` après toute modification de données
- **Rebuild cache** : appeler `MLT:RebuildTrackedItemCache()` après ajout/suppression/obtention d'item
- **Indentation** : 4 espaces
- **Commentaires** : en anglais pour le code, la locale FR est dans frFR.lua
