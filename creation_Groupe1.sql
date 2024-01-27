/*
Auteurs Groupe 1

Chanez KHELIFA 		22115420
Denil BOUAFIA 		21806234
Mateusz BIREMBAUT	21907520
Taha BENSLIMANE       	22113693

*/

prompt -------------------------------------------;
prompt -------------  Mise en page  --------------;
prompt -------------------------------------------;

ALTER session SET NLS_DATE_FORMAT='YYYY-MM-DD' ; 
ALTER session SET NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS' ;

SET PAGESIZE 30
COLUMN COLUMN_NAME FORMAT A30
SET LINESIZE 300

prompt -------------------------------------------;
prompt -------  Création des relations  ----------;
prompt -------------------------------------------;

CREATE TABLE ABONNEMENT (
	TYPE_ABONNEMENT VARCHAR(15) CHECK (TYPE_ABONNEMENT IN ('BASIC', 'PLUS', 'ELITE')),
	TARIF NUMERIC(5, 2) CHECK (TARIF > 0),
	POURCENTAGE_CASHBACK NUMERIC(3, 0) CHECK (POURCENTAGE_CASHBACK BETWEEN 0 AND 100),
	CONSTRAINT PK_ABONNEMENT PRIMARY KEY (TYPE_ABONNEMENT)
);

CREATE TABLE CLIENT (
	ID_CLIENT NUMERIC(6, 0),
	NOM VARCHAR(15) CHECK(NOM IS NOT NULL),
	PRENOM VARCHAR(15) CHECK (PRENOM IS NOT NULL),
	MAIL VARCHAR(50) CHECK (MAIL IS NOT NULL),
	DATE_NAISSANCE DATE,
	VILLE VARCHAR(15),
	CAGNOTTE NUMERIC(5, 2) CHECK (CAGNOTTE >= 0),
	ABONNEMENT_ACTUEL VARCHAR(15),
	DATE_ABONNEMENT DATE CHECK (DATE_ABONNEMENT IS NOT NULL),
	CONSTRAINT PK_CLIENT PRIMARY KEY (ID_CLIENT),
	FOREIGN KEY (ABONNEMENT_ACTUEL) REFERENCES ABONNEMENT (TYPE_ABONNEMENT)
);

CREATE TABLE VOYAGE(
	ID_VOYAGE NUMERIC(6, 0),
	VOYAGEUR NUMERIC(6, 0),
	CONSTRAINT PK_VOYAGE PRIMARY KEY (ID_VOYAGE),
	FOREIGN KEY (VOYAGEUR) REFERENCES CLIENT (ID_CLIENT)
);

CREATE TABLE PRESTATAIRE(
	ID_PRESTATAIRE NUMERIC(6, 0),
	NOM VARCHAR(15) CHECK (NOM IS NOT NULL),
	TYPES_PRESTATIONS VARCHAR(15) CHECK (TYPES_PRESTATIONS IN
		('A', 'H', 'T', 'AH', 'AT', 'HT', 'AHT')
	),
	CONSTRAINT PK_PRESTATAIRE PRIMARY KEY (ID_PRESTATAIRE)
);

CREATE TABLE RESERVATION(
	ID_RESERVATION NUMERIC(6, 0),
	DATE_RESERVATION TIMESTAMP CHECK (DATE_RESERVATION IS NOT NULL),
	PRIX NUMERIC(8, 2) CHECK (PRIX >= 0),
	NB_ADULTES NUMERIC(3, 0) CHECK(NB_ADULTES > 0),
	NB_ENFANTS NUMERIC(3, 0) CHECK(NB_ENFANTS >= 0),
	ID_VOYAGE NUMERIC(6, 0),
	ID_FOURNISSEUR NUMERIC(6, 0),
	CONSTRAINT PK_RESERVATION PRIMARY KEY (ID_RESERVATION),
	FOREIGN KEY (ID_VOYAGE) REFERENCES VOYAGE (ID_VOYAGE),
	FOREIGN KEY (ID_FOURNISSEUR) REFERENCES PRESTATAIRE (ID_PRESTATAIRE)
);

