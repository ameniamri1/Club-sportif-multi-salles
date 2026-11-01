# Normalisation en troisième forme normale

Le fichier à plat est pratique pour lire une réservation complète, mais il répète les descriptions des personnes, des cours et des salles. La décomposition reprend le [modèle relationnel L1](../L1_modelisation/schema_relationnel.md), à partir des [dépendances fonctionnelles](dependances_fonctionnelles.md).

## Passage aux formes normales

Les champs du fichier sont atomiques : une ligne contient une seule réservation, un seul cours et un seul identifiant d'adhérent. La relation est en première forme normale. Dans le jeu local, sa clé est le seul attribut `id_reservation` ; il n'y a donc pas de dépendance partielle sur une partie de cette clé, ce qui satisfait la deuxième forme normale.

La troisième forme normale n'est pas respectée. Le téléphone dépend de l'adhérent, la capacité dépend du cours et le nom de salle dépend du site. Ces déterminants ne sont pas des clés du fichier à plat. La décomposition place ces informations dans leurs entités respectives.

## Relations retenues

| Relation | Clé | Informations qui dépendent de la clé |
| --- | --- | --- |
| SITE | `id_site` | Nom, ville et type de site. La même table remplit les rôles de rattachement et de salle du cours. |
| CATEGORIE | `id_categorie` ; libellé également unique | Libellé de catégorie. |
| USAGER | `id_usager` | Coordonnées retenues, date d'inscription, site de rattachement et parrain facultatif. |
| RESSOURCE | `id_ressource` | Libellé de la séance, catégorie, site, début, durée, capacité et prix. |
| GROUPE_OPERATION | `id_groupe` | Identité du groupe ; aucun site ou propriétaire unique n'est ajouté. |
| OPERATION | `id_operation` | Usager, ressource, date d'exécution, places, montant, statut et groupe facultatif. |

Le site de rattachement reste dans USAGER et le site du cours dans RESSOURCE. OPERATION ne recopie ni les descriptions de l'usager, ni le site et la catégorie de la ressource. Le nombre de places et le montant restent liés à l'opération.

Le parrainage se traduit par une référence facultative de USAGER vers USAGER. Le nom ou les coordonnées du parrain ne sont pas recopiés dans la ligne du filleul.

## Justification de la troisième forme normale

Dans chaque relation, les attributs descriptifs dépendent de sa clé et aucune dépendance transitive retenue ne passe par un autre attribut descriptif. La catégorie est référencée par son identifiant ; le nom de catégorie reste dans CATEGORIE. De même, les noms et villes de sites restent dans SITE.

L'email facultatif ne devient pas une clé candidate totale de USAGER : plusieurs personnes peuvent ne pas avoir d'adresse. L'unicité des emails renseignés accompagne le rapprochement, mais l'identifiant interne reste la clé primaire.

La décomposition respecte donc la 3NF selon les dépendances retenues. Nous ne déduisons pas de nouvelles clés à partir de coïncidences du jeu de données, comme la valeur constante du nombre de places ou l'absence d'un groupe partagé entre plusieurs personnes.

## Reconstitution et conservation des sources

Une opération admise retrouve un seul usager et une seule ressource par leurs clés étrangères. La ressource retrouve son site et sa catégorie par des références obligatoires. Ces jointures sur des clés uniques évitent de multiplier les opérations et permettent de reconstituer leurs descriptions.

La normalisation ne doit pas effacer les défauts de l'archive. Une réservation dont le cours est absent reste dans BRUT_OPERATION et dans le fichier à plat, même si elle ne peut pas être admise avec une FK vers RESSOURCE. La reconstitution sans perte du modèle métier concerne les références résolues ; l'archive complète se relit avec des jointures externes.

Les doublons d'adhérent ne sont pas supprimés. USAGER_SOURCE conserve le lien entre chaque ligne de BRUT_USAGER et la personne retenue. Les coordonnées et l'email d'origine restent accessibles dans BRUT_USAGER, ce qui permet de retrouver les variantes sources même après rapprochement.

## État de l'implémentation

Le [schéma après dénormalisation](schema_apres_denormalisation.md) décrit la référence physique L3 et la copie de reporting ajoutée pour les mesures.

Les tables du modèle L1 existent sur Oracle. Le chargement L2 alimente pour l'instant les tables brutes et ses requêtes passent par les vues. La décomposition décrite ici explique le modèle métier ; elle ne prétend pas que les tables USAGER, RESSOURCE et OPERATION ont déjà été alimentées.

Pour mesurer l'effet d'une dénormalisation, le [script L3](../../sql/04_denormalisation/denormalisation.sql) prépare une référence physique limitée aux opérations et aux ressources. Leurs colonnes sont déjà typées et les clés de personne déjà calculées dans les deux versions. Cette référence permet de comparer une jointure normalisée à une copie de reporting, sans attribuer à la seule dénormalisation le coût des conversions des tables brutes.
