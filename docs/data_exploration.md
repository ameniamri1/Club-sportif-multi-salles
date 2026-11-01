# Exploration des données

L’analyse du 1er novembre 2026 porte sur les quatre CSV de `data/raw/`, lus entièrement avec Python et Pandas 2.3.3. Elle fait ressortir trois points à traiter avant le chargement : des adhérents présents sous plusieurs identifiants, 553 réservations invalides et 38 cours en sur-réservation.

Les fichiers sont en UTF-8 et utilisent la virgule comme séparateur. La lecture conserve les valeurs sous forme de texte (`dtype="string"`, `keep_default_na=False`), puis les convertit en mémoire pour les calculs. Les champs vides ou composés uniquement d’espaces sont comptés comme manquants. Les CSV d’origine sont restés intacts. Pour reproduire l’analyse, lancer `python run/exploration_donnees.py` depuis la racine du projet.

## Ce que contiennent les fichiers

| Fichier / entité | Lignes | Colonnes et types sémantiques observés |
| --- | ---: | --- |
| `salles.csv` / site | 4 | `id_salle` : entier ; `nom`, `ville`, `role` : texte |
| `adherents.csv` / adhérent | 20 467 | `id_adherent`, `id_salle` : entiers ; `nom`, `prenom`, `email`, `telephone`, `ville` : texte ; `date_inscription` : date |
| `cours.csv` / séance datée | 28 571 | `id_cours`, `id_salle`, `duree_minutes`, `capacite` : entiers ; `libelle`, `categorie` : texte ; `debut` : date et heure ; `prix_unitaire` : nombre monétaire, valeurs entières dans ce fichier |
| `reservations.csv` / réservation | 365 069 | `id_reservation`, `id_adherent`, `id_cours`, `nb_places` : entiers ; `date_reservation` : date et heure ; `montant` : nombre monétaire ; `statut`, `id_groupe` : texte, groupe facultatif |

Avec les réglages par défaut, Pandas lit les identifiants en `int64`, le montant en `float64` et les dates en `object`. Il traite aussi le téléphone comme un entier, ce qui supprime le zéro initial. Il faut donc le garder en texte. Le champ `id_groupe` déclenche un avertissement de types mixtes ; sa lecture en texte règle ce problème. Pour les montants, un type décimal exact sera préférable dans la base.

## Valeurs manquantes et doublons

- Aucun doublon de ligne complète dans les quatre fichiers. Aucun identifiant principal vide ou répété.
- `email` : 33 valeurs manquantes, 19 valeurs avec espaces en bordure et 51 valeurs modifiées par la mise en minuscules. Ces populations peuvent se recouper.
- Après normalisation de l’email (minuscules et suppression des espaces), 51 groupes de doublons, chacun de deux lignes : 51 lignes excédentaires. Les autres champs, hors identifiant et email, présentent également 51 lignes dupliquées. Résultat : **20 416 personnes distinctes**, chaque ligne sans email comptant pour une personne.
- Aucun email renseigné ne viole le contrôle syntaxique simple `^[^@\s]+@[^@\s]+\.[^@\s]+$` ; ce contrôle ne vérifie pas la délivrabilité.
- Les 20 467 téléphones ont dix chiffres et respectent `^0[0-9]{9}$`.
- `id_groupe` est vide sur 356 620 réservations ; cette absence est attendue pour une réservation non groupée. Les 8 449 lignes renseignées portent 2 834 identifiants de groupe distincts.
- Aucune autre valeur manquante ; aucune date non interprétable dans les colonnes de dates.
- 362 répétitions supplémentaires du couple `(id_adherent, id_cours)`, mais aucun doublon de réservation si l’on exclut uniquement `id_reservation`. Ne pas imposer l’unicité de ce couple sans règle métier : une répétition peut représenter des opérations distinctes.
- Les groupes valides semblent parfois réunir plusieurs identifiants d’adhérent (6 groupes), mais **aucun ne réunit plusieurs personnes après rapprochement par email normalisé**.

## Réservations invalides selon le sujet

Une opération est valide si son cours existe, si `montant >= 0` et si `date_reservation <= debut`. Le statut et la présence d’un groupe ne changent pas cette définition.

| Motif | Réservations concernées |
| --- | ---: |
| Cours inexistant | 378, visant 364 identifiants de cours absents |
| Réservation après le début du cours | 116 |
| Montant négatif | 59 |
| **Total invalide** | **553** |

Dans ce jeu de données, aucune réservation ne cumule plusieurs de ces motifs. Pour les cours absents, la comparaison des dates est impossible. Il reste **364 516 réservations valides**, dont **336 092 confirmées**. Avant filtrage, les fichiers contiennent 336 595 réservations `CONFIRMEE` et 28 474 `ANNULEE`, sans autre statut.

