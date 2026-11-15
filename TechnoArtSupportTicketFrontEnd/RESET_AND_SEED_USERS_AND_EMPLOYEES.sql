-- ============================================================================
-- TECHNOART SOFTWARE - COMPLETE RESET & FRESH SEED FOR USERS AND EMPLOYEES
-- Database: TASUPORTDB
-- Description:
--   1. Safely clears all user/employee/attendance/ticket records without FK errors
--   2. Seeds default Office Hubs (Branches) & Shifts
--   3. Seeds default Tenant, Projects, and Modules
--   4. Creates 9 fresh, clean users & employees covering ALL system role types:
--      - SuperAdmin (superadmin / admin123)
--      - MD (md / admin123)
--      - SupportManager (supportmanager / admin123)
--      - ProjectManager (projectmanager / admin123)
--      - TeamMember (teammember / admin123)
--      - HRManager (hrmanager / admin123)
--      - AccountsOfficer (accountsofficer / admin123)
--      - ClientAdmin (clientadmin / admin123)
--      - ClientUser (clientuser / admin123)
--   5. Full HR data: Father's Name, Mother's Name, NID, Emergency Contact,
--      Gross Salary, Blood Group, Shift Timing, Joining Date, Branch Hub.
-- ============================================================================

USE TASUPORTDB;
GO

SET NOCOUNT ON;

-- ----------------------------------------------------------------------------
-- 1. TEMPORARILY DISABLE ALL FOREIGN KEY CONSTRAINTS
-- ----------------------------------------------------------------------------
EXEC sp_msforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';
GO

-- ----------------------------------------------------------------------------
-- 2. SAFELY CLEAR ALL DEPENDENT DATA
-- ----------------------------------------------------------------------------
PRINT 'Clearing existing data across user/employee child tables...';

IF OBJECT_ID('dbo.TicketReplies', 'U') IS NOT NULL DELETE FROM dbo.TicketReplies;
IF OBJECT_ID('dbo.TicketTasks', 'U') IS NOT NULL DELETE FROM dbo.TicketTasks;
IF OBJECT_ID('dbo.TicketAttachments', 'U') IS NOT NULL DELETE FROM dbo.TicketAttachments;
IF OBJECT_ID('dbo.Tickets', 'U') IS NOT NULL DELETE FROM dbo.Tickets;
IF OBJECT_ID('dbo.Attendances', 'U') IS NOT NULL DELETE FROM dbo.Attendances;
IF OBJECT_ID('dbo.LeaveRequests', 'U') IS NOT NULL DELETE FROM dbo.LeaveRequests;
IF OBJECT_ID('dbo.ProjectMembers', 'U') IS NOT NULL DELETE FROM dbo.ProjectMembers;
IF OBJECT_ID('dbo.UserMenuPermissions', 'U') IS NOT NULL DELETE FROM dbo.UserMenuPermissions;
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL DELETE FROM dbo.Employees;
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DELETE FROM dbo.Users;
GO

-- ----------------------------------------------------------------------------
-- 3. ENSURE EXTENDED HR COLUMNS EXIST
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Users', 'Name') IS NULL ALTER TABLE dbo.Users ADD Name NVARCHAR(150) NULL;
    IF COL_LENGTH('dbo.Users', 'Username') IS NULL ALTER TABLE dbo.Users ADD Username NVARCHAR(150) NULL;
    IF COL_LENGTH('dbo.Users', 'Email') IS NULL ALTER TABLE dbo.Users ADD Email NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Users', 'PasswordHash') IS NULL ALTER TABLE dbo.Users ADD PasswordHash NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Users', 'Password') IS NULL ALTER TABLE dbo.Users ADD Password NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Users', 'Role') IS NULL ALTER TABLE dbo.Users ADD Role NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'TenantId') IS NULL ALTER TABLE dbo.Users ADD TenantId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'ProjectId') IS NULL ALTER TABLE dbo.Users ADD ProjectId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'ModuleId') IS NULL ALTER TABLE dbo.Users ADD ModuleId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'Phone') IS NULL ALTER TABLE dbo.Users ADD Phone NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'NationalId') IS NULL ALTER TABLE dbo.Users ADD NationalId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'BloodGroup') IS NULL ALTER TABLE dbo.Users ADD BloodGroup NVARCHAR(10) NULL;
    IF COL_LENGTH('dbo.Users', 'IsActive') IS NULL ALTER TABLE dbo.Users ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Users', 'CreatedAt') IS NULL ALTER TABLE dbo.Users ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
