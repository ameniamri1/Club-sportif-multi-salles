"""Génère les scripts de chargement SQL Developer, sans connexion Oracle."""

import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys
import tempfile


RACINE = Path(__file__).resolve().parents[1]
FICHIERS = (
    ("salles.csv", "brut_salle", 4,
     ("id_salle", "nom", "ville", "role")),
    ("adherents.csv", "brut_usager", 20467,
     ("id_adherent", "nom", "prenom", "email", "telephone", "ville", "id_salle", "date_inscription")),
    ("cours.csv", "brut_ressource", 28571,
     ("id_cours", "libelle", "categorie", "id_salle", "debut", "duree_minutes", "capacite", "prix_unitaire")),
    ("reservations.csv", "brut_operation", 365069,
     ("id_reservation", "id_adherent", "id_cours", "date_reservation", "nb_places", "montant", "statut", "id_groupe")),
)


class LignesSource:
    """Garde les lignes physiques consommées par le lecteur CSV pour chaque enregistrement."""

    def __init__(self, fichier):
        self.fichier = fichier
        self.lignes = []

    def __iter__(self):
        return self

    def __next__(self):
        ligne = next(self.fichier)
        self.lignes.append(ligne)
        return ligne


def empreinte(chemin):
    h = hashlib.sha256()
    with chemin.open("rb") as fichier:
        for bloc in iter(lambda: fichier.read(1024 * 1024), b""):
            h.update(bloc)
    return h.hexdigest()


def lire_csv(chemin, colonnes):
    with chemin.open("r", encoding="utf-8-sig", newline="") as fichier:
        source = LignesSource(fichier)
        lecteur = csv.reader(source, delimiter=",", strict=True)
        if next(lecteur, None) != list(colonnes):
            raise ValueError(f"{chemin.name} : en-tête absent ou différent des colonnes attendues.")
        numero = 0
        while True:
            source.lignes.clear()
            try:
                valeurs = next(lecteur)
            except StopIteration:
                break
            numero += 1
            if len(valeurs) != len(colonnes):
                raise ValueError(f"{chemin.name}, enregistrement {numero} : nombre de champs incorrect.")
            originale = "".join(source.lignes)
            if len(originale.encode("utf-8")) > 32767:
                raise ValueError(f"{chemin.name}, enregistrement {numero} : texte original supérieur à 32767 octets.")
            for colonne, valeur in zip(colonnes, valeurs):
                if len(valeur.encode("utf-8")) > 4000:
                    raise ValueError(f"{chemin.name}, enregistrement {numero}, {colonne} : plus de 4000 octets.")
            yield numero, originale, valeurs


def litteral(valeur):
    """Protège les apostrophes, les caractères de contrôle et les limites des littéraux Oracle."""
    if valeur == "":
        return "NULL"
    morceaux = []
    texte = []
    taille = 0

    def terminer():
        if texte:
            morceaux.append("'" + "".join(texte).replace("'", "''") + "'")
            texte.clear()

    for caractere in valeur:
        octets = len(caractere.encode("utf-8"))
        if ord(caractere) < 32 or ord(caractere) == 127:
            terminer()
            taille = 0
            morceaux.append(f"CHR({ord(caractere)})")
        else:
            if taille + octets > 1000:
                terminer()
                taille = 0
            texte.append(caractere)
            taille += octets
    terminer()
    return " || ".join(morceaux)


def ecrire_bloc(sortie, table, colonnes, lignes, libelle):
    debut = lignes[0][0]
    fin = lignes[-1][0]
    sortie.write(f"-- {table} : enregistrements {debut} à {fin}.\nDECLARE\n")
    sortie.write("    TYPE t_textes IS TABLE OF VARCHAR2(32767);\n")
    sortie.write("    TYPE t_numeros IS TABLE OF NUMBER;\n    v_id_lot NUMBER;\n")
    # L'indice FORALL ne peut être utilisé que comme indice de collection.
    sortie.write("    v_numeros t_numeros := t_numeros(" + ", ".join(str(ligne[0]) for ligne in lignes) + ");\n")
    vecteurs = [[ligne[1] for ligne in lignes]]
    vecteurs.extend([[ligne[2][i] for ligne in lignes] for i in range(len(colonnes))])
    for i, valeurs in enumerate(vecteurs):
        sortie.write(f"    v_{i} t_textes := t_textes(\n")
        sortie.write(",\n".join("        " + litteral(valeur) for valeur in valeurs))
        sortie.write("\n    );\n")
    sortie.write("    e_rejets EXCEPTION;\n    PRAGMA EXCEPTION_INIT(e_rejets, -24381);\nBEGIN\n")
    sortie.write(f"    SELECT id_lot INTO v_id_lot FROM lot_source WHERE libelle = {litteral(libelle)};\n")
    sortie.write(f"    FORALL i IN 1 .. {len(lignes)} SAVE EXCEPTIONS\n")
    noms = ", ".join(("id_lot", "numero_ligne", "ligne_originale", *colonnes))
    valeurs = ", ".join(("v_id_lot", "v_numeros(i)", "v_0(i)", *(f"v_{i + 1}(i)" for i in range(len(colonnes)))))
    sortie.write(f"        INSERT INTO {table} ({noms})\n        VALUES ({valeurs});\n")
    sortie.write(f"    IF SQL%ROWCOUNT <> {len(lignes)} THEN\n        RAISE_APPLICATION_ERROR(-20003, 'Nombre de lignes insérées incorrect.');\n    END IF;\n")
    sortie.write("EXCEPTION\n    WHEN e_rejets THEN\n")
    sortie.write("        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP\n")
    sortie.write(f"            DBMS_OUTPUT.PUT_LINE('REJET {table}, numero_ligne=' || ({debut - 1} + SQL%BULK_EXCEPTIONS(j).ERROR_INDEX)\n")
    sortie.write("                || ' : ' || SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));\n        END LOOP;\n")
    sortie.write("        ROLLBACK;\n        RAISE;\n    WHEN OTHERS THEN\n")
    sortie.write(f"        DBMS_OUTPUT.PUT_LINE('ECHEC {table}, bloc {debut}-{fin} : ' || SQLERRM);\n")
    sortie.write("        ROLLBACK;\n        RAISE;\nEND;\n/\n\n")


