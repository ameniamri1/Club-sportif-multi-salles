-- Requêtes de vérification du chargement : lancer avec F5.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 100
SET LINESIZE 250
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT à vérifier : '
@@verifier_lot.sql

SELECT id_lot, libelle, date_creation FROM lot_source WHERE id_lot = &&lot_import;

WITH effectifs AS (
    SELECT 'BRUT_SALLE' AS table_source, 4 AS attendu, COUNT(*) AS present,
           MIN(numero_ligne) AS premier, MAX(numero_ligne) AS dernier
    FROM brut_salle WHERE id_lot = &&lot_import
    UNION ALL
    SELECT 'BRUT_USAGER', 20467, COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    FROM brut_usager WHERE id_lot = &&lot_import
    UNION ALL
    SELECT 'BRUT_RESSOURCE', 28571, COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    FROM brut_ressource WHERE id_lot = &&lot_import
    UNION ALL
    SELECT 'BRUT_OPERATION', 365069, COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    FROM brut_operation WHERE id_lot = &&lot_import
)
SELECT table_source, attendu, present, premier, dernier,
       CASE WHEN present = attendu AND premier = 1 AND dernier = attendu
            THEN 'OK' ELSE 'A_VERIFIER' END AS controle
FROM effectifs ORDER BY table_source;

-- Les autres lots restent visibles et ne sont ni supprimés ni mélangés au lot demandé.
SELECT 'BRUT_SALLE' AS table_source, id_lot, COUNT(*) AS lignes FROM brut_salle GROUP BY id_lot
UNION ALL
SELECT 'BRUT_USAGER', id_lot, COUNT(*) FROM brut_usager GROUP BY id_lot
UNION ALL
SELECT 'BRUT_RESSOURCE', id_lot, COUNT(*) FROM brut_ressource GROUP BY id_lot
UNION ALL
SELECT 'BRUT_OPERATION', id_lot, COUNT(*) FROM brut_operation GROUP BY id_lot
ORDER BY table_source, id_lot;

-- Vérifier le texte original et les accents sur quelques lignes.
SELECT numero_ligne, id_salle, nom, ville, role,
       DBMS_LOB.SUBSTR(ligne_originale, 1000, 1) AS texte_original
FROM brut_salle WHERE id_lot = &&lot_import ORDER BY numero_ligne;

-- Aucun résultat attendu : les FK de lot doivent être actives.
SELECT 'BRUT_SALLE' AS table_source, b.id_lot, b.numero_ligne FROM brut_salle b
LEFT JOIN lot_source l ON l.id_lot = b.id_lot WHERE l.id_lot IS NULL
UNION ALL
SELECT 'BRUT_USAGER', b.id_lot, b.numero_ligne FROM brut_usager b
LEFT JOIN lot_source l ON l.id_lot = b.id_lot WHERE l.id_lot IS NULL
UNION ALL
SELECT 'BRUT_RESSOURCE', b.id_lot, b.numero_ligne FROM brut_ressource b
LEFT JOIN lot_source l ON l.id_lot = b.id_lot WHERE l.id_lot IS NULL
UNION ALL
SELECT 'BRUT_OPERATION', b.id_lot, b.numero_ligne FROM brut_operation b
LEFT JOIN lot_source l ON l.id_lot = b.id_lot WHERE l.id_lot IS NULL;

UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
