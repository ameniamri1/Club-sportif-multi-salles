-- À exécuter après create_tables.sql, une seule fois.

-- Les clés de lot et de ligne identifient les sources sans contrôler leurs valeurs métier.
ALTER TABLE lot_source ADD (
    CONSTRAINT pk_lot_source PRIMARY KEY (id_lot)
);

ALTER TABLE brut_salle ADD (
    CONSTRAINT pk_brut_salle PRIMARY KEY (id_lot, numero_ligne),
    CONSTRAINT fk_bs_lot FOREIGN KEY (id_lot) REFERENCES lot_source (id_lot),
    CONSTRAINT ck_bs_numero CHECK (numero_ligne > 0)
);

ALTER TABLE brut_usager ADD (
    CONSTRAINT pk_brut_usager PRIMARY KEY (id_lot, numero_ligne),
    CONSTRAINT fk_bu_lot FOREIGN KEY (id_lot) REFERENCES lot_source (id_lot),
    CONSTRAINT ck_bu_numero CHECK (numero_ligne > 0)
);

ALTER TABLE brut_ressource ADD (
    CONSTRAINT pk_brut_ressource PRIMARY KEY (id_lot, numero_ligne),
    CONSTRAINT fk_br_lot FOREIGN KEY (id_lot) REFERENCES lot_source (id_lot),
    CONSTRAINT ck_br_numero CHECK (numero_ligne > 0)
);

-- RG08-RG13 : aucune FK sur le cours brut, aucun CHECK sur le montant ou la date.
-- Les opérations invalides restent conservées pour les contrôles ultérieurs.
ALTER TABLE brut_operation ADD (
    CONSTRAINT pk_brut_operation PRIMARY KEY (id_lot, numero_ligne),
    CONSTRAINT fk_bo_lot FOREIGN KEY (id_lot) REFERENCES lot_source (id_lot),
    CONSTRAINT ck_bo_numero CHECK (numero_ligne > 0)
);

ALTER TABLE site ADD (
    CONSTRAINT pk_site PRIMARY KEY (id_site),
    -- RG01 : vérifier le rôle ; le nombre exact d'un siège et trois sites
    -- nécessite un contrôle global, non assuré par ce CHECK.
    CONSTRAINT ck_site_type CHECK (type_site IN ('SIEGE', 'SITE'))
);

ALTER TABLE categorie ADD (
    CONSTRAINT pk_categorie PRIMARY KEY (id_categorie),
    -- RG04 / H03 : un même libellé désigne une seule catégorie.
    CONSTRAINT uq_categorie_libelle UNIQUE (libelle)
);

ALTER TABLE usager ADD (
    CONSTRAINT pk_usager PRIMARY KEY (id_usager),
    -- RG15 : un seul usager par email normalisé renseigné.
    -- RG16 : plusieurs NULL sont autorisés ; le rapprochement doit créer
    -- une personne distincte pour chaque ligne source sans email.
    CONSTRAINT uq_usager_email UNIQUE (email_normalise),
    -- RG15 : vérifier les minuscules et l'absence d'espaces, sans transformer l'email.
    CONSTRAINT ck_usager_email CHECK (
        email_normalise = LOWER(email_normalise)
        AND NOT REGEXP_LIKE(email_normalise, '[[:space:]]')
    ),
    -- RG17 / H05 : le rattachement administratif ne limite pas les sites réservables.
    CONSTRAINT fk_usager_site FOREIGN KEY (id_site_rattachement)
        REFERENCES site (id_site),
    -- RG21 : le parrain doit exister ; la FK non unique permet plusieurs filleuls.
    CONSTRAINT fk_usager_parrain FOREIGN KEY (id_parrain)
        REFERENCES usager (id_usager),
    -- RG25 : interdire de se parrainer soi-même ; l'absence de parrain reste autorisée.
    CONSTRAINT ck_usager_parrain CHECK (id_parrain <> id_usager)
);

