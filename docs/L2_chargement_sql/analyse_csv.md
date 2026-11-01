# Analyse des CSV

Les quatre fichiers décrivent les salles, les adhérents, les séances de cours et les réservations. L'[exploration des données](../data_exploration.md) présente leurs premiers résultats et les défauts repérés. Pour le chargement, chaque fichier alimente sa table brute avec les mêmes champs.

| Fichier | Table cible | Lignes hors en-tête |
| --- | --- | ---: |
| salles.csv | BRUT_SALLE | 4 |
| adherents.csv | BRUT_USAGER | 20 467 |
| cours.csv | BRUT_RESSOURCE | 28 571 |
| reservations.csv | BRUT_OPERATION | 365 069 |

Les dates, les identifiants et les montants sont d'abord stockés en texte. Ce choix permet de garder une valeur incorrecte sans interrompre le chargement pour une raison métier. Les champs vides, les espaces et la casse sont conservés, tout comme le zéro initial du téléphone. Chaque ligne reste retrouvable par son lot, son numéro et son texte original.

Le [guide de chargement](chargement.md) donne l'ordre des scripts. Le [traitement des anomalies](traitement_anomalies.md) précise les conversions et les filtres utilisés dans les vues.
