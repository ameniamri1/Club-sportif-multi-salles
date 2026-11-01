# Journal de bord

## 2026-11-01

- Mise en place du dossier de travail pour L1, L2 et L3, puis copie des quatre CSV dans `data/raw/`.
- Initialisation du dépôt Git et publication de la structure sur GitHub.
- Exploration des fichiers avec Pandas et ajout du script dans `run/` pour pouvoir relancer les calculs.
- Correction du calcul de C6 : il faut inclure les annulations valides et regrouper les adhérents par email normalisé. Le résultat est de 12 258 personnes sur plusieurs sites.
- Création des tables et contraintes L1 sur Oracle. Les captures sont rangées dans `preuves/`.
- Préparation du chargement L2 : génération locale des fichiers SQL, insertions par blocs et validation des quatre fichiers dans une même transaction.
- Les premiers essais dans SQL Developer affichaient `DEBUT : ID_LOT=...`, puis se terminaient sans message de succès. Les comptages renvoyaient zéro ligne et le lot recherché n'était pas visible dans la connexion utilisée.
- Une erreur a été trouvée dans le SQL généré : le numéro de ligne utilisait directement l'indice `i` du FORALL dans une expression. Cet indice doit uniquement servir à accéder à une collection. La génération utilise désormais `v_numeros(i)`.
- Régénération des scripts avec des messages de progression. Le chargement corrigé s'est terminé avec succès sur le lot 6 : 4 salles, 20 467 adhérents, 28 571 cours et 365 069 réservations.
- Vérification des quatre effectifs dans Oracle, puis création des vues de validation. La sortie contient 553 réservations à examiner, 33 emails manquants et 102 lignes avec un email normalisé partagé. Les recherches complémentaires d'anomalies techniques n'ont renvoyé aucune ligne.
- Nettoyage des anciennes générations et du cache Python. La version utilisée pour l'import est conservée dans `sql/02_import/generated/`. Le lanceur PowerShell non implémenté a été retiré.
- Exécution des contrôles C1 à C9 sur le lot 6. Les résultats correspondent à l'exploration des CSV, notamment 20 416 personnes, 553 opérations invalides et 12 258 personnes ayant réservé sur plusieurs sites. Le tableau complet et la sortie Oracle sont conservés avec les documents L2 et les preuves.
