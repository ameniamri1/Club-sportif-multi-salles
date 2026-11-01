-- L3 : exécuter après la fin des requêtes L2, dans une connexion sans travail en attente.
-- Les jointures externes conservent les opérations dont le cours est absent.
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
ACCEPT lot_import NUMBER PROMPT 'ID_LOT du fichier a plat : '
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
@@../02_import/verifier_lot.sql

CREATE OR REPLACE VIEW v_operations_a_plat AS
SELECT o.id_lot, o.numero_ligne, o.id_reservation, o.id_adherent, o.id_cours,
       o.date_reservation, o.nb_places, o.montant, o.statut, o.id_groupe,
       u.nom AS nom_usager, u.prenom AS prenom_usager, u.email AS email_source,
       u.email_normalise, u.cle_personne, u.telephone, u.ville AS ville_usager, u.date_inscription,
       u.id_salle AS id_salle_rattachement, sr.nom AS nom_salle_rattachement,
       sr.ville AS ville_salle_rattachement, sr.role AS role_salle_rattachement,
       r.libelle AS libelle_cours, r.categorie, r.debut AS debut_cours,
       r.duree_minutes, r.capacite, r.prix_unitaire, r.id_salle AS id_salle_cours,
       sc.nom AS nom_salle_cours, sc.ville AS ville_salle_cours, sc.role AS role_salle_cours,
       CASE WHEN r.numero_ligne IS NULL THEN 0 ELSE 1 END AS ressource_presente
FROM brut_operation o
LEFT JOIN v_usagers_source u ON u.id_lot = o.id_lot AND u.id_adherent = o.id_adherent
LEFT JOIN brut_ressource r ON r.id_lot = o.id_lot AND r.id_cours = o.id_cours
LEFT JOIN brut_salle sr ON sr.id_lot = u.id_lot AND sr.id_salle = u.id_salle
LEFT JOIN brut_salle sc ON sc.id_lot = r.id_lot AND sc.id_salle = r.id_salle;

SELECT COUNT(*) AS operations_a_plat, COUNT(DISTINCT id_reservation) AS identifiants_distincts
FROM v_operations_a_plat WHERE id_lot = &&lot_import;

SELECT numero_ligne, id_reservation, id_cours, libelle_cours, ressource_presente
FROM v_operations_a_plat
WHERE id_lot = &&lot_import AND ressource_presente = 0
ORDER BY numero_ligne FETCH FIRST 10 ROWS ONLY;

UNDEFINE lot_import
WHENEVER SQLERROR CONTINUE NONE
