-- Appelé après la saisie de lot_import dans les scripts L2.
-- Aucun filtrage métier : un montant négatif ne bloque pas ce contrôle de chargement.
DECLARE
    v_lot NUMBER := &&lot_import;
    v_nombre NUMBER;

    PROCEDURE verifier(p_table VARCHAR2, p_attendu NUMBER, p_identifiant VARCHAR2) IS
        v_min NUMBER;
        v_max NUMBER;
        v_vides NUMBER;
        v_doublons NUMBER;
    BEGIN
        -- Les noms d'objets ci-dessous sont des constantes du script.
        EXECUTE IMMEDIATE 'SELECT COUNT(*), MIN(numero_ligne), MAX(numero_ligne), '
            || 'COUNT(CASE WHEN ligne_originale IS NULL OR DBMS_LOB.GETLENGTH(ligne_originale) = 0 THEN 1 END) '
            || 'FROM ' || p_table || ' WHERE id_lot = :lot'
            INTO v_nombre, v_min, v_max, v_vides USING v_lot;
        IF v_nombre <> p_attendu OR NVL(v_min, 0) <> 1 OR NVL(v_max, 0) <> p_attendu OR v_vides > 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Lot incomplet ou texte original absent : ' || p_table);
        END IF;
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (SELECT ' || p_identifiant
            || ' FROM ' || p_table || ' WHERE id_lot = :lot GROUP BY ' || p_identifiant
            || ' HAVING COUNT(*) > 1 OR ' || p_identifiant || ' IS NULL)'
            INTO v_doublons USING v_lot;
        IF v_doublons > 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Identifiant source absent ou répété : ' || p_table
                || '. Conserver les lignes brutes et examiner les doublons avant les jointures.');
        END IF;
        DBMS_OUTPUT.PUT_LINE(p_table || ' : ' || v_nombre || ' lignes, numéros continus, identifiants distincts.');
    END;
BEGIN
    SELECT COUNT(*) INTO v_nombre FROM lot_source WHERE id_lot = v_lot;
    IF v_nombre <> 1 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Le lot demandé est absent.');
    END IF;
    verifier('BRUT_SALLE', 4, 'id_salle');
    verifier('BRUT_USAGER', 20467, 'id_adherent');
    verifier('BRUT_RESSOURCE', 28571, 'id_cours');
    verifier('BRUT_OPERATION', 365069, 'id_reservation');
END;
/
