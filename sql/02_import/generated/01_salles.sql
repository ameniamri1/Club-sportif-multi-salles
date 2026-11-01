-- salles.csv vers BRUT_SALLE ; lancer uniquement charger_tout.sql.

PROMPT DEBUT salles.csv : 4 lignes attendues
-- brut_salle : enregistrements 1 à 4.
DECLARE
    TYPE t_textes IS TABLE OF VARCHAR2(32767);
    TYPE t_numeros IS TABLE OF NUMBER;
    v_id_lot NUMBER;
    v_numeros t_numeros := t_numeros(1, 2, 3, 4);
    v_0 t_textes := t_textes(
        '1,Siège,Paris,siège' || CHR(10),
        '2,Site Villeurbanne,Villeurbanne,site' || CHR(10),
        '3,Site Vénissieux,Vénissieux,site' || CHR(10),
        '4,Site Lyon,Lyon,site' || CHR(10)
    );
    v_1 t_textes := t_textes(
        '1',
        '2',
        '3',
        '4'
    );
    v_2 t_textes := t_textes(
        'Siège',
        'Site Villeurbanne',
        'Site Vénissieux',
        'Site Lyon'
    );
    v_3 t_textes := t_textes(
        'Paris',
        'Villeurbanne',
        'Vénissieux',
        'Lyon'
    );
    v_4 t_textes := t_textes(
        'siège',
        'site',
        'site',
        'site'
    );
    e_rejets EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_rejets, -24381);
BEGIN
    SELECT id_lot INTO v_id_lot FROM lot_source WHERE libelle = 'CSV_G08_d3bd9e88655a55744388db29403dbdf157955fce17f85ca8ac9478e21d3ad1d4';
    FORALL i IN 1 .. 4 SAVE EXCEPTIONS
        INSERT INTO brut_salle (id_lot, numero_ligne, ligne_originale, id_salle, nom, ville, role)
        VALUES (v_id_lot, v_numeros(i), v_0(i), v_1(i), v_2(i), v_3(i), v_4(i));
    IF SQL%ROWCOUNT <> 4 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Nombre de lignes insérées incorrect.');
    END IF;
EXCEPTION
    WHEN e_rejets THEN
        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('REJET brut_salle, numero_ligne=' || (0 + SQL%BULK_EXCEPTIONS(j).ERROR_INDEX)
                || ' : ' || SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
        END LOOP;
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ECHEC brut_salle, bloc 1-4 : ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

PROMPT FIN salles.csv : 4 lignes insérées, en attente du COMMIT final
