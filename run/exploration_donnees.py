"""Inspection des CSV : python run/exploration_donnees.py (dépendance : pandas)."""

from pathlib import Path
import hashlib

import pandas as pd


RACINE = Path(__file__).resolve().parents[1]


def afficher(titre, resultat):
    print(f"\n--- {titre} ---")
    print(resultat.to_string() if isinstance(resultat, (pd.Series, pd.DataFrame)) else resultat)


def explorer():
    dossier = RACINE / "data" / "raw"
    fichiers = [dossier / f"{nom}.csv" for nom in ("salles", "adherents", "cours", "reservations")]
    empreintes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fichiers}
    jeux = {
        p.stem: pd.read_csv(p, encoding="utf-8-sig", dtype="string", keep_default_na=False)
        for p in fichiers
    }

    afficher("Version de Pandas", pd.__version__)
    for nom, table in jeux.items():
        afficher(f"{nom} : dimensions", f"{len(table):,} lignes, {len(table.columns)} colonnes")
        afficher("Colonnes et types de lecture", table.dtypes)
        afficher("Valeurs manquantes", table.apply(lambda s: s.str.strip().eq("").sum()))
        afficher("Espaces en bordure", table.apply(lambda s: s.ne(s.str.strip()).sum()))
        afficher("Doublons complets", int(table.duplicated().sum()))
        cle = table.columns[0]
        afficher(f"Clé candidate {cle} : doublons excédentaires", int(table[cle].duplicated().sum()))
        for colonne in table:
            valeurs = table.loc[table[colonne].str.strip().ne(""), colonne]
            nombres = pd.to_numeric(valeurs, errors="coerce")
            if len(valeurs) and nombres.notna().all():
                afficher(f"{colonne} : valeurs numériques observées", {
                    "minimum": nombres.min(), "maximum": nombres.max(),
                    "valeurs_distinctes": valeurs.nunique(),
                    "valeurs_non_entieres": int(nombres.mod(1).ne(0).sum()),
                })
            if colonne.startswith("date_") or colonne == "debut":
                dates = pd.to_datetime(valeurs, errors="coerce")
                afficher(f"{colonne} : dates", {
                    "minimum": str(dates.min()), "maximum": str(dates.max()),
                    "non_interpretables": int(dates.isna().sum()),
                })

    salles, adherents, cours, reservations = (jeux[n] for n in ("salles", "adherents", "cours", "reservations"))
    afficher("Sites", salles)
    for nom, source, colonne, cible, cle in (
        ("adhérent → site", adherents, "id_salle", salles, "id_salle"),
        ("cours → site", cours, "id_salle", salles, "id_salle"),
        ("réservation → adhérent", reservations, "id_adherent", adherents, "id_adherent"),
        ("réservation → cours", reservations, "id_cours", cours, "id_cours"),
    ):
        absentes = source.loc[~source[colonne].isin(cible[cle]), colonne]
        afficher(f"Références absentes : {nom}", {"lignes": len(absentes), "identifiants": absentes.nunique()})

    emails = adherents.email.str.lower().str.replace(r"\s+", "", regex=True)
    renseignes = emails[emails.ne("")]
    identites = pd.Series(
        [f"email:{e}" if e else f"id:{i}" for e, i in zip(emails, adherents.id_adherent)],
        index=adherents.id_adherent,
    )
    afficher("Qualité des emails", {
        "vides": int(emails.eq("").sum()),
        "groupes_dupliques": int(renseignes.value_counts().gt(1).sum()),
        "doublons_excedentaires": int(renseignes.duplicated().sum()),
        "modifies_par_minuscules": int(adherents.email.ne(adherents.email.str.lower()).sum()),
        "syntaxe_invalide": int((emails.ne("") & ~emails.str.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")).sum()),
    })
    afficher("Téléphones ne respectant pas dix chiffres avec zéro initial", int((~adherents.telephone.str.match(r"^0[0-9]{9}$")).sum()))
    afficher("Doublons adhérents hors identifiant et email", int(adherents.drop(columns=["id_adherent", "email"]).duplicated().sum()))
    afficher("Doublons réservations hors identifiant", int(reservations.drop(columns="id_reservation").duplicated().sum()))
    afficher("Répétitions du couple adhérent/cours", int(reservations.duplicated(["id_adherent", "id_cours"]).sum()))
    afficher("Statuts bruts", reservations.statut.value_counts())
    afficher("Catégories de cours", cours.categorie.value_counts())

    operations = reservations.merge(cours, on="id_cours", how="left", validate="many_to_one", indicator=True)
    montant = pd.to_numeric(operations.montant, errors="coerce")
    places = pd.to_numeric(operations.nb_places, errors="coerce")
    date_reservation = pd.to_datetime(operations.date_reservation, errors="coerce")
    debut = pd.to_datetime(operations.debut, errors="coerce")
    cours_absent = operations["_merge"].eq("left_only")
    montant_negatif = montant.lt(0)
    trop_tard = date_reservation.gt(debut)
    # La définition du sujet inclut tous les statuts et accepte les montants nuls.
    valide = ~cours_absent & montant.ge(0) & date_reservation.le(debut)
    motifs = pd.DataFrame({"cours_absent": cours_absent, "montant_negatif": montant_negatif, "apres_debut": trop_tard})
    afficher("C2 : opérations invalides", int((~valide).sum()))
    afficher("Motifs individuels (recouvrements possibles)", motifs.sum())
    afficher("Combinaisons des motifs invalides", motifs.loc[~valide].value_counts())
    afficher("Autres contrôles numériques", {
        "places_non_positives": int(places.le(0).sum()),
        "places_non_entieres": int(places.mod(1).ne(0).sum()),
        "montants_non_numeriques": int(montant.isna().sum()),
        "montants_differents_du_prix_fois_places": int((~cours_absent & montant.ne(places * pd.to_numeric(operations.prix_unitaire, errors="coerce"))).sum()),
    })
    for colonne in ("capacite", "duree_minutes", "prix_unitaire"):
        nombres = pd.to_numeric(cours[colonne], errors="coerce")
        afficher(f"Contrôles {colonne}", {"negatifs": int(nombres.lt(0).sum()), "nuls": int(nombres.eq(0).sum())})

    operations["personne"] = operations.id_adherent.map(identites)
    operations["montant_num"] = montant
    operations["places_num"] = places
    valides = operations.loc[valide].copy()
    confirmees = valides.loc[valides.statut.eq("CONFIRMEE")]
    afficher("Opérations valides, tous statuts", len(valides))
    afficher("C1 : personnes distinctes", identites.nunique())
    afficher("C3 : réservations valides confirmées", len(confirmees))
    afficher("C4 : trois journées les plus chargées, opérations valides", pd.to_datetime(valides.date_reservation).dt.strftime("%Y-%m-%d").value_counts().head(3))
    afficher("C5 : CA valide confirmé par site", confirmees.groupby("id_salle").montant_num.sum())
    afficher("C6 : personnes sur plusieurs sites, tous statuts valides", int(valides.groupby("personne").id_salle.nunique().ge(2).sum()))
    afficher("Comparaison C6 par identifiant source", int(valides.groupby("id_adherent").id_salle.nunique().ge(2).sum()))
    capacites = pd.to_numeric(cours.set_index("id_cours").capacite)
    excedents = confirmees.groupby("id_cours").places_num.sum().sub(capacites).dropna()
    afficher("C7 : sur-réservation", {
        "cours": int(excedents.gt(0).sum()),
        "places_excedentaires": int(excedents[excedents.gt(0)].sum()),
        "maximum_par_cours": int(excedents.max()),
    })
    groupes = valides.loc[valides.id_groupe.ne("")].groupby("id_groupe")
    afficher("C8 : groupes valides sur plusieurs sites", int(groupes.id_salle.nunique().ge(2).sum()))
    afficher("C9 : places valides confirmées par catégorie", confirmees.groupby("categorie").places_num.sum())
    afficher("Groupes", {
        "lignes_brutes_groupees": int(reservations.id_groupe.ne("").sum()),
        "groupes_bruts": reservations.loc[reservations.id_groupe.ne(""), "id_groupe"].nunique(),
        "groupes_valides_plusieurs_identifiants_adherent": int(groupes.id_adherent.nunique().gt(1).sum()),
        "groupes_valides_plusieurs_personnes": int(groupes.personne.nunique().gt(1).sum()),
    })

    repartition = salles.set_index("id_salle")[["ville", "role"]].copy()
    for colonne, valeurs in {
        "adherents": adherents.id_salle.value_counts(),
        "cours": cours.id_salle.value_counts(),
        "reservations_rattachables": operations.id_salle.value_counts(),
        "valides": valides.id_salle.value_counts(),
        "valides_confirmees": confirmees.id_salle.value_counts(),
        "ca_valide_confirme": confirmees.groupby("id_salle").montant_num.sum(),
    }.items():
        repartition[colonne] = valeurs.reindex(repartition.index, fill_value=0)
    afficher("Répartition par site du cours", repartition)
    rattachements = adherents.set_index("id_adherent").id_salle
    afficher("Réservations valides hors site de rattachement", int(valides.id_salle.ne(valides.id_adherent.map(rattachements)).sum()))

    # Vérification de conservation des fichiers après l'inspection.
    for fichier in fichiers:
        if hashlib.sha256(fichier.read_bytes()).hexdigest() != empreintes[fichier.name]:
            raise RuntimeError(f"Empreinte modifiée pendant l'inspection : {fichier.name}")
    afficher("Empreintes SHA-256 des sources inchangées", pd.Series(empreintes))


if __name__ == "__main__":
    explorer()
