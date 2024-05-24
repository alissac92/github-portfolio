-- DROP ALL TABLES
-- DO $$
-- DECLARE
--     r RECORD;
-- BEGIN
--     FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'orlando_development')
--     LOOP
--         EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident('orlando_development') 
-- 		|| '.' || quote_ident(r.tablename) || ' CASCADE';
--     END LOOP;
-- END $$;


-- Show tables loaded into orlando_development schema
SELECT *
FROM information_schema.tables
WHERE table_schema = 'orlando_development';

---------- *** CREATE AND LOAD TABLES *** ----------

-- 1. Create ApplicantDim dimension table
DROP TABLE IF EXISTS orlando_development."ApplicantDim";
CREATE TABLE orlando_development."ApplicantDim" (
    ApplicantID SERIAL PRIMARY KEY,
    PropertyOwnerName VARCHAR(2000),
    ApplicantType VARCHAR(255),
    ApplicantAddress VARCHAR(1000),
    ParcelNumber VARCHAR(1000),
    ParcelOwnerName VARCHAR(2000),
    CurrPermits INTEGER,
    CurrPlanPermits INTEGER,
    IsActive BOOLEAN,
    ValidFrom TIMESTAMP,  
    ValidTo TIMESTAMP,
    UpdateTimestamp TIMESTAMP,
    UNIQUE (PropertyOwnerName, ApplicantAddress, ParcelNumber)
);

Function update_applicant_dim_full for SCD2 Maintenance
CREATE OR REPLACE FUNCTION update_applicant_dim_full()
RETURNS VOID AS $$
BEGIN
    -- Update existing records from Permit_Staging
    UPDATE orlando_development."ApplicantDim" ad
    SET 
        ApplicantType = ps."Plan Review Type",
        UpdateTimestamp = CURRENT_TIMESTAMP,  -- Set to current time
        ValidFrom = CURRENT_TIMESTAMP,  -- and reflect update time
        IsActive = TRUE
    FROM orlando_development."Permit_Staging" ps
    WHERE ad.PropertyOwnerName = ps."Property Owner Name"
      AND ad.ApplicantAddress = ps."Permit Address"
      AND ad.ParcelNumber = ps."Parcel Number"
      AND (ad.UpdateTimestamp IS DISTINCT FROM CURRENT_TIMESTAMP 
		   OR ad.ApplicantType IS DISTINCT FROM ps."Plan Review Type");

    -- Update existing records from Planning_Staging and set CurrPlanPermits
    UPDATE orlando_development."ApplicantDim" ad
    SET 
        UpdateTimestamp = CURRENT_TIMESTAMP,  -- Set to current time
        ValidFrom = CURRENT_TIMESTAMP,  -- and reflect update time
        IsActive = TRUE,
        CurrPlanPermits = (SELECT COUNT(*) FROM orlando_development."Planning_Staging" p 
                           WHERE p."Applicant" = pl."Applicant" AND p."Address" = pl."Address")
    FROM orlando_development."Planning_Staging" pl
    WHERE ad.PropertyOwnerName = pl."Applicant"
      AND ad.ApplicantAddress = pl."Address"
      AND ad.ParcelNumber = pl."Parcel Name"
      AND ad.UpdateTimestamp IS DISTINCT FROM CURRENT_TIMESTAMP;

    -- Insert new records from Permit_Staging
    INSERT INTO orlando_development."ApplicantDim" (
        PropertyOwnerName, ApplicantType, ApplicantAddress, ParcelNumber,
        IsActive, ValidFrom, UpdateTimestamp
    )
    SELECT 
        ps."Property Owner Name", ps."Plan Review Type", ps."Permit Address", ps."Parcel Number",
        TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP  -- Current time for new inserts
    FROM orlando_development."Permit_Staging" ps
    ON CONFLICT (PropertyOwnerName, ApplicantAddress, ParcelNumber)
    DO NOTHING;

    -- Insert new records from Planning_Staging
    INSERT INTO orlando_development."ApplicantDim" (
        PropertyOwnerName, ApplicantAddress, ParcelNumber, 
        IsActive, ValidFrom, UpdateTimestamp, CurrPlanPermits
    )
    SELECT 
        pl."Applicant", pl."Address", pl."Parcel Name",
        TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,  -- Current time for new inserts
        (SELECT COUNT(*) FROM orlando_development."Planning_Staging" p 
         WHERE p."Applicant" = pl."Applicant" AND p."Address" = pl."Address")
    FROM orlando_development."Planning_Staging" pl
    ON CONFLICT (PropertyOwnerName, ApplicantAddress, ParcelNumber)
    DO NOTHING;

