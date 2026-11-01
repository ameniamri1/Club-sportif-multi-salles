-- L3 : préparer une comparaison sur des copies, après la fin des requêtes L2.
-- Les tables métier L1, les BRUT_* et les vues L2 restent les références du projet.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET AUTOCOMMIT OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT à copier pour L3 : '
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
@@../02_import/verifier_lot.sql
@@../02_import/verifier_analyse.sql

-- Le script crée des objets : utiliser une connexion sans modification en attente.
-- Un deuxième lancement est refusé ; aucune table existante n'est supprimée.
DECLARE
    v_nombre NUMBER;
BEGIN
    IF DBMS_TRANSACTION.LOCAL_TRANSACTION_ID(FALSE) IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20030, 'Terminer la transaction en cours avant la préparation L3.');
    END IF;
    SELECT COUNT(*) INTO v_nombre FROM user_objects
    WHERE object_name IN ('L3_N_RESSOURCES', 'L3_N_OPERATIONS', 'L3_D_OPERATIONS',
                          'PK_L3_N_RES', 'PK_L3_N_OPE', 'PK_L3_D_OPE');
    IF v_nombre > 0 THEN
        RAISE_APPLICATION_ERROR(-20031, 'Les objets L3 existent déjà : les examiner avant de relancer.');
    END IF;
END;
/

-- Référence normalisée : le site et la catégorie dépendent uniquement de la ressource.
CREATE TABLE l3_n_ressources (
    id_lot NUMBER(12),
    id_cours VARCHAR2(30 CHAR),
    libelle VARCHAR2(200 CHAR) CONSTRAINT nn_l3_nr_lib NOT NULL,
    id_site VARCHAR2(30 CHAR) CONSTRAINT nn_l3_nr_site NOT NULL,
    categorie VARCHAR2(100 CHAR) CONSTRAINT nn_l3_nr_cat NOT NULL,
    debut TIMESTAMP(0) CONSTRAINT nn_l3_nr_debut NOT NULL,
    capacite NUMBER(10) CONSTRAINT nn_l3_nr_cap NOT NULL,
    prix_unitaire NUMBER(14,2) CONSTRAINT nn_l3_nr_prix NOT NULL,
    CONSTRAINT pk_l3_n_res PRIMARY KEY (id_lot, id_cours)
);

CREATE TABLE l3_n_operations (
    id_lot NUMBER(12),
    id_reservation VARCHAR2(30 CHAR),
    cle_personne VARCHAR2(350 CHAR) CONSTRAINT nn_l3_no_pers NOT NULL,
    id_cours VARCHAR2(30 CHAR) CONSTRAINT nn_l3_no_cours NOT NULL,
    date_reservation TIMESTAMP(0) CONSTRAINT nn_l3_no_date NOT NULL,
    nb_places NUMBER(10) CONSTRAINT nn_l3_no_places NOT NULL,
    montant NUMBER(14,2) CONSTRAINT nn_l3_no_montant NOT NULL,
    statut VARCHAR2(9 CHAR) CONSTRAINT nn_l3_no_statut NOT NULL,
    id_groupe VARCHAR2(100 CHAR),
    CONSTRAINT pk_l3_n_ope PRIMARY KEY (id_lot, id_reservation),
    CONSTRAINT fk_l3_no_res FOREIGN KEY (id_lot, id_cours)
        REFERENCES l3_n_ressources (id_lot, id_cours)
);

-- Copie de reporting : le site et la catégorie sont répétés dans chaque réservation.
-- Cette redondance enlève une jointure pour les statistiques par site et catégorie.
CREATE TABLE l3_d_operations (
    id_lot NUMBER(12),
    id_reservation VARCHAR2(30 CHAR),
    cle_personne VARCHAR2(350 CHAR) CONSTRAINT nn_l3_do_pers NOT NULL,
    id_cours VARCHAR2(30 CHAR) CONSTRAINT nn_l3_do_cours NOT NULL,
    date_reservation TIMESTAMP(0) CONSTRAINT nn_l3_do_date NOT NULL,
    nb_places NUMBER(10) CONSTRAINT nn_l3_do_places NOT NULL,
    montant NUMBER(14,2) CONSTRAINT nn_l3_do_montant NOT NULL,
    statut VARCHAR2(9 CHAR) CONSTRAINT nn_l3_do_statut NOT NULL,
    id_groupe VARCHAR2(100 CHAR),
    id_site VARCHAR2(30 CHAR) CONSTRAINT nn_l3_do_site NOT NULL,
    categorie VARCHAR2(100 CHAR) CONSTRAINT nn_l3_do_cat NOT NULL,
    CONSTRAINT pk_l3_d_ope PRIMARY KEY (id_lot, id_reservation)
);

-- Même chargement pour une création initiale et une reprise sur tables vides.
@@copier_donnees_l3.sql
