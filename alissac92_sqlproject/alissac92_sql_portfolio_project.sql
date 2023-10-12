-- Drop Table and Sequence Section to make the script re-runnable
DROP SEQUENCE prime_user_seq;
DROP SEQUENCE twitch_SO_seq;
DROP SEQUENCE primevid_SO_seq;
DROP SEQUENCE music_SO_seq;
DROP SEQUENCE RecIDSeq;
DROP SEQUENCE RecChangeSeq;
DROP TABLE Prime_Video_Recs;
DROP TABLE Twitch_Recs;
DROP TABLE Amazon_Music_Recs;
DROP TABLE Media_Breakdown;
DROP TABLE Prime_Video;
DROP TABLE Twitch;
DROP TABLE Amazon_Music;
DROP TABLE Prime_User;
/

--Create Table and Sequence Section
CREATE SEQUENCE prime_user_seq START WITH 1;
CREATE SEQUENCE twitch_SO_seq START WITH 1;
CREATE SEQUENCE primevid_SO_seq START WITH 1;
CREATE SEQUENCE music_SO_seq START WITH 1;
/
CREATE TABLE Prime_User (
Prime_Acct_ID DECIMAL(12) NOT NULL PRIMARY KEY,
User_Email VARCHAR(128) NOT NULL,
User_Fname VARCHAR(64) NOT NULL,
User_LName VARCHAR(64) NOT NULL,
User_Address VARCHAR(256) NOT NULL,
User_Payment_ID DECIMAL(12) NOT NULL);

CREATE TABLE Prime_Video (
Prime_Acct_ID  DECIMAL(12) NOT NULL,
FOREIGN KEY (Prime_Acct_ID) REFERENCES Prime_User(Prime_Acct_ID),
PrimeVid_SO_ID DECIMAL (12) NOT NULL PRIMARY KEY,
Media_ID DECIMAL (12) NOT NULL,
PrimeVid_SO_Date DATE NOT NULL);

CREATE TABLE Twitch (
Prime_Acct_ID  DECIMAL(12) NOT NULL,
FOREIGN KEY (Prime_Acct_ID) REFERENCES Prime_User(Prime_Acct_ID),
Twitch_SO_ID DECIMAL (12) NOT NULL PRIMARY KEY,
Media_ID DECIMAL (12) NOT NULL,
Twitch_SO_Date DATE NOT NULL);

CREATE TABLE Amazon_Music (
Prime_Acct_ID  DECIMAL(12) NOT NULL,
FOREIGN KEY (Prime_Acct_ID) REFERENCES Prime_User(Prime_Acct_ID),
Music_SO_ID DECIMAL (12) NOT NULL PRIMARY KEY,
Media_ID DECIMAL (12) NOT NULL,
Music_SO_Date DATE NOT NULL);

CREATE TABLE Media_Breakdown (
Media_ID DECIMAL(12) NOT NULL PRIMARY KEY,
Medium VARCHAR (64) NOT NULL,
Genre VARCHAR (64) NOT NULL,
Subgenre VARCHAR (64),
Title VARCHAR (128) NOT NULL,
Rel_Year DECIMAL(4) NOT NULL);

CREATE TABLE Recommendations (
Rec_ID DECIMAL (12) NOT NULL PRIMARY KEY,
Media_ID DECIMAL (12),
FOREIGN KEY (Media_ID) REFERENCES Media_Breakdown(Media_ID),
Title VARCHAR (128),
Date_Recommended DATE NOT NULL);

CREATE SEQUENCE RecIDSeq START WITH 1;

-- Change History Table and Trigger for Recommendation Dates
CREATE TABLE Rec_History (
RecChange_ID DECIMAL(12) NOT NULL PRIMARY KEY,
OldRecID DECIMAL (12) NOT NULL,
NewRecID DECIMAL (12) NOT NULL,
Old_Media_ID DECIMAL (12) NOT NULL,
New_Media_ID DECIMAL (12) NOT NULL,
ChangeDate DATE NOT NULL);

CREATE SEQUENCE RecChangeSeq START WITH 1;

CREATE OR REPLACE TRIGGER RecDateTrigger
BEFORE UPDATE OF Media_ID ON Recommendations
FOR EACH ROW
BEGIN
    INSERT INTO Rec_History (RecChange_ID, OldRecID, NewRecID, Old_Media_ID, New_Media_ID, ChangeDate)
    VALUES (RecChangeSeq.nextval,
            :OLD.Rec_ID,
            :NEW.Rec_ID,
            :OLD.Media_ID,
            :NEW.Media_ID,
            trunc(sysdate));
END;
/

--Updates to Recommendations to test Rec_History and History Trigger
INSERT INTO Recommendations
VALUES (RecIDSeq.nextval, 2001, 'Halloween', CAST('04-MAR-2021' AS DATE));