END;
$$ LANGUAGE plpgsql;

SELECT update_applicant_dim_full();

-- Select top 10 applicants with most permits/planning permits
SELECT
ApplicantID,
CurrPermits,
CurrPlanPermits,
IsActive,
ValidFrom,
ValidTo,
UpdateTimeStamp
FROM orlando_development."ApplicantDim"
ORDER BY CurrPlanPermits DESC NULLS LAST
LIMIT 10;

-- 2. Create ContractorDim dimension table
DROP TABLE IF EXISTS orlando_development."ContractorDim";
CREATE TABLE orlando_development."ContractorDim" (
    ContractorID SERIAL PRIMARY KEY,
    ContractorCo VARCHAR(2000),
    ContractorType VARCHAR(255),
    ContractorAddress VARCHAR(1000),
    CurrPermits INTEGER,
    IsActive BOOLEAN,
    ValidFrom DATE,
    ValidTo DATE,
    UNIQUE (ContractorCo, ContractorAddress)
);

Function update_contractor_dim updates records with significant changes
Note: this is the old implementation style for SCD2 from the presentation day
CREATE OR REPLACE FUNCTION update_contractor_dim()
RETURNS VOID AS $$
BEGIN
    -- Update existing records and replace them if significant change
    UPDATE orlando_development."ContractorDim" cd
    SET IsActive = FALSE, ValidTo = CURRENT_DATE
    FROM (
        SELECT
            "Contractor Name",
            "Contractor Address",
            COUNT(*) AS TotalPermits
        FROM orlando_development."Permit_Staging"
        WHERE "Application Status" != 'Closed'
        GROUP BY "Contractor Name", "Contractor Address"
    ) AS ps
    WHERE cd.ContractorCo = ps."Contractor Name"
      AND cd.ContractorAddress = ps."Contractor Address"
      AND cd.IsActive
      AND cd.CurrPermits != ps.TotalPermits;

    -- Insert new or updated records
    INSERT INTO orlando_development."ContractorDim" (
        ContractorCo,
        ContractorType,
        ContractorAddress,
        CurrPermits,
        IsActive,
        ValidFrom,
        ValidTo
    )
    SELECT
        ps."Contractor Name",
        'Default Type', 
        ps."Contractor Address",
        ps.TotalPermits,
        TRUE,
        CURRENT_DATE,
        NULL
    FROM (
        SELECT
            "Contractor Name",
            "Contractor Address",
            COUNT(*) AS TotalPermits
        FROM orlando_development."Permit_Staging"
        WHERE "Application Status" != 'Closed'
        GROUP BY "Contractor Name", "Contractor Address"
    ) AS ps
    ON CONFLICT (ContractorCo, ContractorAddress) DO UPDATE
    SET 
        CurrPermits = EXCLUDED.CurrPermits,
        ValidFrom = EXCLUDED.ValidFrom,
        IsActive = EXCLUDED.IsActive;

END;
$$ LANGUAGE plpgsql;

SELECT update_contractor_dim();

