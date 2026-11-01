# Dictionnaire des données

Ce dictionnaire décrit les champs de la base du club sportif. Les types et les contraintes correspondent à [create_tables.sql](../../sql/01_schema/create_tables.sql) et [constraints.sql](../../sql/01_schema/constraints.sql).

Les tables métier regroupent les personnes, les sites, les séances et les réservations. Les tables `BRUT_*` conservent les valeurs des CSV avant traitement, y compris les lignes présentant une anomalie.

Dans les tableaux, PK désigne une clé primaire, FK une clé étrangère et UNIQUE une valeur unique lorsqu'elle est renseignée. Le caractère obligatoire tient compte des deux scripts : une colonne de clé primaire devient obligatoire avec l'ajout de la PK.

## SITE — siège et salles du club

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_site` | `NUMBER(12)` | Oui | PK. Identifiant issu de `salles.id_salle`. |
| `nom` | `VARCHAR2(100 CHAR)` | Oui | Nom du siège ou de la salle. |
| `ville` | `VARCHAR2(100 CHAR)` | Oui | Ville du site. |
| `type_site` | `VARCHAR2(5 CHAR)` | Oui | `SIEGE` ou `SITE` ; contrôlé par `ck_site_type`. La valeur source `siège` reste dans BRUT_SALLE. |

RG01 prévoit un siège et trois sites. Le domaine de `type_site` distingue les rôles, mais ne garantit pas à lui seul leur nombre exact.

## CATEGORIE — catégories de cours

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_categorie` | `NUMBER(12)` | Oui | PK, générée par Oracle avec `GENERATED ALWAYS AS IDENTITY`. |
| `libelle` | `VARCHAR2(100 CHAR)` | Oui | Nom de la catégorie ; UNIQUE avec `uq_categorie_libelle`. Provient de `cours.categorie`. |

Les catégories présentes dans les CSV sont boxe, yoga, natation, cross-training et pilates. Le modèle permet d'en ajouter sans modifier le domaine de la colonne.

## USAGER — personnes inscrites au club

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_usager` | `NUMBER(12)` | Oui | PK interne générée par Oracle. Elle identifie une personne après rapprochement des lignes d'adhérent. |
| `nom` | `VARCHAR2(100 CHAR)` | Non | Nom de famille. |
| `prenom` | `VARCHAR2(100 CHAR)` | Non | Prénom. |
| `email_normalise` | `VARCHAR2(320 CHAR)` | Non | Email en minuscules et sans caractères d'espacement. UNIQUE avec `uq_usager_email` ; forme vérifiée par `ck_usager_email`. |
| `telephone` | `VARCHAR2(32 CHAR)` | Non | Numéro conservé en texte pour garder le zéro initial. Aucun format téléphonique supplémentaire n'est imposé par le SQL. |
| `ville` | `VARCHAR2(100 CHAR)` | Non | Ville déclarée par l'adhérent. Elle ne détermine pas le site d'une réservation. |
| `date_inscription` | `DATE` | Non | Date d'inscription au club, issue de `adherents.date_inscription`. |
| `id_site_rattachement` | `NUMBER(12)` | Oui | FK vers `SITE.id_site`. Site administratif de l'adhérent. |
| `id_parrain` | `NUMBER(12)` | Non | FK vers `USAGER.id_usager`. Au plus un parrain par usager ; `ck_usager_parrain` interdit de se parrainer soi-même. |

Plusieurs lignes sources ayant le même email normalisé désignent une seule personne. Une ligne sans email désigne une personne distincte : les valeurs NULL ne sont pas regroupées. Le parrainage est une extension métier ; aucun champ des CSV ne permet de le renseigner.

## RESSOURCE — séances de cours

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_ressource` | `NUMBER(12)` | Oui | PK. Identifiant issu de `cours.id_cours`. Une ressource correspond à une séance datée. |
| `libelle` | `VARCHAR2(200 CHAR)` | Oui | Intitulé de la séance, issu de `cours.libelle`. |
| `id_categorie` | `NUMBER(12)` | Oui | FK vers `CATEGORIE.id_categorie`. |
| `id_site` | `NUMBER(12)` | Oui | FK vers `SITE.id_site`. Salle qui accueille la séance. |
| `debut` | `TIMESTAMP(0)` | Oui | Date et heure de début, à la seconde et sans fuseau. |
| `duree_minutes` | `NUMBER(6)` | Oui | Durée entière en minutes ; strictement positive avec `ck_ressource_duree`. |
| `capacite` | `NUMBER(10)` | Oui | Nombre entier de places disponibles ; strictement positif avec `ck_ressource_capacite`. |
| `prix_unitaire` | `NUMBER(14,2)` | Oui | Prix d'une place en euros ; positif ou nul avec `ck_ressource_prix`. Les cours gratuits sont autorisés. |

