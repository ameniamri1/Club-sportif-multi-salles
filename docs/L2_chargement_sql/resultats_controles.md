# Résultats des contrôles C1 à C9

Les contrôles ont été exécutés dans SQL Developer le 1er novembre 2026 sur le lot 6, après le chargement des quatre CSV et la création des vues de validation. La sortie ne contient pas d'erreur Oracle et les résultats concordent avec la première exploration des fichiers.

Le script utilisé est [controles_C1_C9.sql](../../sql/03_queries/controles_C1_C9.sql). La [sortie Oracle du lot 6](../../preuves/controles_C1_C9/resultats_oracle_lot_6.txt) est conservée avec les preuves.

## Tableau des résultats

| Contrôle | Ce qui est compté | Résultat |
| --- | --- | --- |
| C1 | Personnes distinctes après rapprochement par email normalisé | 20 416 |
| C2 | Opérations invalides selon les trois critères du sujet | 553 : 378 références à des cours absents, 59 montants négatifs et 116 réservations après le début du cours |
| C3 | Réservations valides confirmées | 336 092 |
| C4 | Journée avec le plus de réservations valides, tous statuts confondus | 11 janvier 2026 : 15 885 opérations |
| C5 | Chiffre d'affaires des réservations valides confirmées par site | Siège : 0 € ; Villeurbanne : 452 631 € ; Vénissieux : 639 813 € ; Lyon : 923 962 € |
| C6 | Personnes ayant des réservations valides sur au moins deux sites | 12 258 |
| C7 | Cours dont les places valides confirmées dépassent la capacité | 38 |
| C8 | Groupes dont les réservations valides concernent au moins deux sites | 1 958 |
| C9 | Places valides confirmées par catégorie | Boxe : 67 734 ; cross-training : 66 600 ; natation : 67 253 ; pilates : 66 532 ; yoga : 67 973 |

## Lecture des résultats

Pour C1 et C6, les lignes avec le même email normalisé sont rattachées à une même personne. Chaque ligne sans email reste une personne distincte. C6 porte sur les opérations valides de tous statuts ; limiter le calcul aux confirmations changerait le résultat.

C2 conserve une seule occurrence de chaque opération invalide, même si plusieurs motifs peuvent se cumuler. Dans les fichiers du groupe, les trois motifs ne se recoupent pas : leur somme correspond donc au total de 553.

Le site retenu pour C5, C6 et C8 est celui du cours, pas le site de rattachement de l'adhérent. Le siège apparaît dans C5 avec un chiffre d'affaires nul.

Les 38 cours en sur-réservation de C7 restent dans les données. Le dépassement de capacité ne rend pas leurs réservations invalides au sens de RG13. Pour C9, les places sont additionnées sur les réservations à la fois valides et confirmées.

La sortie texte conserve les résultats de l'exécution. Les captures à joindre au rapport doivent également montrer la requête, son résultat et la connexion ; elles restent à ajouter dans `preuves/controles_C1_C9/`.
