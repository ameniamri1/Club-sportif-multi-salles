# Opérations à plat

Le fichier à plat rassemble les informations d'une réservation, de son adhérent et de son cours sur une même ligne. Il permet de voir les répétitions qui disparaissent lorsque ces informations sont réparties dans plusieurs tables.

## Fichier utilisé

Le fichier `data/derived/operations_a_plat.csv` est produit à partir des quatre CSV d'origine :

```powershell
python run/generer_operations_a_plat.py
```

Le générateur utilise uniquement Python et sa bibliothèque standard. Il n'accède pas à Oracle. Le fichier contient les 365 069 réservations, y compris les invalides et les annulations. Il est ignoré par Git et peut être reconstruit. Si le fichier existe déjà, le script demande de choisir un autre chemin avec `--sortie` plutôt que de l'écraser.

## Contenu d'une ligne

| Groupe | Champs |
| --- | --- |
| Réservation | `id_reservation`, `id_adherent`, `id_cours`, `date_reservation`, `nb_places`, `montant`, `statut`, `id_groupe` |
| Adhérent | `nom_usager`, `prenom_usager`, `email_source`, `email_normalise`, `cle_personne`, `telephone`, `ville_usager`, `date_inscription` |
| Site de rattachement | `id_salle_rattachement`, `nom_salle_rattachement`, `ville_salle_rattachement`, `role_salle_rattachement` |
| Cours | `libelle_cours`, `categorie`, `debut_cours`, `duree_minutes`, `capacite`, `prix_unitaire` |
| Site du cours | `id_salle_cours`, `nom_salle_cours`, `ville_salle_cours`, `role_salle_cours` |
| Présence du cours | `ressource_presente`, égal à 1 si le cours existe, sinon 0 |

Les valeurs d'origine restent textuelles. L'email normalisé et la clé de personne sont ajoutés pour distinguer une personne de ses éventuels identifiants d'adhérent multiples. Le nom, la casse de l'email source, les dates et les montants ne sont pas corrigés dans cet export.

## Réservations dont le cours est absent

Une jointure interne aurait perdu les 378 réservations qui désignent un cours absent. Elles restent donc dans le fichier avec leur `id_cours` source, `ressource_presente = 0` et les informations du cours laissées vides. Aucune séance fictive n'est créée pour remplir ces champs.

La présence du cours n'est pas un indicateur complet de validité : un cours peut exister alors que le montant est négatif ou la réservation trop tardive. Le fichier à plat ne remplace pas les contrôles de RG13.

## Version Oracle

[operations_a_plat.sql](../../sql/04_denormalisation/operations_a_plat.sql) prépare la vue V_OPERATIONS_A_PLAT avec les mêmes informations, plus `id_lot` et `numero_ligne` pour la traçabilité. Le script se lance avec F5, après la fin des requêtes L2, en indiquant le lot 6.

Le fichier local contient un seul jeu de données ; `id_reservation` y est unique. Dans la vue Oracle, la clé est `(id_lot, id_reservation)`, car deux lots peuvent réutiliser les mêmes identifiants sources. Les informations du cours et des salles sont obtenues par jointures externes.

Le contrôle Oracle doit retrouver 365 069 lignes et autant d'identifiants de réservation distincts pour le lot 6. Cette vue n'a pas encore été créée sur Oracle ; le fichier CSV est préparé localement pour l'étude.

## Répétitions à éliminer dans le modèle métier

Un adhérent qui réserve dix cours apparaît dix fois avec ses coordonnées. De même, une séance est répétée pour chaque réservation, avec son horaire, sa capacité et le nom de sa salle. Cette organisation pose trois problèmes :

- Un changement d'adresse ou de capacité oblige à modifier plusieurs lignes.
- Un cours sans réservation n'a aucune ligne dans ce fichier.
- Supprimer la dernière réservation d'un cours fait disparaître sa description du fichier à plat.

Le modèle normalisé conserve séparément les usagers, les ressources et les sites. Les réservations portent leurs identifiants, sans recopier leurs descriptions.
