# Schéma relationnel — M1-1

Le [diagramme entité-association](schema_entite_association.md) conduit aux relations ci-dessous. Les tables sont définies dans [`create_tables.sql`](../../sql/01_schema/create_tables.sql) et les contraintes PK, FK, UNIQUE et CHECK dans [`constraints.sql`](../../sql/01_schema/constraints.sql).

## Relations métier

Dans la notation ci-dessous, `#` désigne une clé étrangère et `?` un attribut facultatif. Toutes les clés primaires sont obligatoires et uniques. Les identifiants de personne et catégorie sont générés par Oracle ; les autres identifiants métier viennent du jeu source.

```text
SITE(
    id_site PK, nom, ville, type_site
)

CATEGORIE(
    id_categorie PK, libelle UNIQUE
)

USAGER(
    id_usager PK, nom?, prenom?, email_normalise? UNIQUE,
    telephone?, ville?, date_inscription?,
    #id_site_rattachement, #id_parrain?
)

RESSOURCE(
    id_ressource PK, libelle, #id_categorie, #id_site,
    debut, duree_minutes, capacite, prix_unitaire
)

GROUPE_OPERATION(
    id_groupe PK
)

OPERATION(
    id_operation PK, #id_usager, #id_ressource,
    date_execution, nb_places, montant, statut, #id_groupe?
)
```

| FK | Cible | Facultative ? |
| --- | --- | --- |
| `USAGER.id_site_rattachement` | `SITE.id_site` | Non |
| `USAGER.id_parrain` | `USAGER.id_usager` | Oui |
| `RESSOURCE.id_categorie` | `CATEGORIE.id_categorie` | Non |
| `RESSOURCE.id_site` | `SITE.id_site` | Non |
| `OPERATION.id_usager` | `USAGER.id_usager` | Non |
| `OPERATION.id_ressource` | `RESSOURCE.id_ressource` | Non |
| `OPERATION.id_groupe` | `GROUPE_OPERATION.id_groupe` | Oui |

Nous laissons les coordonnées et les informations descriptives de l'usager facultatives : une réservation doit pouvoir être conservée même si une information personnelle manque. Le site de rattachement reste obligatoire, conformément à H05. Les valeurs d'origine se trouvent dans `BRUT_USAGER`.

## Types et domaines

| Attributs | Type Oracle retenu | Motif |
| --- | --- | --- |
| Identifiants numériques | `NUMBER(12)` | Entiers ; marge au-delà des identifiants du jeu fourni |
| `id_groupe` métier | `VARCHAR2(100 CHAR)` | Identifiant opaque, sans supposer qu'il soit numérique |
| Noms, prénoms, villes et catégorie | `VARCHAR2(100 CHAR)` | Texte, accents compris ; les longueurs observées tiennent dans ces limites |
| Libellé de ressource | `VARCHAR2(200 CHAR)` | Description d'une séance |
| Email normalisé | `VARCHAR2(320 CHAR)` | Facultatif, unique lorsqu'il est renseigné |
| Téléphone | `VARCHAR2(32 CHAR)` | Conservation du zéro initial ; aucun calcul numérique |
| Date d'inscription | `DATE` | Date source sans heure significative |
| Début et date d'exécution | `TIMESTAMP(0)` | Dates et heures à la seconde, sans fuseau |
| Durée | `NUMBER(6)` | Nombre entier de minutes, strictement positif |
| Capacité et nombre de places | `NUMBER(10)` | Entiers strictement positifs |
| Prix et montant | `NUMBER(14,2)` | Valeurs décimales exactes, positives ou nulles dans le modèle métier |
| Type de site | `VARCHAR2(5 CHAR)` | `SIEGE` ou `SITE` |
| Statut | `VARCHAR2(9 CHAR)` | `CONFIRMEE` ou `ANNULEE` |

Les tailles choisies couvrent les valeurs présentes dans les fichiers. Si une donnée dépasse ces limites au chargement, elle doit être signalée et rester disponible dans la table brute. Cela vaut aussi pour un montant comportant plus de deux décimales, qui ne doit pas être arrondi sans trace.

L'email est stocké en minuscules et sans espaces dans USAGER. Cette transformation doit être faite avant la recherche ou la création d'une personne. La contrainte `ck_usager_email` vérifie le format obtenu, sans transformer la valeur. L'adresse d'origine reste dans BRUT_USAGER.

La contrainte `uq_usager_email` empêche de créer deux personnes avec le même email normalisé. Elle accepte plusieurs valeurs NULL, ce qui permet de garder des personnes distinctes lorsqu'elles n'ont pas d'email. Lors du rapprochement, il faudra aussi vérifier les correspondances : même email vers une même personne, absence d'email vers une personne propre à chaque ligne.

## Tables des données brutes

```text
LOT_SOURCE(
    id_lot PK, libelle, date_creation
)

BRUT_SALLE(
    #id_lot PK, numero_ligne PK, ligne_originale,
    id_salle?, nom?, ville?, role?
)

BRUT_USAGER(
    #id_lot PK, numero_ligne PK, ligne_originale,
    id_adherent?, nom?, prenom?, email?, telephone?, ville?,
    id_salle?, date_inscription?
)

BRUT_RESSOURCE(
    #id_lot PK, numero_ligne PK, ligne_originale,
    id_cours?, libelle?, categorie?, id_salle?, debut?,
    duree_minutes?, capacite?, prix_unitaire?
)

BRUT_OPERATION(
    #id_lot PK, numero_ligne PK, ligne_originale,
    id_reservation?, id_adherent?, id_cours?, date_reservation?,
    nb_places?, montant?, statut?, id_groupe?
)

USAGER_SOURCE(
    #id_lot PK, #numero_ligne PK, #id_usager
)
```

