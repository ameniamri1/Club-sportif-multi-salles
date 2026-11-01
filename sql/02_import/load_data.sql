-- Générer les fichiers avec : python run/generer_import_sql.py
-- Puis lancer ce fichier entier avec F5 dans SQL Developer.
-- Utiliser une connexion dédiée sans transaction en cours, avec l'autocommit désactivé.
-- Le pilote arrête le chargement à la première erreur et annule la transaction.
@@generated/charger_tout.sql
