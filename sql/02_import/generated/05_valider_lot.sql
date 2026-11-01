-- Valider les quatre effectifs dans la transaction avant le seul COMMIT.
DECLARE
    v_id_lot NUMBER;
    v_nombre NUMBER;
    v_min NUMBER;
    v_max NUMBER;
    v_commit_demande BOOLEAN := FALSE;
BEGIN
    SELECT id_lot INTO v_id_lot FROM lot_source WHERE libelle = 'CSV_G08_d3bd9e88655a55744388db29403dbdf157955fce17f85ca8ac9478e21d3ad1d4';
    SELECT COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    INTO v_nombre, v_min, v_max FROM brut_salle WHERE id_lot = v_id_lot;
    IF v_nombre <> 4 OR NVL(v_min, 0) <> 1 OR NVL(v_max, 0) <> 4 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Chargement incomplet : brut_salle.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('BRUT_SALLE : ' || v_nombre || ' lignes contrôlées.');
    SELECT COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    INTO v_nombre, v_min, v_max FROM brut_usager WHERE id_lot = v_id_lot;
    IF v_nombre <> 20467 OR NVL(v_min, 0) <> 1 OR NVL(v_max, 0) <> 20467 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Chargement incomplet : brut_usager.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('BRUT_USAGER : ' || v_nombre || ' lignes contrôlées.');
    SELECT COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    INTO v_nombre, v_min, v_max FROM brut_ressource WHERE id_lot = v_id_lot;
    IF v_nombre <> 28571 OR NVL(v_min, 0) <> 1 OR NVL(v_max, 0) <> 28571 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Chargement incomplet : brut_ressource.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('BRUT_RESSOURCE : ' || v_nombre || ' lignes contrôlées.');
    SELECT COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    INTO v_nombre, v_min, v_max FROM brut_operation WHERE id_lot = v_id_lot;
    IF v_nombre <> 365069 OR NVL(v_min, 0) <> 1 OR NVL(v_max, 0) <> 365069 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Chargement incomplet : brut_operation.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('BRUT_OPERATION : ' || v_nombre || ' lignes contrôlées.');
    v_commit_demande := TRUE;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCES : ID_LOT=' || v_id_lot || ', les quatre fichiers sont validés.');
EXCEPTION
    WHEN OTHERS THEN
        IF v_commit_demande THEN
            DBMS_OUTPUT.PUT_LINE('COMMIT INCERTAIN : vérifier le lot dans une nouvelle connexion.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('CHARGEMENT ANNULE : ' || SQLERRM);
        END IF;
        ROLLBACK;
        RAISE;
END;
/
