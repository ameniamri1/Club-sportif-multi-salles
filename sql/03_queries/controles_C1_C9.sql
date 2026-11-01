-- Lancer avec F5 après validate_data.sql. Chaque SELECT affiche son résultat réel.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 100
SET LINESIZE 250
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT des contrôles : '
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
@@../02_import/verifier_lot.sql
@@../02_import/verifier_analyse.sql

PROMPT C1 - Nombre de personnes distinctes
-- Un email normalisé commun désigne une personne ; chaque ligne sans email reste distincte.
SELECT COUNT(DISTINCT cle_personne) AS c1_personnes
FROM v_usagers_source WHERE id_lot = &&lot_import;

PROMPT C2 - Nombre d'opérations invalides et répartition par motif
-- Les motifs peuvent se recouper : ne pas additionner leurs effectifs pour obtenir le total.
SELECT COUNT(*) AS c2_operations_invalides,
       NVL(SUM(ressource_absente), 0) AS ressources_absentes,
       NVL(SUM(montant_negatif), 0) AS montants_negatifs,
       NVL(SUM(date_tardive), 0) AS reservations_tardives
FROM v_operations_validation WHERE id_lot = &&lot_import AND est_valide = 0;

PROMPT C3 - Nombre d'opérations valides confirmées
SELECT COUNT(*) AS c3_confirmees
FROM v_operations_valides WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE';

PROMPT C4 - Journée comptant le plus d'opérations valides, tous statuts
-- Tous les jours ex aequo sont affichés si plusieurs journées partagent le maximum.
WITH jours AS (
    SELECT TRUNC(CAST(date_reservation AS DATE)) AS jour, COUNT(*) AS operations
    FROM v_operations_valides WHERE id_lot = &&lot_import
    GROUP BY TRUNC(CAST(date_reservation AS DATE))
)
SELECT TO_CHAR(jour, 'YYYY-MM-DD') AS c4_jour, operations
FROM jours WHERE operations = (SELECT MAX(operations) FROM jours)
ORDER BY jour;

PROMPT C5 - Chiffre d'affaires valide confirmé par site
-- Le siège reste affiché, avec zéro s'il ne possède aucune réservation.
SELECT s.id_salle AS id_site, s.nom, NVL(SUM(o.montant), 0) AS c5_chiffre_affaires
FROM brut_salle s
LEFT JOIN v_operations_valides o
    ON o.id_lot = s.id_lot AND o.id_site = s.id_salle AND o.statut = 'CONFIRMEE'
WHERE s.id_lot = &&lot_import
GROUP BY s.id_salle, s.nom ORDER BY s.id_salle;

PROMPT C6 - Personnes avec des opérations valides dans au moins deux sites
-- Les annulations valides sont incluses et les personnes sont rapprochées par email.
SELECT COUNT(*) AS c6_personnes_multisites
FROM (
    SELECT cle_personne FROM v_operations_valides WHERE id_lot = &&lot_import
    GROUP BY cle_personne HAVING COUNT(DISTINCT id_site) >= 2
);

PROMPT C7 - Ressources en sur-réservation
-- La sur-réservation est mesurée après validation ; elle ne modifie pas est_valide.
SELECT COUNT(*) AS c7_ressources_surchargees
FROM (
    SELECT r.id_cours
    FROM v_ressources_source r
    LEFT JOIN v_operations_valides o
        ON o.id_lot = r.id_lot AND o.id_cours = r.id_cours AND o.statut = 'CONFIRMEE'
    WHERE r.id_lot = &&lot_import
    GROUP BY r.id_cours, r.capacite
    HAVING NVL(SUM(o.nb_places), 0) > r.capacite
);

PROMPT C8 - Groupes dont les opérations valides engagent au moins deux sites
SELECT COUNT(*) AS c8_groupes_multisites
FROM (
    SELECT id_groupe FROM v_operations_valides
    WHERE id_lot = &&lot_import AND id_groupe IS NOT NULL
    GROUP BY id_groupe HAVING COUNT(DISTINCT id_site) >= 2
);

PROMPT C9 - Places valides confirmées par catégorie
SELECT categorie, SUM(nb_places) AS c9_places_confirmees
FROM v_operations_valides WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
GROUP BY categorie ORDER BY categorie;

UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