La durée, la capacité et le prix relèvent de l'hypothèse H07 des [règles de gestion](regles_gestion.md). Ils ne constituent pas des critères supplémentaires de validité d'une opération.

## GROUPE_OPERATION — réservations groupées

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_groupe` | `VARCHAR2(100 CHAR)` | Oui | PK. Identifiant textuel issu de `reservations.id_groupe`, commun aux opérations d'un même groupe. |

Un groupe peut concerner plusieurs cours et plusieurs sites. Il n'a pas de site stocké : ses sites se retrouvent par les ressources de ses opérations.

## OPERATION — réservations

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_operation` | `NUMBER(12)` | Oui | PK. Identifiant issu de `reservations.id_reservation`. |
| `id_usager` | `NUMBER(12)` | Oui | FK vers `USAGER.id_usager`, obtenue après rapprochement de l'adhérent source. |
| `id_ressource` | `NUMBER(12)` | Oui | FK vers `RESSOURCE.id_ressource`, issue de `reservations.id_cours`. |
| `date_execution` | `TIMESTAMP(0)` | Oui | Date et heure de la réservation, issues de `reservations.date_reservation`. |
| `nb_places` | `NUMBER(10)` | Oui | Nombre entier de places réservées ; strictement positif avec `ck_operation_places`. |
| `montant` | `NUMBER(14,2)` | Oui | Montant de l'opération en euros ; positif ou nul avec `ck_operation_montant`. |
| `statut` | `VARCHAR2(9 CHAR)` | Oui | `CONFIRMEE` ou `ANNULEE`, selon `ck_operation_statut`. |
| `id_groupe` | `VARCHAR2(100 CHAR)` | Non | FK vers `GROUPE_OPERATION.id_groupe`. NULL pour une opération non groupée. |

Une opération est valide selon RG13 si le cours existe, si son montant est positif ou nul et si sa date est antérieure ou égale au début du cours. La FK et le CHECK de montant couvrent les deux premières conditions. La comparaison des dates exige un contrôle entre tables ; elle n'est pas garantie par les contraintes actuelles.

Le site de l'opération se retrouve par RESSOURCE. Ni le statut annulé ni une sur-réservation ne rendent l'opération invalide selon RG13. Le montant reste une valeur propre à la réservation : le SQL n'impose pas l'égalité avec le prix courant du cours multiplié par les places.

## LOT_SOURCE — identification des fichiers d'origine

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_lot` | `NUMBER(12)` | Oui | PK générée par Oracle. Identifie une livraison des quatre CSV. |
| `libelle` | `VARCHAR2(255 CHAR)` | Oui | Description du lot. |
| `date_creation` | `TIMESTAMP(0)` | Oui | Date technique de création du lot, initialisée par `LOCALTIMESTAMP`. |

## Tables BRUT_* — valeurs des CSV

Les quatre tables brutes partagent les colonnes techniques suivantes :

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_lot` | `NUMBER(12)` | Oui | Partie de la PK composée et FK vers `LOT_SOURCE.id_lot`. |
| `numero_ligne` | `NUMBER(12)` | Oui | Partie de la PK composée ; numéro d'enregistrement hors en-tête, strictement positif. |
| `ligne_originale` | `CLOB` | Oui | Texte original de l'enregistrement CSV. |