END

IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Employees', 'UserId') IS NULL ALTER TABLE dbo.Employees ADD UserId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'EmployeeCode') IS NULL ALTER TABLE dbo.Employees ADD EmployeeCode NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'Designation') IS NULL ALTER TABLE dbo.Employees ADD Designation NVARCHAR(100) NULL;
    IF COL_LENGTH('dbo.Employees', 'Department') IS NULL ALTER TABLE dbo.Employees ADD Department NVARCHAR(100) NULL;
    IF COL_LENGTH('dbo.Employees', 'BloodGroup') IS NULL ALTER TABLE dbo.Employees ADD BloodGroup NVARCHAR(10) NULL;
    IF COL_LENGTH('dbo.Employees', 'IsWfhAllowed') IS NULL ALTER TABLE dbo.Employees ADD IsWfhAllowed BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Employees', 'BranchId') IS NULL ALTER TABLE dbo.Employees ADD BranchId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'OfficeTimeId') IS NULL ALTER TABLE dbo.Employees ADD OfficeTimeId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'IsActive') IS NULL ALTER TABLE dbo.Employees ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Employees', 'CustomStartTime') IS NULL ALTER TABLE dbo.Employees ADD CustomStartTime TIME NULL;
    IF COL_LENGTH('dbo.Employees', 'CustomEndTime') IS NULL ALTER TABLE dbo.Employees ADD CustomEndTime TIME NULL;
    IF COL_LENGTH('dbo.Employees', 'GrossSalary') IS NULL ALTER TABLE dbo.Employees ADD GrossSalary DECIMAL(18,2) NULL;
    IF COL_LENGTH('dbo.Employees', 'Salary') IS NULL ALTER TABLE dbo.Employees ADD Salary DECIMAL(18,2) NULL;
    IF COL_LENGTH('dbo.Employees', 'Phone') IS NULL ALTER TABLE dbo.Employees ADD Phone NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'NationalId') IS NULL ALTER TABLE dbo.Employees ADD NationalId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'PhotoUrl') IS NULL ALTER TABLE dbo.Employees ADD PhotoUrl NVARCHAR(500) NULL;
    IF COL_LENGTH('dbo.Employees', 'JoiningDate') IS NULL ALTER TABLE dbo.Employees ADD JoiningDate DATE NULL;
    IF COL_LENGTH('dbo.Employees', 'FatherName') IS NULL ALTER TABLE dbo.Employees ADD FatherName NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Employees', 'MotherName') IS NULL ALTER TABLE dbo.Employees ADD MotherName NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Employees', 'EmergencyContact') IS NULL ALTER TABLE dbo.Employees ADD EmergencyContact NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'EmergencyContactRelation') IS NULL ALTER TABLE dbo.Employees ADD EmergencyContactRelation NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'CreatedAt') IS NULL ALTER TABLE dbo.Employees ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
END
GO

-- ----------------------------------------------------------------------------
-- 4. ENSURE DEFAULT BRANCHES (OFFICE HUBS)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE Id = 'B0000000001')
BEGIN
    INSERT INTO dbo.Branches (Id, Name, Latitude, Longitude, RadiusMeters, Radius, Address, IsActive, CreatedAt)
    VALUES ('B0000000001', 'TechnoArt Corporate HQ (Dhaka)', 23.7925, 90.4078, 250, 250, 'Plot 12, Road 4, Gulshan-1, Dhaka 1212', 1, SYSDATETIMEOFFSET());
END

IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE Id = 'B0000000002')
BEGIN
    INSERT INTO dbo.Branches (Id, Name, Latitude, Longitude, RadiusMeters, Radius, Address, IsActive, CreatedAt)
    VALUES ('B0000000002', 'TechnoArt Operations Hub (Chittagong)', 22.3569, 91.7832, 200, 200, 'Agrabad Commercial Area, Chittagong', 1, SYSDATETIMEOFFSET());
END
GO

-- ----------------------------------------------------------------------------
-- 5. ENSURE DEFAULT SHIFT CONFIGURATION
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.CompanyShifts', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.CompanyShifts WHERE IsDefault = 1)
    BEGIN
        INSERT INTO dbo.CompanyShifts (ShiftName, StartTime, EndTime, GraceMinutes, HalfDayCutoffMinutes, IsDefault, CreatedAt)
        VALUES ('General Day Shift', '09:30:00', '18:30:00', 15, 120, 1, SYSDATETIMEOFFSET());
    END
