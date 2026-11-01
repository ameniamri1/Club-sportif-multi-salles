-- Lancer avec F5 après validate_data.sql. Les PROMPT donnent l'énoncé de chaque requête.
-- Les résultats sont produits sur Oracle au moment de l'exécution.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 100
SET LINESIZE 250
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT des requêtes métier : '
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
@@../02_import/verifier_lot.sql
@@../02_import/verifier_analyse.sql

PROMPT Q01 - Activité confirmée de chaque site, y compris les sites sans réservation
-- Jointure externe : conserver le siège et toute salle sans activité.
SELECT s.id_salle, s.nom, COUNT(o.numero_ligne) AS reservations,
       NVL(SUM(o.nb_places), 0) AS places, NVL(SUM(o.montant), 0) AS chiffre_affaires
FROM brut_salle s
LEFT JOIN v_operations_valides o
    ON o.id_lot = s.id_lot AND o.id_site = s.id_salle AND o.statut = 'CONFIRMEE'
WHERE s.id_lot = &&lot_import
GROUP BY s.id_salle, s.nom ORDER BY s.id_salle;

PROMPT Q02 - Les vingt séances ayant au moins vingt places valides confirmées les plus demandées
-- HAVING filtre les séances après agrégation des places.
SELECT r.id_cours, r.libelle, r.id_salle, r.capacite, SUM(o.nb_places) AS places_confirmees
FROM v_ressources_source r
JOIN v_operations_valides o ON o.id_lot = r.id_lot AND o.id_cours = r.id_cours
WHERE r.id_lot = &&lot_import AND o.statut = 'CONFIRMEE'
GROUP BY r.id_cours, r.libelle, r.id_salle, r.capacite
HAVING SUM(o.nb_places) >= 20
ORDER BY places_confirmees DESC, r.id_cours FETCH FIRST 20 ROWS ONLY;

PROMPT Q03 - Personnes sans aucune réservation valide, aperçu des vingt premières
-- Sous-requête corrélée : la recherche de réservation dépend de la personne courante.
SELECT DISTINCT u.cle_personne
FROM v_usagers_source u
WHERE u.id_lot = &&lot_import
  AND NOT EXISTS (
      SELECT 1 FROM v_operations_valides o
      WHERE o.id_lot = u.id_lot AND o.cle_personne = u.cle_personne
  )
ORDER BY u.cle_personne FETCH FIRST 20 ROWS ONLY;

PROMPT Q04 - Personnes ayant une réservation valide confirmée dans chacune des trois salles, aperçu de vingt
-- Division par double NOT EXISTS : aucune salle opérationnelle ne doit manquer.
SELECT DISTINCT u.cle_personne
FROM v_usagers_source u
WHERE u.id_lot = &&lot_import
  AND EXISTS (SELECT 1 FROM brut_salle s WHERE s.id_lot = u.id_lot AND s.role = 'site')
  AND NOT EXISTS (
      SELECT 1 FROM brut_salle s
      WHERE s.id_lot = u.id_lot AND s.role = 'site'
        AND NOT EXISTS (
            SELECT 1 FROM v_operations_valides o
            WHERE o.id_lot = u.id_lot AND o.cle_personne = u.cle_personne
              AND o.id_site = s.id_salle AND o.statut = 'CONFIRMEE'
        )
  )
ORDER BY u.cle_personne FETCH FIRST 20 ROWS ONLY;

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
SELECT r.id_cours, r.libelle, r.id_salle, r.debut,
       r.capacite - NVL(SUM(o.nb_places), 0) AS places_restantes
FROM v_ressources_source r
LEFT JOIN v_operations_valides o
    ON o.id_lot = r.id_lot AND o.id_cours = r.id_cours AND o.statut = 'CONFIRMEE'
WHERE r.id_lot = &&lot_import
  AND r.debut >= TIMESTAMP '2026-01-01 00:00:00' AND r.debut < TIMESTAMP '2026-02-01 00:00:00'
GROUP BY r.id_cours, r.libelle, r.id_salle, r.debut, r.capacite
HAVING r.capacite - NVL(SUM(o.nb_places), 0) > 0
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
)
SELECT cle_personne, reservations, montant
FROM depenses WHERE montant > (SELECT AVG(montant) FROM depenses)
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

UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