CREATE TABLE RESERVATION_ACTIVITE(
	ID_RESERVATION_ACTIVITE NUMERIC(6, 0),
	DATE_ACTIVITE DATE CHECK (DATE_ACTIVITE IS NOT NULL),
	ADRESSE VARCHAR(200) CHECK (ADRESSE IS NOT NULL),
	FOREIGN KEY (ID_RESERVATION_ACTIVITE) REFERENCES RESERVATION (ID_RESERVATION)
);

CREATE TABLE RESERVATION_TRANSPORT(
	ID_RESERVATION_TRANSPORT NUMERIC(6, 0),
	DATE_DEPART DATE CHECK (DATE_DEPART IS NOT NULL),
	DATE_RETOUR DATE CHECK (DATE_RETOUR IS NOT NULL),
	ADRESSE_DEPART VARCHAR(200) CHECK (ADRESSE_DEPART IS NOT NULL),
	ADRESSE_RETOUR VARCHAR(200) CHECK (ADRESSE_RETOUR IS NOT NULL),
	FOREIGN KEY (ID_RESERVATION_TRANSPORT) REFERENCES RESERVATION (ID_RESERVATION)
);

CREATE TABLE RESERVATION_HOTEL(
	ID_RESERVATION_HOTEL NUMERIC(6, 0),
	DATE_DEPART DATE CHECK (DATE_DEPART IS NOT NULL),
	DATE_ARRIVEE DATE CHECK (DATE_ARRIVEE IS NOT NULL),
	ADRESSE VARCHAR(200) CHECK (ADRESSE IS NOT NULL),
	FOREIGN KEY (ID_RESERVATION_HOTEL) REFERENCES RESERVATION (ID_RESERVATION)
);

prompt -------------------------------------------;
prompt ---- Création des fonctions/procedures ----;
prompt -------------------------------------------;

CREATE OR REPLACE PROCEDURE procedure_maj_prestataire (
	var_idVoyage NUMERIC,
	var_idReservation NUMERIC,
	var_idFournisseurActuel NUMERIC,
	var_PrestationVoulue VARCHAR
	)
IS	
	e_exit EXCEPTION;
	PRAGMA EXCEPTION_INIT(e_exit , -20999);
	CURSOR fournisseursActuels IS
	SELECT ID_PRESTATAIRE, TYPES_PRESTATIONS
	FROM PRESTATAIRE
	JOIN RESERVATION ON ID_PRESTATAIRE = ID_FOURNISSEUR
	WHERE ID_VOYAGE = var_idVoyage;
BEGIN
	FOR fournisseur IN fournisseursActuels LOOP
	IF fournisseur.ID_PRESTATAIRE <> var_idFournisseurActuel
	AND fournisseur.TYPES_PRESTATIONS LIKE var_PrestationVoulue THEN
		UPDATE RESERVATION
		SET ID_FOURNISSEUR = fournisseur.ID_PRESTATAIRE
		WHERE ID_RESERVATION = var_idReservation;
		RAISE_APPLICATION_ERROR(-20999,null);
	END IF;
	END LOOP;
	EXCEPTION WHEN e_exit THEN null;
END;
/

CREATE OR REPLACE PROCEDURE procedure_maj_abonnement_clients
IS 
    CURSOR client_cursor IS
        SELECT DISTINCT ID_CLIENT FROM CLIENT;

    v_depenses_client NUMBER(16, 2);

