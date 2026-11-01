# Dénormalisation

Nous proposons une copie de reporting des opérations dans laquelle le site du cours et sa catégorie sont stockés avec chaque réservation valide. La requête Q06, qui calcule les réservations et le taux d'annulation par salle et catégorie, pourra ainsi se passer de la jointure vers les ressources.

La campagne de 30 séries sur Oracle, pour le lot 6, donne une médiane de 0,07 seconde sur la version normalisée et de 0,05 seconde sur la copie dénormalisée, soit une baisse de 28,57 %. Les résultats de Q06 sont identiques. La copie est plus rapide selon la médiane dans 29 séries ; une série est à égalité. Le gain observé concerne cette requête, avec un cache déjà sollicité et des temps courts.

## Redondance introduite

Dans le modèle normalisé, `(id_lot, id_cours)` détermine `id_site` et `categorie` dans la table des ressources. Dans la copie dénormalisée, ces deux valeurs sont répétées pour chaque réservation du cours. Elles dépendent donc d'une autre clé que celle de l'opération : c'est une dénormalisation volontaire.

Les noms, les emails et les coordonnées personnelles ne sont pas ajoutés à la copie de reporting. Elle garde seulement la clé de personne déjà utilisée pour les analyses.

## Préparer la comparaison

Attendre la fin des requêtes L2 avant d'exécuter ces scripts. Ils ne sont pas lancés pendant les requêtes en cours.

Dans SQL Developer, sur une connexion sans modification en attente, ouvrir [denormalisation.sql](../../sql/04_denormalisation/denormalisation.sql), lancer avec F5 et saisir le lot 6. Le script crée trois tables de comparaison :

| Table | Contenu |
| --- | --- |
| L3_N_RESSOURCES | Séances du lot, avec leurs valeurs typées. |
| L3_N_OPERATIONS | Opérations valides, sans copie du site ni de la catégorie. |
| L3_D_OPERATIONS | Mêmes opérations, avec `id_site` et `categorie` ajoutés. |

Les annulations valides sont conservées dans les deux versions. Les réservations invalides restent dans les tables brutes mais n'entrent pas dans cette comparaison, puisque Q06 porte sur les opérations valides. D'après le chargement et C2, le lot 6 doit fournir 364 516 opérations dans chaque version et 28 571 ressources dans la référence.

Le chargement utilise READ COMMITTED. Pendant la copie, des verrous SHARE empêchent les modifications des quatre tables brutes, tout en laissant les lectures possibles. Des verrous EXCLUSIVE protègent les trois copies L3. Les sources restent ainsi stables pendant les insertions et les vérifications. Les verrous utilisent NOWAIT : si une écriture concurrente les empêche, le script échoue immédiatement et annule la copie. Ils sont libérés au COMMIT ou au ROLLBACK.

Le script compare les effectifs et le contenu des copies dans les deux sens avec MINUS avant de valider. Les tables possèdent des clés primaires comparables ; aucun index de reporting supplémentaire n'est ajouté à une seule version. Les statistiques des trois tables sont ensuite calculées avec les mêmes paramètres.

La préparation ne modifie pas les BRUT_* ni les tables métier L1. Elle crée toutefois des objets Oracle, ce qui implique les commits habituels du DDL. Si un chargement échoue, les insertions sont annulées mais les tables créées restent présentes. Le script refuse de recréer des objets existants et ne supprime rien automatiquement.

### Correction de la première tentative

La première tentative exécutée sur Oracle a créé les trois tables, puis échoué avec ORA-08177 au début de la copie en mode SERIALIZABLE. Les insertions ont été annulées. Cette sortie ne permet pas d'identifier précisément l'origine du conflit ; elle ne constitue pas une préparation L3 réussie.

Le chargement a été corrigé pour utiliser READ COMMITTED et les verrous décrits ci-dessus. Pour une nouvelle installation, lancer uniquement `denormalisation.sql` : il crée les tables et appelle [copier_donnees_l3.sql](../../sql/04_denormalisation/copier_donnees_l3.sql). Ce fichier doit rester dans le même dossier ; il ne se lance pas seul. Le script de reprise utilisé pendant les essais a été retiré de la version livrée.

Le chargement vérifie sous verrou que les trois tables sont entièrement vides. Si une table contient déjà des lignes, il s'arrête sans les supprimer. La copie corrigée exécutée dans SQL Developer sur le lot 6 a confirmé 364 516 opérations dans chaque version, aucun écart de contenu et la fin sans erreur de la collecte des statistiques. Si une future création échoue après le DDL, examiner les objets restants avant toute relance ; aucune suppression automatique n'est prévue.

