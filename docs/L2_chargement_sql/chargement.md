# Chargement des CSV et exécution des requêtes

Nous préparons les fichiers SQL à partir des CSV sur le PC, puis nous les exécutons dans SQL Developer avec la connexion « Projet Multisite ». Python sert uniquement à générer les fichiers ; la connexion à Oracle se fait dans SQL Developer.

Ce choix permet de garder les CSV sur le PC sans configurer de dossier sur le serveur Oracle. Les insertions sont regroupées par blocs de 500 lignes avec `FORALL`. En contrepartie, les fichiers SQL sont assez volumineux : ils contiennent les champs à insérer et une copie du texte original de chaque enregistrement.

Le dossier `generated/` contient la version qui a permis de charger le lot 6 sur Oracle. Les anciennes générations ont été retirées. Les numéros de ligne sont préparés dans une collection et lus avec `v_numeros(i)` dans le FORALL.

## Prérequis

- Python 3.10 ou ultérieur pour la génération, sans bibliothèque supplémentaire.
- Les quatre CSV d'origine dans `data/raw/`, avec leur en-tête et leur encodage UTF-8.
- Les tables et contraintes L1 déjà créées sur Oracle 19c ou ultérieur.
- Une base dont le jeu de caractères est `AL32UTF8`, avec assez de quota de tablespace et d'espace UNDO pour conserver l'import dans une seule transaction.
- SQL Developer configuré pour ouvrir les scripts en UTF-8. Le compte du projet doit pouvoir insérer dans ses tables et créer des vues pour la validation.

## 1. Générer les fichiers SQL

Les fichiers corrigés sont inclus dans le dépôt : un nouvel utilisateur peut directement passer à l'étape 2 dans SQL Developer. Python n'est nécessaire que pour les reconstruire. Pour préparer une nouvelle génération, utiliser un autre dossier de sortie, car le générateur refuse d'écraser un dossier existant :

```powershell
python run/generer_import_sql.py --sortie sql/02_import/nouvelle_generation
```

Le dossier versionné `sql/02_import/generated/` contient :

```text
00_initialiser_lot.sql
01_salles.sql
02_adherents.sql
03_cours.sql
04_reservations.sql
05_valider_lot.sql
charger_tout.sql
manifest.json
```

Chaque fichier de données regroupe ses insertions dans des blocs `FORALL`. `manifest.json` permet de retrouver les fichiers sources utilisés et leurs effectifs. Ces huit fichiers sont versionnés pour permettre le chargement après un clonage, sans étape de génération locale.

La génération s'arrête si un fichier est illisible, si son en-tête ou son nombre de champs est incorrect, ou si une valeur dépasse la taille prévue. Le dossier de sortie est créé une fois les quatre fichiers traités. Les valeurs sont conservées telles quelles, y compris les espaces et les montants négatifs.

Si le dossier de sortie existe déjà, le générateur refuse de l'écraser. Pour préparer une autre génération :

```powershell
python run/generer_import_sql.py --sortie sql/02_import/generated/nouvelle_generation --taille-lot 250
```

Avec cette commande, le fichier à exécuter devient `generated/nouvelle_generation/charger_tout.sql`. `load_data.sql` reste un raccourci vers la génération par défaut. Générer à nouveau les fichiers ne demande pas de recharger un lot déjà validé sur Oracle.

## 2. Charger les quatre fichiers dans SQL Developer

Utiliser une connexion sans modification en attente et désactiver l'autocommit. Le chargement doit aller jusqu'à son COMMIT final : les quatre fichiers font partie de la même transaction. Il faut donc lancer `charger_tout.sql` en entier, sans exécuter les sous-fichiers séparément ni valider au milieu.

Ouvrir `sql/02_import/generated/charger_tout.sql`, sélectionner la connexion du projet et appuyer sur **F5 — Exécuter un script**. Les appels `@@` chargent les fichiers voisins dans l'ordre. Si la version de SQL Developer ne résout pas le chemin depuis l'onglet ouvert, lancer ce fichier par son chemin absolu dans une feuille SQL :

```sql
@"C:/Users/Bellouch/Downloads/General/General/projet/Club-sportif-multi-salles/sql/02_import/generated/charger_tout.sql"
```

Le script commence par créer un lot dans LOT_SOURCE. Les quatre tables reçoivent le même `id_lot`. Dans chaque CSV, les enregistrements sont numérotés à partir de 1, après l'en-tête. Un champ contenant un retour à la ligne ne crée pas un nouvel enregistrement.

`ligne_originale` contient le texte de l'enregistrement tel qu'il a été lu, y compris les guillemets, espaces et fins de ligne. Les retours à la ligne sont encodés dans le SQL avec `CHR(10)` et `CHR(13)`. Les champs sont insérés en texte, sans nettoyage. Un champ vide devient NULL dans Oracle ; son écriture d'origine reste dans le CLOB. Les apostrophes sont échappées et `SET DEFINE OFF` protège les esperluettes.

La sortie affiche le début et la fin de chaque fichier, ainsi qu'une progression toutes les 5 000 lignes avec la taille de bloc par défaut. Ces lignes restent en attente du COMMIT final. À la fin, la sortie doit afficher les quatre effectifs contrôlés puis :

```text
SUCCES : ID_LOT=..., les quatre fichiers sont validés.
```

Le message `DEBUT : ID_LOT=...` indique seulement la création du lot. Il faut attendre `SUCCES` pour confirmer que les quatre fichiers ont été validés. L'identifiant affiché à la fin sera utilisé dans les scripts suivants ; il peut être supérieur à 1, car les identifiants consommés ne sont pas récupérés après un rollback.

