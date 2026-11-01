# Club sportif multi-salles

Projet Data Storage Systems — groupe 08.

Ce projet porte sur la gestion des adhérents, des cours et des réservations d'un club réparti entre trois salles. Le modèle L1 et ses contraintes ont été créés sur Oracle. Le travail en cours concerne L2 : charger les fichiers, examiner les anomalies, puis exécuter les contrôles et les requêtes métier. L3 n'a pas encore commencé.

- `data/raw/` : copies des CSV sources (UTF-8, séparateur virgule).
- `sql/` : schéma, import, validation, requêtes et dénormalisation.
- `docs/` : modélisation, chargement, normalisation et journal.
- `preuves/` : captures des résultats de contrôle et des requêtes métier.
- `run/` : exploration Python et génération des fichiers SQL d'import.

Pour consulter les premiers résultats, voir [l’exploration des données](docs/data_exploration.md). L’analyse peut être relancée depuis la racine du projet avec Pandas installé :

```powershell
python run/exploration_donnees.py
```

Pour générer les scripts d'import à partir des CSV :

```powershell
python run/generer_import_sql.py
```

Le fichier à lancer dans SQL Developer est `sql/02_import/generated/charger_tout.sql`. Le chargement du lot 6 et la validation des anomalies ont été exécutés sur Oracle. Le [guide L2](docs/L2_chargement_sql/chargement.md) donne l'ordre des scripts pour poursuivre les contrôles et les requêtes métier.