## Mesurer sur les deux versions

Après la préparation, lancer [mesurer_denormalisation.sql](../../sql/04_denormalisation/mesurer_denormalisation.sql) avec F5, toujours pour le lot 6. Il faut avoir terminé les autres requêtes et garder les copies inchangées pendant la mesure.

Le script vérifie d'abord l'égalité des résultats de Q06 sur les deux versions. Il demande ensuite le nombre de séries, avec 30 par défaut. Chaque série commence par un passage de chauffe par version, puis comporte cinq mesures. L'ordre normalisé/dénormalisé alterne entre les passages et entre les séries. Chaque exécution lit tous les résultats avant d'arrêter le chronomètre ; le temps d'affichage dans SQL Developer n'est pas inclus.

Pour lancer les 30 séries, ouvrir le script avec F5, saisir 6 pour le lot et 30 pour le nombre de séries. Cela produit 150 mesures par version, auxquelles s'ajoutent 30 passages de chauffe par version. Le script affiche chaque mesure, les médianes de chaque série, la médiane de tous les passages, la médiane des médianes et le nombre de séries gagnées, égales ou perdues par la copie dénormalisée. La médiane de 150 valeurs est la moyenne des deux valeurs centrales. Ces deux façons de résumer les temps sont présentées séparément.

La sortie DBMS_OUTPUT peut n'apparaître qu'à la fin du bloc PL/SQL. Attendre sa fin, puis conserver la sortie complète de SQL Developer dans les preuves. Les plans et les tailles ne sont demandés qu'une fois, à la fin des séries. Il ne faut ni recréer les tables ni relancer le chargement pour répéter les mesures.

Les deux premières séries ci-dessous proviennent de la version initiale du script, qui exécutait une seule série de cinq passages à chaque lancement. Elles sont conservées séparément de la campagne automatique de 30 séries, exécutée ensuite sur Oracle.

Le chronomètre a une résolution de 0,01 seconde. Si les temps sont nuls ou trop proches de cette résolution, ils ne permettent pas de conclure. Les mesures sont faites avec un cache déjà sollicité ; aucun cache partagé n'est vidé.

Les requêtes utilisent `gather_plan_statistics`. Le script cherche leurs SQL_ID explicites, puis demande les plans et statistiques avec `DBMS_XPLAN.DISPLAY_CURSOR`. Selon les droits du compte, ces informations peuvent être indisponibles. Oracle demande des droits de lecture sur V$SQL, V$SQL_PLAN, V$SESSION et V$SQL_PLAN_STATISTICS_ALL. Sans ces droits, les temps restent affichés mais les lectures de blocs ne doivent pas être inventées ni remplacées par le coût estimé d'un EXPLAIN PLAN.

Dans les plans, relever les lignes réelles, le temps, les buffers et les lectures physiques lorsqu'ils sont présents. Les buffers représentent des lectures logiques ; les lectures physiques dépendent notamment de l'état du cache. Les tailles allouées aux tables et à leurs index sont affichées à la fin.

| Mesure | Version normalisée | Version dénormalisée |
| --- | --- | --- |
| Nombre d'opérations | 364 516 | 364 516 |
| Résultats de Q06 | Identiques à la copie | Identiques à la référence |
| Médiane de cinq exécutions, série 1 | 0,08 s | 0,06 s |
| Médiane de cinq exécutions, série 2 | 0,07 s | 0,04 s |
| Médiane de 150 exécutions, campagne de 30 séries | 0,07 s | 0,05 s |
| Buffers et lectures physiques | Indisponibles, droits manquants | Indisponibles, droits manquants |
| Taille allouée, tables et index | 49 283 072 octets, soit 47 Mio | 50 331 648 octets, soit 48 Mio |

### Résultats de la première série

Les sorties ont été fournies après exécution dans SQL Developer. Elles sont conservées dans [la preuve du lot 6](../../preuves/L3_normalisation/mesures_oracle_lot_6.txt).

| Passage | Normalisé | Dénormalisé |
| --- | --- | --- |
| 1 | 0,11 s | 0,07 s |
| 2 | 0,08 s | 0,07 s |
| 3 | 0,08 s | 0,06 s |
| 4 | 0,08 s | 0,04 s |
| 5 | 0,10 s | 0,04 s |

La médiane baisse de 0,02 seconde, soit 25 % par rapport à la version normalisée.

### Résultats de la deuxième série