BEGIN
    FOR client_rec IN client_cursor
    LOOP
        SELECT SUM(NVL(PRIX, 0)) INTO v_depenses_client
        FROM RESERVATION r
        JOIN VOYAGE v ON v.ID_VOYAGE = r.ID_VOYAGE
        WHERE VOYAGEUR = client_rec.ID_CLIENT
        AND r.DATE_RESERVATION >= TRUNC(SYSDATE, 'YYYY');

        UPDATE CLIENT
        SET ABONNEMENT_ACTUEL = 
            CASE 
                WHEN v_depenses_client > 10000 THEN 'ELITE'
                WHEN v_depenses_client > 5000 THEN 'PLUS'
                ELSE 'BASIC'
            END
        WHERE ID_CLIENT = client_rec.ID_CLIENT;
    END LOOP;
END;
/

CREATE OR REPLACE FUNCTION getPrestationsPossibles (var_idPrestataire NUMERIC)
RETURN VARCHAR IS
	var_PrestationsPossibles VARCHAR(15);
BEGIN
	SELECT TYPES_PRESTATIONS INTO var_PrestationsPossibles
	FROM PRESTATAIRE
	WHERE ID_PRESTATAIRE = var_idPrestataire;
	RETURN (var_PrestationsPossibles);
END;
/

prompt -------------------------------------------;
prompt -------   Création des triggers  ----------;
prompt -------------------------------------------;

CREATE OR REPLACE TRIGGER trigger_update_cagnotte_client
AFTER INSERT ON RESERVATION
FOR EACH ROW
DECLARE 
    v_pourcentage_cashback NUMERIC(3,0);
    v_id_client NUMERIC(6,0);
    v_new_cagnotte NUMERIC(5,2);
    v_cagnotte NUMERIC(5,2);
BEGIN
    SELECT ID_CLIENT, CAGNOTTE
    INTO v_id_client, v_cagnotte
    FROM CLIENT c
    JOIN VOYAGE v ON v.VOYAGEUR = c.ID_CLIENT
    WHERE ID_VOYAGE = :new.ID_VOYAGE;

    SELECT POURCENTAGE_CASHBACK INTO v_pourcentage_cashback
    FROM CLIENT c
    JOIN ABONNEMENT a ON c.ABONNEMENT_ACTUEL = a.TYPE_ABONNEMENT
    WHERE ID_CLIENT = v_id_client;

    BEGIN
        v_new_cagnotte := v_cagnotte + (:new.PRIX * v_pourcentage_cashback / 100);
    EXCEPTION
        WHEN VALUE_ERROR THEN
                UPDATE CLIENT
                SET CAGNOTTE = 999.99
                WHERE ID_CLIENT = v_id_client;
            RETURN;
    END;

    UPDATE CLIENT
    SET CAGNOTTE = v_new_cagnotte
    WHERE ID_CLIENT = v_id_client;

END;
/

CREATE OR REPLACE TRIGGER trigger_after_insert_reservation_hotel
AFTER INSERT ON RESERVATION_HOTEL
FOR EACH ROW
DECLARE
    var_idReservation RESERVATION_HOTEL.ID_RESERVATION_HOTEL%TYPE;
    var_idPrestataire RESERVATION_HOTEL.ID_RESERVATION_HOTEL%TYPE;
    var_idVoyage RESERVATION_HOTEL.ID_RESERVATION_HOTEL%TYPE;
BEGIN
    SELECT ID_RESERVATION, ID_VOYAGE, ID_FOURNISSEUR INTO var_idReservation, var_idVoyage, var_idPrestataire
    FROM RESERVATION
    WHERE ID_RESERVATION = :new.ID_RESERVATION_HOTEL;

    IF NOT getPrestationsPossibles(var_idPrestataire) LIKE '%H%' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le prestataire choisi ne peut fournir cette réservation');
    END IF;

    procedure_maj_prestataire(var_idVoyage, var_idReservation, var_idPrestataire, '%H%');

END;
/

CREATE OR REPLACE TRIGGER trigger_after_insert_reservation_activite
AFTER INSERT ON RESERVATION_ACTIVITE
FOR EACH ROW
DECLARE
    var_idReservation RESERVATION_ACTIVITE.ID_RESERVATION_ACTIVITE%TYPE;
    var_idPrestataire RESERVATION_ACTIVITE.ID_RESERVATION_ACTIVITE%TYPE;
    var_idVoyage RESERVATION_ACTIVITE.ID_RESERVATION_ACTIVITE%TYPE;
