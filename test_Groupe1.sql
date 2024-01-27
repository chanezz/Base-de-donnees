SET PAGESIZE 30
COLUMN COLUMN_NAME FORMAT A30
SET LINESIZE 300

prompt ------------------------------------------;
prompt -----     test TRIGGER INSERTION   -------;
prompt ------------------------------------------;
prompt -- On crée un voyage id 1 pour le client 5
prompt -- Il contient 3 reservations avec 3 fournisseurs différents
prompt -- La reservation 1 sera une reservation transport avec prestataire 5 proposant transport
prompt -- La reservation 2 sera une reservation hôtel avec prestataire 2 proposant hôtel et transport
prompt -- La reservation 3 sera une reservation activite avec prestataire 3 proposant activité
prompt -----------------------------------------------------;

INSERT INTO VOYAGE VALUES (1,5);

--transport
INSERT INTO RESERVATION VALUES (1,'1990-05-15',500,1,0,1,5);
--hotel
INSERT INTO RESERVATION VALUES (2,'1990-05-15',150,1,0,1,2);
--activite
INSERT INTO RESERVATION VALUES (3,'1990-05-15',50,1,0,1,3);

prompt -------------  Réservations du voyage 1  -----------;

SELECT * FROM RESERVATION WHERE ID_VOYAGE = 1;

prompt -----------------------------------------------------;
prompt -- Le trigger permet minimiser le nombre de prestataires différents
prompt -----------------------------------------------------;

INSERT INTO RESERVATION_TRANSPORT VALUES (1,'1990-05-15','1990-05-15','ADRESSE','ADRESSE');

SELECT * FROM RESERVATION WHERE ID_VOYAGE = 1;

prompt -----------------------------------------------------;
prompt -- Le fournisseur 5 n'est plus le prestataire de la reservation 1, il est remplacé par le 2
prompt -- car le prestataire 2 peut fournir les prestations pour 2 reservations
prompt -----------------------------------------------------;

INSERT INTO RESERVATION_HOTEL VALUES (2,'1990-05-15','1990-05-15','ADRESSE');
INSERT INTO RESERVATION_ACTIVITE VALUES (3,'1990-05-15','ADRESSE');


prompt ------------------------------------------;
prompt -----     test TRIGGER MAJ CAGNOTTE   ----;
prompt ------------------------------------------;


INSERT INTO VOYAGE VALUES (2,10);
--BASIC
INSERT INTO VOYAGE VALUES (3,9);
--ELITE


prompt ------------------------------------------;
prompt ----     test MAJ CAGNOTTE ABO BASIC  ----;
prompt ------------------------------------------;

prompt -- Cagnotte du client 10, l'abonnement basic a 2% de cashback
SELECT ID_CLIENT, CAGNOTTE,ABONNEMENT_ACTUEL FROM CLIENT WHERE ID_CLIENT = 10;


INSERT INTO RESERVATION VALUES (4,'1990-05-15',100,1,0,2,5); 
INSERT INTO RESERVATION VALUES (5,'1990-05-15',46,1,0,2,2); 
INSERT INTO RESERVATION VALUES (6,'1990-05-15',833,1,0,2,3); 

prompt -- Prix des reservations :
SELECT PRIX FROM RESERVATION WHERE ID_VOYAGE = 2;


prompt -- Cagnotte du client 10 après insertions 

SELECT ID_CLIENT, CAGNOTTE,ABONNEMENT_ACTUEL FROM CLIENT WHERE ID_CLIENT = 10;

prompt ------------------------------------------;
prompt ----     test MAJ CAGNOTTE ABO ELITE  ----;
prompt ------------------------------------------;


prompt -- Cagnotte du client 9, l'abonnement élite a 10% de cashback
SELECT ID_CLIENT, CAGNOTTE,ABONNEMENT_ACTUEL FROM CLIENT WHERE ID_CLIENT = 9;


INSERT INTO RESERVATION VALUES (7,'1990-05-15',784,1,0,3,5); 
INSERT INTO RESERVATION VALUES (8,'1990-05-15',478,1,0,3,2); 
INSERT INTO RESERVATION VALUES (9,'1990-05-15',456,1,0,3,3); 

prompt -- Prix des reservations :
SELECT PRIX FROM RESERVATION WHERE ID_VOYAGE = 3;

prompt -- Cagnotte du client 9 après insertions  (235.2+143.4+136.8=515.4)
SELECT ID_CLIENT, CAGNOTTE,ABONNEMENT_ACTUEL FROM CLIENT WHERE ID_CLIENT = 9;

INSERT INTO RESERVATION VALUES (16,'1990-05-15',999999,1,0,3,3); 

prompt -- Cagnotte du client 9 après insertions  (999999)
SELECT ID_CLIENT, CAGNOTTE,ABONNEMENT_ACTUEL FROM CLIENT WHERE ID_CLIENT = 9;
prompt -- On a catch une exception si la valeur de la cagnotte depasse celle possible alors on la bloque au max (999.99)


prompt ------------------------------------------;
prompt -----     test FUNCTION    -------;
prompt ------------------------------------------;



SELECT ID_PRESTATAIRE, getPrestationsPossibles(ID_PRESTATAIRE) AS Retour_fonction
FROM PRESTATAIRE
WHERE ROWNUM < 4
ORDER BY ID_PRESTATAIRE;

SELECT ID_PRESTATAIRE, TYPES_PRESTATIONS
FROM PRESTATAIRE
WHERE ROWNUM < 4
ORDER BY ID_PRESTATAIRE;


prompt ------------------------------------------;
prompt ----------     test PROCEDURE    ---------;
prompt ------------------------------------------;

prompt ----------     test mise a jour abonnement clients    ---------;

SELECT ID_CLIENT, ABONNEMENT_ACTUEL FROM CLIENT;

prompt -- On va modifier leur abonnement_actuel pour prendre le meilleur abonnement qui leur est disponible
prompt -- en fonction de leur dépense sur l'année 


BEGIN
	procedure_maj_abonnement_clients;
END;
/

prompt -- On a aucun client qui a fait assez de reservation pour avoir plus haut que basic


SELECT ID_CLIENT, ABONNEMENT_ACTUEL FROM CLIENT;


prompt -- on ajoute des lignes pour que le client 14 soit a plus de 10000 € depensé cette année (qu'il passe élite)

prompt -- on ajoute des lignes pour que le client 11 soit a plus de 5000 € depensé cette année (qu'il passe plus)


INSERT INTO VOYAGE VALUES (10,14);

INSERT INTO RESERVATION VALUES (10,'2023-05-15',4000,1,0,10,7); 
INSERT INTO RESERVATION VALUES (11,'2023-05-15',4000,1,0,10,8); 
INSERT INTO RESERVATION VALUES (12,'2023-05-15',4000,1,0,10,10); 

INSERT INTO VOYAGE VALUES (11,11);

INSERT INTO RESERVATION VALUES (13,'2023-05-15',2000,1,0,11,7); 
INSERT INTO RESERVATION VALUES (14,'2023-05-15',3000,1,0,11,8); 
INSERT INTO RESERVATION VALUES (15,'2023-05-15',400,1,0,11,10); 


BEGIN
	procedure_maj_abonnement_clients;
END;
/

SELECT ID_CLIENT, ABONNEMENT_ACTUEL FROM CLIENT;

prompt -- Ils ont bien le bon abonnement en fonction de leurs dépenses

