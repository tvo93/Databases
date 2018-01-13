
/*
	PROJECT - DocOffice Database
	[ Thuan Vo
	Leeza Vuong
	Ngan Nguyen ]
*/


-- create database
CREATE DATABASE DocOffice;

-- Use DocOffice database to create tables and relationship
use DocOffice

/*
	Create tables, indexes, relationships and triggers to reach 
	business rules
*/

-----------------------------------------------
---------------- CREATE TABLES ----------------
-----------------------------------------------

-- create PERSON table
CREATE TABLE Person (
	PersonID		int				PRIMARY KEY		NOT NULL,
	FirstName		varchar(60)		NOT NULL,
	LastName		varchar(60)		NOT NULL,
	StreetAddress	varchar(60)		NOT NULL,
	City			varchar(40)		NOT NULL,
	[State]			varchar(40)		NOT NULL,
	Zip				varchar(10)		NOT NULL,
	PhoneNumber		varchar(12)		NOT NULL,
	SSN				varchar(11)		NOT NULL
) 

-- createa DOCTOR table
CREATE TABLE Doctor (	
	DoctorID		char(6)				PRIMARY KEY NOT NULL,
	MedicalDegree	varchar(255)	NOT NULL,
	PersonID		int				NOT NULL,
	check (DATALENGTH(DoctorID) = 6 and DoctorID LIKE '[a-z][a-z][0-9][0-9][0-9][0-9]')
)

-- create PATIENT doctor
CREATE TABLE Patient (
	PatientID		int				PRIMARY KEY		IDENTITY,
	SecPhoneNumber	varchar(12)	NOT NULL,
	DOB				date			NOT NULL,
	PersonID		int				NOT NULL,
)

-- creata PATIENTVISIT table
CREATE TABLE PatientVisit (
	VisitID		int				PRIMARY KEY		 NOT NULL,
	PatientID	int			NOT NULL,
	DoctorID	char(6)				NOT NULL,
	VisitDate	date			NOT NULL,
	DocNote		varchar(255)	DEFAULT NULL
)

-- create TEST table
CREATE TABLE Test (
	TestID		int				PRIMARY KEY NOT NULL,
	TestName	varchar(60)		NOT NULL
)


-- create PVISITTEST table
CREATE TABLE PVisitTest (
	VisitID		int		NOT NULL,
	TestID		int	    default NULL,	
	PRIMARY KEY(VisitID, TestID)
)
							
-- create PRESCRIPTION table
CREATE TABLE Prescription (
	PrescriptionID		int				PRIMARY KEY NOT NULL,
	PrescriptionName	varchar(255)	NOT NULL,	
)

-- create PVISITPRESCRIPTION table
CREATE TABLE PVisitPrescription (
	VisitID int NOT NULL,
	PrescriptionID int default NULL,
	PRIMARY KEY (VisitID, PrescriptionID)
)

-- create SPECIALITY table
CREATE TABLE Speciality (
	SpecialityID	int				PRIMARY KEY NOT NULL,
	SpecialityName  varchar(100)	NOT NULL
)

-- create DOCTORSPECIALITY table
CREATE TABLE DoctorSpeciality (
	DoctorID		char(6)		NOT NULL, 
	SpecialityID	int		default	NULL,
	PRIMARY KEY (DoctorID, SpecialityID)
)

------------------------------------------------
--------- CREATE INDEXES FOR TABLES ------------
----  Data retrieval speed is a priority -------
----  Use techniques to make it faster ---------
------------------------------------------------
	Create index IX_Person
		on Person (FirstName, LastName, City)
	create index IX_Prescription
		on Prescription (PrescriptionName)
	create index IX_Speciality 
		on Speciality (SpecialityName)
	create index IX_PatientVisit
		on PatientVisit(PatientID ASC , DoctorID ASC)
	create index IX_Test
		on Test (TestName)
	create index IX_DoctorPerson 
		on Doctor (PersonID)
	create index IX_PatientPerson
		on Patient (PersonID)

-----------------------------------------------
------- CREATE RELATIONSHIPS FOR TABLES -------
-----------------------------------------------

-- create relationship between Doctor and person tables
ALTER TABLE Doctor
	ADD CONSTRAINT Person_Doctor
	FOREIGN KEY (PersonID) REFERENCES Person(PersonID)

-- create relationship between Patient and person tables
ALTER TABLE Patient
	ADD CONSTRAINT Person_Patient
	FOREIGN KEY (PersonID) REFERENCES Person(PersonID)

-- create relationship between Test and PVisitTest
ALTER TABLE PVisitTest
	ADD CONSTRAINT T_PVisitTest
	FOREIGN KEY (TestID) REFERENCES Test(TestID),
	FOREIGN KEY (VisitID) REFERENCES PatientVisit(VisitID)