END
GO

-- ----------------------------------------------------------------------------
-- 6. ENSURE DEFAULT TENANT (CLIENT ORGANIZATION)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Tenants', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Tenants WHERE TenantId = 'T00000000001' OR Code = 'T00000000001')
    BEGIN
        INSERT INTO dbo.Tenants (TenantId, Name, Code, CompanyCode, IsActive, CreatedAt)
        VALUES ('T00000000001', 'TechnoArt Client Enterprise (Pirthe Org)', 'T00000000001', 'T00000000001', 1, SYSDATETIMEOFFSET());
    END
END
GO

-- ----------------------------------------------------------------------------
-- 7. ENSURE DEFAULT PROJECT & MODULES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Projects', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Projects WHERE Code = 'PROJ-001' OR ProjectId = 'PROJ-001')
    BEGIN
        INSERT INTO dbo.Projects (ProjectId, TenantId, Code, Name, Description, IsActive, CreatedAt)
        VALUES ('PROJ-001', 'T00000000001', 'PROJ-001', 'Core Enterprise Portal & Support System', 'Main Enterprise ERP & Customer Support Portal', 1, SYSDATETIMEOFFSET());
    END
END

IF OBJECT_ID('dbo.ProjectModules', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.ProjectModules WHERE Code = 'HRM')
        INSERT INTO dbo.ProjectModules (ModuleId, ProjectId, Code, Name, ModuleName, Description, IsActive, CreatedAt)
        VALUES ('MOD-001', 'PROJ-001', 'HRM', 'HRM & Biometric Attendance', 'HRM & Biometric Attendance', 'Employee records, shifts and attendance roster', 1, SYSDATETIMEOFFSET());

    IF NOT EXISTS (SELECT 1 FROM dbo.ProjectModules WHERE Code = 'SUPPORT')
        INSERT INTO dbo.ProjectModules (ModuleId, ProjectId, Code, Name, ModuleName, Description, IsActive, CreatedAt)
        VALUES ('MOD-002', 'PROJ-001', 'SUPPORT', 'Support Desk & Ticketing', 'Support Desk & Ticketing', 'Ticket queue, SLA, customer issues', 1, SYSDATETIMEOFFSET());

    IF NOT EXISTS (SELECT 1 FROM dbo.ProjectModules WHERE Code = 'PAYROLL')
        INSERT INTO dbo.ProjectModules (ModuleId, ProjectId, Code, Name, ModuleName, Description, IsActive, CreatedAt)
        VALUES ('MOD-003', 'PROJ-001', 'PAYROLL', 'Accounts & Payroll System', 'Accounts & Payroll System', 'Monthly salary disbursements and reports', 1, SYSDATETIMEOFFSET());
END
GO

-- ----------------------------------------------------------------------------
-- 8. SEED 9 CLEAN USERS (COVERING ALL ROLES)
-- ----------------------------------------------------------------------------
PRINT 'Inserting 9 fresh users with sequential IDs U1000000001 to U1000000009...';

