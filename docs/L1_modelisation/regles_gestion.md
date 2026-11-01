# Règles de gestion — M1-1

Le club comprend un siège à Paris et trois salles : Villeurbanne, Vénissieux et Lyon. Un adhérent peut réserver des cours dans plusieurs salles, y compris dans une même réservation groupée.

Dans le modèle, nous utilisons les termes du cahier des charges : USAGER pour un adhérent, RESSOURCE pour une séance de cours et OPERATION pour une réservation.

## Les 25 règles

| ID | Règle de gestion |
| --- | --- |
| RG01 | L'organisation comprend un siège et trois sites. |
| RG02 | Chaque ressource est rattachée à un seul site. |
| RG03 | Un site peut gérer plusieurs ressources. |
| RG04 | Chaque ressource appartient à une catégorie. |
| RG05 | Chaque ressource possède une capacité exprimée en nombre de places. |
| RG06 | Chaque ressource possède une date de début. |
| RG07 | Chaque opération est associée à un usager. |
| RG08 | Chaque opération référence une ressource, éventuellement inexistante dans les données brutes. |
| RG09 | Chaque opération possède une date d'exécution. |
| RG10 | Chaque opération possède un montant. |
| RG11 | Une opération peut réserver une ou plusieurs places. |
| RG12 | Une opération peut avoir le statut « confirmée ». |
| RG13 | Une opération est valide si et seulement si sa ressource existe, son montant est positif ou nul et sa date est antérieure ou égale au début de la ressource. |
| RG14 | Le site d'une opération est déterminé par celui de sa ressource. |
| RG15 | Deux lignes d'usagers ayant le même email normalisé (minuscules et suppression des espaces) désignent une seule personne. |
| RG16 | Chaque ligne d'usager sans adresse électronique représente une personne distincte. |
| RG17 | Une même personne peut effectuer des opérations sur plusieurs sites. |
| RG18 | Plusieurs opérations peuvent partager un même identifiant de groupe (`id_groupe`). |
| RG19 | Un groupe est multisite lorsque ses opérations valides concernent au moins deux sites distincts. |
| RG20 | Une ressource est en sur-réservation lorsque la somme des places des opérations valides confirmées dépasse sa capacité. |
| RG21 | Un usager peut parrainer plusieurs usagers, mais chaque usager peut avoir au maximum un parrain. |
| RG22 | Chaque opération possède un identifiant unique. |
| RG23 | Le nombre de places d'une opération doit être strictement positif. |
| RG24 | Une opération appartient à zéro ou un groupe d'opérations. |
| RG25 | Un usager ne peut pas être son propre parrain. |

## Hypothèses et choix de modélisation

L'organisation du club, la définition d'une opération valide et le regroupement des personnes par email viennent de l'énoncé. D'autres choix précisent le fonctionnement de la base. Les données nous aident à les définir, sans limiter le modèle aux seules valeurs observées : toutes les réservations du fichier portent sur une place, mais RG11 en autorise plusieurs.

Nous proposons le parrainage comme extension métier : un adhérent peut en recommander d'autres et devenir leur parrain. Cette relation donne l'association réflexive prévue dans M1-1. RG21 fixe les cardinalités et RG25 interdit de se parrainer soi-même. Les CSV ne contiennent aucun lien de parrainage ; le champ reste donc vide au départ.

Les hypothèses retenues sont les suivantes :

