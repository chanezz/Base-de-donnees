prompt -------------------------------------------;
prompt --  Creation de procedure de suppression --;
prompt -------------------------------------------;

CREATE PROCEDURE delete_if_exists(p_type VARCHAR2, p_name VARCHAR2)
IS
BEGIN
  IF p_type = 'table' THEN EXECUTE IMMEDIATE 'DROP TABLE ' || p_name;
  ELSIF p_type = 'tuple' THEN EXECUTE IMMEDIATE 'DELETE FROM ' || p_name;
  ELSIF p_type = 'function' THEN EXECUTE IMMEDIATE 'DROP FUNCTION ' || p_name;
  ELSIF p_type = 'procedure' THEN EXECUTE IMMEDIATE 'DROP PROCEDURE ' || p_name;
  ELSIF p_type = 'trigger' THEN EXECUTE IMMEDIATE 'DROP TRIGGER ' || p_name;
  END IF;
EXCEPTION
  WHEN OTHERS THEN null;
END;
/

prompt -------------------------------------------;
prompt Suppression des triggers/procedures/fonctions;
prompt -------------------------------------------;

EXEC delete_if_exists('function', 'getPrestationsPossibles');
EXEC delete_if_exists('procedure', 'procedure_maj_prestataire');
EXEC delete_if_exists('trigger', 'trigger_update_cagnotte_client');
EXEC delete_if_exists('trigger', 'trigger_after_insert_reservation_hotel');
EXEC delete_if_exists('trigger', 'trigger_after_insert_reservation_activite');
EXEC delete_if_exists('trigger', 'trigger_after_insert_reservation_transport');

prompt -------------------------------------------;
prompt --- Suppression des anciens tuples --------;
prompt -------------------------------------------;

EXEC delete_if_exists('tuple', 'RESERVATION_ACTIVITE');
EXEC delete_if_exists('tuple', 'RESERVATION_TRANSPORT');
EXEC delete_if_exists('tuple', 'RESERVATION_HOTEL');
EXEC delete_if_exists('tuple', 'RESERVATION');
EXEC delete_if_exists('tuple', 'VOYAGE');
EXEC delete_if_exists('tuple', 'PRESTATAIRE');
EXEC delete_if_exists('tuple', 'CLIENT');
EXEC delete_if_exists('tuple', 'ABONNEMENT');

prompt -------------------------------------------;
prompt ------  Suppression des relations  --------;
prompt -------------------------------------------;

EXEC delete_if_exists('table', 'RESERVATION_ACTIVITE');
EXEC delete_if_exists('table', 'RESERVATION_TRANSPORT');
EXEC delete_if_exists('table', 'RESERVATION_HOTEL');
EXEC delete_if_exists('table', 'RESERVATION');
EXEC delete_if_exists('table', 'VOYAGE');
EXEC delete_if_exists('table', 'PRESTATAIRE');
EXEC delete_if_exists('table', 'CLIENT');
EXEC delete_if_exists('table', 'ABONNEMENT');

prompt -------------------------------------------;
prompt - Suppression de procedure de suppression -;
prompt -------------------------------------------;

DROP PROCEDURE delete_if_exists;