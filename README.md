# Club sportif multi-salles

Projet Data Storage Systems — groupe 08.

Ce projet porte sur la gestion des adhérents, des cours et des réservations d'un club réparti entre trois salles. Le modèle L1 et ses contraintes ont été créés sur Oracle. Les données du lot 6 sont chargées ; les contrôles C1 à C9 et les dix requêtes métier ont été exécutés. Leurs résultats sont consignés dans `docs/L2_chargement_sql/`. L'étude L3 et la campagne de 30 séries de mesures sur Oracle sont documentées dans `docs/L3_normalisation/`.

- `data/raw/` : copies des CSV sources (UTF-8, séparateur virgule).
- `sql/` : schéma, import, validation, requêtes et dénormalisation.
- `docs/` : modélisation, chargement, normalisation et journal.
- `preuves/` : captures des résultats de contrôle et des requêtes métier.
- `run/` : exploration Python et génération des fichiers SQL d'import.

Pour consulter les premiers résultats, voir [l’exploration des données](docs/data_exploration.md). L’analyse peut être relancée depuis la racine du projet avec Pandas installé :

```powershell
python run/exploration_donnees.py
```

Les scripts d'import sont inclus dans `sql/02_import/generated/` et prêts à être exécutés dans SQL Developer. Pour les reconstruire dans un autre dossier à partir des CSV :

```powershell
python run/generer_import_sql.py --sortie sql/02_import/nouvelle_generation
```

Le fichier à lancer dans SQL Developer est `sql/02_import/generated/charger_tout.sql`. Le chargement du lot 6 et la validation des anomalies ont été exécutés sur Oracle. Le [guide L2](docs/L2_chargement_sql/chargement.md) donne l'ordre des scripts pour poursuivre les contrôles et les requêtes métier.

Pour produire le fichier à plat de L3 :

```powershell
python run/generer_operations_a_plat.py
```

L'[étude de dénormalisation](docs/L3_normalisation/denormalisation.md) décrit les scripts à lancer après L2 et les mesures sur le lot 6. Sur 30 séries de cinq passages, Q06 produit les mêmes résultats, avec des médianes normalisée/dénormalisée de 0,07/0,05 s, soit une baisse de 28,57 %. La médiane dénormalisée est inférieure dans 29 séries et égale dans une série. Les plans et les lectures de blocs restent indisponibles avec les droits actuels du compte Oracle.
