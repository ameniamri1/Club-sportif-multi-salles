-- Contrôles techniques avant les agrégats, sans modifier la définition de validité.
DECLARE
    v_nombre NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_nombre FROM v_operations_validation WHERE id_lot = &&lot_import;
    IF v_nombre <> 365069 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Les jointures ne conservent pas une ligne par réservation source.');
    END IF;
    SELECT COUNT(*) INTO v_nombre FROM v_operations_validation
    WHERE id_lot = &&lot_import
      AND (conversion_a_verifier = 1 OR cle_personne IS NULL OR nb_places IS NULL);
    IF v_nombre > 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 'Conversion ou référence usager à examiner dans validate_data.sql avant les agrégats.');
    END IF;
    SELECT COUNT(*) INTO v_nombre FROM v_ressources_source r
    WHERE r.id_lot = &&lot_import
      AND (r.capacite IS NULL OR NOT EXISTS (
          SELECT 1 FROM brut_salle s WHERE s.id_lot = r.id_lot AND s.id_salle = r.id_salle
      ));
    IF v_nombre > 0 THEN
        RAISE_APPLICATION_ERROR(-20022, 'Capacité ou site de ressource à examiner avant les agrégats.');
    END IF;
END;
/