def initialisation(libelle):
    return f"""-- Créer un lot unique pour ces quatre fichiers, sans modifier les lots existants.
DECLARE
    v_charset VARCHAR2(100);
    v_nombre NUMBER;
    v_id_lot NUMBER;
    v_transaction BOOLEAN := FALSE;
BEGIN
    IF DBMS_TRANSACTION.LOCAL_TRANSACTION_ID(FALSE) IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Utiliser une connexion sans transaction en cours.');
    END IF;
    SELECT value INTO v_charset FROM nls_database_parameters
    WHERE parameter = 'NLS_CHARACTERSET';
    IF v_charset <> 'AL32UTF8' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Une base AL32UTF8 est requise pour préserver les fichiers UTF-8.');
    END IF;
    v_transaction := TRUE;
    LOCK TABLE lot_source IN EXCLUSIVE MODE NOWAIT;
    SELECT COUNT(*) INTO v_nombre FROM lot_source WHERE libelle = {litteral(libelle)};
    IF v_nombre <> 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Ces fichiers possèdent déjà un lot : vérifier ce lot avant tout relancement.');
    END IF;
    INSERT INTO lot_source (libelle) VALUES ({litteral(libelle)})
    RETURNING id_lot INTO v_id_lot;
    DBMS_OUTPUT.PUT_LINE('DEBUT : ID_LOT=' || v_id_lot);
EXCEPTION
    WHEN OTHERS THEN
        IF v_transaction THEN ROLLBACK; END IF;
        DBMS_OUTPUT.PUT_LINE('INITIALISATION REFUSEE : ' || SQLERRM);
        RAISE;
END;
/
"""


def validation_finale(libelle):
    texte = """-- Valider les quatre effectifs dans la transaction avant le seul COMMIT.
DECLARE
    v_id_lot NUMBER;
    v_nombre NUMBER;
    v_min NUMBER;
    v_max NUMBER;
    v_commit_demande BOOLEAN := FALSE;
BEGIN
"""
    texte += f"    SELECT id_lot INTO v_id_lot FROM lot_source WHERE libelle = {litteral(libelle)};\n"
    for _, table, attendu, _ in FICHIERS:
        texte += f"""    SELECT COUNT(*), MIN(numero_ligne), MAX(numero_ligne)
    INTO v_nombre, v_min, v_max FROM {table} WHERE id_lot = v_id_lot;
    IF v_nombre <> {attendu} OR NVL(v_min, 0) <> 1 OR NVL(v_max, 0) <> {attendu} THEN
        RAISE_APPLICATION_ERROR(-20005, 'Chargement incomplet : {table}.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('{table.upper()} : ' || v_nombre || ' lignes contrôlées.');
"""
    texte += """    v_commit_demande := TRUE;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCES : ID_LOT=' || v_id_lot || ', les quatre fichiers sont validés.');
EXCEPTION
    WHEN OTHERS THEN
        IF v_commit_demande THEN
            DBMS_OUTPUT.PUT_LINE('COMMIT INCERTAIN : vérifier le lot dans une nouvelle connexion.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('CHARGEMENT ANNULE : ' || SQLERRM);
        END IF;
        ROLLBACK;
        RAISE;
END;
/
"""
    return texte


