-- Créer un lot unique pour ces quatre fichiers, sans modifier les lots existants.
DECLARE
    v_charset VARCHAR2(100);
    v_nombre NUMBER;
    v_id_lot NUMBER;
    v_transaction BOOLEAN := FALSE;
BEGIN
    IF DBMS_TRANSACTION.LOCAL_TRANSACTION_ID(FALSE) IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Utiliser une connexion sans transaction en cours.');
    END IF;
    SELECT value INTO v_charset FROM nls_database_parameters
    WHERE parameter = 'NLS_CHARACTERSET';
    IF v_charset <> 'AL32UTF8' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Une base AL32UTF8 est requise pour préserver les fichiers UTF-8.');
    END IF;
    v_transaction := TRUE;
    LOCK TABLE lot_source IN EXCLUSIVE MODE NOWAIT;
    SELECT COUNT(*) INTO v_nombre FROM lot_source WHERE libelle = 'CSV_G08_d3bd9e88655a55744388db29403dbdf157955fce17f85ca8ac9478e21d3ad1d4';
    IF v_nombre <> 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Ces fichiers possèdent déjà un lot : vérifier ce lot avant tout relancement.');
    END IF;
    INSERT INTO lot_source (libelle) VALUES ('CSV_G08_d3bd9e88655a55744388db29403dbdf157955fce17f85ca8ac9478e21d3ad1d4')
    RETURNING id_lot INTO v_id_lot;
    DBMS_OUTPUT.PUT_LINE('DEBUT : ID_LOT=' || v_id_lot);
EXCEPTION
    WHEN OTHERS THEN
        IF v_transaction THEN ROLLBACK; END IF;
        DBMS_OUTPUT.PUT_LINE('INITIALISATION REFUSEE : ' || SQLERRM);
        RAISE;
END;
/
