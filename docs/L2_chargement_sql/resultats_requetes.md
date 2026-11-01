# Résultats des requêtes

Les dix requêtes de [requetes_metier.sql](../../sql/03_queries/requetes_metier.sql) portent sur l'activité des salles, les cours demandés et les habitudes de réservation. Elles utilisent les opérations valides. Lorsque l'énoncé parle de réservations confirmées, le filtre `statut = 'CONFIRMEE'` s'ajoute à cette sélection.

| Requête | Énoncé | Construction principale | Colonnes du résultat |
| --- | --- | --- | --- |
| Q01 | Activité confirmée de chaque site, y compris sans réservation | Jointure externe LEFT JOIN | Site, nom, réservations, places, chiffre d'affaires |
| Q02 | Vingt séances les plus demandées ayant au moins vingt places confirmées | GROUP BY et HAVING | Cours, libellé, salle, capacité, places confirmées |
| Q03 | Personnes sans réservation valide, aperçu de vingt | Sous-requête corrélée NOT EXISTS | Clé de personne |
| Q04 | Personnes ayant réservé dans chacune des trois salles, aperçu de vingt | Division par double NOT EXISTS | Clé de personne |
| Q05 | Trois premiers rangs des séances par site, selon les places confirmées | DENSE_RANK et PARTITION BY | Site, rang, cours, libellé, places |
| Q06 | Réservations et taux d'annulation par site et catégorie | Agrégation conditionnelle | Site, catégorie, réservations, annulations, taux en % |
| Q07 | Vingt premières séances de janvier 2026 avec des places disponibles | Jointure externe et HAVING | Cours, libellé, salle, début, places restantes |
| Q08 | Vingt groupes ayant les plus gros montants confirmés sur plusieurs sites | HAVING et COUNT DISTINCT | Groupe, sites, séances, places, montant confirmé |
| Q09 | Vingt personnes dépassant la dépense moyenne des personnes ayant réservé | Sous-requête sur une moyenne | Personne, réservations, montant |
| Q10 | Chiffre d'affaires mensuel selon la date de réservation et cumul | SUM OVER et LAG | Mois, chiffre d'affaires, cumul, écart avec le mois précédent |

Un résultat vide pour Q03 signifie que toutes les personnes ont au moins une réservation valide. Q05 garde les ex aequo, donc un site peut avoir plus de trois cours affichés. Q10 compare les mois présents dans les données, sans ajouter de mois vide.

Les contrôles C1 à C9 sont dans [controles_C1_C9.sql](../../sql/03_queries/controles_C1_C9.sql). C4 conserve les journées ex aequo. C5 affiche aussi le siège à zéro. C6 et C8 incluent les annulations valides. C9 additionne les places des réservations valides confirmées.

Les [résultats C1 à C9 du lot 6](resultats_controles.md) ont été obtenus sur Oracle et sont consignés séparément des dix requêtes métier.

Le lot 6 est chargé et les vues de validation sont créées. Les résultats chiffrés des requêtes restent à renseigner après leur exécution. Pour chaque requête, conserver l'ID_LOT et la capture ou la sortie correspondante dans `preuves/requetes_metier/`. Le [guide de chargement](chargement.md) explique comment enregistrer la sortie avec les énoncés et les résultats.