-- Function to categorize contractors by the type of work they do most (Electric, General, etc.) 
CREATE OR REPLACE FUNCTION categorize_contractor_type()
RETURNS VOID AS $$
BEGIN
    -- Temp table holds counts of app type by contractor
    CREATE TEMP TABLE contractor_types AS
    SELECT
        "Contractor Name",
        "Application Type",
        COUNT(*) AS permit_count
    FROM orlando_development."Permit_Staging"
    GROUP BY "Contractor Name", "Application Type";

    -- Update table with the most frequent app type
    UPDATE orlando_development."ContractorDim" cd
    SET ContractorType = CASE
                             WHEN ranked_ct."Application Type" = 'Building Permit' THEN 'General'
                             WHEN ranked_ct."Application Type" = 'Mechanical Permit' THEN 'Mechanical'
							 WHEN ranked_ct."Application Type" = 'Fire Permit' THEN 'Fire'
							 WHEN ranked_ct."Application Type" = 'Demolition Permit' THEN 'Demolition'
                             ELSE ranked_ct."Application Type"
                         END
    FROM (
        SELECT 
            "Contractor Name" AS contractor_name,
            "Application Type",
            RANK() OVER (PARTITION BY "Contractor Name" ORDER BY permit_count DESC) AS rank
        FROM contractor_types
    ) ranked_ct
    WHERE cd.ContractorCo = ranked_ct.contractor_name
      AND ranked_ct.rank = 1;

    -- Drop temp table
    DROP TABLE contractor_types;
END;
$$ LANGUAGE plpgsql;

SELECT categorize_contractor_type();

-- 3. Create LocationDim dimension table
DROP TABLE IF EXISTS orlando_development."LocationDim";
CREATE TABLE orlando_development."LocationDim" (
    LocationID SERIAL PRIMARY KEY,
    Commissioner_District INTEGER,
	Mainstreet_District VARCHAR(255),
	Neighborhood VARCHAR(255),
	Parcel_Number VARCHAR(2000),
	Address VARCHAR(1000),
	UNIQUE (Parcel_Number, Address)
	);

INSERT INTO orlando_development."LocationDim" (
    commissioner_district,
    mainstreet_district,
    neighborhood,
    parcel_number,
    address
)
SELECT DISTINCT
    CAST(NULLIF(TRIM("Commissioner District"), '') AS INTEGER),
    "Mainstreet District",
    "Neighborhood",
    "Parcel Number",
    "Permit Address"
FROM orlando_development."Permit_Staging"
ON CONFLICT (Parcel_Number, Address) DO NOTHING;

-- 4. Create DateDim dimension table
DROP TABLE IF EXISTS orlando_development."DateDim" CASCADE;
CREATE TABLE orlando_development."DateDim" (
    DateID SERIAL PRIMARY KEY,
    FullDate DATE NOT NULL UNIQUE,
    DayOfWeek VARCHAR(10),
    DayOfMonth INT,
    Month INT,
    MonthName VARCHAR(20),
    Quarter INT,
    Year INT,
    YearMonth VARCHAR(20),
    YearQuarter VARCHAR(20)
);

INSERT INTO orlando_development."DateDim" (
    FullDate,
    DayOfWeek,
    DayOfMonth,
    Month,
    MonthName,
    Quarter,
    Year,
    YearMonth,
    YearQuarter
)
SELECT 
    date,
    TRIM(TO_CHAR(date, 'Day')), 
    EXTRACT(DAY FROM date) AS DayOfMonth,
    EXTRACT(MONTH FROM date) AS Month,
    TO_CHAR(date, 'Month') AS MonthName,
    EXTRACT(QUARTER FROM date) AS Quarter,
    EXTRACT(YEAR FROM date) AS Year,
    TO_CHAR(date, 'YYYY-MM') AS YearMonth,
    TO_CHAR(date, 'YYYY-"Q"Q') AS YearQuarter
FROM generate_series('2019-01-01'::date, '2024-12-31'::date, '1 day'::interval) AS date;


BEGIN;

-- 5. Create PermitAppFact table
DROP TABLE IF EXISTS orlando_development."PermitAppFact" CASCADE;
CREATE TABLE orlando_development."PermitAppFact" (
    PermitID SERIAL PRIMARY KEY,
    PermitNumber VARCHAR(2000),
    PlanReviewType VARCHAR(100),
    AppType VARCHAR(100),
    ProjName VARCHAR(500),
    LocationID INTEGER,
    Neighborhood VARCHAR(100),
	PermitAddress VARCHAR(1000),
    ApplicantID INTEGER,
    ApplicantName VARCHAR (2000),
    ContractorID INTEGER,
    ContractorName VARCHAR (2000),
    SqFootage DOUBLE PRECISION,
    EstCost DOUBLE PRECISION,
    PermitStatus VARCHAR(100),
    FOREIGN KEY (applicantid) REFERENCES orlando_development."ApplicantDim"(applicantid),
    FOREIGN KEY (contractorid) REFERENCES orlando_development."ContractorDim"(contractorid),
    FOREIGN KEY (locationid) REFERENCES orlando_development."LocationDim"(locationid)
);

