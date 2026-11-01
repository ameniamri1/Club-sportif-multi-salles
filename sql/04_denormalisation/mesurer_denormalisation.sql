-- À lancer lorsque les requêtes L2 sont terminées et les copies L3 sont créées.
-- Lecture seule des copies : aucun index ou paramètre global n'est modifié.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT des copies L3 : '
ACCEPT nombre_series NUMBER DEFAULT 30 PROMPT 'Nombre de séries de cinq passages [30] : '

DECLARE
    v_lot NUMBER := &&lot_import;
    v_series NUMBER := &&nombre_series;
    TYPE t_textes IS TABLE OF VARCHAR2(100);
    TYPE t_nombres IS TABLE OF NUMBER;
    v_sites t_textes;
    v_categories t_textes;
    v_reservations t_nombres;
    v_annulations t_nombres;
    v_taux t_nombres;
    v_avant t_nombres := t_nombres();
    v_apres t_nombres := t_nombres();
    v_tous_avant t_nombres := t_nombres();
    v_tous_apres t_nombres := t_nombres();
    v_medianes_avant t_nombres := t_nombres();
    v_medianes_apres t_nombres := t_nombres();
    v_gagnes PLS_INTEGER := 0;
    v_egaux PLS_INTEGER := 0;
    v_index PLS_INTEGER;
    v_nombre NUMBER;
    v_ecarts NUMBER;
    v_sql_avant VARCHAR2(4000) := 'SELECT /*+ gather_plan_statistics */ /* L3_NORMALISE */ '
        || 'r.id_site, r.categorie, COUNT(*), '
        || 'SUM(CASE WHEN o.statut = ''ANNULEE'' THEN 1 ELSE 0 END), '
        || 'ROUND(100 * SUM(CASE WHEN o.statut = ''ANNULEE'' THEN 1 ELSE 0 END) / COUNT(*), 2) '
        || 'FROM l3_n_operations o JOIN l3_n_ressources r '
        || 'ON r.id_lot = o.id_lot AND r.id_cours = o.id_cours '
        || 'WHERE o.id_lot = :lot GROUP BY r.id_site, r.categorie ORDER BY r.id_site, r.categorie';
    v_sql_apres VARCHAR2(4000) := 'SELECT /*+ gather_plan_statistics */ /* L3_DENORMALISE */ '
        || 'o.id_site, o.categorie, COUNT(*), '
        || 'SUM(CASE WHEN o.statut = ''ANNULEE'' THEN 1 ELSE 0 END), '
        || 'ROUND(100 * SUM(CASE WHEN o.statut = ''ANNULEE'' THEN 1 ELSE 0 END) / COUNT(*), 2) '
        || 'FROM l3_d_operations o WHERE o.id_lot = :lot '
        || 'GROUP BY o.id_site, o.categorie ORDER BY o.id_site, o.categorie';

    FUNCTION mesurer(p_sql VARCHAR2) RETURN NUMBER IS
        v_debut NUMBER;
    BEGIN
        v_debut := DBMS_UTILITY.GET_TIME;
        -- Tous les résultats sont lus ; le temps d'affichage SQL Developer est exclu.
        EXECUTE IMMEDIATE p_sql BULK COLLECT
            INTO v_sites, v_categories, v_reservations, v_annulations, v_taux USING v_lot;
        RETURN (DBMS_UTILITY.GET_TIME - v_debut) / 100;
    END;

    FUNCTION mediane(p_valeurs t_nombres) RETURN NUMBER IS
        v_trie t_nombres := p_valeurs;
        v_tmp NUMBER;
    BEGIN
        FOR i IN 1 .. v_trie.COUNT LOOP
            FOR j IN i + 1 .. v_trie.COUNT LOOP
                IF v_trie(i) > v_trie(j) THEN
                    v_tmp := v_trie(i); v_trie(i) := v_trie(j); v_trie(j) := v_tmp;
                END IF;
            END LOOP;
        END LOOP;
        IF MOD(v_trie.COUNT, 2) = 1 THEN
            RETURN v_trie((v_trie.COUNT + 1) / 2);
        END IF;
        RETURN (v_trie(v_trie.COUNT / 2) + v_trie(v_trie.COUNT / 2 + 1)) / 2;
    END;

    PROCEDURE afficher_plan(p_sql VARCHAR2, p_nom VARCHAR2) IS
        v_sql_id VARCHAR2(13);
        v_enfant NUMBER;
    BEGIN
        -- L'identifiant explicite évite de récupérer le plan d'une requête interne du client.
        EXECUTE IMMEDIATE
            'SELECT sql_id, child_number FROM (SELECT sql_id, child_number FROM v$sql '
            || 'WHERE sql_text = :texte AND parsing_schema_name = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'') '
            || 'ORDER BY last_active_time DESC, child_number DESC) WHERE ROWNUM = 1'
            INTO v_sql_id, v_enfant USING p_sql;
        DBMS_OUTPUT.PUT_LINE('PLAN ' || p_nom || ', SQL_ID=' || v_sql_id);
        FOR ligne IN (
            SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
                v_sql_id, v_enfant, 'ALLSTATS LAST +IOSTATS'))
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(ligne.plan_table_output);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Plan ' || p_nom || ' indisponible : ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('Conserver les temps ; les lectures de blocs restent à mesurer avec les droits nécessaires.');
    END;