Le script a été relancé sur le même lot. Les résultats de Q06 restent identiques et les tailles allouées sont inchangées. La sortie est conservée à la suite de la première série dans la preuve du lot 6.

| Passage | Normalisé | Dénormalisé |
| --- | --- | --- |
| 1 | 0,07 s | 0,04 s |
| 2 | 0,06 s | 0,04 s |
| 3 | 0,08 s | 0,04 s |
| 4 | 0,06 s | 0,05 s |
| 5 | 0,08 s | 0,04 s |

La deuxième médiane baisse de 0,03 seconde, soit environ 42,9 %. La copie dénormalisée est plus rapide dans chacun des dix passages des deux séries. La baisse du temps médian est donc retrouvée lors du relancement, mais son ampleur varie. Avec un chronomètre gradué à 0,01 seconde et un cache déjà sollicité, ces mesures ne permettent pas de garantir un pourcentage de gain stable ni de le généraliser aux dix requêtes métier.

### Campagne de 30 séries

La sortie Oracle annonce un début de campagne le 1er novembre 2026 à 14:44:24 UTC, soit 15:44:24 à Paris. Elle est conservée intégralement dans [la preuve des 30 séries](../../preuves/L3_normalisation/mesures_oracle_lot_6_30_series.txt). Les 150 couples de mesures ont été relus : les 30 séries comportent chacune cinq passages distincts, et le recalcul des médianes et des effectifs confirme le bilan du script.

| Indicateur | Résultat |
| --- | --- |
| Lot | 6 |
| Résultats de Q06 | Identiques |
| Mesures conservées | 150 par version, hors chauffe |
| Médiane de tous les passages, normalisé / dénormalisé | 0,07 s / 0,05 s |
| Médiane des médianes, normalisé / dénormalisé | 0,07 s / 0,05 s |
| Baisse relative des médianes globales | 28,57 %, soit 0,02 s |
| Séries où la médiane dénormalisée est inférieure / égale / supérieure | 29 / 1 / 0 |
| Passages où le temps dénormalisé est inférieur / égal / supérieur | 143 / 6 / 1 |

Cette campagne retrouve un temps médian inférieur pour Q06 sur la copie dénormalisée. Elle ne montre pas que chaque exécution est plus rapide : un passage est plus lent et six sont à égalité. Les séries se suivent dans la même session, avec un cache sollicité ; elles ne constituent pas 30 expériences indépendantes sur des environnements différents. La résolution reste de 0,01 seconde et les durées sont courtes. Le bilan permet de retenir un gain observé pour Q06 dans ces conditions, sans l'étendre aux autres requêtes ni garantir un gain fixe en production.

La récupération des deux plans a encore échoué avec ORA-00942 sur SYS.V_$SQL. Les temps et l'égalité des résultats ont bien été mesurés ; les lectures logiques et physiques restent inconnues. Les blocs affichés par USER_SEGMENTS décrivent l'espace alloué, pas les blocs lus par une requête.

La référence normalisée totalise 47 Mio : les deux tables et leurs deux index de clé primaire. La copie dénormalisée et son index totalisent 48 Mio, soit 1 Mio de plus (+2,13 %). Ce sont les tailles de segments allouées observées, influencées par l'allocation des extensions et l'état des index. Puisque la référence est conservée, ajouter la copie de reporting consomme en pratique 48 Mio supplémentaires ; le total des objets L3 est de 95 Mio. Le temps de construction et le coût de rafraîchissement n'ont pas été mesurés.

## Mise à jour et limites

La copie sert à la lecture et représente un instantané, pas une table à modifier directement. Une nouvelle réservation, une annulation ou un changement de salle ou de catégorie doit être répercuté dans la copie si elle devient un outil de reporting permanent. Une reconstruction ou un rafraîchissement contrôlé serait alors nécessaire ; aucun rafraîchissement automatique n'est implémenté ici.

Les tables normalisées restent nécessaires. L'espace de la copie s'ajoute donc au stockage existant : il ne le remplace pas. Le temps de construction et le coût des mises à jour devront être pris en compte avant un usage permanent. Les mesures de lecture ne suffisent pas à évaluer ces coûts.

La copie sera intéressante si la baisse du temps ou des lectures est répétable sur les requêtes ciblées et si le besoin de fraîcheur accepte son coût de maintenance. Si les résultats sont proches, conserver la requête normalisée sera plus simple.

Références : [DBMS_XPLAN et ses prérequis](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_XPLAN.html), [collecte des statistiques avec DBMS_STATS](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_STATS.html).