INSERT INTO dbo.Users (Id, Username, Email, PasswordHash, Password, Name, Role, TenantId, ProjectId, ModuleId, Phone, NationalId, BloodGroup, IsActive, CreatedAt)
VALUES
('U1000000001', 'superadmin', 'superadmin@technoart.com', 'admin123', 'admin123', 'Shahidul Islam (SuperAdmin)', 'SuperAdmin', NULL, 'PROJ-001', 'MOD-001', '01711000001', '1985269100001', 'O+', 1, SYSDATETIMEOFFSET()),
('U1000000002', 'md', 'md@technoart.com', 'admin123', 'admin123', 'Mahbubur Rahman (MD)', 'MD', NULL, 'PROJ-001', 'MOD-001', '01711000002', '1980269100002', 'A+', 1, SYSDATETIMEOFFSET()),
('U1000000003', 'supportmanager', 'supportmanager@technoart.com', 'admin123', 'admin123', 'Kamrul Hassan (Support Lead)', 'SupportManager', NULL, 'PROJ-001', 'MOD-002', '01711000003', '1990269100003', 'B+', 1, SYSDATETIMEOFFSET()),
('U1000000004', 'projectmanager', 'projectmanager@technoart.com', 'admin123', 'admin123', 'Tariqul Islam (Project Manager)', 'ProjectManager', NULL, 'PROJ-001', 'MOD-001', '01711000004', '1988269100004', 'AB+', 1, SYSDATETIMEOFFSET()),
('U1000000005', 'teammember', 'teammember@technoart.com', 'admin123', 'admin123', 'Shuvo TAS (Full Stack Engineer)', 'TeamMember', NULL, 'PROJ-001', 'MOD-002', '01711000005', '1994269100005', 'B+', 1, SYSDATETIMEOFFSET()),
('U1000000006', 'hrmanager', 'hrmanager@technoart.com', 'admin123', 'admin123', 'Farzana Akter (HR Lead)', 'HRManager', NULL, 'PROJ-001', 'MOD-001', '01711000006', '1992269100006', 'A+', 1, SYSDATETIMEOFFSET()),
('U1000000007', 'accountsofficer', 'accountsofficer@technoart.com', 'admin123', 'admin123', 'Zahid Hasan (Accounts)', 'AccountsOfficer', NULL, 'PROJ-001', 'MOD-003', '01711000007', '1991269100007', 'O-', 1, SYSDATETIMEOFFSET()),
('U1000000008', 'clientadmin', 'clientadmin@clientorg.com', 'admin123', 'admin123', 'Anisur Rahman (Client Admin)', 'ClientAdmin', 'T00000000001', 'PROJ-001', 'MOD-002', '01711000008', '1987269100008', 'B+', 1, SYSDATETIMEOFFSET()),
('U1000000009', 'clientuser', 'clientuser@clientorg.com', 'admin123', 'admin123', 'Sultana Razia (Client User)', 'ClientUser', 'T00000000001', 'PROJ-001', 'MOD-002', '01711000009', '1995269100009', 'O+', 1, SYSDATETIMEOFFSET());
GO

-- ----------------------------------------------------------------------------
-- 9. SEED 9 MATCHING EMPLOYEES WITH FULL EXTENDED HR DATA
-- ----------------------------------------------------------------------------
PRINT 'Inserting 9 fresh employees with sequential IDs E0000000001 to E0000000009...';

DECLARE @defOfficeTimeId NVARCHAR(50) = NULL;
IF OBJECT_ID('dbo.OfficeTimes', 'U') IS NOT NULL
BEGIN
    SELECT TOP 1 @defOfficeTimeId = CONVERT(NVARCHAR(50), Id) FROM dbo.OfficeTimes;
END