def generer(dossier_source, dossier_sortie, taille_lot):
    if dossier_sortie.exists():
        raise ValueError("Le dossier de sortie existe déjà. Choisir un nouveau dossier avec --sortie pour ne rien écraser.")
    dossier_sortie.parent.mkdir(parents=True, exist_ok=True)
    manifeste = {"taille_lot": taille_lot, "fichiers": {}}
    for nom, _, _, _ in FICHIERS:
        manifeste["fichiers"][nom] = {"sha256": empreinte(dossier_source / nom)}
    signature = hashlib.sha256(json.dumps(manifeste["fichiers"], sort_keys=True).encode("utf-8")).hexdigest()
    libelle = "CSV_G08_" + signature
    manifeste["libelle_lot"] = libelle

    # Le dossier final n'apparaît que lorsque les quatre fichiers sont générés.
    with tempfile.TemporaryDirectory(prefix=".generation-", dir=dossier_sortie.parent) as temporaire:
        travail = Path(temporaire)
        scripts = ["00_initialiser_lot.sql"]
        (travail / scripts[0]).write_text(initialisation(libelle), encoding="utf-8", newline="\n")
        for rang, (nom, table, attendu, colonnes) in enumerate(FICHIERS, 1):
            script = f"{rang:02}_{Path(nom).stem}.sql"
            scripts.append(script)
            nombre = 0
            blocs = 0
            with (travail / script).open("w", encoding="utf-8", newline="\n") as sortie:
                sortie.write(f"-- {nom} vers {table.upper()} ; lancer uniquement charger_tout.sql.\n\n")
                sortie.write(f"PROMPT DEBUT {nom} : {attendu} lignes attendues\n")
                lot = []
                for ligne in lire_csv(dossier_source / nom, colonnes):
                    nombre += 1
                    lot.append(ligne)
                    if len(lot) == taille_lot:
                        ecrire_bloc(sortie, table, colonnes, lot, libelle)
                        blocs += 1
                        lot.clear()
                        if blocs % 10 == 0:
                            sortie.write(f"PROMPT {table.upper()} : {nombre}/{attendu} lignes insérées, en attente du COMMIT final\n")
                if lot:
                    ecrire_bloc(sortie, table, colonnes, lot, libelle)
                    blocs += 1
                sortie.write(f"PROMPT FIN {nom} : {nombre} lignes insérées, en attente du COMMIT final\n")
            if nombre != attendu:
                raise ValueError(f"{nom} : {nombre} lignes lues au lieu de {attendu}. Aucun dossier SQL final publié.")
            manifeste["fichiers"][nom].update({"table": table.upper(), "lignes": nombre, "blocs": blocs, "script": script})
            print(f"{nom} : {nombre} lignes, {blocs} blocs.")
        for nom, _, _, _ in FICHIERS:
            if empreinte(dossier_source / nom) != manifeste["fichiers"][nom]["sha256"]:
                raise ValueError(f"{nom} a changé pendant la génération : recommencer avec des sources stables.")
        scripts.append("05_valider_lot.sql")
        (travail / scripts[-1]).write_text(validation_finale(libelle), encoding="utf-8", newline="\n")
        pilote = """-- Ouvrir ce fichier avec SQL Developer et lancer le script entier avec F5.
-- Utiliser une connexion dédiée, sans modifications en attente, et désactiver l'autocommit.
SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET AUTOCOMMIT OFF
WHENEVER OSERROR EXIT FAILURE ROLLBACK
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
"""
        pilote += "\n".join("@@" + script for script in scripts)
        pilote += "\nWHENEVER SQLERROR CONTINUE NONE\nWHENEVER OSERROR CONTINUE NONE\nSET FEEDBACK ON\n"
        (travail / "charger_tout.sql").write_text(pilote, encoding="utf-8", newline="\n")
        (travail / "manifest.json").write_text(json.dumps(manifeste, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        # Renommer le dossier préparé évite de publier une génération incomplète.
        publication = travail / "publication"
        publication.mkdir()
        for chemin in list(travail.iterdir()):
            if chemin != publication:
                chemin.rename(publication / chemin.name)
        publication.rename(dossier_sortie)
    print(f"Scripts prêts : {dossier_sortie / 'charger_tout.sql'}")
    print("Aucune connexion Oracle effectuée. Les CSV sont inchangés.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=RACINE / "data/raw", help="Dossier des quatre CSV.")
    parser.add_argument("--sortie", type=Path, default=RACINE / "sql/02_import/generated", help="Nouveau dossier des scripts SQL.")
    parser.add_argument("--taille-lot", type=int, default=500, help="Enregistrements par bloc, entre 1 et 500.")
    args = parser.parse_args()
    if not 1 <= args.taille_lot <= 500:
        parser.error("--taille-lot doit être compris entre 1 et 500.")
    try:
        generer(args.source.resolve(), args.sortie.resolve(), args.taille_lot)
    except (OSError, UnicodeError, csv.Error, ValueError) as erreur:
        print(f"Génération refusée : {erreur}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