Tous les montants sont numériques. Pour les cours existants, 59 montants diffèrent de `nb_places × prix_unitaire` : ce sont exactement les 59 montants négatifs. Cette égalité constitue un constat sur les données, pas une condition supplémentaire de validité imposée par le sujet.

Les réservations valides confirmées dépassent la capacité de **38 cours**, pour **79 places excédentaires** au total et un maximum de **3 places excédentaires par cours**. Ces réservations restent valides au sens des contrôles : la sur-réservation est une anomalie métier distincte.

## Répartition par site

Le site d’une réservation est celui du cours, indépendamment du site de rattachement de l’adhérent.

| Site | Adhérents bruts | Cours | Réservations rattachables, tous statuts | Valides | Valides confirmées | CA valide confirmé |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 — Paris, siège | 0 | 0 | 0 | 0 | 0 | 0 € |
| 2 — Villeurbanne | 4 475 | 6 318 | 81 701 | 81 657 | 75 432 | 452 631 € |
| 3 — Vénissieux | 6 488 | 9 042 | 115 727 | 115 680 | 106 634 | 639 813 € |
| 4 — Lyon | 9 504 | 13 211 | 167 263 | 167 179 | 154 026 | 923 962 € |

Les 378 réservations sans cours ne peuvent pas être affectées à un site. Lyon concentre le plus de cours et de réservations. Cette différence sera à prendre en compte pour la répartition des données entre sites.

Parmi les opérations valides, 23 481 concernent un cours situé hors du site de rattachement de l’adhérent. C’est un usage prévu pour ce club : le modèle doit permettre de réserver dans une autre salle. **12 258 personnes distinctes** ont des réservations valides sur au moins deux sites. Ce calcul inclut les annulations et regroupe les adhérents par email normalisé, comme le demande le sujet. En comptant les identifiants bruts, on obtiendrait 12 271 : certains doublons seraient alors comptés comme des personnes différentes.

**1 958 groupes** engagent au moins deux sites en ne considérant que leurs réservations valides, tous statuts confondus.

## Dates, catégories et capacités

- Inscriptions : du 12/07/2019 au 01/01/2025.
- Débuts des cours : du 01/01/2025 à 08:30 au 31/12/2026 à 21:45.
- Réservations brutes : du 02/11/2024 à 00:13:43 au 06/01/2027 à 12:15 ; la borne finale inclut des opérations invalides.
- Pic des réservations valides : **15 885 opérations le 11/01/2026**, cohérent avec la reprise de janvier annoncée.
- Durées : 45 à 120 minutes, quatre valeurs distinctes ; capacités : 10 à 30 places. Aucune durée ou capacité nulle ou négative.
- Prix unitaires : 0 à 12 € ; 1 210 cours gratuits, aucun prix négatif. La gratuité ne doit pas être rejetée.
- `nb_places` vaut 1 sur toutes les réservations ; cela ne suffit pas à imposer cette valeur comme règle générale.

| Catégorie | Cours | Places valides confirmées |
| --- | ---: | ---: |
| Boxe | 5 779 | 67 734 |
| Yoga | 5 765 | 67 973 |
| Natation | 5 711 | 67 253 |
| Cross-training | 5 681 | 66 600 |
| Pilates | 5 635 | 66 532 |

## Clés et relations candidates

| Clé ou relation | Observation et implication pour la modélisation |
| --- | --- |
| Clés primaires candidates | `salles.id_salle`, `adherents.id_adherent`, `cours.id_cours`, `reservations.id_reservation` : uniques et renseignées sur tout le jeu |
| Adhérent → site | `adherents.id_salle → salles.id_salle` : aucune référence absente ; plusieurs adhérents par site |
| Cours → site | `cours.id_salle → salles.id_salle` : aucune référence absente ; chaque séance possède un site |
| Réservation → adhérent | `reservations.id_adherent → adherents.id_adherent` : aucune référence absente |
| Réservation → cours | `reservations.id_cours → cours.id_cours` : 378 références invalides à traiter avant un chargement strict |
| Adhérent ↔ cours | Relation plusieurs-à-plusieurs portée par la réservation, avec date, places, montant et statut |
| Groupe → réservations | Identifiant facultatif et répété, candidat à une entité d’opération groupée ; ce n’est pas une clé de réservation |
| Identité de personne | L’email brut n’est ni obligatoire ni unique ; distinguer l’identifiant source et l’identité rapprochée avant de fixer les règles d’unicité |

Au chargement, il faudra garder une trace des lignes rejetées ou corrigées et expliquer chaque traitement. Les fichiers ne donnent pas directement de relation d’héritage ni d’association réflexive. Pour répondre à cette partie de L1, il reste donc à définir une règle métier qui ait du sens pour le club.

Les chiffres de ce rapport viennent du script Pandas. Ils serviront de référence pour comparer les résultats lorsque les requêtes SQL seront prêtes.