-- RG15-RG16 : une ligne source correspond au plus à une personne.
-- Ces FK ne vérifient pas l'égalité des emails ni le bon rapprochement :
-- ces deux points doivent être contrôlés au traitement des sources.
ALTER TABLE usager_source ADD (
    CONSTRAINT pk_usager_source PRIMARY KEY (id_lot, numero_ligne),
    CONSTRAINT fk_us_source_brut FOREIGN KEY (id_lot, numero_ligne)
        REFERENCES brut_usager (id_lot, numero_ligne),
    CONSTRAINT fk_us_source_usager FOREIGN KEY (id_usager)
        REFERENCES usager (id_usager)
);

ALTER TABLE ressource ADD (
    CONSTRAINT pk_ressource PRIMARY KEY (id_ressource),
    -- RG04 : la catégorie obligatoire doit exister.
    CONSTRAINT fk_ressource_categorie FOREIGN KEY (id_categorie)
        REFERENCES categorie (id_categorie),
    -- RG02-RG03 : le site doit exister et peut être référencé par plusieurs ressources.
    CONSTRAINT fk_ressource_site FOREIGN KEY (id_site) REFERENCES site (id_site),
    -- H07 : une séance a une durée strictement positive.
    CONSTRAINT ck_ressource_duree CHECK (duree_minutes > 0),
    -- RG05 / H07 : la capacité renseignée doit être strictement positive.
    CONSTRAINT ck_ressource_capacite CHECK (capacite > 0),
    -- H07 : accepter les cours gratuits, refuser les prix négatifs.
    CONSTRAINT ck_ressource_prix CHECK (prix_unitaire >= 0)
);

-- RG18 : chaque groupe a un identifiant unique, réutilisable dans plusieurs opérations.
-- RG19 : son caractère multisite se déduit des sites de ses opérations valides,
-- tous statuts confondus ; cette propriété demande un agrégat, pas un CHECK de ligne.
ALTER TABLE groupe_operation ADD (
    CONSTRAINT pk_groupe_operation PRIMARY KEY (id_groupe)
);

ALTER TABLE operation ADD (
    -- RG22 : l'identifiant de chaque opération est unique et non nul.
    CONSTRAINT pk_operation PRIMARY KEY (id_operation),
    -- RG07 : l'usager associé doit exister.
    CONSTRAINT fk_operation_usager FOREIGN KEY (id_usager)
        REFERENCES usager (id_usager),
    -- RG08-RG13 : la ressource doit exister dans le modèle métier.
    -- RG14 : son site est celui de l'opération, sans recopier id_site.
    CONSTRAINT fk_operation_ressource FOREIGN KEY (id_ressource)
        REFERENCES ressource (id_ressource),
    -- RG18-RG24 : le groupe, s'il est renseigné, doit exister ; la FK reste non unique.
    CONSTRAINT fk_operation_groupe FOREIGN KEY (id_groupe)
        REFERENCES groupe_operation (id_groupe),
    -- RG11-RG23 : autoriser une ou plusieurs places, jamais zéro ni une valeur négative.
    CONSTRAINT ck_operation_places CHECK (nb_places > 0),
    -- RG13 : deuxième condition de validité, montant positif ou nul.
    -- La troisième, date_execution <= ressource.debut, exige un contrôle inter-table.
    -- Ce CHECK ne garantit donc pas à lui seul toute la règle RG13.
    CONSTRAINT ck_operation_montant CHECK (montant >= 0),
    -- RG12 / H06 : autoriser les réservations confirmées et annulées.
    CONSTRAINT ck_operation_statut CHECK (statut IN ('CONFIRMEE', 'ANNULEE'))
);

-- RG20 : le dépassement de capacité se calcule sur les opérations valides confirmées.
-- Aucun CHECK de capacité n'est ajouté : une sur-réservation ne rend pas l'opération
-- invalide selon RG13 et les réservations historiques doivent rester représentables.