| Repère | Choix retenu et justification |
| --- | --- |
| H01 | `SITE` représente aussi le siège ; `type_site` vaut `SIEGE` ou `SITE`. La valeur brute `siège` reste conservée dans la zone source. |
| H02 | Une ressource représente une séance datée, et non une activité récurrente. C'est le sens d'une ligne de `cours.csv`. |
| H03 | Une catégorie possède son propre identifiant et un libellé unique. La liste reste ouverte ; les cinq catégories observées ne deviennent pas une liste fermée. |
| H04 | Un usager représente une personne rapprochée, avec un identifiant interne distinct de `id_adherent`. Une table de correspondance garde les identifiants sources et leurs lignes d'origine. |
| H05 | Le rattachement administratif d'un usager à un site est obligatoire et unique dans le modèle. Il ne limite pas les sites où il peut réserver. Les CSV ne présentent pas de conflit de rattachement parmi les doublons décrits dans l'exploration ; si un conflit apparaît, il faudra le traiter explicitement. |
| H06 | Les statuts du modèle métier sont `CONFIRMEE` et `ANNULEE`, les deux valeurs présentes dans les fichiers. Ajouter un autre statut demandera de revoir cette contrainte. |
| H07 | Une capacité et une durée sont des entiers strictement positifs ; un prix unitaire est positif ou nul. Ces choix sont cohérents avec les fichiers et permettent les cours gratuits. |
| H08 | Les dates et heures des cours et réservations sont conservées sans fuseau, à la seconde, comme dans les sources. L'inscription est une date. Les montants sont stockés en décimal avec deux chiffres après la virgule. |
| H09 | Les identifiants de site, ressource et opération reprennent les identifiants de l'unique jeu de données du groupe. Les identifiants de personne et catégorie sont internes. Un second jeu indépendant nécessiterait une stratégie d'identifiants adaptée. |
| H10 | La suppression d'un parent encore référencé est refusée. Le modèle ne prévoit pas de suppression en cascade des réservations. |

Un groupe n'a pas de site propre : ses sites sont ceux des cours réservés. Nous ne lui attribuons pas non plus de propriétaire, car les règles ne l'imposent pas. Pour le parrainage, seule la référence à soi-même est interdite ; les cycles entre plusieurs adhérents ne sont pas traités par RG25.

## Écarts entre le modèle et les fichiers

L'[exploration des CSV](../data_exploration.md) fait ressortir plusieurs points à prendre en compte dans le modèle.

| Point observé | Conséquence pour M1-1 |
| --- | --- |
| `salles.csv` contient Paris comme siège, puis Villeurbanne, Vénissieux et Lyon. | RG01 est cohérente. Le siège n'a ni adhérent ni cours dans les fichiers, ce qui justifie une cardinalité minimale de zéro côté site. |
| Des réservations désignent des cours absents. | Une FK métier ne doit pas être appliquée aux références brutes de RG08. |
| Certains montants sont négatifs et certaines réservations sont postérieures au début du cours. | Ces lignes doivent rester accessibles dans la zone source malgré leur non-validité selon RG13. |
| Certains cours sont en sur-réservation. | RG20 décrit une situation à mesurer ; elle n'ajoute aucun motif d'invalidité à RG13. |
| Plusieurs identifiants d'adhérent peuvent correspondre au même email normalisé ; certains emails sont absents. | L'email brut ne peut pas être une clé primaire. RG15 et RG16 nécessitent une correspondance entre lignes sources et personnes. |
| Des couples adhérent/cours se répètent. | Aucune contrainte `UNIQUE (id_usager, id_ressource)` n'est ajoutée. |
| Toutes les places observées valent 1. | La contrainte reste `nb_places > 0`, sans figer la valeur à 1. |
| Aucun champ ne décrit le parrainage. | `id_parrain` sera facultatif ; aucun lien ne sera inventé. |

## Données brutes et données métier

Nous séparons les données brutes des tables métier pour garder les réservations qui présentent une anomalie. Les tables `BRUT_*` conservent les valeurs en texte, avec leur lot, leur numéro de ligne et l'enregistrement original. Les contraintes métier s'appliquent dans les autres tables.

La validité d'une réservation repose sur les trois conditions de RG13 : le cours existe, le montant est positif ou nul et la réservation a lieu au plus tard au début du cours. Le statut, le nombre de places ou une sur-réservation ne changent pas cette définition. Une ligne peut donc respecter RG13 tout en présentant une autre anomalie à traiter avant son admission dans les tables métier.

Les contrôles C1 à C9 devront s'appuyer sur l'ensemble des données sources et sur les valeurs converties. Utiliser seulement les tables métier laisserait de côté les lignes rejetées et fausserait les résultats.
