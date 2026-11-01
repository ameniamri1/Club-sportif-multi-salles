-- Appelé par les scripts de création et de reprise ; lot_import doit être défini.
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE
    v_lot NUMBER := &&lot_import;
    v_attendu NUMBER;
    v_normalise NUMBER;
    v_denormalise NUMBER;
    v_ecarts NUMBER;
BEGIN
    -- Les lecteurs restent autorisés. Une écriture concurrente fait échouer NOWAIT.
    LOCK TABLE brut_salle, brut_usager, brut_ressource, brut_operation IN SHARE MODE NOWAIT;
    LOCK TABLE l3_n_ressources, l3_n_operations, l3_d_operations IN EXCLUSIVE MODE NOWAIT;

    SELECT (SELECT COUNT(*) FROM l3_n_ressources)
         + (SELECT COUNT(*) FROM l3_n_operations)
         + (SELECT COUNT(*) FROM l3_d_operations)
    INTO v_ecarts FROM dual;
    IF v_ecarts <> 0 THEN
        RAISE_APPLICATION_ERROR(-20034, 'Les copies L3 ne sont pas vides : aucune reprise automatique.');
    END IF;

    INSERT INTO l3_n_ressources
        (id_lot, id_cours, libelle, id_site, categorie, debut, capacite, prix_unitaire)
    SELECT id_lot, id_cours, libelle, id_salle, categorie, debut, capacite, prix_unitaire
    FROM v_ressources_source WHERE id_lot = v_lot;

    INSERT INTO l3_n_operations
        (id_lot, id_reservation, cle_personne, id_cours, date_reservation, nb_places, montant, statut, id_groupe)
    SELECT id_lot, id_reservation, cle_personne, id_cours, date_reservation, nb_places, montant, statut, id_groupe
    FROM v_operations_valides WHERE id_lot = v_lot;

    INSERT INTO l3_d_operations
        (id_lot, id_reservation, cle_personne, id_cours, date_reservation, nb_places, montant,
         statut, id_groupe, id_site, categorie)
    SELECT o.id_lot, o.id_reservation, o.cle_personne, o.id_cours, o.date_reservation,
           o.nb_places, o.montant, o.statut, o.id_groupe, r.id_site, r.categorie
    FROM l3_n_operations o
    JOIN l3_n_ressources r ON r.id_lot = o.id_lot AND r.id_cours = o.id_cours
    WHERE o.id_lot = v_lot;

    SELECT COUNT(*) INTO v_attendu FROM v_operations_valides WHERE id_lot = v_lot;
    SELECT COUNT(*) INTO v_normalise FROM l3_n_operations WHERE id_lot = v_lot;
    SELECT COUNT(*) INTO v_denormalise FROM l3_d_operations WHERE id_lot = v_lot;
    IF v_normalise <> v_attendu OR v_denormalise <> v_attendu THEN
        RAISE_APPLICATION_ERROR(-20032, 'La copie L3 a perdu ou multiplié des opérations.');
    END IF;

    -- Comparaison dans les deux sens, sur toutes les colonnes et pas seulement les totaux.
    WITH reference AS (
        SELECT o.id_lot, o.id_reservation, o.cle_personne, o.id_cours, o.date_reservation,
               o.nb_places, o.montant, o.statut, o.id_groupe, r.id_site, r.categorie
        FROM l3_n_operations o JOIN l3_n_ressources r
            ON r.id_lot = o.id_lot AND r.id_cours = o.id_cours
        WHERE o.id_lot = v_lot
    ), copie AS (
        SELECT id_lot, id_reservation, cle_personne, id_cours, date_reservation,
               nb_places, montant, statut, id_groupe, id_site, categorie
        FROM l3_d_operations WHERE id_lot = v_lot
    )
    SELECT COUNT(*) INTO v_ecarts FROM (
        SELECT * FROM (SELECT * FROM reference MINUS SELECT * FROM copie)
        UNION ALL
        SELECT * FROM (SELECT * FROM copie MINUS SELECT * FROM reference)
    );
    IF v_ecarts > 0 THEN
        RAISE_APPLICATION_ERROR(-20033, 'Les copies normalisée et dénormalisée diffèrent.');
    END IF;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Copies L3 créées pour le lot ' || v_lot || ' : '
        || v_attendu || ' opérations dans chaque version, aucun écart de contenu.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Copie annulée. Les tables créées par DDL restent présentes : ' || SQLERRM);
        RAISE;
END;
/

-- Statistiques calculées uniquement sur les trois copies L3.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'L3_N_RESSOURCES', estimate_percent => 100,
        method_opt => 'FOR ALL COLUMNS SIZE 1', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'L3_N_OPERATIONS', estimate_percent => 100,
        method_opt => 'FOR ALL COLUMNS SIZE 1', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'L3_D_OPERATIONS', estimate_percent => 100,
        method_opt => 'FOR ALL COLUMNS SIZE 1', cascade => TRUE);
END;
/

UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