-- Create Indexes to help runtime efficiency
DROP INDEX IF EXISTS orlando_development.idx_applicant_propertyownername;
CREATE INDEX idx_applicant_propertyownername ON orlando_development."ApplicantDim" (PropertyOwnerName);

DROP INDEX IF EXISTS orlando_development.idx_contractor_contractorco;
CREATE INDEX idx_contractor_contractorco ON orlando_development."ContractorDim" (ContractorCo);

DROP INDEX IF EXISTS orlando_development.idx_location_address;
CREATE INDEX idx_location_address ON orlando_development."LocationDim" (Address);

Create Trigger Function to update PermitAppFact when ApplicantDim is updated
CREATE OR REPLACE FUNCTION update_permitappfact_applicant()
RETURNS TRIGGER AS $$
BEGIN
    -- Update ApplicantName in PermitAppFact when ApplicantDim is updated
    UPDATE orlando_development."PermitAppFact"
    SET ApplicantName = NEW.PropertyOwnerName
    WHERE ApplicantID = NEW.ApplicantID;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Trigger on ApplicantDim table
CREATE TRIGGER applicantdim_update_trigger
AFTER UPDATE ON orlando_development."ApplicantDim"
FOR EACH ROW
WHEN (OLD.PropertyOwnerName IS DISTINCT FROM NEW.PropertyOwnerName)
EXECUTE FUNCTION update_permitappfact_applicant();

BEGIN;

-- Insert into PermitAppFact
INSERT INTO orlando_development."PermitAppFact" (
    PermitNumber, AppType, PlanReviewType, ProjName, Neighborhood, PermitAddress,
    LocationID, ApplicantID, ApplicantName, ContractorID, ContractorName, 
    SqFootage, EstCost, PermitStatus)
SELECT DISTINCT ON (ps."Permit Number")
    ps."Permit Number",
    ps."Application Type",
    ps."Plan Review Type",
    ps."Project Name",
    ps."Neighborhood",
    ps."Permit Address",
    ld.LocationID,
    ad.ApplicantID,
    ad.PropertyOwnerName AS ApplicantName,
    cd.ContractorID,
    cd.ContractorCo AS ContractorName,
    ps."Square Footage",
    ps."Estimated Cost",
    ps."Application Status"
FROM
    orlando_development."Permit_Staging" ps
LEFT JOIN orlando_development."LocationDim" ld ON ld.Address = ps."Permit Address"
LEFT JOIN orlando_development."ApplicantDim" ad ON UPPER(TRIM(ad.PropertyOwnerName)) = UPPER(TRIM(ps."Property Owner Name"))
LEFT JOIN orlando_development."ContractorDim" cd ON cd.ContractorCo = ps."Contractor Name"
ORDER BY ps."Permit Number" ASC;

COMMIT;

-- Verify updates
SELECT * FROM orlando_development."PermitAppFact"
WHERE ApplicantID IS NOT NULL;

BEGIN;

-- 6. Create PlanningFact table
DROP TABLE IF EXISTS orlando_development."PlanningFact" CASCADE;
CREATE TABLE orlando_development."PlanningFact" (
    PlanAppID SERIAL PRIMARY KEY,
	AppNumber VARCHAR (100),
    ApplicantID INTEGER,
    ApplicantName VARCHAR (2000),
    PlanAppName VARCHAR (2000),
	LocationID INTEGER,
	Neighborhood VARCHAR(100),
	PlanAppAddress VARCHAR(1000),
    PlanAppStatus VARCHAR(100),
	PlanAppDesc VARCHAR (500),
    FOREIGN KEY (applicantid) REFERENCES orlando_development."ApplicantDim"(applicantid),
    FOREIGN KEY (locationid) REFERENCES orlando_development."LocationDim"(locationid)
);

