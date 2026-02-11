# MyLootTraking - WoW Classic Anniversary Edition Addon

Addon de suivi de loot pour WoW Classic Anniversary Edition (Interface 20505).
Creez des listes d'objets a obtenir, suivez votre progression et recevez des alertes quand vos objets drop.

## Installation

1. Extraire le dossier `MyLootTraking` dans :
   ```
   World of Warcraft\_anniversary_\Interface\AddOns\MyLootTraking\
   ```
2. Relancer le jeu ou taper `/reload` en jeu
3. L'addon apparait dans la liste des AddOns au menu de personnages

## Commandes

| Commande | Action |
|---|---|
| `/mlt` | Afficher l'aide |
| `/mlt add [itemID\|lien]` | Ajouter un objet a une liste |
| `/mlt list` | Ouvrir/fermer la fenetre detaillee |
| `/mlt track` | Afficher/masquer le mini-tracker |
| `/mlt search [nom]` | Rechercher un objet |
| `/mlt config` | Ouvrir les parametres |

## Bouton Minimap

- **Clic gauche** : Ouvrir la liste detaillee
- **Clic droit** : Ouvrir les parametres
- **Survol** : Nombre d'objets a recuperer + progression globale
- **Glisser** : Repositionner le bouton sur la minimap

## Fonctionnalites

### Deux types de listes

**Listes BiS (par personnage)**
- Creer des listes d'objets a obtenir pour chaque personnage
- Suivi automatique : l'objet est marque "obtenu" quand vous le lootez
- Donnees partagees entre tous les personnages du compte
- Icone de classe du personnage dans le panneau de listes

**Listes de Farm**
- Creer des listes d'objets a farmer avec une quantite cible (ex: Cuir granuleux x20)
- Compteur automatique : se synchronise avec le contenu de vos sacs en temps reel
- Progression mise a jour a chaque loot ou changement dans les sacs
- Clic droit sur un item farm : modifier la quantite cible ou reinitialiser le compteur

### Ajout d'objets

3 methodes pour ajouter un objet a une liste :
1. **Commande** : `/mlt add 28795` ou `/mlt add [lien d'objet]`
2. **Tooltip** : `Ctrl + Clic droit` sur n'importe quel objet (tooltip, lien chat, AtlasLoot)
3. **Interface** : Bouton "Ajouter" dans la fenetre principale ou `/mlt search [nom]`

### Mini-Tracker

Overlay compact toujours visible sur le cote de l'ecran :
- Items groupes par liste avec en-tete cliquable par liste
- Clic sur le nom d'une liste pour la replier/deplier
- Clic sur le titre "MyLootTraking" pour tout replier/deplier
- Listes farm : compteur (5/20) sous chaque item
- Listes BiS : source (Boss - Instance) avec difficulte (N)/(H)
- Clic droit sur un item pour les options (marquer obtenu, modifier, supprimer...)
- Transparence, echelle, position ajustables et verrouillables

### Sources d'objets

- Base de donnees integree de 3977 items avec boss, instance et difficulte
- Indicateur de difficulte : **(N)** Normal en vert, **(H)** Heroique en orange (TBC)
- Noms des boss et instances traduits en francais
- Modification manuelle via clic droit > Modifier la source
- Lien Wowhead pour les objets sans source connue

### Alertes

- **Drop de groupe** : popup orange + son quand un objet de la liste droppe
- **Loot personnel** : popup vert + son quand vous lootez un objet de la liste
- **Entree en donjon** : popup bleu quand vous entrez dans une instance avec des objets a recuperer
- Systeme de file d'attente : les alertes s'affichent une par une (pas de superposition)
- Positions deplacables et verrouillables

### Fenetre principale

- Panneau gauche : liste de toutes vos listes avec progression
- Panneau droit : items de la liste selectionnee avec tri et filtres
- **Filtres** : par instance (Karazhan, Gruul's Lair, etc.)
- **Tri** : par nom, source, statut, instance ou ordre manuel
- Glisser-deposer pour reorganiser les objets
- Notes personnelles et assignation de personnage par objet

### Statistiques

- Nombre de kills par boss
- Nombre de runs par donjon/raid
- Progression par liste : `7/12 - 58%`
- Progression globale dans la barre de titre et le tooltip minimap

### Recherche

- Interface de recherche en temps reel (`/mlt search`)
- Recherche par nom ou ID d'objet dans la base de donnees (3977 items)
- Clic sur un resultat pour l'ajouter a une liste

### Parametres

- Activer/desactiver les popups et les sons
- Alerte a l'entree de donjon/raid
- Transparence et echelle du mini-tracker
- Verrouiller la position du tracker et des alertes
- Afficher/masquer les objets obtenus
- Reinitialisation complete des parametres

### Integrations

- **AtlasLoot** : bouton "+" sur chaque objet pour l'ajouter avec le contexte (boss/instance)
- **ElvUI** : compatible, respecte l'echelle ElvUI
- **Interface Blizzard** : accessible via le menu Interface > AddOns

### Langues

Francais (complet), English (complet)

## Structure des fichiers

```
MyLootTraking/
├── MyLootTraking.toc           # Configuration addon (Interface 20505)
├── Core.lua                     # Initialisation, evenements, BAG_UPDATE
├── Database.lua                 # Donnees, CRUD, listes farm, scan sacs
├── Utils.lua                    # Fonctions utilitaires, couleurs, formatage
├── ItemSources.lua              # Base de donnees des sources (3977 items)
├── LootDetection.lua            # Detection de loot + quantites + boss kills
├── Statistics.lua               # Statistiques de kills/runs/progression
├── Alerts.lua                   # Notifications popup avec file d'attente
├── TooltipHook.lua              # Tooltips + Ctrl+Clic droit
├── MinimapButton.lua            # Bouton minimap
├── MiniTracker.lua              # Mini-tracker groupe par liste
├── MainFrame.lua                # Fenetre detaillee + filtres + tri
├── SearchFrame.lua              # Interface de recherche
├── ConfigFrame.lua              # Panneau de parametres
├── SlashCommands.lua            # Commandes /mlt
├── AtlasLootIntegration.lua     # Integration AtlasLoot
├── Locales/
│   ├── enUS.lua                 # Anglais (base)
│   └── frFR.lua                 # Francais + traductions boss/instances
└── tools/
    └── parse_atlasloot.ps1      # Generateur ItemSources.lua
```

## SavedVariables

- `MyLootTrakingDB` : Donnees partagees au compte (listes, items, stats, config)

## Developpement

1. Les donnees sont dans `WTF/Account/VOTRE_COMPTE/SavedVariables/MyLootTraking.lua`
2. `/reload` pour recharger apres modification
3. `/script MyLootTrakingDB = nil; ReloadUI()` pour reset complet
4. Pour regenerer ItemSources.lua : `tools/parse_atlasloot.ps1` avec les fichiers data AtlasLoot