BEGIN
    SELECT ID_RESERVATION, ID_VOYAGE, ID_FOURNISSEUR INTO var_idReservation, var_idVoyage, var_idPrestataire
    FROM RESERVATION
    WHERE ID_RESERVATION = :new.ID_RESERVATION_ACTIVITE;

    IF NOT getPrestationsPossibles(var_idPrestataire) LIKE '%A%' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le prestataire choisi ne peut fournir cette réservation');
    END IF;

    procedure_maj_prestataire(var_idVoyage, var_idReservation, var_idPrestataire, '%A%');

END;
/

CREATE OR REPLACE TRIGGER trigger_after_insert_reservation_transport
AFTER INSERT ON RESERVATION_TRANSPORT
FOR EACH ROW
DECLARE
    var_idReservation RESERVATION_TRANSPORT.ID_RESERVATION_TRANSPORT%TYPE;
    var_idPrestataire RESERVATION_TRANSPORT.ID_RESERVATION_TRANSPORT%TYPE;
    var_idVoyage RESERVATION_TRANSPORT.ID_RESERVATION_TRANSPORT%TYPE;
BEGIN
    SELECT ID_RESERVATION, ID_VOYAGE, ID_FOURNISSEUR INTO var_idReservation, var_idVoyage, var_idPrestataire
    FROM RESERVATION
    WHERE ID_RESERVATION = :new.ID_RESERVATION_TRANSPORT;

    IF NOT getPrestationsPossibles(var_idPrestataire) LIKE '%T%' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le prestataire choisi ne peut fournir cette réservation');
    END IF;

    procedure_maj_prestataire(var_idVoyage, var_idReservation, var_idPrestataire, '%T%');

END;
/

prompt -------------------------------------------;
prompt ---------- Insertion des tuples -----------;
prompt -------------------------------------------;

prompt ------------------------------------------;
prompt -------  insertion ABONNEMENT   ----------;
prompt ------------------------------------------;

INSERT INTO ABONNEMENT VALUES ('BASIC', 10, 2) ;
INSERT INTO ABONNEMENT VALUES ('PLUS', 20, 5) ;
INSERT INTO ABONNEMENT VALUES ('ELITE', 30, 10) ;

prompt ------------------------------------------;
prompt -------   insertion CLIENT    ------------;
prompt ------------------------------------------;

