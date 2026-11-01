# Club sportif multi-salles

Projet Data Storage Systems — groupe 08.

Ce dépôt rassemble le travail sur les livrables L1, L2 et L3 du club sportif. L’exploration des données est disponible ; la modélisation et les scripts SQL restent à compléter.

- `data/raw/` : copies des CSV sources (UTF-8, séparateur virgule).
- `sql/` : schéma, import, validation, requêtes et dénormalisation.
- `docs/` : modélisation, chargement, normalisation et journal.
- `preuves/` : captures des résultats de contrôle et des requêtes métier.
- `run/` : script d’exploration Python et fichier prévu pour l’exécution SQL.

Pour consulter les premiers résultats, voir [l’exploration des données](docs/data_exploration.md). L’analyse peut être relancée depuis la racine du projet avec Pandas installé :

```powershell
python run/exploration_donnees.py
```
