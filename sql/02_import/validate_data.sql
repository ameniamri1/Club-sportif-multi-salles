-- Lancer le fichier entier avec F5 après le chargement et son COMMIT final.
-- Les vues lisent les tables brutes ; elles ne corrigent et ne suppriment aucune ligne.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 100
SET LINESIZE 250
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT à valider : '
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
@@verifier_lot.sql

-- RG15-RG16 : clé de personne calculée, sans fusionner les lignes sources.
CREATE OR REPLACE VIEW v_usagers_source AS
SELECT a.*,
       LOWER(REGEXP_REPLACE(a.email, '[[:space:]]', '')) AS email_normalise,
       CASE WHEN REGEXP_REPLACE(a.email, '[[:space:]]', '') IS NULL
            THEN 'LIGNE:' || TO_CHAR(a.numero_ligne, 'FM999999999999')
            ELSE 'EMAIL:' || LOWER(REGEXP_REPLACE(a.email, '[[:space:]]', ''))
       END AS cle_personne
FROM brut_usager a;

-- Les valeurs d'origine restent accessibles à côté des valeurs converties.
CREATE OR REPLACE VIEW v_ressources_source AS
SELECT r.id_lot, r.numero_ligne, r.id_cours, r.libelle, r.categorie, r.id_salle,
       r.debut AS debut_source, r.capacite AS capacite_source,
       r.duree_minutes AS duree_source, r.prix_unitaire AS prix_source,
       TO_TIMESTAMP(r.debut DEFAULT NULL ON CONVERSION ERROR,
                    'FXYYYY-MM-DD HH24:MI:SS') AS debut,
       TO_NUMBER(r.capacite DEFAULT NULL ON CONVERSION ERROR) AS capacite,
       TO_NUMBER(r.duree_minutes DEFAULT NULL ON CONVERSION ERROR) AS duree_minutes,
       TO_NUMBER(r.prix_unitaire DEFAULT NULL ON CONVERSION ERROR) AS prix_unitaire
FROM brut_ressource r;

-- RG13 : seulement existence de la ressource, montant >= 0 et date <= début.
-- Une conversion impossible est signalée séparément, sans inventer une valeur.
CREATE OR REPLACE VIEW v_operations_validation AS
WITH operations_converties AS (
    SELECT o.*,
           TO_NUMBER(o.montant DEFAULT NULL ON CONVERSION ERROR) AS montant_num,
           TO_NUMBER(o.nb_places DEFAULT NULL ON CONVERSION ERROR) AS places_num,
           TO_TIMESTAMP(o.date_reservation DEFAULT NULL ON CONVERSION ERROR,
                        'FXYYYY-MM-DD HH24:MI:SS') AS date_num
    FROM brut_operation o
)
SELECT o.id_lot, o.numero_ligne, o.id_reservation, o.id_adherent, o.id_cours,
       o.date_reservation AS date_source, o.montant AS montant_source,
       o.nb_places AS places_source, o.statut, o.id_groupe,
       o.montant_num AS montant, o.places_num AS nb_places, o.date_num AS date_reservation,
       u.cle_personne, r.id_salle AS id_site, r.categorie, r.debut,
       r.capacite, r.prix_unitaire, r.numero_ligne AS numero_ressource,
       CASE WHEN r.numero_ligne IS NULL THEN 1 ELSE 0 END AS ressource_absente,
       CASE WHEN o.montant_num < 0 THEN 1 ELSE 0 END AS montant_negatif,
       CASE WHEN o.date_num > r.debut THEN 1 ELSE 0 END AS date_tardive,
       CASE WHEN o.montant_num IS NULL OR o.date_num IS NULL
                 OR (r.numero_ligne IS NOT NULL AND r.debut IS NULL)
            THEN 1 ELSE 0 END AS conversion_a_verifier,
       CASE WHEN r.numero_ligne IS NULL OR o.montant_num < 0 OR o.date_num > r.debut THEN 0
            WHEN o.montant_num >= 0 AND o.date_num <= r.debut THEN 1
            ELSE NULL END AS est_valide
FROM operations_converties o
LEFT JOIN v_ressources_source r ON r.id_lot = o.id_lot AND r.id_cours = o.id_cours
LEFT JOIN v_usagers_source u ON u.id_lot = o.id_lot AND u.id_adherent = o.id_adherent;

CREATE OR REPLACE VIEW v_operations_valides AS
SELECT * FROM v_operations_validation WHERE est_valide = 1;

PROMPT Réservations présentant un motif d'invalidité ou un problème de conversion
SELECT id_lot, numero_ligne, id_reservation, id_adherent, id_cours,
       montant_source, date_source, debut,
       ressource_absente, montant_negatif, date_tardive, conversion_a_verifier
FROM v_operations_validation
WHERE id_lot = &&lot_import
  AND (est_valide = 0 OR conversion_a_verifier = 1)
ORDER BY numero_ligne;

PROMPT Emails absents ou composés uniquement d'espaces
SELECT id_lot, numero_ligne, id_adherent, email
FROM v_usagers_source
WHERE id_lot = &&lot_import AND email_normalise IS NULL
ORDER BY numero_ligne;

PROMPT Emails normalisés partagés par plusieurs lignes : détail de chaque ligne
SELECT id_lot, numero_ligne, id_adherent, email, email_normalise, occurrences
FROM (
    SELECT u.*, COUNT(*) OVER (PARTITION BY id_lot, email_normalise) AS occurrences
    FROM v_usagers_source u WHERE id_lot = &&lot_import
)
WHERE email_normalise IS NOT NULL AND occurrences > 1
ORDER BY email_normalise, numero_ligne;

PROMPT Autres anomalies techniques à examiner séparément de RG13
SELECT id_lot, numero_ligne, id_reservation, places_source, statut, cle_personne
FROM v_operations_validation
WHERE id_lot = &&lot_import
  AND (nb_places IS NULL OR nb_places <= 0 OR nb_places <> TRUNC(nb_places)
       OR statut IS NULL OR statut NOT IN ('CONFIRMEE', 'ANNULEE') OR cle_personne IS NULL)
ORDER BY numero_ligne;

PROMPT Ressources dont les valeurs numériques ou la date sont à examiner
SELECT id_lot, numero_ligne, id_cours, debut_source, capacite_source, duree_source, prix_source
FROM v_ressources_source
WHERE id_lot = &&lot_import
  AND (debut IS NULL OR capacite IS NULL OR capacite <= 0 OR capacite <> TRUNC(capacite)
       OR duree_minutes IS NULL OR duree_minutes <= 0 OR duree_minutes <> TRUNC(duree_minutes)
       OR prix_unitaire IS NULL OR prix_unitaire < 0)
ORDER BY numero_ligne;

-- RG20 : pas de rejet des sur-réservations et pas de mise à jour des sources.
UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
