-- Lancer le fichier entier avec F5 après validate_data.sql, pour le lot 6.
-- Chaque énoncé est suivi du résultat et du temps affiché par SQL Developer.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 100
SET LINESIZE 250
SET TIMING OFF
SET FEEDBACK ON
COLUMN id_salle FORMAT A8
COLUMN id_site FORMAT A8
COLUMN id_cours FORMAT A10
COLUMN id_groupe FORMAT A12
COLUMN nom FORMAT A28
COLUMN libelle FORMAT A32
COLUMN categorie FORMAT A18
COLUMN cle_personne FORMAT A80
COLUMN mois FORMAT A7
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT des requêtes métier : '
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS';
@@../02_import/verifier_lot.sql
@@../02_import/verifier_analyse.sql
SET TIMING ON

PROMPT Q01 - Activité confirmée de chaque site, y compris les sites sans réservation
-- Jointure externe : conserver le siège et toute salle sans activité.
WITH activite AS (
    SELECT id_lot, id_site, COUNT(*) AS reservations,
           SUM(nb_places) AS places, SUM(montant) AS chiffre_affaires
    FROM v_operations_valides
    WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
    GROUP BY id_lot, id_site
)
SELECT s.id_salle, s.nom, NVL(a.reservations, 0) AS reservations,
       NVL(a.places, 0) AS places, NVL(a.chiffre_affaires, 0) AS chiffre_affaires
FROM brut_salle s
LEFT JOIN activite a ON a.id_lot = s.id_lot AND a.id_site = s.id_salle
WHERE s.id_lot = &&lot_import
ORDER BY s.id_salle;

PROMPT Q02 - Les vingt séances ayant au moins vingt places valides confirmées les plus demandées
-- HAVING filtre les séances après agrégation des places.
WITH demandes AS (
    SELECT id_lot, id_cours, SUM(nb_places) AS places_confirmees
    FROM v_operations_valides
    WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
    GROUP BY id_lot, id_cours HAVING SUM(nb_places) >= 20
)
SELECT r.id_cours, r.libelle, r.id_salle, r.capacite, d.places_confirmees
FROM demandes d
JOIN v_ressources_source r ON r.id_lot = d.id_lot AND r.id_cours = d.id_cours
ORDER BY d.places_confirmees DESC, r.id_cours FETCH FIRST 20 ROWS ONLY;

PROMPT Q03 - Personnes sans aucune réservation valide, aperçu des vingt premières
-- MINUS retire les personnes ayant réservé et élimine les doublons.
-- Même résultat que NOT EXISTS, sans corrélation explicite sur la vue des opérations.
SELECT cle_personne
FROM (
    SELECT cle_personne FROM v_usagers_source WHERE id_lot = &&lot_import
    MINUS
    SELECT cle_personne FROM v_operations_valides WHERE id_lot = &&lot_import
)
ORDER BY cle_personne FETCH FIRST 20 ROWS ONLY;

PROMPT Q04 - Personnes ayant une réservation valide confirmée dans chacune des trois salles, aperçu de vingt
-- Division par comptage : visiter autant de salles distinctes qu'il en existe dans le lot.
-- La sous-requête corrélée porte sur les quatre sites, pas sur les réservations.
-- La jointure filtre les sites opérationnels ; sans salle, aucun groupe n'est produit.
SELECT o.cle_personne
FROM v_operations_valides o
JOIN brut_salle s ON s.id_lot = o.id_lot AND s.id_salle = o.id_site AND s.role = 'site'
WHERE o.id_lot = &&lot_import AND o.statut = 'CONFIRMEE'
GROUP BY o.id_lot, o.cle_personne
HAVING COUNT(DISTINCT o.id_site) = (
    SELECT COUNT(*) FROM brut_salle attendues
    WHERE attendues.id_lot = o.id_lot AND attendues.role = 'site'
)
ORDER BY o.cle_personne FETCH FIRST 20 ROWS ONLY;