UPDATE Recommendations
SET
    Media_ID = 2002,
    Title = 'A Nightmare on Elm Street',
    Date_Recommended = CAST('05-MAR-2021' AS DATE)
WHERE
    Rec_ID = 5;
    
INSERT INTO Recommendations
VALUES (RecIDSeq.nextval, 2009, 'The Boys', CAST('04-APR-2021' AS DATE));

UPDATE Recommendations
SET
    Media_ID = 2008,
    Title = 'Wonder Woman: 1984',
    Date_Recommended = CAST('05-APR-2021' AS DATE)
WHERE
    Rec_ID = 21;

INSERT INTO Recommendations
VALUES (RecIDSeq.nextval, 2003, 'Stranger Things', CAST('09-APR-2021' AS DATE));

UPDATE Recommendations
SET
    Media_ID = 1001,
    Title = 'Dead by Daylight',
    Date_Recommended = CAST('10-APR-2021' AS DATE)
WHERE
    Rec_ID = 41;
/
SELECT *
FROM Recommendations;

--Proof the trigger works for updating Rec History
SELECT *
FROM Rec_History;

--Indexes
CREATE INDEX PrimeVidSODate
ON Prime_Video(PrimeVid_SO_Date);

CREATE INDEX TwitchSODate
ON Twitch(Twitch_SO_Date);

CREATE INDEX MusicSODate
ON Amazon_Music(Music_SO_Date);

CREATE INDEX DateRecIdx
ON Recommendations(Date_Recommended);

--Transactions

CREATE OR REPLACE PROCEDURE AddPrimeUser (Prime_Acct_ID IN DECIMAL, User_Email IN VARCHAR, User_FName IN VARCHAR, 
User_LName IN VARCHAR, User_Address IN VARCHAR, User_Payment_ID IN DECIMAL)
AS
BEGIN
    INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
    VALUES(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID);
    
    INSERT INTO Prime_Video(Prime_Acct_ID)
    VALUES(Prime_Acct_ID);
    
    INSERT INTO Twitch(Prime_Acct_ID)
    VALUES(Prime_Acct_ID);
    
    INSERT INTO Amazon_Music(Prime_Acct_ID)
    VALUES(Prime_Acct_ID);
END;

/

BEGIN
    AddPrimeUser(2, 'blight@dbd.com', 'Blight', 'Monster', '123 Daylight Way', 2);
    COMMIT;
END;
/
--Populating Tables / Prime Users
INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(1,'mmyers@dbd.com', 'Michael', 'Myers', '100 Lamplight Lane', 100);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(2,'huntress@dbd.com', 'Huntress', 'Hatchet', '300 Hatchet Circle', 101);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(3,'plague@dbd.com', 'Plague', 'Illness', '89 Infection Street', 102);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(4,'wraith@dbd.com', 'Wraith', 'Bell', '99 Wailing Bell Lane', 103);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(5,'doctor@dbd.com', 'Doctor', 'Shock', '200 Electric Avenue', 104);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(6,'nurse@dbd.com', 'Nurse', 'Blink', '188 Teleport Ave', 105);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(7,'trickster@dbd.com', 'Trickster', 'Singer', '144 Studio Street', 106);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(8,'twins@dbd.com', 'Charlotte', 'Twin', '22 Twin Circle', 107);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(9,'spirit@dbd.com', 'Bella', 'Spirit', '88 Walker Way', 108);

INSERT INTO Prime_User(Prime_Acct_ID, User_Email, User_FName, User_LName, User_Address, User_Payment_ID)
VALUES(10,'ghostface@dbd.com', 'Ghost', 'Face', '73 Silent Street', 109);

SELECT *
FROM Prime_User;
/

--Adding Media
INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2004, 'Song', 'Pop', 'Korean Pop', 'How You Like That', 2020);

INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2005, 'Song', 'Rock', '80s Classic Rock', 'Welcome to the Jungle', 1987);

INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2006, 'TV Series', 'Drama', 'Thriller', 'Tell Me Your Secrets', 2021);

INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2007, 'Video Game', 'Horror', 'Zombie', 'The Last of Us', 2014);

INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2008, 'Feature Film', 'Action', 'Superhero', 'Wonder Woman: 1984', 2020);

INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2009, 'TV Show', 'Action', 'Superhero', 'The Boys', 2019);

INSERT INTO Media_Breakdown(Media_ID, Medium, Genre, Subgenre, Title, Rel_Year)
VALUES(2010, 'Song', 'Pop', '80s Pop', 'Material Girl', 1984);