INSERT INTO CLIENT VALUES (1, 'Dupont', 'Jean', 'jean.dupont@mail.com', '1990-05-15', 'Paris', 0.00, 'BASIC', '2022-01-01');
INSERT INTO CLIENT VALUES (2, 'Martin', 'Sophie', 'sophie.martin@mail.com', '1985-08-22', 'Lyon', 0.00, 'PLUS', '2022-02-05');
INSERT INTO CLIENT VALUES (3, 'Dubois', 'Pierre', 'pierre.dubois@mail.com', '1995-03-10', 'Marseille', 0.00, 'ELITE', '2022-03-10');
INSERT INTO CLIENT VALUES (4, 'Lefevre', 'Marie', 'marie.lefevre@mail.com', '1980-11-28', 'Toulouse', 0.00, 'BASIC', '2022-04-15');
INSERT INTO CLIENT VALUES (5, 'Moreau', 'Philippe', 'philippe.moreau@mail.com', '1992-07-03', 'Nice', 0.00, 'PLUS', '2022-05-20');
INSERT INTO CLIENT VALUES (6, 'Girard', 'Isabelle', 'isabelle.girard@mail.com', '1988-04-18', 'Strasbourg', 0.00, 'ELITE', '2022-06-25');
INSERT INTO CLIENT VALUES (7, 'Lemoine', 'Francois', 'francois.lemoine@mail.com', '1998-09-05', 'Bordeaux', 0.00, 'BASIC', '2022-07-30');
INSERT INTO CLIENT VALUES (8, 'Roux', 'Catherine', 'catherine.roux@mail.com', '1993-12-12', 'Lille', 0.00, 'PLUS', '2022-08-05');
INSERT INTO CLIENT VALUES (9, 'Fournier', 'Luc', 'luc.fournier@mail.com', '1983-02-28', 'Nantes', 0.00, 'ELITE', '2022-09-10');
INSERT INTO CLIENT VALUES (10, 'Roy', 'Claire', 'claire.roy@mail.com', '1991-06-08', 'Montpellier', 0.00, 'BASIC', '2022-10-15');
INSERT INTO CLIENT VALUES (11, 'Leroux', 'David', 'david.leroux@mail.com', '1987-10-25', 'Rennes', 0.00, 'PLUS', '2022-11-20');
INSERT INTO CLIENT VALUES (12, 'Guerin', 'Elodie', 'elodie.guerin@mail.com', '1996-04-05', 'Toulon', 0.00, 'ELITE', '2022-12-25');
INSERT INTO CLIENT VALUES (13, 'Michel', 'Guillaume', 'guillaume.michel@mail.com', '1982-08-15', 'Cannes', 0.00, 'BASIC', '2023-01-01');
INSERT INTO CLIENT VALUES (14, 'Perrin', 'Mireille', 'mireille.perrin@mail.com', '1994-01-20', 'Nice', 0.00, 'PLUS', '2023-02-05');
INSERT INTO CLIENT VALUES (15, 'Rousseau', 'Francoise', 'francoise.rousseau@mail.com', '1989-05-30', 'Marseille', 0.00, 'ELITE', '2023-03-10');

prompt ------------------------------------------;
prompt -----     insertion PRESTATAIRE   --------;
prompt ------------------------------------------;

INSERT INTO PRESTATAIRE VALUES (1, 'Prestataire1', 'AH');
INSERT INTO PRESTATAIRE VALUES (2, 'Prestataire2', 'HT');
INSERT INTO PRESTATAIRE VALUES (3, 'Prestataire3', 'A');
INSERT INTO PRESTATAIRE VALUES (4, 'Prestataire4', 'AHT');
INSERT INTO PRESTATAIRE VALUES (5, 'Prestataire5', 'T');
INSERT INTO PRESTATAIRE VALUES (6, 'Prestataire6', 'AT');
INSERT INTO PRESTATAIRE VALUES (7, 'Prestataire7', 'HT');
INSERT INTO PRESTATAIRE VALUES (8, 'Prestataire8', 'AH');
INSERT INTO PRESTATAIRE VALUES (9, 'Prestataire9', 'T');
INSERT INTO PRESTATAIRE VALUES (10, 'Prestataire10', 'AHT');
INSERT INTO PRESTATAIRE VALUES (11, 'Prestataire11', 'AH');
INSERT INTO PRESTATAIRE VALUES (12, 'Prestataire12', 'AT');
INSERT INTO PRESTATAIRE VALUES (13, 'Prestataire13', 'HT');
INSERT INTO PRESTATAIRE VALUES (14, 'Prestataire14', 'A');
INSERT INTO PRESTATAIRE VALUES (15, 'Prestataire15', 'T');

-- ID_VOYAGE ET ID_RESERVATION < 20 RESERVES AUX TESTS

prompt ------------------------------------------;
prompt --------     insertion VOYAGE   ----------;
prompt ------------------------------------------;

INSERT INTO VOYAGE VALUES(21, 1);
INSERT INTO VOYAGE VALUES(22, 2);
INSERT INTO VOYAGE VALUES(23, 3);
INSERT INTO VOYAGE VALUES(24, 4);
INSERT INTO VOYAGE VALUES(25, 5);