La clé `(id_lot, numero_ligne)` est propre à chaque table brute. Les autres champs sont tous de type `VARCHAR2(4000 BYTE)` et facultatifs. Ils n'ont ni FK métier, ni contrainte d'unicité, ni contrôle de montant ou de date. Cela permet de conserver les valeurs incorrectes sans les remplacer.

### BRUT_SALLE — salles.csv

| Champ source | Signification |
| --- | --- |
| `id_salle` | Identifiant source du siège ou de la salle. |
| `nom` | Nom source du site. |
| `ville` | Ville source du site. |
| `role` | Rôle tel qu'il figure dans le fichier, notamment `siège` ou `site`. |

### BRUT_USAGER — adherents.csv

| Champ source | Signification |
| --- | --- |
| `id_adherent` | Identifiant de la ligne d'adhérent dans le jeu fourni. |
| `nom` | Nom de famille source. |
| `prenom` | Prénom source. |
| `email` | Adresse d'origine, avant mise en minuscules et suppression des espaces. |
| `telephone` | Numéro de téléphone tel qu'il apparaît dans le fichier. |
| `ville` | Ville déclarée. |
| `id_salle` | Identifiant source du site de rattachement. |
| `date_inscription` | Date d'inscription sous forme de texte. |

### BRUT_RESSOURCE — cours.csv

| Champ source | Signification |
| --- | --- |
| `id_cours` | Identifiant source de la séance. |
| `libelle` | Intitulé source du cours. |
| `categorie` | Libellé de catégorie présent dans le fichier. |
| `id_salle` | Identifiant source de la salle du cours. |
| `debut` | Date et heure de début sous forme de texte. |
| `duree_minutes` | Durée source, avant conversion numérique. |
| `capacite` | Nombre de places source, avant conversion numérique. |
| `prix_unitaire` | Prix source d'une place, avant conversion décimale. |

### BRUT_OPERATION — reservations.csv

| Champ source | Signification |
| --- | --- |
| `id_reservation` | Identifiant source de la réservation. |
| `id_adherent` | Référence source à l'adhérent. |
| `id_cours` | Référence source au cours, même si ce cours est absent. |
| `date_reservation` | Date et heure de réservation sous forme de texte, même si elles dépassent le début du cours. |
| `nb_places` | Nombre de places source, avant conversion numérique. |
| `montant` | Montant source, y compris une éventuelle valeur négative. |
| `statut` | Statut tel qu'il apparaît dans le fichier. |
| `id_groupe` | Identifiant source du groupe ; champ vide pour une réservation non groupée. |

Oracle représente les chaînes vides par NULL. `ligne_originale` conserve leur représentation dans le fichier, ainsi que les espaces et les guillemets. Les CSV restent les fichiers d'origine et ne sont pas modifiés.

## USAGER_SOURCE — correspondance entre lignes et personnes

| Champ | Type Oracle | Obligatoire | Description et contraintes |
| --- | --- | --- | --- |
| `id_lot` | `NUMBER(12)` | Oui | Partie de la PK et de la FK composée vers BRUT_USAGER. |
| `numero_ligne` | `NUMBER(12)` | Oui | Partie de la PK et de la FK composée vers BRUT_USAGER. |
| `id_usager` | `NUMBER(12)` | Oui | FK vers `USAGER.id_usager`. Personne correspondant à la ligne source. |

La FK `(id_lot, numero_ligne)` vise `BRUT_USAGER(id_lot, numero_ligne)`. Une ligne ne peut correspondre qu'à une personne, mais plusieurs lignes peuvent pointer vers le même usager. L'égalité des emails et le traitement séparé des lignes sans email doivent être vérifiés lors du rapprochement.