INSERT INTO orlando_development."PlanningFact" (
    AppNumber, ApplicantID, ApplicantName, PlanAppName, LocationID, Neighborhood,
    PlanAppAddress, PlanAppStatus, PlanAppDesc)
SELECT DISTINCT ON (pls."Application Number")
    pls."Application Number",
	ad.ApplicantID,
    pls."Applicant",
    pls."Application Name",
    ld.LocationID,
	pls."Neighborhood",
	pls."Address",
    pls."Application Status",
	pls."Application Description"
FROM
    orlando_development."Planning_Staging" pls
LEFT JOIN orlando_development."LocationDim" ld ON ld.Address = pls."Address"
LEFT JOIN orlando_development."ApplicantDim" ad ON ad.PropertyOwnerName = pls."Applicant"
ORDER BY pls."Application Number" DESC;

COMMIT;

SELECT * FROM orlando_development."PlanningFact";

7. Create PermitDateDim table
DROP TABLE IF EXISTS orlando_development."PermitDateDim";
CREATE TABLE orlando_development."PermitDateDim" (
    PermitID INTEGER,
    Processed_Date DATE,
    Processed_Date_ID INTEGER,
    Issue_Date DATE,
    Issue_Date_ID INTEGER,
    Permit_Days_to_Issue INTEGER,
    Processed_YearMonth VARCHAR(20),
    Issue_YearMonth VARCHAR(20),
    FOREIGN KEY (PermitID) REFERENCES orlando_development."PermitAppFact"(PermitID),
    FOREIGN KEY (Processed_Date_ID) REFERENCES orlando_development."DateDim"(DateID),
    FOREIGN KEY (Issue_Date_ID) REFERENCES orlando_development."DateDim"(DateID)
);

-- Insert data into PermitDateDim
INSERT INTO orlando_development."PermitDateDim" (
    PermitID,
    Processed_Date,
    Processed_Date_ID,
    Issue_Date,
    Issue_Date_ID,
    Permit_Days_to_Issue,
    Processed_YearMonth,
    Issue_YearMonth
)
SELECT
    paf.PermitID,
    ps."Processed Date",
    dd1.DateID AS Processed_Date_ID,
    ps."Issue Permit Date",
    dd2.DateID AS Issue_Date_ID,
    EXTRACT(DAY FROM (ps."Issue Permit Date" - ps."Processed Date")) AS Permit_Days_to_Issue,
    dd1.YearMonth AS Processed_YearMonth,
    dd2.YearMonth AS Issue_YearMonth
FROM
    orlando_development."Permit_Staging" ps
LEFT JOIN orlando_development."PermitAppFact" paf ON paf.PermitNumber = ps."Permit Number"
LEFT JOIN orlando_development."DateDim" dd1 ON dd1.FullDate = ps."Processed Date"
LEFT JOIN orlando_development."DateDim" dd2 ON dd2.FullDate = ps."Issue Permit Date";

SELECT *
FROM orlando_development."PermitDateDim"
ORDER BY Permit_Days_to_Issue ASC NULLS LAST;

-- 8. Create PlanningDateDim table
DROP TABLE IF EXISTS orlando_development."PlanningDateDim" CASCADE;
CREATE TABLE orlando_development."PlanningDateDim" (
    PlanAppID INTEGER,
    Plan_App_Date DATE,
    PlanApp_Date_ID INTEGER,
    Plan_Approval_Date DATE,
    Approval_Date_ID INTEGER,
    Last_Action_Date DATE,
    LastAction_Date_ID INTEGER,
    PlanApp_YearMonth VARCHAR(20),
    Approval_YearMonth VARCHAR(20),
    LastAction_YearMonth VARCHAR(20),
    FOREIGN KEY (PlanAppID) REFERENCES orlando_development."PlanningFact"(PlanAppID),
    FOREIGN KEY (PlanApp_Date_ID) REFERENCES orlando_development."DateDim"(DateID),
    FOREIGN KEY (Approval_Date_ID) REFERENCES orlando_development."DateDim"(DateID),
    FOREIGN KEY (LastAction_Date_ID) REFERENCES orlando_development."DateDim"(DateID)
);

