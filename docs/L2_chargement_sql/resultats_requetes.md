# Résultats des requêtes

Les dix requêtes de [requetes_metier.sql](../../sql/03_queries/requetes_metier.sql) portent sur l'activité des salles, les cours demandés et les habitudes de réservation. Elles utilisent les opérations valides. Lorsque l'énoncé parle de réservations confirmées, le filtre `statut = 'CONFIRMEE'` s'ajoute à cette sélection.

| Requête | Énoncé | Construction principale | Colonnes du résultat |
| --- | --- | --- | --- |
| Q01 | Activité confirmée de chaque site, y compris sans réservation | Jointure externe LEFT JOIN | Site, nom, réservations, places, chiffre d'affaires |
| Q02 | Vingt séances les plus demandées ayant au moins vingt places confirmées | GROUP BY et HAVING | Cours, libellé, salle, capacité, places confirmées |
| Q03 | Personnes sans réservation valide, aperçu de vingt | Différence d'ensembles avec MINUS | Clé de personne |
| Q04 | Personnes ayant réservé dans chacune des trois salles, aperçu de vingt | Division par comptage et sous-requête corrélée sur les sites du lot | Clé de personne |
| Q05 | Trois premiers rangs des séances par site, selon les places confirmées | DENSE_RANK et PARTITION BY | Site, rang, cours, libellé, places |
| Q06 | Réservations et taux d'annulation par site et catégorie | Agrégation conditionnelle | Site, catégorie, réservations, annulations, taux en % |
| Q07 | Vingt premières séances de janvier 2026 avec des places disponibles | Agrégation des places par cours, puis jointure externe | Cours, libellé, salle, début, places restantes |
| Q08 | Vingt groupes ayant les plus gros montants confirmés sur plusieurs sites | HAVING et COUNT DISTINCT | Groupe, sites, séances, places, montant confirmé |
| Q09 | Vingt personnes dépassant la dépense moyenne des personnes ayant réservé | Moyenne globale avec AVG OVER après agrégation par personne | Personne, réservations, montant |
| Q10 | Chiffre d'affaires mensuel selon la date de réservation et cumul | SUM OVER et LAG | Mois, chiffre d'affaires, cumul, écart avec le mois précédent |

Un résultat vide pour Q03 signifie que toutes les personnes ont au moins une réservation valide. Q05 garde les ex aequo, donc un site peut avoir plus de trois cours affichés. Q10 compare les mois présents dans les données, sans ajouter de mois vide.

La première écriture de Q03 avec NOT EXISTS est restée en cours pendant trente minutes. Elle est remplacée par MINUS. Q04 utilise une division par comptage : les réservations sont regroupées par personne, puis le nombre de salles visitées est comparé au nombre de salles du lot. La sous-requête corrélée demandée pour L2 reste présente dans cette comparaison.

## Résultats obtenus sur Oracle

Les dix requêtes ont été exécutées le 1er novembre 2026 sur le lot 6 dans SQL Developer, après les contrôles du chargement. La [sortie complète](../../preuves/requetes_metier/resultats_oracle_lot_6.txt) contient les résultats et les temps affichés pour chaque requête, sans erreur Oracle visible.

| Requête | Lignes affichées | Temps affiché | Résultat principal |
| --- | ---: | ---: | --- |
| Q01 | 4 | 1,040 s | Le siège reste à zéro. Villeurbanne compte 75 432 confirmations, Vénissieux 106 634 et Lyon 154 026. |
| Q02 | 20 | 1,147 s | Le maximum est de 33 places confirmées pour une capacité de 30, sur les cours 25520, 3524 et 361. |
| Q03 | 0 | 2,976 s | Toutes les personnes ont au moins une réservation valide. |
| Q04 | 20 | 4,195 s | Aperçu de vingt personnes ayant une réservation valide confirmée dans chacune des trois salles. Ce n'est pas leur effectif total. |
| Q05 | 12 | 1,239 s | Les trois premiers rangs donnent 5 cours à Villeurbanne, 4 à Vénissieux et 3 à Lyon, en conservant les ex aequo. |
| Q06 | 15 | 1,140 s | Les trois salles et cinq catégories donnent 15 groupes. Les taux d'annulation vont de 7,52 % à 8,07 %. |
| Q07 | 20 | 1,188 s | Les vingt premières séances disponibles sont toutes le 1er janvier 2026. La première est le cours 14132 à 08:30, avec 3 places restantes. |
| Q08 | 20 | 0,091 s | Le groupe G00565 arrive en tête : 42 € confirmés, 4 séances et 3 sites. |
| Q09 | 20 | 2,857 s | La dépense la plus élevée affichée est de 229 € pour 30 réservations valides confirmées. |
| Q10 | 26 | 1,222 s | Les mois vont de novembre 2024 à décembre 2026. Le cumul final atteint 2 016 406 €. |

Les limites à vingt lignes sont des aperçus ordonnés, pas des effectifs totaux. Pour Q03, l'absence de ligne établit bien qu'aucune personne n'est sans réservation valide dans le lot.

Les résultats restent cohérents avec les contrôles : Q01 totalise les 336 092 réservations valides confirmées de C3. Son chiffre d'affaires et le cumul final de Q10 retrouvent les 2 016 406 € de C5. Q06 porte sur 364 516 opérations valides, dont 28 424 annulées. Les dépassements de capacité visibles dans Q02 restent des réservations valides selon RG13.

## Lecture des temps

Ces temps correspondent à un seul passage dans SQL Developer, avec le transfert et l'affichage des résultats. Q03 a terminé en 2,976 secondes avec MINUS, alors que l'ancienne écriture était encore en cours après trente minutes. Le plan et l'état du cache de la première tentative n'ont pas été relevés : cette observation ne constitue pas une comparaison contrôlée des deux versions.

Pour L3, les mesures seront refaites sur les copies normalisée et dénormalisée, avec plusieurs passages et les plans réels lorsque les droits du compte le permettent. Les temps L2 ne donnent pas à eux seuls le nombre de blocs lus.

Les contrôles C1 à C9 sont dans [controles_C1_C9.sql](../../sql/03_queries/controles_C1_C9.sql). C4 conserve les journées ex aequo. C5 affiche aussi le siège à zéro. C6 et C8 incluent les annulations valides. C9 additionne les places des réservations valides confirmées.

Les [résultats C1 à C9 du lot 6](resultats_controles.md) ont été obtenus sur Oracle et sont consignés séparément des dix requêtes métier.

La sortie texte de cette exécution est conservée dans `preuves/requetes_metier/`. Les captures à joindre au rapport doivent montrer les requêtes, leurs résultats et la connexion. Le [guide de chargement](chargement.md) rappelle la procédure d'enregistrement.