BEGIN
    IF v_series IS NULL OR v_series <> TRUNC(v_series) OR v_series < 1 OR v_series > 1000 THEN
        RAISE_APPLICATION_ERROR(-20043, 'Choisir un nombre entier de séries entre 1 et 1000.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Début des mesures : ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
        || ' ; lot=' || v_lot || ' ; séries=' || v_series || ' ; cinq passages par série.');
    SELECT COUNT(*) INTO v_nombre FROM l3_n_operations WHERE id_lot = v_lot;
    IF v_nombre = 0 THEN
        RAISE_APPLICATION_ERROR(-20040, 'Aucune copie normalisée pour ce lot.');
    END IF;
    SELECT COUNT(*) INTO v_ecarts FROM l3_d_operations WHERE id_lot = v_lot;
    IF v_ecarts <> v_nombre THEN
        RAISE_APPLICATION_ERROR(-20041, 'Les deux versions ne contiennent pas le même nombre de lignes.');
    END IF;

    -- Vérifier l'égalité des résultats de la requête avant de comparer ses temps.
    WITH normalise AS (
        SELECT r.id_site, r.categorie, COUNT(*) AS reservations,
               SUM(CASE WHEN o.statut = 'ANNULEE' THEN 1 ELSE 0 END) AS annulations
        FROM l3_n_operations o JOIN l3_n_ressources r
            ON r.id_lot = o.id_lot AND r.id_cours = o.id_cours
        WHERE o.id_lot = v_lot GROUP BY r.id_site, r.categorie
    ), denormalise AS (
        SELECT id_site, categorie, COUNT(*) AS reservations,
               SUM(CASE WHEN statut = 'ANNULEE' THEN 1 ELSE 0 END) AS annulations
        FROM l3_d_operations WHERE id_lot = v_lot GROUP BY id_site, categorie
    )
    SELECT COUNT(*) INTO v_ecarts FROM (
        SELECT * FROM (SELECT * FROM normalise MINUS SELECT * FROM denormalise)
        UNION ALL
        SELECT * FROM (SELECT * FROM denormalise MINUS SELECT * FROM normalise)
    );
    IF v_ecarts > 0 THEN
        RAISE_APPLICATION_ERROR(-20042, 'Résultats différents : comparaison des temps refusée.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Résultats identiques pour la requête Q06 adaptée aux copies L3.');

    FOR serie IN 1 .. v_series LOOP
      v_avant := t_nombres();
      v_apres := t_nombres();
      IF MOD(serie, 2) = 1 THEN
          v_nombre := mesurer(v_sql_avant);
          v_nombre := mesurer(v_sql_apres);
      ELSE
          v_nombre := mesurer(v_sql_apres);
          v_nombre := mesurer(v_sql_avant);
      END IF;
      DBMS_OUTPUT.PUT_LINE('Série ' || serie || ' : un passage de chauffe par version.');
      FOR passage IN 1 .. 5 LOOP
        v_avant.EXTEND; v_apres.EXTEND;
        -- Alterner l'ordre pour ne pas toujours mesurer la même version en premier.
        IF MOD((serie - 1) * 5 + passage, 2) = 1 THEN
            v_avant(passage) := mesurer(v_sql_avant);
            v_apres(passage) := mesurer(v_sql_apres);
        ELSE
            v_apres(passage) := mesurer(v_sql_apres);
            v_avant(passage) := mesurer(v_sql_avant);
        END IF;
        v_tous_avant.EXTEND; v_tous_apres.EXTEND;
        v_index := v_tous_avant.COUNT;
        v_tous_avant(v_index) := v_avant(passage);
        v_tous_apres(v_index) := v_apres(passage);
        DBMS_OUTPUT.PUT_LINE('Série ' || serie || ', passage ' || passage || ' : normalisé=' || v_avant(passage)
            || ' s ; dénormalisé=' || v_apres(passage) || ' s');
      END LOOP;
      v_medianes_avant.EXTEND; v_medianes_apres.EXTEND;
      v_medianes_avant(serie) := mediane(v_avant);
      v_medianes_apres(serie) := mediane(v_apres);
      IF v_medianes_apres(serie) < v_medianes_avant(serie) THEN
          v_gagnes := v_gagnes + 1;
      ELSIF v_medianes_apres(serie) = v_medianes_avant(serie) THEN
          v_egaux := v_egaux + 1;
      END IF;
      DBMS_OUTPUT.PUT_LINE('Série ' || serie || ' : médiane normalisée=' || v_medianes_avant(serie)
          || ' s ; médiane dénormalisée=' || v_medianes_apres(serie) || ' s');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Bilan : ' || v_series || ' séries, ' || v_tous_avant.COUNT
        || ' mesures par version, hors chauffe.');
    DBMS_OUTPUT.PUT_LINE('Médiane de tous les passages normalisés : ' || mediane(v_tous_avant) || ' s');
    DBMS_OUTPUT.PUT_LINE('Médiane de tous les passages dénormalisés : ' || mediane(v_tous_apres) || ' s');
    DBMS_OUTPUT.PUT_LINE('Médiane des médianes normalisées : ' || mediane(v_medianes_avant) || ' s');
    DBMS_OUTPUT.PUT_LINE('Médiane des médianes dénormalisées : ' || mediane(v_medianes_apres) || ' s');
    DBMS_OUTPUT.PUT_LINE('Selon les médianes par série, dénormalisé plus rapide : ' || v_gagnes
        || ' ; égalité : ' || v_egaux || ' ; plus lent : ' || (v_series - v_gagnes - v_egaux));
    IF mediane(v_tous_avant) > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Baisse relative des médianes de tous les passages : '
            || ROUND(100 * (mediane(v_tous_avant) - mediane(v_tous_apres)) / mediane(v_tous_avant), 2) || ' %');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Résolution du chronomètre : 0,01 s. Un temps nul ne permet pas de conclure à un gain.');
    afficher_plan(v_sql_avant, 'NORMALISE');
    afficher_plan(v_sql_apres, 'DENORMALISE');
END;
/

-- Taille allouée aux tables et à leurs index PK, en octets et blocs.
SELECT segment_name, segment_type, bytes, blocks
FROM user_segments
WHERE segment_name IN ('L3_N_RESSOURCES', 'L3_N_OPERATIONS', 'L3_D_OPERATIONS',
                       'PK_L3_N_RES', 'PK_L3_N_OPE', 'PK_L3_D_OPE')
ORDER BY segment_type, segment_name;

UNDEFINE lot_import
UNDEFINE nombre_series
WHENEVER SQLERROR CONTINUE NONE