INSERT INTO orlando_development."PlanningDateDim" (
    PlanAppID,
    Plan_App_Date,
    PlanApp_Date_ID,
    Plan_Approval_Date,
    Approval_Date_ID,
    Last_Action_Date,
    LastAction_Date_ID,
    PlanApp_YearMonth,
    Approval_YearMonth,
    LastAction_YearMonth
)
SELECT
    plf.PlanAppID,
    pls."Application Date",
    dd3.DateID AS PlanApp_Date_ID, 
    pls."Approval Date",
    dd4.DateID AS Approval_Date_ID,
    pls."Last Action Date",
    dd5.DateID AS LastAction_Date_ID,
    dd3.YearMonth AS PlanApp_YearMonth,
    dd4.YearMonth AS Approval_YearMonth,
    dd5.YearMonth AS LastAction_YearMonth
FROM
    orlando_development."Planning_Staging" pls
LEFT JOIN orlando_development."PlanningFact" plf ON plf.AppNumber = pls."Application Number"
LEFT JOIN orlando_development."DateDim" dd3 ON dd3.FullDate = pls."Application Date" 
LEFT JOIN orlando_development."DateDim" dd4 ON dd4.FullDate = pls."Approval Date"
LEFT JOIN orlando_development."DateDim" dd5 ON dd5.FullDate = pls."Last Action Date";

SELECT *
FROM orlando_development."PlanningDateDim";

-- 9. Create Permits_By_Date cumulative fact table
DROP TABLE IF EXISTS orlando_development."Permits_By_Date";
CREATE TABLE orlando_development."Permits_By_Date" (
    DateID INTEGER NOT NULL PRIMARY KEY,
    TotalPermits INTEGER DEFAULT 0,
    TotalPlanningPermits INTEGER DEFAULT 0,
    FOREIGN KEY (DateID) REFERENCES orlando_development."DateDim"(DateID)
);

INSERT INTO orlando_development."Permits_By_Date" (DateID, TotalPermits, TotalPlanningPermits)
SELECT
    dd.DateID,
    COALESCE(pd.TotalPermits, 0),
    COALESCE(pld.TotalPlanningPermits, 0)
FROM
    orlando_development."DateDim" dd
LEFT JOIN (
    SELECT
        processed_date_id,
        COUNT(*) AS TotalPermits
    FROM
        orlando_development."PermitDateDim"
    GROUP BY
        processed_date_id
) pd ON pd.processed_date_id = dd.DateID
LEFT JOIN (
    SELECT
        planapp_date_id,
        COUNT(*) AS TotalPlanningPermits
    FROM
        orlando_development."PlanningDateDim"
    GROUP BY
        planapp_date_id
) pld ON pld.planapp_date_id = dd.DateID
ORDER BY
    dd.DateID;

-- 10. Create Permits_By_Location cumulative fact table
DROP TABLE IF EXISTS orlando_development."Permits_By_Location";
CREATE TABLE orlando_development."Permits_By_Location" (
    LocationID INTEGER NOT NULL PRIMARY KEY,
    TotalPermits INTEGER DEFAULT 0,
    TotalPlanningPermits INTEGER DEFAULT 0,
    FOREIGN KEY (LocationID) REFERENCES orlando_development."LocationDim"(LocationID)
);

INSERT INTO orlando_development."Permits_By_Location" (LocationID, TotalPermits, TotalPlanningPermits)
SELECT
    ld.LocationID,
    COALESCE(paf.TotalPermits, 0),
    COALESCE(plf.TotalPlanningPermits, 0)
FROM
    orlando_development."LocationDim" ld
LEFT JOIN (
    SELECT
        LocationID,
        COUNT(*) AS TotalPermits
    FROM
        orlando_development."PermitAppFact"
    GROUP BY
        LocationID
) paf ON paf.LocationID = ld.LocationID
LEFT JOIN (
    SELECT
        LocationID,
        COUNT(*) AS TotalPlanningPermits
    FROM
        orlando_development."PlanningFact"
    GROUP BY
        LocationID
) plf ON plf.LocationID = ld.LocationID
ORDER BY
    ld.LocationID;

