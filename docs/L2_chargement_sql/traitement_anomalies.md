# Traitement des anomalies

Nous gardons toutes les lignes des CSV dans les tables BRUT_*, même lorsqu'une référence ou un montant est incorrect. Cela permet de retrouver chaque anomalie et de calculer les contrôles sur le jeu complet. [validate_data.sql](../../sql/02_import/validate_data.sql) prépare les vues qui servent à examiner ces données.

| Défaut ou situation | Traitement |
| --- | --- |
| Cours inexistant | Ligne conservée dans BRUT_OPERATION ; `ressource_absente = 1`. |
| Montant négatif | Valeur d'origine conservée ; `montant_negatif = 1`. |
| Réservation après le début du cours | Date conservée ; `date_tardive = 1`. L'égalité des dates est acceptée. |
| Plusieurs motifs sur une ligne | Chaque indicateur est renseigné séparément ; une même opération n'est comptée qu'une fois dans le total d'invalides. |
| Montant ou date impossible à convertir | Valeur source accessible, conversion à NULL et indicateur `conversion_a_verifier = 1`. Si aucun critère ne permet déjà de conclure à l'invalidité, `est_valide` reste NULL. Les agrégats demandent d'examiner ce cas avant de poursuivre. |
| Email vide ou composé uniquement d'espaces | Une clé de personne propre à la ligne source est attribuée dans la vue. Aucun rapprochement entre valeurs NULL. |
| Emails identiques après normalisation | Minuscules et suppression des caractères d'espacement ; même clé de personne, sans suppression des lignes sources. |
| Réservation annulée | Reste valide si elle respecte RG13. Le statut CONFIRMEE est filtré uniquement dans les calculs qui le demandent. |
| Sur-réservation | Ne change pas `est_valide`. Elle est mesurée séparément pour C7. |
| Places, statut ou référence à un usager incorrects | Anomalie distincte, affichée sans ajouter de critère à RG13. Une conversion de places impossible ou une personne introuvable bloque les agrégats concernés. |
| Identifiant source absent ou répété | Toutes les lignes sont conservées. Le contrôle technique bloque les jointures de l'analyse pour éviter de multiplier ou perdre des réservations. |
| CSV illisible, mauvais nombre de champs ou valeur trop longue | Génération SQL refusée sans publication d'un dossier partiel ; fichier et numéro d'enregistrement signalés. |
| Rejet Oracle au chargement | Bloc identifié, erreurs détaillées et rollback de l'import. Aucune ligne partielle n'est validée. |

Une réservation est valide si le cours existe, si son montant est positif ou nul et si elle a été passée au plus tard au début du cours. Ce sont les trois conditions de RG13. Une annulation ou une sur-réservation ne change pas cette définition.

Les réservations retrouvent leur cours avec l'identifiant source et le même `id_lot`. Ce lien évite de prendre un cours dans un autre lot. Les identifiants des fichiers fournis ont déjà une écriture cohérente ; ils sont conservés en texte dans les tables brutes.

Pour L2, les requêtes passent par les vues des données sources. Les lignes invalides restent dans BRUT_OPERATION et les doublons d'adhérent dans BRUT_USAGER. Le rapprochement des personnes est calculé dans V_USAGERS_SOURCE ; il ne supprime aucune ligne et ne remplit pas encore la table USAGER.
