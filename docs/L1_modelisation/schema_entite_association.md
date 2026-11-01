# Schéma entité-association — M1-1

Le modèle s'organise autour des adhérents, des séances de cours et des réservations, nommés USAGER, RESSOURCE et OPERATION. Une réservation relie un adhérent à une séance ; elle peut aussi faire partie d'un groupe. Les [règles de gestion](regles_gestion.md) précisent les choix retenus.

## Modèle métier

```mermaid
erDiagram
    SITE ||--o{ USAGER : "rattache administrativement"
    SITE ||--o{ RESSOURCE : "accueille"
    CATEGORIE ||--o{ RESSOURCE : "classe"
    USAGER ||--o{ OPERATION : "effectue"
    RESSOURCE ||--o{ OPERATION : "concerne"
    GROUPE_OPERATION o|--o{ OPERATION : "regroupe"
    USAGER o|--o{ USAGER : "parrain vers filleul"

    SITE {
        number id_site PK
        string nom
        string ville
        string type_site
    }
    CATEGORIE {
        number id_categorie PK
        string libelle UK
    }
    USAGER {
        number id_usager PK
        string nom
        string prenom
        string email_normalise UK "facultatif"
        string telephone
        string ville
        date date_inscription
        number id_site_rattachement FK
        number id_parrain FK "facultatif"
    }
    RESSOURCE {
        number id_ressource PK
        string libelle
        number id_categorie FK
        number id_site FK
        timestamp debut
        number duree_minutes
        number capacite
        decimal prix_unitaire
    }
    GROUPE_OPERATION {
        string id_groupe PK
    }
    OPERATION {
        number id_operation PK
        number id_usager FK
        number id_ressource FK
        timestamp date_execution
        number nb_places
        decimal montant
        string statut
        string id_groupe FK "facultatif"
    }
```

Pour lire le diagramme : `||` signifie exactement un, `o|` zéro ou un et `o{` zéro à plusieurs. Un adhérent peut n'avoir encore aucune réservation, et une séance peut n'avoir aucun inscrit. Le siège peut également exister sans accueillir de cours.

OPERATION est l'association porteuse d'attributs entre USAGER et RESSOURCE. Elle contient la date de réservation, les places, le montant et le statut. Nous lui donnons son propre identifiant, car un adhérent peut effectuer plusieurs réservations pour la même séance.

L'association réflexive se lit du parrain vers ses filleuls : un adhérent peut parrainer plusieurs personnes, mais chaque filleul a au maximum un parrain. Le champ facultatif `USAGER.id_parrain` représente ce lien. La condition `id_parrain <> id_usager` empêche un adhérent de se parrainer lui-même. Les données fournies ne renseignent aucun parrainage.

## Lien avec les données brutes

Une personne peut apparaître sur plusieurs lignes du fichier des adhérents. Nous gardons ces lignes séparées dans BRUT_USAGER et les relions à une même personne avec USAGER_SOURCE. Les autres fichiers sont conservés de la même manière dans leurs tables brutes.

```mermaid
erDiagram
    LOT_SOURCE ||--o{ BRUT_SALLE : "contient"
    LOT_SOURCE ||--o{ BRUT_USAGER : "contient"
    LOT_SOURCE ||--o{ BRUT_RESSOURCE : "contient"
    LOT_SOURCE ||--o{ BRUT_OPERATION : "contient"
    BRUT_USAGER ||--o| USAGER_SOURCE : "est rapproche"
    USAGER ||--o{ USAGER_SOURCE : "provient de"

    LOT_SOURCE {
        number id_lot PK
        string libelle
        timestamp date_creation
    }
    BRUT_SALLE {
        number id_lot PK, FK
        number numero_ligne PK
        clob ligne_originale
        string id_salle
        string nom
        string ville
        string role
    }
    BRUT_USAGER {
        number id_lot PK, FK
        number numero_ligne PK
        clob ligne_originale
        string id_adherent
        string nom
        string prenom
        string email
        string telephone
        string ville
        string id_salle
        string date_inscription
    }
    BRUT_RESSOURCE {
        number id_lot PK, FK
        number numero_ligne PK
        clob ligne_originale
        string id_cours
        string libelle
        string categorie
        string id_salle
        string debut
        string duree_minutes
        string capacite
        string prix_unitaire
    }
    BRUT_OPERATION {
        number id_lot PK, FK
        number numero_ligne PK
        clob ligne_originale
        string id_reservation
        string id_adherent
        string id_cours
        string date_reservation
        string nb_places
        string montant
        string statut
        string id_groupe
    }
    USAGER_SOURCE {
        number id_lot PK, FK
        number numero_ligne PK, FK
        number id_usager FK
    }
    USAGER {
        number id_usager PK
    }
```

Dans chaque table brute, une ligne est identifiée par son lot et son numéro dans le fichier. La référence `BRUT_OPERATION.id_cours` reste libre : elle doit pouvoir contenir l'identifiant d'un cours absent. Dans le modèle métier, en revanche, chaque opération est obligatoirement liée à une ressource existante.

USAGER_SOURCE relie les lignes d'adhérent traitées aux personnes correspondantes. Les lignes ayant le même email normalisé sont rattachées au même usager. Une ligne sans email donne lieu à une personne distincte. Tant qu'une ligne n'est pas traitée, elle peut rester sans correspondance.

Le site d'une réservation se retrouve par le cours. La validité, le caractère multisite d'un groupe et la sur-réservation se calculent à partir des données ; aucun champ supplémentaire ne les stocke.