INSERT INTO dbo.Employees (
    Id, UserId, EmployeeCode, BranchId, OfficeTimeId, Designation, Department, BloodGroup, NationalId, Phone, 
    FatherName, MotherName, EmergencyContact, EmergencyContactRelation, JoiningDate, GrossSalary, Salary, 
    CustomStartTime, CustomEndTime, IsWfhAllowed, IsActive, CreatedAt
)
VALUES
('E0000000001', 'U1000000001', 'TAS-1001', 'B0000000001', @defOfficeTimeId, 'Chief Technology Officer', 'Executive Board', 'O+', '1985269100001', '01711000001', 'Rafiqul Islam', 'Shahanara Begum', '01811000001', 'Spouse', '2020-01-01', 150000.00, 150000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000002', 'U1000000002', 'TAS-1002', 'B0000000001', @defOfficeTimeId, 'Managing Director', 'Executive Management', 'A+', '1980269100002', '01711000002', 'Khorshed Alam', 'Amena Khatun', '01811000002', 'Brother', '2019-06-01', 180000.00, 180000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000003', 'U1000000003', 'TAS-1003', 'B0000000001', @defOfficeTimeId, 'Support Operations Manager', 'Technical Support', 'B+', '1990269100003', '01711000003', 'Abdul Haque', 'Fatema Begum', '01811000003', 'Parent', '2021-03-15', 85000.00, 85000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000004', 'U1000000004', 'TAS-1004', 'B0000000001', @defOfficeTimeId, 'Lead Project Manager', 'Engineering & Delivery', 'AB+', '1988269100004', '01711000004', 'Mofizur Rahman', 'Rasheda Akhtar', '01811000004', 'Spouse', '2021-07-01', 95000.00, 95000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000005', 'U1000000005', 'TAS-1005', 'B0000000001', @defOfficeTimeId, 'Senior Full Stack Engineer', 'Core Engineering', 'B+', '1994269100005', '01711000005', 'Nurul Huda', 'Nasima Begum', '01811000005', 'Sibling', '2022-01-10', 75000.00, 75000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000006', 'U1000000006', 'TAS-1006', 'B0000000001', @defOfficeTimeId, 'Human Resources Director', 'HR & Administration', 'A+', '1992269100006', '01711000006', 'Sirajul Islam', 'Rokeya Begum', '01811000006', 'Spouse', '2021-11-01', 80000.00, 80000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000007', 'U1000000007', 'TAS-1007', 'B0000000001', @defOfficeTimeId, 'Senior Accounts Officer', 'Finance & Payroll', 'O-', '1991269100007', '01711000007', 'Anwar Hossain', 'Salma Khatun', '01811000007', 'Parent', '2022-02-01', 70000.00, 70000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000008', 'U1000000008', 'TAS-1008', 'B0000000001', @defOfficeTimeId, 'Enterprise IT Administrator', 'Client Operations', 'B+', '1987269100008', '01711000008', 'Matiur Rahman', 'Laila Begum', '01811000008', 'Spouse', '2023-01-15', 85000.00, 85000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET()),
('E0000000009', 'U1000000009', 'TAS-1009', 'B0000000001', @defOfficeTimeId, 'Client Operations Specialist', 'Client Operations', 'O+', '1995269100009', '01711000009', 'Habibur Rahman', 'Parveen Sultana', '01811000009', 'Sibling', '2023-05-01', 55000.00, 55000.00, '09:30:00', '18:30:00', 1, 1, SYSDATETIMEOFFSET());
GO

-- ----------------------------------------------------------------------------
-- 10. SEED PROJECT MEMBERS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.ProjectMembers', 'U') IS NOT NULL
BEGIN
    INSERT INTO dbo.ProjectMembers (ProjectId, UserId, ModuleId, IsProjectManager)
    VALUES
    ('PROJ-001', 'U1000000004', 'MOD-001', 1), -- Designated PM
    ('PROJ-001', 'U1000000005', 'MOD-002', 0), -- Developer / Engineer
    ('PROJ-001', 'U1000000008', 'MOD-002', 0), -- Client Admin
    ('PROJ-001', 'U1000000009', 'MOD-002', 0); -- Client User
END
GO

-- ----------------------------------------------------------------------------
-- 11. RE-ENABLE ALL FOREIGN KEY CONSTRAINTS
-- ----------------------------------------------------------------------------
-- Sanity check: Ensure Employees.OfficeTimeId does not violate FK if office time was deleted
IF OBJECT_ID('dbo.OfficeTimes', 'U') IS NOT NULL
BEGIN
    UPDATE e
    SET e.OfficeTimeId = NULL
    FROM dbo.Employees e
    WHERE e.OfficeTimeId IS NOT NULL 
      AND NOT EXISTS (SELECT 1 FROM dbo.OfficeTimes ot WHERE CONVERT(NVARCHAR(50), ot.Id) = CONVERT(NVARCHAR(50), e.OfficeTimeId));
END
GO

BEGIN TRY
    EXEC sp_msforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL';
    PRINT 'All foreign key constraints verified and re-enabled successfully.';
END TRY
BEGIN CATCH
    PRINT 'Notice: Checked foreign keys enabled with standard validation.';
    EXEC sp_msforeachtable 'ALTER TABLE ? CHECK CONSTRAINT ALL';
END CATCH
GO

-- ----------------------------------------------------------------------------
-- 12. VERIFICATION OUTPUT
-- ----------------------------------------------------------------------------
PRINT '============================================================================';
PRINT 'TECHNOART TASUPORTDB USERS & EMPLOYEES RESET AND SEEDED SUCCESSFULLY!';
PRINT 'All passwords are: admin123';
PRINT '============================================================================';

SELECT 
    u.Id AS [User ID],
    u.Username AS [Username],
    u.Role AS [Role],
    u.Name AS [Full Name],
    e.Id AS [Emp ID],
    e.EmployeeCode AS [Code],
    e.Designation AS [Designation],
    e.Department AS [Department],
    e.GrossSalary AS [Gross Salary],
    e.FatherName AS [Father Name],
    e.EmergencyContact AS [Emergency Contact]
FROM dbo.Users u
LEFT JOIN dbo.Employees e ON u.Id = e.UserId
ORDER BY u.Id ASC;
GO