SELECT *
FROM Media_Breakdown;
/
--Adding Streaming Occurences
INSERT INTO Prime_Video(Prime_Acct_ID, PrimeVid_SO_ID, Media_ID, PrimeVid_SO_Date)
VALUES(1, 100001, 2003, CAST('12-APR-2021'AS DATE));

INSERT INTO Prime_Video(Prime_Acct_ID, PrimeVid_SO_ID, Media_ID, PrimeVid_SO_Date)
VALUES(9, 100002, 2008, CAST('04-APR-2021'AS DATE));

INSERT INTO Prime_Video(Prime_Acct_ID, PrimeVid_SO_ID, Media_ID, PrimeVid_SO_Date)
VALUES(7, 100003, 2002, CAST('08-APR-2021'AS DATE));

INSERT INTO Prime_Video(Prime_Acct_ID, PrimeVid_SO_ID, Media_ID, PrimeVid_SO_Date)
VALUES(6, 100004, 2001, CAST('30-APR-2021'AS DATE));

INSERT INTO Prime_Video(Prime_Acct_ID, PrimeVid_SO_ID, Media_ID, PrimeVid_SO_Date)
VALUES(10, 100005, 2003, CAST('10-APR-2021'AS DATE));

INSERT INTO Twitch(Prime_Acct_ID, Twitch_SO_ID, Media_ID, Twitch_SO_Date)
VALUES(4, 200001, 1001, CAST('01-APR-2021'AS DATE));

INSERT INTO Twitch(Prime_Acct_ID, Twitch_SO_ID, Media_ID, Twitch_SO_Date)
VALUES(5, 200002, 2007, CAST('21-APR-2021'AS DATE));

INSERT INTO Amazon_Music(Prime_Acct_ID, Music_SO_ID, Media_ID, Music_SO_Date)
VALUES(2, 300001, 2004, CAST('24-APR-2021'AS DATE));

INSERT INTO Amazon_Music(Prime_Acct_ID, Music_SO_ID, Media_ID, Music_SO_Date)
VALUES(3, 300002, 2005, CAST('26-APR-2021'AS DATE));

INSERT INTO Amazon_Music(Prime_Acct_ID, Music_SO_ID, Media_ID, Music_SO_Date)
VALUES(8, 300003, 2010, CAST('11-APR-2021'AS DATE));
/

--Queries

--First Query
SELECT New_Media_ID, ChangeDate FROM Rec_History
ORDER BY ChangeDate ASC;

--Second Query (for all sub-accounts)
SELECT Prime_User.Prime_Acct_ID, Prime_User.User_Fname, Prime_User.User_LName
FROM Prime_User
RIGHT JOIN Prime_Video ON Prime_User.Prime_Acct_ID=Prime_Video.Prime_Acct_ID;

SELECT Prime_User.Prime_Acct_ID, Prime_User.User_Fname, Prime_User.User_LName
FROM Prime_User
RIGHT JOIN Twitch ON Prime_User.Prime_Acct_ID=Twitch.Prime_Acct_ID;

SELECT Prime_User.Prime_Acct_ID, Prime_User.User_Fname, Prime_User.User_LName
FROM Prime_User
RIGHT JOIN Amazon_Music ON Prime_User.Prime_Acct_ID=Amazon_Music.Prime_Acct_ID;

--Third Query
SELECT *
FROM Prime_Video
LEFT JOIN Media_Breakdown ON Prime_Video.Media_ID=Media_Breakdown.Media_ID;

SELECT *
FROM Twitch
LEFT JOIN Media_Breakdown ON Twitch.Media_ID=Media_Breakdown.Media_ID;

SELECT *
FROM Amazon_Music
LEFT JOIN Media_Breakdown ON Amazon_Music.Media_ID=Media_Breakdown.Media_ID;

Select *
FROM Rec_History
JOIN Media_Breakdown ON Rec_History.New_Media_ID=Media_Breakdown.Media_ID;

--Fourth Query

--Group 1
SELECT *
FROM Media_Breakdown
WHERE Genre = 'Horror';

--Group 2
SELECT Prime_Video.Media_ID
FROM Prime_Video
LEFT JOIN Media_Breakdown ON Prime_Video.Media_ID=Media_Breakdown.Media_ID
GROUP BY Prime_Video.Media_ID
HAVING COUNT(PrimeVid_SO_ID) > 1;

--Data Visualization
SELECT Genre, COUNT(Media_ID)
FROM Media_Breakdown
GROUP BY Genre
ORDER BY Count(Media_ID) DESC;
/ 

SELECT Media_Breakdown.Media_ID, Media_Breakdown.Title, Prime_Video.PrimeVid_SO_ID
FROM Prime_Video
INNER JOIN Media_Breakdown ON Media_Breakdown.Media_ID = Prime_Video.Media_ID
ORDER BY Media_ID;