-- 11. Create OrlandoHousingFact snapshot fact table
DROP TABLE IF EXISTS orlando_development."OrlandoHousingFact";
CREATE TABLE orlando_development."OrlandoHousingFact" (
    housingid SERIAL PRIMARY KEY,
    dateid INTEGER,
    Homes_for_Sale INTEGER,
    Median_Sale_Price NUMERIC,
    Num_Homes_Sold INTEGER,
    FOREIGN KEY (dateid) REFERENCES orlando_development."DateDim"(DateID)
);

INSERT INTO orlando_development."OrlandoHousingFact" (
    dateid,
    Homes_for_Sale,
    Median_Sale_Price,
    Num_Homes_Sold
)
SELECT
    dd.DateID,
    hs.Homes_for_Sale,
    hs.Median_Sale_Price,
    hs.Num_Homes_Sold
FROM
    orlando_development."Housing_Staging" hs
JOIN
    orlando_development."DateDim" dd ON (dd.Year = hs.Year AND dd.Month = 
										 TO_NUMBER(TO_CHAR(TO_DATE(hs.Month, 'Month'), 'MM'), '99'))
WHERE
    dd.dayofmonth = 1;

-- 12. Create OrlandoWorkForceFact snapshot fact table
DROP TABLE IF EXISTS orlando_development."OrlandoWorkForceFact";
CREATE TABLE orlando_development."OrlandoWorkForceFact" (
    workforceid SERIAL PRIMARY KEY,
    dateid INTEGER,
    total_workforce INTEGER,
    FOREIGN KEY (dateid) REFERENCES orlando_development."DateDim"(DateID)
);

INSERT INTO orlando_development."OrlandoWorkForceFact" (
    dateid,
    total_workforce
)
SELECT
    dd.DateID,
    ws.total_workforce
FROM
    orlando_development."Workforce_Staging" ws
JOIN
    orlando_development."DateDim" dd ON (dd.Year = ws.Year AND dd.Month = 
										 TO_NUMBER(TO_CHAR(TO_DATE(ws.Month, 'Month'), 'MM'), '99'))
WHERE
    dd.dayofmonth = 1;

---------- *** QUERIES *** ----------

/*
Question 1:	Which neighborhoods in Orlando saw the most applications for 
COMMERCIAL development in the past year?
*/

SELECT
    Neighborhood,
    TotalCommercialApplications,
    RANK() OVER (ORDER BY TotalCommercialApplications DESC) AS NeighborhoodRank
FROM (
    SELECT
        l.Neighborhood,
        COUNT(p.PermitID) AS TotalCommercialApplications
    FROM
        orlando_development."PermitAppFact" p
    JOIN
        orlando_development."PermitDateDim" pd ON pd.PermitID = p.PermitID
    JOIN
        orlando_development."DateDim" d ON pd.processed_date_id = d.DateID
    JOIN
        orlando_development."LocationDim" l ON p.LocationID = l.LocationID
    WHERE
        d.FullDate BETWEEN DATE_TRUNC('year', CURRENT_DATE) - 
		INTERVAL '1 year' AND DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 day'
        AND p.PlanReviewType IN ('Commercial')
    GROUP BY
        l.Neighborhood
) AS Subquery
ORDER BY
    TotalCommercialApplications DESC;

/*
Question 2:	Which neighborhoods in Orlando saw the most permit applications for 
RESIDENTIAL development in the past year?
*/

SELECT
    Neighborhood,
    TotalResidentialApplications,
    RANK() OVER (ORDER BY TotalResidentialApplications DESC) AS NeighborhoodRank
FROM (
    SELECT
        l.Neighborhood,
        COUNT(p.PermitID) AS TotalResidentialApplications
    FROM
        orlando_development."PermitAppFact" p
    JOIN
        orlando_development."PermitDateDim" pd ON pd.PermitID = p.PermitID
    JOIN
        orlando_development."DateDim" d ON pd.processed_date_id = d.DateID
    JOIN
        orlando_development."LocationDim" l ON p.LocationID = l.LocationID
    WHERE
        d.FullDate BETWEEN DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 year' AND DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 day'
        AND p.PlanReviewType IN ('Residential 1/2', 'Residential 3 or more')
    GROUP BY
        l.Neighborhood
) AS Subquery
ORDER BY
    TotalResidentialApplications DESC;

