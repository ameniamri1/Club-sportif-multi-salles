# Dépendances fonctionnelles

Une dépendance fonctionnelle indique qu'une même valeur de départ impose une seule valeur d'arrivée. Dans le fichier à plat, une réservation identifie par exemple son adhérent, son cours et son montant.

L'étude ci-dessous se place dans un seul jeu de données. Dans une base contenant plusieurs lots, il faut ajouter `id_lot` aux identifiants sources.

## Dépendances retenues

| Repère | Dépendance | Origine |
| --- | --- | --- |
| DF01 | `id_reservation → id_adherent, id_cours, date_reservation, nb_places, montant, statut, id_groupe` | RG07 à RG12, RG22 et RG24 : une opération possède un identifiant unique et ses propres valeurs. |
| DF02 | `id_adherent → nom_usager, prenom_usager, email_source, telephone, ville_usager, date_inscription, id_salle_rattachement` | Une ligne d'adhérent du fichier est identifiée par `id_adherent`. |
| DF03 | `id_adherent → email_normalise, cle_personne` | Le rapprochement utilise l'email de cette ligne ; l'absence d'email donne une clé propre à la ligne. |
| DF04 | `id_cours → libelle_cours, categorie, debut_cours, duree_minutes, capacite, prix_unitaire, id_salle_cours` | RG02 et RG04 à RG06 : une ressource décrit une séance datée. Cette dépendance porte sur les cours existants. |
| DF05 | `id_salle_rattachement → nom_salle_rattachement, ville_salle_rattachement, role_salle_rattachement` | Identité du site administratif, dans le rôle de rattachement. |
| DF06 | `id_salle_cours → nom_salle_cours, ville_salle_cours, role_salle_cours` | Même entité SITE, utilisée dans le rôle de salle du cours. |

Les descriptions d'un cours absent restent inconnues dans l'archive à plat. La démonstration de normalisation porte sur les entités connues et les références résolues ; une référence incorrecte n'est pas transformée en ressource pour satisfaire une FK.

La catégorie est un libellé dans les CSV. Dans le modèle L1, elle reçoit un identifiant interne : `id_categorie → libelle`, et le libellé est également unique selon H03. Cela permet de modifier son nom sans changer toutes les ressources.

## Identité des personnes

`id_adherent` identifie une ligne source ; il ne constitue pas toujours l'identifiant d'une personne distincte. Deux identifiants peuvent avoir le même email normalisé et représenter la même personne.

Lorsque l'email est renseigné, son écriture normalisée permet de retrouver la personne. Une valeur NULL ne constitue pas une clé : chaque ligne sans email reçoit une identité différente. Les coordonnées sources restent rattachées à leur ligne d'origine. Si deux lignes rapprochées présentent des coordonnées différentes, le choix des coordonnées métier doit être explicite ; la règle sur les emails ne suffit pas à le trancher.

Dans le modèle métier, `id_usager → coordonnées retenues, id_site_rattachement, id_parrain`. Cette dépendance tient à l'identité attribuée dans USAGER après rapprochement, pas à l'hypothèse que les noms ou les téléphones seraient uniques.

## Dépendances que nous ne retenons pas

| Proposition | Pourquoi elle n'est pas une règle du modèle |
| --- | --- |
| `(id_adherent, id_cours) → id_reservation` | Le même couple peut correspondre à plusieurs opérations. |
| `id_groupe → id_salle_cours` | Un groupe peut concerner plusieurs salles. |
| `id_groupe → id_adherent` | Les règles n'imposent pas un identifiant d'adhérent unique pour un groupe. |
| `id_adherent → id_salle_cours` | L'adhérent peut réserver en dehors de sa salle de rattachement. |
| `nom_usager → id_adherent` ou `telephone → id_adherent` | Ni le nom ni le téléphone ne sont définis comme identifiants uniques. |
| `prix_unitaire, nb_places → montant` | Le montant appartient à l'opération. Une égalité observée dans les données ne suffit pas à imposer cette dépendance pour tous les usages futurs. |
| `nb_places = 1` comme règle permanente | C'est une valeur constante du jeu fourni, alors que RG11 autorise plusieurs places. |

## Clé et dépendances transitives

Sur les lignes dont les références sont résolues, la fermeture de `id_reservation` permet de retrouver les informations de l'adhérent, du cours et des deux sites. C'est donc une clé du fichier à plat dans ce jeu de données.

Les déterminants `id_adherent`, `id_cours` et les identifiants de site ne sont pas des clés de ce fichier : chacun peut être répété sur plusieurs réservations. Ils déterminent pourtant des attributs descriptifs. Par exemple :

```text
id_reservation → id_cours → id_salle_cours → nom_salle_cours
id_reservation → id_adherent → telephone
```

Ces dépendances transitives expliquent pourquoi les descriptions doivent être séparées des opérations pour atteindre la troisième forme normale.