PROMPT Q05 - Trois premiers rangs des séances par site selon les places valides confirmées
-- Fonction de fenêtrage : les ex aequo partagent un rang et sont tous conservés.
WITH frequences AS (
    SELECT id_site, id_cours, SUM(nb_places) AS places
    FROM v_operations_valides WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
    GROUP BY id_site, id_cours
), classement AS (
    SELECT f.*, DENSE_RANK() OVER (PARTITION BY id_site ORDER BY places DESC) AS rang
    FROM frequences f
)
SELECT c.id_site, c.rang, c.id_cours, r.libelle, c.places
FROM classement c JOIN v_ressources_source r ON r.id_cours = c.id_cours AND r.id_lot = &&lot_import
WHERE c.rang <= 3 ORDER BY c.id_site, c.rang, c.id_cours;

PROMPT Q06 - Réservations et taux d'annulation par site et catégorie, sur les opérations valides
SELECT id_site, categorie, COUNT(*) AS reservations,
       SUM(CASE WHEN statut = 'ANNULEE' THEN 1 ELSE 0 END) AS annulations,
       ROUND(100 * SUM(CASE WHEN statut = 'ANNULEE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS taux_annulation_pct
FROM v_operations_valides WHERE id_lot = &&lot_import
GROUP BY id_site, categorie ORDER BY id_site, categorie;

PROMPT Q07 - Vingt premières séances de janvier 2026 ayant encore des places après réservations confirmées valides
-- Additionner les places par cours avant de joindre les séances de janvier.
WITH occupation AS (
    SELECT id_lot, id_cours, SUM(nb_places) AS places_confirmees
    FROM v_operations_valides
    WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
    GROUP BY id_lot, id_cours
)
SELECT r.id_cours, r.libelle, r.id_salle, r.debut,
       r.capacite - NVL(o.places_confirmees, 0) AS places_restantes
FROM v_ressources_source r
LEFT JOIN occupation o ON o.id_lot = r.id_lot AND o.id_cours = r.id_cours
WHERE r.id_lot = &&lot_import
  AND r.debut >= TIMESTAMP '2026-01-01 00:00:00' AND r.debut < TIMESTAMP '2026-02-01 00:00:00'
  AND r.capacite - NVL(o.places_confirmees, 0) > 0
ORDER BY r.debut, r.id_cours FETCH FIRST 20 ROWS ONLY;

PROMPT Q08 - Vingt groupes aux montants confirmés les plus élevés, avec réservations valides dans plusieurs sites
SELECT id_groupe, COUNT(DISTINCT id_site) AS sites, COUNT(DISTINCT id_cours) AS seances,
       SUM(nb_places) AS places, SUM(montant) AS montant_confirme
FROM v_operations_valides
WHERE id_lot = &&lot_import AND id_groupe IS NOT NULL AND statut = 'CONFIRMEE'
GROUP BY id_groupe HAVING COUNT(DISTINCT id_site) >= 2
ORDER BY montant_confirme DESC, id_groupe FETCH FIRST 20 ROWS ONLY;

PROMPT Q09 - Vingt personnes dépassant la dépense moyenne des personnes ayant une réservation valide confirmée
WITH depenses AS (
    SELECT cle_personne, COUNT(*) AS reservations, SUM(montant) AS montant
    FROM v_operations_valides WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
    GROUP BY cle_personne
), comparaison AS (
    SELECT d.*, AVG(montant) OVER () AS moyenne FROM depenses d
)
SELECT cle_personne, reservations, montant
FROM comparaison WHERE montant > moyenne
ORDER BY montant DESC, cle_personne FETCH FIRST 20 ROWS ONLY;

PROMPT Q10 - Chiffre d'affaires mensuel et cumul selon la date des réservations valides confirmées
WITH mois AS (
    SELECT TRUNC(CAST(date_reservation AS DATE), 'MM') AS mois, SUM(montant) AS chiffre_affaires
    FROM v_operations_valides WHERE id_lot = &&lot_import AND statut = 'CONFIRMEE'
    GROUP BY TRUNC(CAST(date_reservation AS DATE), 'MM')
)
SELECT TO_CHAR(mois, 'YYYY-MM') AS mois, chiffre_affaires,
       SUM(chiffre_affaires) OVER (ORDER BY mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumul,
       chiffre_affaires - LAG(chiffre_affaires) OVER (ORDER BY mois) AS ecart_mois_precedent
FROM mois ORDER BY mois;

SET TIMING OFF
UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