/*
Question 3:	Which contractor types were most hired in Orlando in the last year?
*/

SELECT
    ContractorType,
    PlanReviewType,
    TotalHires,
    Rank
FROM (
    SELECT
        c.ContractorType,
        p.PlanReviewType,
        COUNT(p.PermitID) AS TotalHires,
        RANK() OVER (PARTITION BY p.PlanReviewType ORDER BY COUNT(p.PermitID) DESC) AS Rank
    FROM
        orlando_development."PermitAppFact" p
    JOIN
        orlando_development."ContractorDim" c ON p.ContractorID = c.ContractorID
    JOIN
        orlando_development."PermitDateDim" pd ON p.PermitID = pd.PermitID
    JOIN
        orlando_development."DateDim" d ON pd.processed_date_id = d.DateID
    WHERE
        d.FullDate BETWEEN DATE_TRUNC('year', CURRENT_DATE) - 
		INTERVAL '1 year' AND DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 day'
        AND p.PlanReviewType IN ('Commercial', 'Residential 1/2', 'Residential 3 or more')
    GROUP BY
        c.ContractorType,
        p.PlanReviewType
) SubQuery
WHERE Rank <= 10
ORDER BY
    PlanReviewType,
    Rank;

/*
Question 4: How has both residential and commercial development in the 
Orlando area impacted home prices, sales, and inventory?
*/

SELECT
    dd.YearMonth,
    ohf.Median_Sale_Price,
    ohf.Num_Homes_Sold,
    ohf.Homes_for_Sale,
    COALESCE(pbd.TotalPermits, 0) AS TotalPermits,
    COALESCE(pbd.TotalPlanningPermits, 0) AS TotalPlanningPermits
FROM
    orlando_development."OrlandoHousingFact" ohf
JOIN
    orlando_development."DateDim" dd ON ohf.DateID = dd.DateID
LEFT JOIN
    (SELECT DateID, SUM(TotalPermits) AS TotalPermits, 
	 SUM(TotalPlanningPermits) AS TotalPlanningPermits
     FROM orlando_development."Permits_By_Date"
     GROUP BY DateID) pbd ON dd.DateID = pbd.DateID
WHERE
    dd.FullDate BETWEEN DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '2 year' 
	AND DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 day'
ORDER BY
    dd.YearMonth;

/*
Question 5: How has COMMERCIAL development in the Orlando area impacted workforce numbers?
*/

SELECT
    dd.YearMonth,
    SUM(pld.TotalCommercialApps) AS TotalCommercialApps,
    SUM(wf.Total_Workforce) AS TotalWorkforce  -- Summing workforce figures
FROM
    orlando_development."DateDim" dd
LEFT JOIN (
    SELECT
        DateID,
        SUM(TotalCommercialApps) AS TotalCommercialApps
    FROM (
        SELECT
            pd.processed_date_id AS DateID,
            COUNT(*) AS TotalCommercialApps
        FROM
            orlando_development."PermitAppFact" p
        JOIN
            orlando_development."PermitDateDim" pd ON p.PermitID = pd.PermitID
        WHERE
            p.PlanReviewType = 'Commercial'
        GROUP BY
            pd.processed_date_id
        UNION ALL
        SELECT
            pld.planapp_date_id AS DateID,
            COUNT(*) AS TotalCommercialApps
        FROM
            orlando_development."PlanningFact" p
        JOIN
            orlando_development."PlanningDateDim" pld ON p.PlanAppID = pld.PlanAppID
        GROUP BY
            pld.planapp_date_id
    ) a
    GROUP BY
        DateID
) pld ON dd.DateID = pld.DateID
LEFT JOIN orlando_development."OrlandoWorkForceFact" wf ON dd.DateID = wf.DateID
WHERE
    dd.FullDate BETWEEN DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '2 year' 
	AND DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 day'
GROUP BY
    dd.YearMonth
ORDER BY
    dd.YearMonth;





