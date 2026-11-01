-- Exécuter dans un schéma vide, puis lancer constraints.sql.

-- Un lot représente les quatre fichiers sources d'une même livraison.
CREATE TABLE lot_source (
    id_lot NUMBER(12) GENERATED ALWAYS AS IDENTITY,
    libelle VARCHAR2(255 CHAR) CONSTRAINT nn_lot_libelle NOT NULL,
    date_creation TIMESTAMP(0) DEFAULT LOCALTIMESTAMP
        CONSTRAINT nn_lot_date NOT NULL
);

-- Les valeurs sources restent en texte ; ligne_originale conserve l'enregistrement.
CREATE TABLE brut_salle (
    id_lot NUMBER(12),
    numero_ligne NUMBER(12),
    ligne_originale CLOB CONSTRAINT nn_bs_ligne NOT NULL,
    id_salle VARCHAR2(4000 BYTE),
    nom VARCHAR2(4000 BYTE),
    ville VARCHAR2(4000 BYTE),
    role VARCHAR2(4000 BYTE)
);

-- RG15-RG16 : conserver les lignes d'adhérents avant le rapprochement par email.
CREATE TABLE brut_usager (
    id_lot NUMBER(12),
    numero_ligne NUMBER(12),
    ligne_originale CLOB CONSTRAINT nn_bu_ligne NOT NULL,
    id_adherent VARCHAR2(4000 BYTE),
    nom VARCHAR2(4000 BYTE),
    prenom VARCHAR2(4000 BYTE),
    email VARCHAR2(4000 BYTE),
    telephone VARCHAR2(4000 BYTE),
    ville VARCHAR2(4000 BYTE),
    id_salle VARCHAR2(4000 BYTE),
    date_inscription VARCHAR2(4000 BYTE)
);

CREATE TABLE brut_ressource (
    id_lot NUMBER(12),
    numero_ligne NUMBER(12),
    ligne_originale CLOB CONSTRAINT nn_br_ligne NOT NULL,
    id_cours VARCHAR2(4000 BYTE),
    libelle VARCHAR2(4000 BYTE),
    categorie VARCHAR2(4000 BYTE),
    id_salle VARCHAR2(4000 BYTE),
    debut VARCHAR2(4000 BYTE),
    duree_minutes VARCHAR2(4000 BYTE),
    capacite VARCHAR2(4000 BYTE),
    prix_unitaire VARCHAR2(4000 BYTE)
);

-- RG08 : id_cours reste libre pour conserver les références aux cours absents.
-- RG13 : garder aussi les montants négatifs et les dates de réservation incorrectes.
CREATE TABLE brut_operation (
    id_lot NUMBER(12),
    numero_ligne NUMBER(12),
    ligne_originale CLOB CONSTRAINT nn_bo_ligne NOT NULL,
    id_reservation VARCHAR2(4000 BYTE),
    id_adherent VARCHAR2(4000 BYTE),
    id_cours VARCHAR2(4000 BYTE),
    date_reservation VARCHAR2(4000 BYTE),
    nb_places VARCHAR2(4000 BYTE),
    montant VARCHAR2(4000 BYTE),
    statut VARCHAR2(4000 BYTE),
    id_groupe VARCHAR2(4000 BYTE)
);

-- RG01 : type_site distingue le siège des salles du club.
CREATE TABLE site (
    id_site NUMBER(12),
    nom VARCHAR2(100 CHAR) CONSTRAINT nn_site_nom NOT NULL,
    ville VARCHAR2(100 CHAR) CONSTRAINT nn_site_ville NOT NULL,
    type_site VARCHAR2(5 CHAR) CONSTRAINT nn_site_type NOT NULL
);

-- RG04 : chaque catégorie possède un identifiant utilisé par les ressources.
CREATE TABLE categorie (
    id_categorie NUMBER(12) GENERATED ALWAYS AS IDENTITY,
    libelle VARCHAR2(100 CHAR) CONSTRAINT nn_cat_libelle NOT NULL
);

-- RG15-RG16 : une personne a son propre identifiant, indépendant de l'email.
CREATE TABLE usager (
    id_usager NUMBER(12) GENERATED ALWAYS AS IDENTITY,
    nom VARCHAR2(100 CHAR),
    prenom VARCHAR2(100 CHAR),
    -- RG16 : l'email est facultatif pour représenter les personnes sans adresse.
    email_normalise VARCHAR2(320 CHAR),
    telephone VARCHAR2(32 CHAR),
    ville VARCHAR2(100 CHAR),
    date_inscription DATE,
    id_site_rattachement NUMBER(12) CONSTRAINT nn_usa_site NOT NULL,
    -- RG21 : une seule colonne facultative donne au plus un parrain par usager.
    id_parrain NUMBER(12)
);

-- RG15-RG16 : relier chaque ligne source à la personne issue du rapprochement.
CREATE TABLE usager_source (
    id_lot NUMBER(12),
    numero_ligne NUMBER(12),
    id_usager NUMBER(12) CONSTRAINT nn_us_source_usager NOT NULL
);

CREATE TABLE ressource (
    id_ressource NUMBER(12),
    libelle VARCHAR2(200 CHAR) CONSTRAINT nn_res_libelle NOT NULL,
    -- RG04 : la catégorie est obligatoire ; la FK est dans constraints.sql.
    id_categorie NUMBER(12) CONSTRAINT nn_res_categorie NOT NULL,
    -- RG02 : chaque ressource possède une seule référence de site, obligatoire.
    id_site NUMBER(12) CONSTRAINT nn_res_site NOT NULL,
    -- RG06 : chaque séance possède une date et une heure de début.
    debut TIMESTAMP(0) CONSTRAINT nn_res_debut NOT NULL,
    duree_minutes NUMBER(6) CONSTRAINT nn_res_duree NOT NULL,
    -- RG05 : la capacité est un nombre entier de places, obligatoire.
    capacite NUMBER(10) CONSTRAINT nn_res_capacite NOT NULL,
    prix_unitaire NUMBER(14,2) CONSTRAINT nn_res_prix NOT NULL
);

-- RG18 : un identifiant de groupe peut être partagé par plusieurs opérations.
CREATE TABLE groupe_operation (
    id_groupe VARCHAR2(100 CHAR)
);

-- RG14-RG17 : le site se retrouve par la ressource ; aucune égalité n'est imposée
-- avec le site de rattachement de l'usager.
CREATE TABLE operation (
    -- RG22 : l'unicité de l'identifiant est définie par pk_operation.
    id_operation NUMBER(12),
    -- RG07 : une opération est obligatoirement associée à un usager.
    id_usager NUMBER(12) CONSTRAINT nn_ope_usager NOT NULL,
    -- RG08 : la référence à une ressource est obligatoire dans le modèle métier.
    id_ressource NUMBER(12) CONSTRAINT nn_ope_ressource NOT NULL,
    -- RG09 : la date d'exécution est obligatoire.
    date_execution TIMESTAMP(0) CONSTRAINT nn_ope_date NOT NULL,
    -- RG11-RG23 : le nombre de places est entier et obligatoire ; CHECK > 0 à part.
    nb_places NUMBER(10) CONSTRAINT nn_ope_places NOT NULL,
    -- RG10 : chaque opération possède un montant.
    montant NUMBER(14,2) CONSTRAINT nn_ope_montant NOT NULL,
    statut VARCHAR2(9 CHAR) CONSTRAINT nn_ope_statut NOT NULL,
    -- RG24 : une référence facultative permet zéro ou un groupe par opération.
    id_groupe VARCHAR2(100 CHAR)
);