Chaque table `BRUT_*` a une PK composée `(id_lot, numero_ligne)`, une FK vers `LOT_SOURCE` et un contrôle `numero_ligne > 0`. Le numéro identifie l'enregistrement CSV hors en-tête dans le fichier concerné. Toutes les colonnes issues du CSV sont de type `VARCHAR2(4000 BYTE)` et facultatives ; aucune n'est utilisée comme FK ou contrainte unique métier. Cette limite couvre les valeurs des fichiers inspectés. `ligne_originale`, un `CLOB` obligatoire, garde le texte de l'enregistrement tel qu'il a été lu.

Oracle assimile une chaîne vide à `NULL`. Le texte original permet donc de retrouver la représentation source d'un champ vide, les espaces et les guillemets. Les fichiers CSV eux-mêmes restent la référence originale ; aucune conversion n'est écrite dans ces fichiers.

`LOT_SOURCE.id_lot` est généré par Oracle. Son libellé est obligatoire, et `date_creation` est une date technique initialisée à l'heure locale de la session. Un lot doit correspondre aux quatre fichiers d'une même livraison ; leur complétude devra être vérifiée au chargement.

`USAGER_SOURCE` a une FK composée vers `BRUT_USAGER(id_lot, numero_ligne)` et une FK vers `USAGER(id_usager)`. Une ligne source ne peut correspondre qu'à une personne, tandis qu'une personne peut être liée à plusieurs lignes sources. `id_adherent` se retrouve dans `BRUT_USAGER` ; le recopier dans la correspondance serait redondant. Les réservations sources retrouveront ainsi la personne par leur identifiant d'adhérent dans le lot concerné.

## Contraintes et contrôles complémentaires

Les contraintes PK, FK, UNIQUE, CHECK et les déclarations explicites NOT NULL ont un nom dans le script. Les PK rendent également leurs colonnes non nulles. Les FK utilisent le comportement Oracle par défaut : une suppression de parent encore référencé est refusée.

La FK vers RESSOURCE garantit que le cours existe, et `ck_operation_montant` impose un montant positif ou nul. La comparaison des dates demande un contrôle supplémentaire : un CHECK Oracle ne peut pas consulter une autre table. Il faudra donc comparer `OPERATION.date_execution` à `RESSOURCE.debut` lors de l'admission d'une réservation, puis refaire ce contrôle si l'une de ces dates change. Le [tableau de traçabilité](tracabilite_regles.md) précise les règles concernées.

La capacité ne bloque pas la conservation des réservations historiques. Une sur-réservation reste compatible avec RG13 lorsque le cours existe, que le montant est positif ou nul et que la date est correcte. Le contrôle des places disponibles pour une nouvelle réservation devra être traité dans la procédure transactionnelle.

## Normalisation

Les attributs descriptifs de chaque table métier dépendent de sa clé. Le libellé d'une catégorie reste dans `CATEGORIE`, les informations du site dans `SITE`, et les informations personnelles dans `USAGER`. OPERATION ne recopie ni le site du cours, ni sa catégorie, ni les coordonnées de l'usager. La date, les places, le montant et le statut dépendent de l'identifiant de l'opération, pas du seul couple usager/ressource.

Cette répartition suit les principes de la troisième forme normale : chaque information métier est placée dans la table dont elle dépend. L'email reste une information facultative et ne remplace pas l'identifiant de l'usager. Les tables brutes servent à garder les fichiers et leurs anomalies ; elles ne sont pas utilisées comme modèle métier normalisé.

## Compatibilité et exécution

Nous retenons Oracle Database 19c ou une version ultérieure. Ce choix correspond aux fonctionnalités utilisées dans le cours : packages, sécurité par ligne, audit unifié et liens entre schémas. La version exacte du kit reste à confirmer.

Les scripts utilisent les types Oracle `NUMBER`, `VARCHAR2`, `TIMESTAMP` et `CLOB`. Les identifiants internes sont générés avec `GENERATED ALWAYS AS IDENTITY`. Les références techniques sont la documentation Oracle sur [CREATE TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLE.html) et les [contraintes](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/constraint.html).

Les deux scripts se lancent dans cet ordre, dans un schéma vide disposant du privilège `CREATE TABLE` et d'un quota de tablespace. Depuis la racine du dépôt, dans SQLcl ou SQL*Plus :

```text
@sql/01_schema/create_tables.sql
@sql/01_schema/constraints.sql
```

`create_tables.sql` crée les tables et leurs contraintes NOT NULL. `constraints.sql` ajoute les clés et les contrôles de domaine. Les scripts ne suppriment pas les objets existants et ne doivent être exécutés qu'une fois dans le schéma vide.

Les captures prises sur la connexion « Projet Multisite » montrent les objets créés et l'état des contraintes :

| Capture | Résultat visible |
| --- | --- |
| [A01 — Tables](../../preuves/A01_tables.png) | Les 12 tables du modèle sont présentes dans `USER_TABLES`. |
| [A02 — Contraintes](../../preuves/A02_contraintes.png) | `USER_CONSTRAINTS` contient 12 PK, 13 FK, 2 contraintes UNIQUE et 41 contraintes de type C, qui comprennent les CHECK et les NOT NULL. |
| [A03 — Validation des contraintes](../../preuves/A03_validation_contraintes.png) | La recherche des contraintes désactivées ou non validées ne renvoie aucune ligne. |

Ces captures confirment la présence et l'activation des contraintes. Les règles qui nécessitent un traitement entre tables restent celles indiquées dans le [tableau de traçabilité](tracabilite_regles.md).