prompt ------------------------------------------;
prompt --------   insertion RESERVATION ---------;
prompt ------------------------------------------;

--t
INSERT INTO RESERVATION VALUES (21, '2022-01-02 12:00:00', 500.00, 2, 1, 21, 2);
--h
INSERT INTO RESERVATION VALUES(22, '2022-02-06 14:30:00', 800.00, 3, 2, 21, 2);
--a
INSERT INTO RESERVATION VALUES(23, '2022-03-11 10:00:00', 1200.00, 4, 3, 21, 3);
--t
INSERT INTO RESERVATION VALUES(24, '2022-04-16 08:45:00', 550.00, 2, 1, 21, 2);

--t
INSERT INTO RESERVATION VALUES(25, '2022-05-21 16:20:00', 850.00, 3, 2, 22, 15);
--t
INSERT INTO RESERVATION VALUES(26, '2022-06-26 09:30:00', 1300.00, 4, 3, 22, 15);

--t
INSERT INTO RESERVATION VALUES(27, '2022-07-31 11:15:00', 520.00, 2, 1, 23, 13);
--h
INSERT INTO RESERVATION VALUES(28, '2022-08-06 13:45:00', 780.00, 3, 2, 23, 13);
--h
INSERT INTO RESERVATION VALUES(29, '2022-09-11 17:00:00', 1250.00, 4, 3, 23, 13);
--h
INSERT INTO RESERVATION VALUES(30, '2022-10-16 15:20:00', 480.00, 2, 1, 23, 13);
--t
INSERT INTO RESERVATION VALUES(31, '2022-11-21 12:30:00', 750.00, 3, 2, 23, 13);

--t
INSERT INTO RESERVATION VALUES(32, '2022-12-26 18:45:00', 1100.00, 4, 3, 24, 15);
--h
INSERT INTO RESERVATION VALUES(33, '2023-01-02 14:00:00', 600.00, 2, 1, 24, 8);
--a
INSERT INTO RESERVATION VALUES(34, '2023-02-06 11:10:00', 900.00, 3, 2, 24, 8);
--t
INSERT INTO RESERVATION VALUES(35, '2023-03-10 09:00:00', 1400.00, 4, 3, 24, 5);

--t
INSERT INTO RESERVATION VALUES(36, '2023-07-05 09:00:00', 75.00, 2, 1, 25, 10);
--h
INSERT INTO RESERVATION VALUES(37, '2023-08-10 14:30:00', 120.00, 1, 0, 25, 10);
--a
INSERT INTO RESERVATION VALUES(38, '2023-09-15 10:00:00', 90.00, 1, 1, 25, 10);
--t
INSERT INTO RESERVATION VALUES(39, '2023-10-20 16:45:00', 110.00, 2, 2, 25, 10);

prompt ------------------------------------------;
prompt --  insertion RESERVATION_TRANSPORT ------;
prompt ------------------------------------------;

INSERT INTO RESERVATION_TRANSPORT VALUES (21, '2022-02-06', '2022-02-12', 'Aeroport Nice Côte dAzur', 'Gare Thiers Nice');
INSERT INTO RESERVATION_TRANSPORT VALUES (24, '2022-03-11', '2022-03-20', 'Gare Saint-Charles Marseille', 'Aeroport Marignane Provence');
INSERT INTO RESERVATION_TRANSPORT VALUES (25, '2022-04-16', '2022-04-25', 'Gare de Lyon Paris', 'Aeroport Orly');
INSERT INTO RESERVATION_TRANSPORT VALUES (26, '2022-05-21', '2022-05-30', 'Aeroport Toulouse Blagnac', 'Gare Matabiau Toulouse');
INSERT INTO RESERVATION_TRANSPORT VALUES (27, '2022-06-26', '2022-07-05', 'Gare de lEst Paris', 'Aeroport Beauvais Tille');
INSERT INTO RESERVATION_TRANSPORT VALUES (31, '2022-07-31', '2022-08-09', 'Aeroport Bordeaux Merignac', 'Gare Saint Jean Bordeaux');
INSERT INTO RESERVATION_TRANSPORT VALUES (32, '2023-02-06', '2023-02-15', 'Gare Nice Ville', 'Aeroport Nice Cote dAzur');
INSERT INTO RESERVATION_TRANSPORT VALUES (35, '2023-03-10', '2023-03-19', 'Aeroport Paris Orly', 'Gare Montparnasse Paris');
INSERT INTO RESERVATION_TRANSPORT VALUES (36, '2022-12-26', '2022-12-31', 'Aéroport Marseille Provence', 'Gare Saint-Charles, Marseille');
INSERT INTO RESERVATION_TRANSPORT VALUES (39, '2023-01-02', '2023-01-09', 'Aéroport Lyon-Saint Exupéry', 'Gare de la Part-Dieu, Lyon');