## 3. Vérifier le chargement

Ouvrir `sql/02_import/verify_import.sql`, puis F5. Saisir l'ID_LOT du chargement.

| Table | Lignes attendues | Numéros attendus |
| --- | ---: | --- |
| BRUT_SALLE | 4 | 1 à 4 |
| BRUT_USAGER | 20 467 | 1 à 20 467 |
| BRUT_RESSOURCE | 28 571 | 1 à 28 571 |
| BRUT_OPERATION | 365 069 | 1 à 365 069 |

Les quatre lignes du tableau de contrôle doivent afficher `OK`. Avec la clé primaire sur le lot et le numéro de ligne, les effectifs et les bornes permettent de repérer une ligne manquante. Le script vérifie aussi le texte original et les identifiants sources. L'affichage des salles permet de vérifier les accents dans « Vénissieux » et « Siège ».

## 4. Repérer les défauts

Ouvrir `sql/02_import/validate_data.sql`, puis F5, avec le même ID_LOT.

La validation s'appuie sur quatre vues : V_USAGERS_SOURCE pour les personnes, V_RESSOURCES_SOURCE pour les cours, V_OPERATIONS_VALIDATION pour examiner les réservations et V_OPERATIONS_VALIDES pour celles qui respectent RG13. Le script affiche les défauts à examiner, dont les cours absents, les montants négatifs et les emails partagés.

Les conversions restent dans les vues ; les valeurs des tables brutes restent disponibles. Le [traitement des anomalies](traitement_anomalies.md) explique comment chaque cas est pris en compte.

Les vues utilisent les conversions numériques de la session. Les scripts L2 fixent donc `NLS_NUMERIC_CHARACTERS = '.,'`. Faire de même avant de les interroger séparément avec Ctrl+Entrée.

## 5. Exécuter C1 à C9 et les dix requêtes métier

Après la validation, exécuter successivement avec F5 :

```text
sql/03_queries/controles_C1_C9.sql
sql/03_queries/requetes_metier.sql
```

Saisir le même ID_LOT dans les deux scripts. Avant les calculs, ils vérifient que le lot est complet et que les données peuvent être jointes et converties. Si un de ces contrôles échoue, revenir au détail des anomalies avant d'interpréter les totaux.

Chaque énoncé apparaît dans la sortie, suivi du résultat du SELECT. Pour conserver ces résultats, enregistrer la sortie de script ou utiliser SPOOL avec un chemin local accessible :

```sql
SPOOL "C:/Users/Bellouch/Downloads/General/General/projet/Club-sportif-multi-salles/preuves/requetes_metier/resultats_requetes.log"
@"C:/Users/Bellouch/Downloads/General/General/projet/Club-sportif-multi-salles/sql/03_queries/requetes_metier.sql"
SPOOL OFF
```

Enregistrer les preuves de C1 à C9 dans `preuves/controles_C1_C9/`, avec la requête, le résultat et la connexion visibles. Si SQL Developer limite le nombre de lignes affichées, augmenter cette limite avant d'enregistrer une sortie complète.

## Erreurs, interruption et relancement

Lorsqu'une insertion échoue, le bloc indique la table et les lignes concernées. `SAVE EXCEPTIONS` permet de détailler les rejets avant le rollback de l'import. La sortie SQL Developer est à enregistrer pour garder le message exact et retrouver la ligne dans le CSV.

En cas d'annulation manuelle avec le bouton d'arrêt, exécuter `ROLLBACK;` dans la même connexion avant de recommencer. Si la connexion est perdue pendant le COMMIT, son résultat peut être incertain : vérifier LOT_SOURCE et les effectifs dans une nouvelle connexion avant de relancer.

Le libellé du lot est déterminé par le contenu des quatre fichiers. Un nouveau lancement avec les mêmes fichiers refuse de créer un second lot si le premier existe déjà. Un verrou sur LOT_SOURCE empêche deux chargements de ce pilote de démarrer simultanément ; un échec de verrouillage demande simplement d'attendre la fin de l'autre transaction. Les anciens lots ne sont jamais supprimés automatiquement.

Après avoir corrigé l'erreur et vérifié le rollback, relancer le script entier. Répéter F5 sans examiner l'erreur ne résout pas le problème : cela peut seulement consommer de nouveaux identifiants de lot. Si un lot incomplet a été validé manuellement, il faut d'abord l'examiner ; le script ne le supprime pas. Changer la taille des blocs ne crée pas une nouvelle identité pour les mêmes fichiers.

Le chargement corrigé s'est terminé avec `SUCCES : ID_LOT=6`. Les quatre effectifs ont ensuite été vérifiés dans Oracle. Le script de validation a créé les quatre vues et renvoyé 553 réservations à examiner, 33 emails manquants et 102 lignes partageant un email normalisé. Les deux recherches complémentaires d'anomalies techniques n'ont renvoyé aucune ligne. La prochaine étape est l'exécution de C1 à C9 puis des dix requêtes métier sur ce même lot.

Références : [FORALL et traitement des erreurs par lots](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/bulk-sql-and-bulk-binding.html), [exécution des scripts SQL Developer](https://docs.oracle.com/en/database/oracle/sql-developer/24.3/rptug/sql-developer-concepts-usage.html#GUID-AC4E85E0-6684-4C74-B376-C7F7CB89234D).
