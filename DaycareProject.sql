/*
This project focuses on the dataset that contains information on childcare programs in Alberta. It is taken from the Government of Alberta open datasets and publications. 
In this project we will filter the data to find the best available option for a child based on a few criteria: proximity to home, 
absence of inspection problems and incidents, type of the program. After the filtering of the data is completed, 
we will have 3 top contestants and then we will complete the calculation of the distance from the given point (home) to each location. 
The closest location will be chosen as the facility of choice.
*/

-- Looking at the total number of facilities in the dataset:
SELECT *
FROM DaycareInfo

--We need to identify which daycares are located in teh Beltline neighbourhood in Calgary. 
--Beltline is a region of central Calgary, Alberta, Canada, this is the location we reside so we are going to explore the daycare facilities in the vicinity.
--The Postal code that belongs to Beltline is 'T2R':

SELECT *
FROM DaycareInfo
WHERE [Physical Postal Code] LIKE 'T2R%'

-- Calculating total number of the facilities in the given region:

SELECT Distinct COUNT ([Program Name])
FROM DaycareInfo
WHERE [Physical Postal Code] LIKE 'T2R%'

--We now look at 31 facility to explore further.
-- Just by looking at the names of the facilities it apears that there maybe some duplicates. 
--Checking if there are any duplicates by looking at the uniques addresses of the facilities. 

SELECT DISTINCT [Physical Address Line]
FROM DaycareInfo
WHERE [Physical Postal Code] LIKE 'T2R%'

--It appears we have 8 facilities located in the desired area. Let's explore further. 
--Now, we would like to see only the facilities that are characterised as 'Daycare Program' as we have a 1 year old and she is too small to attend "Out of School facilities":

SELECT DISTINCT [Physical Address Line], [Program Name]
FROM DaycareInfo
WHERE [Physical Postal Code] LIKE 'T2R%' AND [Type Name] = 'DAY CARE PROGRAM'

-- Looks like we narrowed the list down to 6 properties of interest.
--We are adding more column names to apply other filters to our dataset:

SELECT DISTINCT [Program Name], [Physical Address Line], Space, [Inspection Date], [Inspection Reason Name]
FROM DaycareInfo
WHERE [Physical Postal Code] LIKE 'T2R%' AND [Type Name] = 'DAY CARE PROGRAM' 

-- Upon exploration we identified that some facities had a few different kind of inspections and some may raise redflags for us. Let's investigate further. 
-- We are only interested in year 2020 since it's the most recent, "inspection" and "licence renewal" seems to be normal reasons for inspection, however 'incident' and 'inforcement action' raise some concerns:

-- Converting Inspection Date into DATE from NVARCHAR and saving into Betline Daycares table:

SELECT DISTINCT [Program Name], CONVERT(DATE, [Inspection Date]) AS [New Inspection Date], [Inspection Reason Name]
INTO [Beltline Daycares]
FROM DaycareInfo
WHERE [Physical Postal Code] LIKE 'T2R%' 
AND [Type Name] = 'DAY CARE PROGRAM' 

--- Filtering by year and inspection type

SELECT DISTINCT [Program Name], [New Inspection Date], [Inspection Reason Name]
FROM [Beltline Daycares]
WHERE [New Inspection Date] > '2020-01-01' AND [Inspection Reason Name] = 'FOLLOW UP TO ENFORCEMENT ACTION' 
OR [Inspection Reason Name] = 'COMPLAINT INVESTIGATION'
OR [Inspection Reason Name] = 'INCIDENT REPORT'

--Looks like we do not want to register with 2 daycares (Cups and KIDO Care) as they had some incidents in 2020 and we decided it's a Red Flag for us. Let's filter them out. 

SELECT DISTINCT [Program Name]
FROM [Beltline Daycares]
WHERE [Program Name] <> 'CUPS-ONE WORLD CHILD DEVELOPMENT CENTRE' 
AND [Program Name] <> 'KIDO CARE INC.'

-- we now have 3 daycare facilities to choose from: Cross-Cultural Children's Center, Family First Child Development Centre and KIDS & Company Beltline.
-- It is important for us that the daycare is within a walking distance from the house, so let see which of three is the closest to us:

SELECT DISTINCT [Beltline Daycares].[Program Name], [Physical Address Line], [Physical City Name], [Physical Postal Code], [Type Name]
INTO  [Final 3]
FROM DaycareInfo JOIN [Beltline Daycares] 
ON ([DaycareInfo].[Program Name] = [Beltline Daycares].[Program Name])
WHERE [Beltline Daycares].[Program Name] <> 'CUPS-ONE WORLD CHILD DEVELOPMENT CENTRE' 
AND [Beltline Daycares].[Program Name] <> 'KIDO CARE INC.'
AND [Beltline Daycares].[Program Name] <> 'FAMILY FIRST CREATIVE LEARNING CENTRE INC.'

SELECT * 
FROM [Final 3]

/* 
Calculating distance between the house and the daycare using STDistance (geometry Data Type) - Returns the shortest distance between a point in a geometry instance and a point in another geometry instance.
We will be using 4326 web mercator locator. The Well-Known ID (WKID) is a unique number assigned to a coordinate system. 
You can find the WKID in the Coordinate Systems Details window. Once you know this number, it's a handy way to search for the coordinate system later. 
We will take lat/long coordinates for all 3 daycares and our home to calculate the distance
*/

 ALTER TABLE [Final 3]
Add [Shape] geometry

SELECT * 
FROM [Final 3]

UPDATE [Final 3] 
SET Shape = geometry::STGeomFromText('POINT (-114.06968321511208 51.0425917902214)', 4326)
where [Program Name] = 'KIDS & COMPANY BELTLINE'

UPDATE [Final 3] 
SET Shape = geometry::STGeomFromText('POINT (-114.07284545181597  51.04242380683708)', 4326)
where [Program Name] = 'FAMILY FIRST CHILD DEVELOPMENT CENTRE'

UPDATE [Final 3] 
SET Shape = geometry::STGeomFromText('POINT (-114.08660305928944 51.04305143292856)', 4326)
WHERE [Physical Postal Code] = 'T2R0G5'

DECLARE @homeLocation AS geometry = (geometry::STGeomFromText('POINT (-114.08422525189592 51.04246300509929)', 4326))
DECLARE @HomeLocationGeo AS geography = geography::STGeomFromText(@HomeLocation.ToString(), 4326);
--SELECT @homeLocationGeo AS GeoShape

DECLARE @NearestDaycare AS geometry = (SELECT TOP 1 [Final 3].Shape FROM [Final 3] WHERE Shape.STDistance(@homeLocation) IS NOT NULL ORDER BY Shape.STDistance(@homeLocation) ASC)
DECLARE @NearestDaycareGeo AS geography = geography::STGeomFromText(@NearestDaycare.ToString(), 4326);

DECLARE @DistanceMeter int= @HomeLocationGeo.STDistance(@NearestDaycareGeo);

select TOP 1 @DistanceMeter as Distance, [Program Name]
From [Final 3]
-- We've checked the results using Google Earth Measurement tool and they appear to be correct.Hence, we've got the winning contestant - CROSS CULTURAL CHILDREN'S CENTER.