-- create relationship between Prescription and PatienVisit, Prescription
ALTER TABLE PVisitPrescription
ADD 
	CONSTRAINT P_PVisitPrescription
	FOREIGN KEY (PrescriptionID) REFERENCES Prescription(PrescriptionID),
	FOREIGN KEY (VisitID) REFERENCES PatientVisit(VisitID)


-- create relationship between Speciality and DoctorSpeciality
ALTER TABLE DoctorSpeciality
	ADD CONSTRAINT Doctor_Speciality
	FOREIGN KEY (DoctorID) REFERENCES Doctor(DoctorID),
	FOREIGN KEY (SpecialityID) REFERENCES Speciality(SpecialityID)


-- create relationship between the PatientVisit and the other tables
ALTER TABLE PatientVisit
ADD 
	CONSTRAINT Patient_PatientVisit_Details
    FOREIGN KEY  (PatientID) REFERENCES Patient(PatientID),	
	FOREIGN KEY (DoctorID) REFERENCES Doctor(DoctorID)

-----------------------------------------------
------ CREATE TRIGGERS FOR BUSINESS RULES -----
-----------------------------------------------

-- 3. If one doctor see’s the same patient multiple times in one day, 
-- then it’s only recorded once in the database. 
create trigger tPatientRecord
on PatientVisit
for insert 
as
declare @pt as int;
declare @doc as char(6);
declare @n as int;
select  @pt = PatientID, @doc = DoctorID from inserted;
SELECT @n = PatientID
FROM PatientVisit 
	where @doc = DoctorID
	group by PatientID
	having count(patientid) > 1 and count(doctorid) > 1 and count(visitdate) > 1
if @pt = @n
rollback;
	
-- 5  A doctor cannot be his/her own patient.
create trigger tDoctorPatient
on PatientVisit
for insert
as
declare @doc as char(6);
declare @per as char(6);
declare @pa as int;
select @doc = DoctorID, @pa = PatientID from inserted;
select @per = pv.DoctorID
	from patientvisit as pv
	inner join doctor as d
	on d.DoctorID = pv.DoctorID
	inner join patient as p
	on p.PatientID = pv.PatientID
	where d.PersonID = p.PersonID and @pa = pv.PatientID;
if @doc = @per
rollback;
	
--7 Each patient will get 0 to 10 prescriptions(medicine).   
create trigger tPrescription
on pVisitPrescription
for insert
as 
declare @vi as int;
declare @check as int;
select @vi = VisitID from inserted;
select @check = visitID
	from pVisitPrescription
	group by VisitID
	having count(prescriptionID) > 3;
if @vi = @check
rollback;

--8 Each patient can be given 0­5 tests (medical test).
create trigger tPatientTest
on PVisitTest
for insert
as
declare @v as int;
declare @c as int;
select @v = visitid from inserted;
select @c = VisitID
	from PVisitTest
	group by visitid
	having count(testid) > 5;
if @v = @c
rollback;

--10 Make sure that the Doctor ID is first 2 letter of his first name followed by number.
-- Eg. If the Doctors name is Ron Gates, then his DoctorID can be RO3283
create trigger tDoctor 
on Doctor
for insert
as 
	declare @d char(6);
	declare @v varchar(60);
	declare @id int;
select @d = DoctorID, @id = PersonID from inserted;
select @v = FirstName
	from Person
	where PersonID = @id;
if left(@v,2) != left(@d, 2)
rollback;
	
-----------------------------------------------
------------	QUESTIONS 2 - 6 ---------------
-----------------------------------------------

/*
Doc Rob Belkin is retiring. We need to inform all his patients, and ask them to select a new doctor.
For this purpose, Create a VIEW that finds the names and Phone numbers of all of Rob's patients.
*/