prompt ------------------------------------------;
prompt ----- insertion RESERVATION_HOTEL --------;
prompt ------------------------------------------;

INSERT INTO RESERVATION_HOTEL VALUES (22, '2023-05-15', '2023-05-22', 'Grand Hotel 456 Avenue des Champs Elysees Paris');
INSERT INTO RESERVATION_HOTEL VALUES (28, '2023-06-20', '2023-06-30', 'Hotel de la Plage 789 Promenade des Anglais Nice');
INSERT INTO RESERVATION_HOTEL VALUES (29, '2023-07-05', '2023-07-15', 'Hotel du Vieux Port 101 Quai des Belges  Marseille');
INSERT INTO RESERVATION_HOTEL VALUES (30, '2023-08-10', '2023-08-20', 'Hotel Lyon Centr 222 Rue de la Republique Lyon');
INSERT INTO RESERVATION_HOTEL VALUES (33, '2023-09-15', '2023-09-25', 'Hotel Bordeaux 333 Cours de l Intendance Bordeaux');
INSERT INTO RESERVATION_HOTEL VALUES (37, '2023-10-20', '2023-10-30', 'Hotel Lille Métropole 444 Avenue de la Marne Lille');

prompt ------------------------------------------;
prompt ---- insertion RESERVATION_ACTIVITE  -----;
prompt ------------------------------------------;

INSERT INTO RESERVATION_ACTIVITE VALUES(23, '2022-01-02', '123 Rue de la Liberte 75001 Paris');
INSERT INTO RESERVATION_ACTIVITE VALUES(34, '2022-02-06', '456 Avenue des Champs-elyees 008 Paris');
INSERT INTO RESERVATION_ACTIVITE VALUES(38, '2022-03-11', '789 Rue du Vieux Port 13002 Marseille');

prompt ------------------------------------------;
prompt ------------     REQUETES   --------------;
prompt ------------------------------------------;

prompt ------------------------------------------;
prompt --Liste des types d'abonnements avec le nombre total de clients pour chaque type
prompt ------------------------------------------;

SELECT ABONNEMENT_ACTUEL, COUNT(ABONNEMENT_ACTUEL) AS Nombre_Clients
FROM CLIENT
GROUP BY ABONNEMENT_ACTUEL;


prompt ------------------------------------------;
prompt --Liste des clients ayant réservé tous les types de prestations (A, H, T).
prompt ------------------------------------------;

