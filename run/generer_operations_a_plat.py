"""Construit le fichier à plat de L3 à partir des CSV, sans connexion Oracle."""

import argparse
import csv
import hashlib
from pathlib import Path
import re
import sys
import tempfile


RACINE = Path(__file__).resolve().parents[1]
COLONNES = (
    "id_reservation", "id_adherent", "id_cours", "date_reservation", "nb_places", "montant", "statut", "id_groupe",
    "nom_usager", "prenom_usager", "email_source", "email_normalise", "cle_personne", "telephone", "ville_usager", "date_inscription",
    "id_salle_rattachement", "nom_salle_rattachement", "ville_salle_rattachement", "role_salle_rattachement",
    "libelle_cours", "categorie", "debut_cours", "duree_minutes", "capacite", "prix_unitaire",
    "id_salle_cours", "nom_salle_cours", "ville_salle_cours", "role_salle_cours", "ressource_presente",
)


def empreinte(chemin):
    h = hashlib.sha256()
    with chemin.open("rb") as fichier:
        for bloc in iter(lambda: fichier.read(1024 * 1024), b""):
            h.update(bloc)
    return h.hexdigest()


def indexer(chemin, cle):
    resultat = {}
    with chemin.open(encoding="utf-8-sig", newline="") as fichier:
        for numero, ligne in enumerate(csv.DictReader(fichier, strict=True), 1):
            identifiant = ligne.get(cle)
            if not identifiant or identifiant in resultat or None in ligne or None in ligne.values():
                raise ValueError(f"{chemin.name}, ligne {numero} : identifiant absent, répété ou structure incorrecte.")
            resultat[identifiant] = (numero, ligne)
    return resultat


def generer(source, destination):
    if destination.exists():
        raise ValueError("Le fichier de sortie existe déjà. Utiliser --sortie pour choisir un nouveau fichier.")
    fichiers = [source / nom for nom in ("salles.csv", "adherents.csv", "cours.csv", "reservations.csv")]
    signatures = {p: empreinte(p) for p in fichiers}
    salles = indexer(source / "salles.csv", "id_salle")
    usagers = indexer(source / "adherents.csv", "id_adherent")
    cours = indexer(source / "cours.csv", "id_cours")
    destination.parent.mkdir(parents=True, exist_ok=True)
    compte = 0
    absentes = 0
    identifiants = set()
    with tempfile.TemporaryDirectory(prefix=".aplatissement-", dir=destination.parent) as temporaire:
        travail = Path(temporaire) / "operations.csv"
        with travail.open("w", encoding="utf-8", newline="") as sortie:
            writer = csv.DictWriter(sortie, fieldnames=COLONNES, lineterminator="\n")
            writer.writeheader()
            with (source / "reservations.csv").open(encoding="utf-8-sig", newline="") as fichier:
                for operation in csv.DictReader(fichier, strict=True):
                    compte += 1
                    if None in operation or None in operation.values():
                        raise ValueError(f"reservations.csv, ligne {compte} : structure incorrecte.")
                    identifiant = operation["id_reservation"]
                    if not identifiant or identifiant in identifiants:
                        raise ValueError(f"Réservation sans identifiant ou répétée, ligne {compte}.")
                    identifiants.add(identifiant)
                    if operation["id_adherent"] not in usagers:
                        raise ValueError(f"Usager absent, réservation {identifiant} : rapprochement à examiner.")
                    numero_usager, usager = usagers[operation["id_adherent"]]
                    ressource = cours.get(operation["id_cours"], (None, {}))[1]
                    rattachement = salles.get(usager["id_salle"], (None, {}))[1]
                    site_cours = salles.get(ressource.get("id_salle"), (None, {}))[1]
                    email = re.sub(r"\s+", "", usager["email"]).lower()
                    ligne = dict(operation)
                    ligne.update({
                        "nom_usager": usager["nom"], "prenom_usager": usager["prenom"],
                        "email_source": usager["email"], "email_normalise": email,
                        "cle_personne": "EMAIL:" + email if email else "LIGNE:" + str(numero_usager),
                        "telephone": usager["telephone"], "ville_usager": usager["ville"],
                        "date_inscription": usager["date_inscription"], "id_salle_rattachement": usager["id_salle"],
                        "nom_salle_rattachement": rattachement.get("nom", ""),
                        "ville_salle_rattachement": rattachement.get("ville", ""),
                        "role_salle_rattachement": rattachement.get("role", ""),
                        "libelle_cours": ressource.get("libelle", ""), "categorie": ressource.get("categorie", ""),
                        "debut_cours": ressource.get("debut", ""), "duree_minutes": ressource.get("duree_minutes", ""),
                        "capacite": ressource.get("capacite", ""), "prix_unitaire": ressource.get("prix_unitaire", ""),
                        "id_salle_cours": ressource.get("id_salle", ""), "nom_salle_cours": site_cours.get("nom", ""),
                        "ville_salle_cours": site_cours.get("ville", ""), "role_salle_cours": site_cours.get("role", ""),
                        "ressource_presente": "1" if ressource else "0",
                    })
                    absentes += not bool(ressource)
                    writer.writerow(ligne)
        if compte != 365069:
            raise ValueError(f"{compte} opérations lues au lieu des 365069 attendues.")
        if any(empreinte(p) != signature for p, signature in signatures.items()):
            raise ValueError("Un CSV a changé pendant la génération.")
        travail.rename(destination)
    print(f"{compte} opérations exportées, dont {absentes} références à des cours absents.")
    print(f"Fichier : {destination}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=RACINE / "data/raw")
    parser.add_argument("--sortie", type=Path, default=RACINE / "data/derived/operations_a_plat.csv")
    args = parser.parse_args()
    try:
        generer(args.source.resolve(), args.sortie.resolve())
    except (OSError, UnicodeError, ValueError, KeyError, csv.Error) as erreur:
        print(f"Export refusé : {erreur}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
