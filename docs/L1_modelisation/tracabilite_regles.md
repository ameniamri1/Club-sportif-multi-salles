# Traçabilité des règles — M1-1

Chaque [règle de gestion](regles_gestion.md) se traduit par une relation, une contrainte ou un contrôle à effectuer lors du traitement des données. Le tableau reprend les contraintes de [`create_tables.sql`](../../sql/01_schema/create_tables.sql) et de [`constraints.sql`](../../sql/01_schema/constraints.sql).

| Règle | Entités ou associations | Traduction et contraintes | Validation complémentaire |
| --- | --- | --- | --- |
| RG01 | SITE, rôle siège/site | `pk_site`, `nn_site_type`, `ck_site_type` distinguent les rôles. | La présence d'exactement un siège et trois sites est un contrôle global à faire après initialisation et lors d'une modification de l'organisation. Un CHECK de ligne ne compte pas les autres lignes. |
| RG02 | SITE accueille RESSOURCE | `nn_res_site`, `fk_ressource_site` : une seule référence obligatoire. | Aucune pour cette cardinalité dans les tables métier. |
| RG03 | SITE accueille RESSOURCE | La FK `fk_ressource_site` n'est pas unique : plusieurs ressources peuvent partager le site. | Un site peut n'avoir aucune ressource, notamment le siège. |
| RG04 | CATEGORIE classe RESSOURCE | `nn_res_categorie`, `fk_ressource_categorie`, `pk_categorie`. | Le classement des libellés sources sera fait au chargement ; pas de liste fermée des catégories. |
| RG05 | RESSOURCE.capacite | `nn_res_capacite` ; type entier. H07 ajoute `ck_ressource_capacite`. | La capacité strictement positive est un choix métier complémentaire, pas une condition de validité d'opération. |
| RG06 | RESSOURCE.debut | `nn_res_debut`, type `TIMESTAMP(0)`. | Conversion de la date source au chargement. |
| RG07 | USAGER effectue OPERATION | `nn_ope_usager`, `fk_operation_usager`. La référence brute reste dans BRUT_OPERATION. | Résoudre l'identifiant d'adhérent source via BRUT_USAGER et USAGER_SOURCE dans le même lot. Une absence d'usager serait une anomalie d'admission séparée de RG13. |
| RG08 | RESSOURCE concerne OPERATION ; BRUT_OPERATION | `nn_ope_ressource`, `fk_operation_ressource` pour le métier. Aucune FK sur `BRUT_OPERATION.id_cours`. | Conserver le cours absent comme valeur source ; ne pas créer une ressource fictive. |
| RG09 | OPERATION.date_execution | `nn_ope_date`, type `TIMESTAMP(0)` ; texte conservé dans BRUT_OPERATION. | Conversion de la date source, sans remplacer une date incorrecte. |
| RG10 | OPERATION.montant | `nn_ope_montant`, type `NUMBER(14,2)` ; montant brut textuel conservé. | Les montants négatifs restent disponibles dans BRUT_OPERATION. |
| RG11 | OPERATION.nb_places | `nn_ope_places`, entier et `ck_operation_places`. | La valeur peut être supérieure à 1 malgré l'unique valeur observée dans les fichiers. |
| RG12 | OPERATION.statut | `nn_ope_statut`, `ck_operation_statut` autorisent `CONFIRMEE` et, selon H06, `ANNULEE`. | Le statut ne participe pas à la définition de validité de RG13. |
| RG13 | OPERATION, RESSOURCE, sources brutes | `fk_operation_ressource` couvre l'existence ; `nn_ope_montant` et `ck_operation_montant` couvrent le montant. Les dates sont obligatoires côté métier. | Comparer la date d'exécution au début de la ressource par traitement d'admission ou requête de validation. Revoir aussi les opérations liées si une date est modifiée. Le prédicat officiel ne comporte que ces trois conditions. |
| RG14 | OPERATION → RESSOURCE → SITE | `fk_operation_ressource`, `fk_ressource_site`. Aucun `id_site` stocké dans OPERATION. | Obtenir le site par la ressource. Pour une référence brute absente, le site est indéterminable. |
| RG15 | USAGER, BRUT_USAGER, USAGER_SOURCE | `ck_usager_email`, `uq_usager_email`, `fk_us_source_brut`, `fk_us_source_usager`. | Normaliser l'email puis faire pointer toutes les lignes correspondantes vers le même usager ; vérifier que la correspondance respecte cet email. Une FK seule ne compare pas les emails de deux tables. |
| RG16 | USAGER, USAGER_SOURCE | `pk_usager` donne une identité indépendante ; `uq_usager_email` autorise plusieurs NULL ; `pk_usager_source` évite plusieurs correspondances pour une ligne. | Créer un usager distinct pour chaque ligne source sans email et vérifier qu'aucun regroupement n'a été fait sur NULL, le nom ou le téléphone. |
| RG17 | USAGER → OPERATION → RESSOURCE → SITE | Les FK n'imposent aucune égalité entre site de rattachement et site du cours. | Aucune restriction supplémentaire à appliquer. |
| RG18 | GROUPE_OPERATION regroupe OPERATION | `fk_operation_groupe` est non unique ; `pk_groupe_operation` identifie le groupe. | Plusieurs opérations peuvent référencer le même groupe. |
| RG19 | GROUPE_OPERATION, OPERATION, RESSOURCE | Les sites d'un groupe se retrouvent par ses opérations et leurs ressources. | Compter les sites distincts des opérations valides, tous statuts confondus. À partir de deux sites, le groupe est multisite. |
| RG20 | RESSOURCE, OPERATION | Capacité et places sont stockées ; aucun CHECK de somme ni rejet des historiques en sur-réservation. | Comparer les places des opérations valides confirmées à la capacité. Le dépassement ne change pas RG13. La protection des nouvelles réservations relève du traitement transactionnel ultérieur. |
| RG21 | USAGER parraine USAGER | `fk_usager_parrain` ; `id_parrain` est une colonne facultative et non unique. | Un seul parrain par filleul, plusieurs filleuls par parrain. Aucune donnée source ne permet de renseigner cette extension. |
| RG22 | OPERATION | `pk_operation`. En source, `pk_brut_operation` identifie chaque ligne indépendamment de la valeur brute de réservation. | Détecter un éventuel identifiant source répété lors de l'admission ; ne pas perdre les lignes brutes concernées. |
| RG23 | OPERATION.nb_places | `nn_ope_places`, `ck_operation_places` imposent une valeur entière strictement positive. | Une violation éventuelle relève de l'intégrité métier ; elle n'ajoute pas un quatrième critère à RG13. |
| RG24 | GROUPE_OPERATION regroupe OPERATION | `id_groupe` nullable et `fk_operation_groupe` : zéro ou un groupe par opération. | Un champ source vide sera représenté par NULL dans le modèle métier. |
| RG25 | USAGER parraine USAGER | `ck_usager_parrain` interdit `id_parrain = id_usager`. NULL reste autorisé. | Aucun contrôle de cycles entre plusieurs personnes n'est ajouté aux règles demandées. |

## Règles qui demandent un contrôle supplémentaire

Une contrainte suffit pour imposer un montant positif ou nul, une référence existante ou l'interdiction de se parrainer. D'autres règles demandent de comparer plusieurs lignes ou plusieurs tables :

- Le nombre exact de sièges et de sites doit être vérifié sur l'ensemble de l'organisation, à l'initialisation puis à chaque changement.
- La date d'une réservation doit être comparée au début du cours. Ce contrôle reste nécessaire si l'une des dates est modifiée.
- Le rapprochement des personnes doit respecter les emails normalisés tout en gardant une personne distincte pour chaque ligne sans email.
- Le caractère multisite d'un groupe et la sur-réservation d'un cours se calculent à partir des opérations concernées.

L'unicité des emails et des libellés de catégorie, les domaines de statut et de type de site, ainsi que les contrôles de durée, capacité et prix sont les choix complémentaires H01 à H08. Ils s'appliquent aux tables métier. Les seules contraintes sur les tables brutes concernent le lot, le numéro de ligne et la présence de l'enregistrement original.
