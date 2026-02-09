# MyLootTraking - WoW Classic TBC Addon

## 📦 Installation

1. Extraire le dossier `MyLootTraking` dans :
   ```
   World of Warcraft\_classic_\Interface\AddOns\MyLootTraking\
   ```
2. Relancer le jeu ou taper `/reload` en jeu
3. L'addon apparaît dans la liste des AddOns au menu de personnages

## 🎮 Commandes

| Commande | Action |
|---|---|
| `/mlt` | Afficher l'aide |
| `/mlt add [itemID\|lien]` | Ajouter un objet à une liste |
| `/mlt list` | Ouvrir/fermer la fenêtre détaillée |
| `/mlt track` | Afficher/masquer le mini-tracker |
| `/mlt search [nom]` | Rechercher un objet |
| `/mlt config` | Ouvrir les paramètres |

## 🖱️ Bouton Minimap

- **Clic gauche** : Ouvrir la liste détaillée
- **Clic droit** : Ouvrir les paramètres
- **Survol** : Résumé rapide (nombre d'objets à récupérer + progression)
- **Glisser** : Repositionner le bouton sur la minimap

## ✨ Fonctionnalités

### Listes
- Créer des listes **par personnage** ou **par objectif**
- Données partagées entre tous les personnages du compte
- Glisser-déposer pour réorganiser les objets
- Notes personnelles sur chaque objet
- Assigner un objet à un personnage spécifique

### 3 méthodes pour ajouter un objet
1. **Commande** : `/mlt add 28795`
2. **Tooltip** : `Shift + Clic droit` sur un lien d'objet dans le chat
3. **Interface de recherche** : `/mlt search Épée`

### Alertes
- **Popup + son unique** quand un objet de la liste **droppe dans le groupe**
- **Popup + son différent** quand vous **lootez** un objet de la liste
- **Alerte à l'entrée** d'un donjon/raid contenant des objets de votre liste
- Positions des alertes déplaçables et verrouillables

### Mini-Tracker
- Overlay compact toujours visible
- Nombre d'objets configurable
- Transparence ajustable, sans fond de couleur
- Déplaçable et verrouillable

### Statistiques
- Nombre de kills par boss
- Nombre de runs par donjon/raid
- Progression par liste : `7/12 - 58%`

### Import / Export
- Partager une liste via code copiable
- Format : `MLT:NomDeLaListe:12345,67890,11111`

### Intégrations
- **AtlasLoot** : Bouton "+" sur chaque objet pour l'ajouter directement
- **ElvUI** : Compatible, thème épuré adapté
- **Interface Blizzard** : Accessible via menu Interface > AddOns

### Langues supportées
Français, English, Deutsch, Español, Português, Русский, 한국어, 简体中文, 繁體中文

## 📁 Structure des fichiers

```
MyLootTraking/
├── MyLootTraking.toc          # Fichier de configuration addon
├── Core.lua                    # Initialisation et système d'événements
├── Database.lua                # Gestion des données et CRUD
├── Utils.lua                   # Fonctions utilitaires
├── LootDetection.lua           # Détection de loot (groupe + personnel)
├── Statistics.lua              # Statistiques de kills/runs
├── Alerts.lua                  # Système de notifications popup
├── TooltipHook.lua             # Intégration aux tooltips
├── MinimapButton.lua           # Bouton minimap
├── MiniTracker.lua             # Mini-tracker overlay
├── MainFrame.lua               # Fenêtre détaillée principale
├── SearchFrame.lua             # Interface de recherche
├── ConfigFrame.lua             # Panneau de paramètres
├── SlashCommands.lua           # Commandes slash
├── ImportExport.lua            # Import/export de listes
├── AtlasLootIntegration.lua    # Intégration AtlasLoot
└── Locales/                    # Traductions
    ├── enUS.lua
    ├── frFR.lua
    ├── deDE.lua
    ├── esES.lua
    ├── ruRU.lua
    ├── koKR.lua
    ├── zhCN.lua
    ├── zhTW.lua
    └── ptBR.lua
```

## ⚙️ SavedVariables

- `MyLootTrakingDB` : Données partagées au compte (listes, items, stats, config)
- `MyLootTrakingCharDB` : Données par personnage (réservé pour usage futur)

## 🔧 Développement

Pour contribuer ou modifier l'addon :
1. Les données sont stockées dans `WTF/Account/VOTRE_COMPTE/SavedVariables/MyLootTraking.lua`
2. `/reload` pour recharger après modification
3. Utiliser `/script MyLootTrakingDB = nil; ReloadUI()` pour reset complet