create view [Rob's patient list]
as
select pe.FirstName, pe.LastName, pe.PhoneNumber, p.SecPhoneNumber
from PatientVisit as Pv
	inner join patient as p
	on pv.PatientID = p.PatientID
	inner join person as pe
	on pe.PersonID = p.PersonID
	inner join doctor as d
	on d.DoctorID = pv.DoctorID
	where d.DoctorID in (
		select d.DoctorID
		from doctor as d
		inner join person as pe
		on pe.PersonID = d.PersonID
		where pe.FirstName = 'Rob' and pe.LastName = 'Belkin'
	)

select * from [Rob's patient list]

/*
Create a view which has First Names, Last Names of all doctors who gave out prescription for Panadol
*/
create view [Doctor list for Panadol precription]
as
select distinct pe.FirstName, pe.LastName
from PatientVisit as pv
	inner join doctor as d
	on d.DoctorID = pv.DoctorID
	inner join person as pe
	on pe.PersonID = d.PersonID
	where pv.VisitID in (
		select pv.VisitID
		from PatientVisit as pv
		inner join PVisitPrescription as pvp
		on pvp.VisitID = pv.VisitID
		inner join Prescription as pr
		on pr.PrescriptionID = pvp.PrescriptionID
		where pr.PrescriptionName = 'Panadol'
	)

SELECT * FROM [Doctor list for Panadol precription]

/*
Create a view which Shows the First Name and Last name of all doctors and their specialty’s
*/
create view [Doctor's speciality]
AS
select p.FirstName, p.LastName, s.SpecialityName
	from Doctor  as d
	inner join person as p
	on p.PersonID = d.PersonID
	inner join DoctorSpeciality as ds
	on ds.DoctorID = d.DoctorID
	inner join Speciality as s
	on s.SpecialityID = ds.SpecialityID

SELECT * FROM  [Doctor's speciality]

/*Modify the view created in Q4 to show the First Name and Last name of 
all doctors and their specialties ALSO include doctors who DO NOT have any specialty*/
create view [AllDocWithSpecialties]
AS
select p.FirstName, p.LastName, s.SpecialityName
	from Doctor as d
	inner join person as p
	on p.PersonID = d.PersonID
	left outer join DoctorSpeciality as ds
	on ds.DoctorID = d.DoctorID
	left outer join Speciality as s
	on s.SpecialityID = ds.SpecialityID

select * from [AllDocWithSpecialties]

/*Create a stored procedure that gives Prescription name and the number patients from city of Tacoma 
with that prescription.
Example
| 20 | Aspirin        | 
| 2  | Ciprofloxacin |
*/

CREATE proc PrescriptionNo
@pre varchar(25) output,
@total int output
with encryption
as
select @total = count(*), @pre = p.PrescriptionName
from PatientVisit as pv
	inner join PVisitPrescription as pvp
	on pv.VisitID = pvp.VisitID
	inner join Prescription as p
	on p.PrescriptionID = pvp.PrescriptionID
	inner join patient as pa
	on pa.PatientID = pv.PatientID
	where pa.PersonID IN (SELECT pa.PersonID
		from patient as pa
		inner join person as pe
		on pe.PersonID = pa.PersonID
		where pe.City = 'Tacoma'
	)
	group by p.PrescriptionName

--execute
declare @num int
declare @name varchar(25)

exec PrescriptionNo @total = @num output, 
		@pre = @name output	
print '| '  +  CAST(@num AS VARCHAR) + ' | ' + @name + ' |'


/*
Extra credit
*/

-----------------------------------------------------------------------------------------------------------
----------Create trigger on the DoctorSpeciality so that every time a doctor specialty is updated or added
----------a new entry is made in the audit table. The audit table will have the following  
----------(Hint­The trigger will be on DoctorSpecialty table)
---------------------- Doctor FirstName ---------------------------
---------------------- Action(indicate update or added) -----------
---------------------- Specialty ----------------------------------
---------------------- Date of modification ---------------------
------------------------------------------------------------------------------------------------------------

-- create an audit table
CREATE TABLE DoctorSpecialityAudit (
	DoctorFirstName varchar(60),
	[Action] varchar(60),
	SpecialityName varchar(100),
	DateModified date
)
go

-- create a trigger for doctor spectiality 
CREATE TRIGGER DoctorSpecialityTrigger 
ON DoctorSpeciality
after update, insert 
as
begin 
DECLARE @Action as char(10);
    SET @Action = (CASE WHEN EXISTS(SELECT * FROM INSERTED)
                         AND EXISTS(SELECT * FROM DELETED)
                        THEN 'Updated'  
                        WHEN EXISTS(SELECT * FROM INSERTED)
                        THEN 'Added' 
                        ELSE NULL
                    END)
declare @Docname as varchar(60);
declare @SpeName as varchar(100);

select @Docname = p.FirstName, @SpeName = s.SpecialityName
from Doctor  as d
	inner join person as p
	on p.PersonID = d.PersonID
	inner join DoctorSpeciality as ds
	on ds.DoctorID = d.DoctorID
	inner join Speciality as s
	on s.SpecialityID = ds.SpecialityID

insert into DoctorSpecialityAudit (DoctorFirstName, [Action], SpecialityName, DateModified) 
values(@Docname, @Action,@SpeName, getdate())
end 
go

---------------------------------------------------------------------------------------------
----------- Create a script to do the following (Write the script for this)------------------
----------- If first time backup take backup of all the tables ------------------------------
----------- If not the first time remove the previous backup tables and take new backups ----
---------------------------------------------------------------------------------------------
declare @fileName varchar(100);
declare @databaseName varchar(100);
declare @date varchar(50);
set @fileName = 'C:\Program Files\Microsoft SQL Server\MSSQL13.SQLEXPRESS\MSSQL\Backup';
set @databaseName = 'DocOffice';
set @date = CONVERT(VARCHAR(50), GETDATE(), 112);
set @fileName = @fileName + @databaseName  + '-' + @date
backup database @databaseName to Disk = @fileName;






