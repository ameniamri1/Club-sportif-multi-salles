-- Ouvrir ce fichier avec SQL Developer et lancer le script entier avec F5.
-- Utiliser une connexion dédiée, sans modifications en attente, et désactiver l'autocommit.
SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET AUTOCOMMIT OFF
WHENEVER OSERROR EXIT FAILURE ROLLBACK
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
@@00_initialiser_lot.sql
@@01_salles.sql
@@02_adherents.sql
@@03_cours.sql
@@04_reservations.sql
@@05_valider_lot.sql
WHENEVER SQLERROR CONTINUE NONE
WHENEVER OSERROR CONTINUE NONE
SET FEEDBACK ON