SELECT *
FROM CLIENT
WHERE EXISTS (
    SELECT *
    FROM RESERVATION_ACTIVITE
    WHERE ID_RESERVATION_ACTIVITE IN (
	SELECT ID_RESERVATION FROM RESERVATION 
	JOIN VOYAGE ON VOYAGE.ID_VOYAGE = RESERVATION.ID_VOYAGE
	WHERE VOYAGEUR = ID_CLIENT
    )
)
AND EXISTS (
    SELECT *
    FROM RESERVATION_TRANSPORT
    WHERE ID_RESERVATION_TRANSPORT IN (
	SELECT ID_RESERVATION FROM RESERVATION 
	JOIN VOYAGE ON VOYAGE.ID_VOYAGE = RESERVATION.ID_VOYAGE
	WHERE VOYAGEUR = ID_CLIENT
    )
)
AND EXISTS (
    SELECT *
    FROM RESERVATION_HOTEL
    WHERE ID_RESERVATION_HOTEL IN (
	SELECT ID_RESERVATION FROM RESERVATION 
	JOIN VOYAGE ON VOYAGE.ID_VOYAGE = RESERVATION.ID_VOYAGE
	WHERE VOYAGEUR = ID_CLIENT
    )
);

prompt ------------------------------------------;
prompt Client ayant réservé toutes les réservations d'activités, s'il existe;
prompt ------------------------------------------;

SELECT *
FROM CLIENT
WHERE NOT EXISTS (
	SELECT ID_RESERVATION_ACTIVITE
	FROM RESERVATION_ACTIVITE
	WHERE NOT EXISTS (
		SELECT *
		FROM RESERVATION
		JOIN VOYAGE ON VOYAGE.ID_VOYAGE = RESERVATION.ID_VOYAGE
		WHERE ID_RESERVATION = ID_RESERVATION_ACTIVITE
		AND VOYAGEUR = ID_CLIENT
	)
);

prompt ------------------------------------------;
prompt Chiffre d'affaires par année;
prompt ------------------------------------------;

SELECT ANNEE, SUM(PRIX) AS Chiffre_Affaires
FROM (
	SELECT EXTRACT(YEAR FROM DATE_RESERVATION) AS ANNEE, PRIX
	FROM RESERVATION
)
GROUP BY ANNEE;

prompt ------------------------------------------;
prompt Nombre de réservations et revenu par prestataire;
prompt ------------------------------------------;

SELECT ID_FOURNISSEUR AS PRESTATAIRE, COUNT(PRIX) AS NB_RESERVATIONS, SUM(PRIX) AS REVENU
FROM RESERVATION
GROUP BY ID_FOURNISSEUR;


prompt ------------------------------------------;
prompt -- Clients ELITE ayant une cagnotte égale à la cagnotte la plus élevée parmi tous les clients ayant un abonnement de type ELITE;
prompt ------------------------------------------;


SELECT NOM, PRENOM, CAGNOTTE
FROM CLIENT 
WHERE ABONNEMENT_ACTUEL = 'ELITE'
AND CAGNOTTE = (
	SELECT MAX(C.CAGNOTTE)
	FROM CLIENT C
	WHERE C.ABONNEMENT_ACTUEL = 'ELITE'
);


prompt ------------------------------------------;
prompt --Liste des réservations d'activités avec la date et l'adresse, ainsi que le nom du client associé.
prompt ------------------------------------------;

SELECT ID_RESERVATION_ACTIVITE, DATE_ACTIVITE, ADRESSE, 
	(SELECT NOM ||' '|| PRENOM FROM CLIENT WHERE VOYAGEUR = ID_CLIENT) AS Nom_Client
FROM RESERVATION_ACTIVITE
JOIN RESERVATION ON ID_RESERVATION_ACTIVITE = ID_RESERVATION
JOIN VOYAGE ON VOYAGE.ID_VOYAGE = RESERVATION.ID_VOYAGE;

prompt ------------------------------------------;
prompt --Liste des clients avec le montant total dépensé pour les réservations, triés par le montant total décroissant.
prompt ------------------------------------------;

SELECT ID_CLIENT, NOM, PRENOM, SUM(PRIX) AS Montant_Total_Depense
FROM CLIENT
JOIN VOYAGE ON ID_CLIENT = VOYAGEUR
JOIN RESERVATION ON RESERVATION.ID_VOYAGE = VOYAGE.ID_VOYAGE
GROUP BY ID_CLIENT, NOM, PRENOM
ORDER BY Montant_Total_Depense DESC;

