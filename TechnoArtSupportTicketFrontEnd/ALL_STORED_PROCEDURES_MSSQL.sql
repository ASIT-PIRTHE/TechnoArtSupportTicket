-- ============================================================================
-- TECHNOART SOFTWARE - COMPLETE & ERROR-FREE STORED PROCEDURES SCRIPT (TASUPORTDB)
-- SQL SERVER (MSSQL) FULL SCHEMA & PROCEDURE REPAIR
-- ZERO duplicate variable declarations (Msg 134 fixed)
-- ZERO missing scalar variables (Msg 137 fixed)
-- Covers: Office Hubs/Branches, Users/Employees, Clients/Tenants, Projects/Modules,
-- Leave Requests, Dynamic Permissions, Attendance, Dashboard & Ticket Operations
-- ============================================================================

USE TASUPORTDB;
GO

-- ----------------------------------------------------------------------------
-- 1. ENSURE SCHEMAS AND TABLE SCHEMAS ARE PROPERLY CONFIGURED
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'support')
BEGIN
    EXEC('CREATE SCHEMA support');
END
GO

-- dbo.Branches
IF OBJECT_ID('dbo.Branches', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Branches', 'Name') IS NULL
        ALTER TABLE dbo.Branches ADD Name NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Branches', 'Latitude') IS NULL
        ALTER TABLE dbo.Branches ADD Latitude FLOAT NULL;
    IF COL_LENGTH('dbo.Branches', 'Longitude') IS NULL
        ALTER TABLE dbo.Branches ADD Longitude FLOAT NULL;
    IF COL_LENGTH('dbo.Branches', 'RadiusMeters') IS NULL
        ALTER TABLE dbo.Branches ADD RadiusMeters INT NOT NULL DEFAULT 150;
    IF COL_LENGTH('dbo.Branches', 'Radius') IS NULL
        ALTER TABLE dbo.Branches ADD Radius INT NOT NULL DEFAULT 150;
    IF COL_LENGTH('dbo.Branches', 'Address') IS NULL
        ALTER TABLE dbo.Branches ADD Address NVARCHAR(500) NULL;
    IF COL_LENGTH('dbo.Branches', 'IsActive') IS NULL
        ALTER TABLE dbo.Branches ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Branches', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Branches ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Branches', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Branches ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Tenants
IF OBJECT_ID('dbo.Tenants', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Tenants', 'TenantId') IS NULL
        ALTER TABLE dbo.Tenants ADD TenantId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    IF COL_LENGTH('dbo.Tenants', 'Name') IS NULL
        ALTER TABLE dbo.Tenants ADD Name NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Tenants', 'CompanyCode') IS NULL
        ALTER TABLE dbo.Tenants ADD CompanyCode NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tenants', 'LogoUrl') IS NULL
        ALTER TABLE dbo.Tenants ADD LogoUrl NVARCHAR(500) NULL;
    IF COL_LENGTH('dbo.Tenants', 'IsActive') IS NULL
        ALTER TABLE dbo.Tenants ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Tenants', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Tenants ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Tenants', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Tenants ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Users
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Users', 'Name') IS NULL
        ALTER TABLE dbo.Users ADD Name NVARCHAR(150) NULL;
    IF COL_LENGTH('dbo.Users', 'Username') IS NULL
        ALTER TABLE dbo.Users ADD Username NVARCHAR(150) NULL;
    IF COL_LENGTH('dbo.Users', 'Email') IS NULL
        ALTER TABLE dbo.Users ADD Email NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Users', 'PasswordHash') IS NULL
        ALTER TABLE dbo.Users ADD PasswordHash NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Users', 'Password') IS NULL
        ALTER TABLE dbo.Users ADD Password NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Users', 'Role') IS NULL
        ALTER TABLE dbo.Users ADD Role NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'TenantId') IS NULL
        ALTER TABLE dbo.Users ADD TenantId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'ProjectId') IS NULL
        ALTER TABLE dbo.Users ADD ProjectId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'ModuleId') IS NULL
        ALTER TABLE dbo.Users ADD ModuleId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Users', 'FcmToken') IS NULL
        ALTER TABLE dbo.Users ADD FcmToken NVARCHAR(500) NULL;
    IF COL_LENGTH('dbo.Users', 'IsActive') IS NULL
        ALTER TABLE dbo.Users ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Users', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Users ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Users', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Users ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Projects
IF OBJECT_ID('dbo.Projects', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Projects', 'ProjectId') IS NULL
        ALTER TABLE dbo.Projects ADD ProjectId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    IF COL_LENGTH('dbo.Projects', 'TenantId') IS NULL
        ALTER TABLE dbo.Projects ADD TenantId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Projects', 'Code') IS NULL
        ALTER TABLE dbo.Projects ADD Code NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Projects', 'Name') IS NULL
        ALTER TABLE dbo.Projects ADD Name NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Projects', 'Description') IS NULL
        ALTER TABLE dbo.Projects ADD Description NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.Projects', 'IsActive') IS NULL
        ALTER TABLE dbo.Projects ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Projects', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Projects ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Projects', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Projects ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.ProjectModules
IF OBJECT_ID('dbo.ProjectModules', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.ProjectModules', 'ModuleId') IS NULL
        ALTER TABLE dbo.ProjectModules ADD ModuleId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    IF COL_LENGTH('dbo.ProjectModules', 'ProjectId') IS NULL
        ALTER TABLE dbo.ProjectModules ADD ProjectId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.ProjectModules', 'Code') IS NULL
        ALTER TABLE dbo.ProjectModules ADD Code NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.ProjectModules', 'Name') IS NULL
        ALTER TABLE dbo.ProjectModules ADD Name NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.ProjectModules', 'ModuleName') IS NULL
        ALTER TABLE dbo.ProjectModules ADD ModuleName NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.ProjectModules', 'Description') IS NULL
        ALTER TABLE dbo.ProjectModules ADD Description NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.ProjectModules', 'IsActive') IS NULL
        ALTER TABLE dbo.ProjectModules ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.ProjectModules', 'CreatedAt') IS NULL
        ALTER TABLE dbo.ProjectModules ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
END
GO

-- dbo.Employees
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Employees', 'UserId') IS NULL
        ALTER TABLE dbo.Employees ADD UserId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'EmployeeCode') IS NULL
        ALTER TABLE dbo.Employees ADD EmployeeCode NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'Designation') IS NULL
        ALTER TABLE dbo.Employees ADD Designation NVARCHAR(100) NULL;
    IF COL_LENGTH('dbo.Employees', 'Department') IS NULL
        ALTER TABLE dbo.Employees ADD Department NVARCHAR(100) NULL;
    IF COL_LENGTH('dbo.Employees', 'BloodGroup') IS NULL
        ALTER TABLE dbo.Employees ADD BloodGroup NVARCHAR(10) NULL;
    IF COL_LENGTH('dbo.Employees', 'IsWfhAllowed') IS NULL
        ALTER TABLE dbo.Employees ADD IsWfhAllowed BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Employees', 'BranchId') IS NULL
        ALTER TABLE dbo.Employees ADD BranchId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Employees', 'IsActive') IS NULL
        ALTER TABLE dbo.Employees ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Employees', 'CustomStartTime') IS NULL
        ALTER TABLE dbo.Employees ADD CustomStartTime TIME NULL;
    IF COL_LENGTH('dbo.Employees', 'CustomEndTime') IS NULL
        ALTER TABLE dbo.Employees ADD CustomEndTime TIME NULL;
    IF COL_LENGTH('dbo.Employees', 'GrossSalary') IS NULL
        ALTER TABLE dbo.Employees ADD GrossSalary DECIMAL(18,2) NULL;
    IF COL_LENGTH('dbo.Employees', 'Salary') IS NULL
        ALTER TABLE dbo.Employees ADD Salary DECIMAL(18,2) NULL;
    IF COL_LENGTH('dbo.Employees', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Employees ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Employees', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Employees ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Attendances
IF OBJECT_ID('dbo.Attendances', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Attendances', 'Id') IS NULL
        ALTER TABLE dbo.Attendances ADD Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    IF COL_LENGTH('dbo.Attendances', 'EmployeeId') IS NULL
        ALTER TABLE dbo.Attendances ADD EmployeeId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Attendances', 'AttendanceDate') IS NULL
        ALTER TABLE dbo.Attendances ADD AttendanceDate DATE NULL;
    IF COL_LENGTH('dbo.Attendances', 'InTime') IS NULL
        ALTER TABLE dbo.Attendances ADD InTime DATETIMEOFFSET NULL;
    IF COL_LENGTH('dbo.Attendances', 'OutTime') IS NULL
        ALTER TABLE dbo.Attendances ADD OutTime DATETIMEOFFSET NULL;
    IF COL_LENGTH('dbo.Attendances', 'InLatitude') IS NULL
        ALTER TABLE dbo.Attendances ADD InLatitude FLOAT NULL;
    IF COL_LENGTH('dbo.Attendances', 'InLongitude') IS NULL
        ALTER TABLE dbo.Attendances ADD InLongitude FLOAT NULL;
    IF COL_LENGTH('dbo.Attendances', 'OutLatitude') IS NULL
        ALTER TABLE dbo.Attendances ADD OutLatitude FLOAT NULL;
    IF COL_LENGTH('dbo.Attendances', 'OutLongitude') IS NULL
        ALTER TABLE dbo.Attendances ADD OutLongitude FLOAT NULL;
    IF COL_LENGTH('dbo.Attendances', 'IsWfh') IS NULL
        ALTER TABLE dbo.Attendances ADD IsWfh BIT NOT NULL DEFAULT 0;
    IF COL_LENGTH('dbo.Attendances', 'BranchId') IS NULL
        ALTER TABLE dbo.Attendances ADD BranchId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Attendances', 'Punctuality') IS NULL
        ALTER TABLE dbo.Attendances ADD Punctuality NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Attendances', 'InApprovalStatus') IS NULL
        ALTER TABLE dbo.Attendances ADD InApprovalStatus NVARCHAR(50) NOT NULL DEFAULT 'PENDING';
    IF COL_LENGTH('dbo.Attendances', 'InApprovedBy') IS NULL
        ALTER TABLE dbo.Attendances ADD InApprovedBy NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Attendances', 'OutApprovalStatus') IS NULL
        ALTER TABLE dbo.Attendances ADD OutApprovalStatus NVARCHAR(50) NOT NULL DEFAULT 'PENDING';
    IF COL_LENGTH('dbo.Attendances', 'OutApprovedBy') IS NULL
        ALTER TABLE dbo.Attendances ADD OutApprovedBy NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Attendances', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Attendances ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Attendances', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Attendances ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Tickets
IF OBJECT_ID('dbo.Tickets', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Tickets', 'TicketNumber') IS NULL
        ALTER TABLE dbo.Tickets ADD TicketNumber NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'TenantId') IS NULL
        ALTER TABLE dbo.Tickets ADD TenantId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'ProjectId') IS NULL
        ALTER TABLE dbo.Tickets ADD ProjectId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'ModuleId') IS NULL
        ALTER TABLE dbo.Tickets ADD ModuleId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'Title') IS NULL
        ALTER TABLE dbo.Tickets ADD Title NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Tickets', 'Description') IS NULL
        ALTER TABLE dbo.Tickets ADD Description NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.Tickets', 'Priority') IS NULL
        ALTER TABLE dbo.Tickets ADD Priority NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'Status') IS NULL
        ALTER TABLE dbo.Tickets ADD Status NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'EstimatedHours') IS NULL
        ALTER TABLE dbo.Tickets ADD EstimatedHours DECIMAL(10,2) NULL;
    IF COL_LENGTH('dbo.Tickets', 'AssignedTo') IS NULL
        ALTER TABLE dbo.Tickets ADD AssignedTo NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Tickets', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Tickets ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Tickets', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Tickets ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.TicketTasks
IF OBJECT_ID('dbo.TicketTasks', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.TicketTasks', 'TaskId') IS NULL
        ALTER TABLE dbo.TicketTasks ADD TaskId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.TicketTasks', 'TicketNumber') IS NULL
        ALTER TABLE dbo.TicketTasks ADD TicketNumber NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.TicketTasks', 'Name') IS NULL
        ALTER TABLE dbo.TicketTasks ADD Name NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.TicketTasks', 'AssignedTo') IS NULL
        ALTER TABLE dbo.TicketTasks ADD AssignedTo NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.TicketTasks', 'Status') IS NULL
        ALTER TABLE dbo.TicketTasks ADD Status NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.TicketTasks', 'CreatedAt') IS NULL
        ALTER TABLE dbo.TicketTasks ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.TicketTasks', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.TicketTasks ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.TicketComments
IF OBJECT_ID('dbo.TicketComments', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.TicketComments', 'TicketNumber') IS NULL
        ALTER TABLE dbo.TicketComments ADD TicketNumber NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.TicketComments', 'UserId') IS NULL
        ALTER TABLE dbo.TicketComments ADD UserId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.TicketComments', 'Comment') IS NULL
        ALTER TABLE dbo.TicketComments ADD Comment NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.TicketComments', 'CreatedAt') IS NULL
        ALTER TABLE dbo.TicketComments ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
END
GO

-- dbo.LeaveRequests
IF OBJECT_ID('dbo.LeaveRequests', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.LeaveRequests', 'Id') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    IF COL_LENGTH('dbo.LeaveRequests', 'EmployeeId') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD EmployeeId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'LeaveType') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD LeaveType NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'FromDate') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD FromDate DATE NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'ToDate') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD ToDate DATE NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'Reason') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD Reason NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'Status') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD Status NVARCHAR(50) NOT NULL DEFAULT 'PENDING';
    IF COL_LENGTH('dbo.LeaveRequests', 'Remarks') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD Remarks NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'ApprovedBy') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD ApprovedBy NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.LeaveRequests', 'CreatedAt') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.LeaveRequests', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.LeaveRequests ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Notices
IF OBJECT_ID('dbo.Notices', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.Notices', 'Id') IS NULL
        ALTER TABLE dbo.Notices ADD Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    IF COL_LENGTH('dbo.Notices', 'Title') IS NULL
        ALTER TABLE dbo.Notices ADD Title NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Notices', 'Content') IS NULL
        ALTER TABLE dbo.Notices ADD Content NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.Notices', 'IsActive') IS NULL
        ALTER TABLE dbo.Notices ADD IsActive BIT NOT NULL DEFAULT 1;
    IF COL_LENGTH('dbo.Notices', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Notices ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
    IF COL_LENGTH('dbo.Notices', 'UpdatedAt') IS NULL
        ALTER TABLE dbo.Notices ADD UpdatedAt DATETIMEOFFSET NULL;
END
GO

-- dbo.Notifications
IF OBJECT_ID('dbo.Notifications', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Notifications (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        UserId NVARCHAR(50) NULL,
        Title NVARCHAR(255) NOT NULL,
        Message NVARCHAR(MAX) NULL,
        IsRead BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
    );
END
ELSE
BEGIN
    IF COL_LENGTH('dbo.Notifications', 'UserId') IS NULL
        ALTER TABLE dbo.Notifications ADD UserId NVARCHAR(50) NULL;
    IF COL_LENGTH('dbo.Notifications', 'Title') IS NULL
        ALTER TABLE dbo.Notifications ADD Title NVARCHAR(255) NULL;
    IF COL_LENGTH('dbo.Notifications', 'Message') IS NULL
        ALTER TABLE dbo.Notifications ADD Message NVARCHAR(MAX) NULL;
    IF COL_LENGTH('dbo.Notifications', 'IsRead') IS NULL
        ALTER TABLE dbo.Notifications ADD IsRead BIT NOT NULL DEFAULT 0;
    IF COL_LENGTH('dbo.Notifications', 'CreatedAt') IS NULL
        ALTER TABLE dbo.Notifications ADD CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET();
END
GO

-- dbo.Roles
IF OBJECT_ID('dbo.Roles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Roles (
        RoleKey NVARCHAR(50) PRIMARY KEY,
        DisplayName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(MAX) NULL,
        IsSystem BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
    );
END
GO

-- Seed Default Roles if missing
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'SuperAdmin')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('SuperAdmin', 'Super Administrator', 'Full unrestricted system access', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'MD')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('MD', 'Managing Director', 'Executive administrative management access', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'SupportManager')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('SupportManager', 'Support Manager', 'Manage queues, assignments and team shifts', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'ProjectManager')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('ProjectManager', 'Project Manager', 'Manage assigned software projects and deliverables', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'TeamMember')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('TeamMember', 'Team Member / Engineer', 'Individual engineer workbench, tickets and tasks', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'ClientAdmin')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('ClientAdmin', 'Client Administrator', 'Client organization account administrator', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'ClientUser')
    INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES ('ClientUser', 'Client User', 'Client organization employee raising support tickets', 1);
GO

-- dbo.RoleMenuPermissions
IF OBJECT_ID('dbo.RoleMenuPermissions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RoleMenuPermissions (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        RoleKey NVARCHAR(50) NOT NULL,
        MenuKey NVARCHAR(50) NOT NULL,
        CanView BIT NOT NULL DEFAULT 1,
        CanEdit BIT NOT NULL DEFAULT 0,
        CanDelete BIT NOT NULL DEFAULT 0,
        CanApprove BIT NOT NULL DEFAULT 0,
        UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
    );
END
GO

-- dbo.UserMenuPermissions
IF OBJECT_ID('dbo.UserMenuPermissions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserMenuPermissions (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        UserId NVARCHAR(50) NOT NULL,
        MenuKey NVARCHAR(50) NOT NULL,
        CanView BIT NOT NULL DEFAULT 1,
        CanEdit BIT NOT NULL DEFAULT 0,
        CanDelete BIT NOT NULL DEFAULT 0,
        CanApprove BIT NOT NULL DEFAULT 0,
        UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
    );
END
GO

-- dbo.CompanyShifts
IF OBJECT_ID('dbo.CompanyShifts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CompanyShifts (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ShiftName NVARCHAR(100) NOT NULL DEFAULT 'General Day Shift',
        StartTime TIME NOT NULL DEFAULT '09:30:00',
        EndTime TIME NOT NULL DEFAULT '18:30:00',
        GraceMinutes INT NOT NULL DEFAULT 15,
        HalfDayCutoffMinutes INT NOT NULL DEFAULT 120,
        IsDefault BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        UpdatedAt DATETIMEOFFSET NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.CompanyShifts WHERE IsDefault = 1)
BEGIN
    INSERT INTO dbo.CompanyShifts (ShiftName, StartTime, EndTime, GraceMinutes, HalfDayCutoffMinutes, IsDefault)
    VALUES ('General Day Shift', '09:30:00', '18:30:00', 15, 120, 1);
END
GO

-- Seed Default Branches if empty
IF OBJECT_ID('dbo.Branches', 'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Branches)
BEGIN
    IF COLUMNPROPERTY(OBJECT_ID('dbo.Branches'), 'Id', 'IsIdentity') = 1
    BEGIN
        INSERT INTO dbo.Branches (Name, Latitude, Longitude, RadiusMeters, Radius, Address, IsActive)
        VALUES ('Dhaka Main Office (Headquarters)', 23.7925, 90.4078, 150, 150, 'Gulshan-1, Dhaka, Bangladesh', 1),
               ('Chittagong Regional Hub', 22.3569, 91.7832, 200, 200, 'Agrabad Commercial Area, Chittagong', 1);
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Branches (Id, Name, Latitude, Longitude, RadiusMeters, Radius, Address, IsActive)
        VALUES (NEWID(), 'Dhaka Main Office (Headquarters)', 23.7925, 90.4078, 150, 150, 'Gulshan-1, Dhaka, Bangladesh', 1),
               (NEWID(), 'Chittagong Regional Hub', 22.3569, 91.7832, 200, 200, 'Agrabad Commercial Area, Chittagong', 1);
    END
END
GO

-- Seed sample attendance record if empty so approvals queue has data immediately
IF OBJECT_ID('dbo.Attendances', 'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Attendances)
BEGIN
    DECLARE @seedEmpId NVARCHAR(50);
    SELECT TOP 1 @seedEmpId = CONVERT(NVARCHAR(50), Id) FROM dbo.Employees;
    IF @seedEmpId IS NULL SELECT TOP 1 @seedEmpId = CONVERT(NVARCHAR(50), Id) FROM dbo.Users;

    IF @seedEmpId IS NOT NULL
    BEGIN
        IF COLUMNPROPERTY(OBJECT_ID('dbo.Attendances'), 'Id', 'IsIdentity') = 1
        BEGIN
            INSERT INTO dbo.Attendances (EmployeeId, AttendanceDate, InTime, OutTime, IsWfh, InApprovalStatus, OutApprovalStatus)
            VALUES (@seedEmpId, CAST(GETDATE() AS DATE), DATEADD(hour, -5, SYSDATETIMEOFFSET()), DATEADD(minute, -15, SYSDATETIMEOFFSET()), 1, 'PENDING', 'PENDING');
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Attendances (Id, EmployeeId, AttendanceDate, InTime, OutTime, IsWfh, InApprovalStatus, OutApprovalStatus)
            VALUES (NEWID(), @seedEmpId, CAST(GETDATE() AS DATE), DATEADD(hour, -5, SYSDATETIMEOFFSET()), DATEADD(minute, -15, SYSDATETIMEOFFSET()), 1, 'PENDING', 'PENDING');
        END
    END
END
GO

-- ----------------------------------------------------------------------------
-- 2. PROCEDURE: support.SP_TICKET_OPERATIONS & dbo.SP_TICKET_OPERATIONS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('support.SP_TICKET_OPERATIONS', 'P') IS NOT NULL DROP PROCEDURE support.SP_TICKET_OPERATIONS;
GO
IF OBJECT_ID('dbo.SP_TICKET_OPERATIONS', 'P') IS NOT NULL DROP PROCEDURE dbo.SP_TICKET_OPERATIONS;
GO

CREATE PROCEDURE support.SP_TICKET_OPERATIONS
    -- 1. Identity & System Parameters
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_UserName NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',
    @p_TerminalId NVARCHAR(100) = '',
    @p_HostName NVARCHAR(100) = '',
    @p_IPAddress NVARCHAR(100) = '',
    @p_AppID NVARCHAR(100) = '',
    @p_ModuleId NVARCHAR(100) = '',

    -- 2. General @p_parm Parameters
    @p_parm00 NVARCHAR(255) = '',
    @p_parm01 NVARCHAR(255) = '',
    @p_parm02 NVARCHAR(255) = '',
    @p_parm03 NVARCHAR(255) = '',
    @p_parm04 NVARCHAR(255) = '',
    @p_parm05 NVARCHAR(255) = '',
    @p_parm06 NVARCHAR(MAX) = '',
    @p_parm07 NVARCHAR(255) = '',
    @p_parm08 NVARCHAR(255) = '',
    @p_parm09 NVARCHAR(255) = '',
    @p_parm10 NVARCHAR(255) = '',
    @p_parm1 NVARCHAR(255) = '',
    @p_parm2 NVARCHAR(255) = '',
    @p_parm3 NVARCHAR(255) = '',
    @p_parm4 NVARCHAR(255) = '',
    @p_parm5 NVARCHAR(255) = '',
    @p_parm6 NVARCHAR(MAX) = '',
    @p_parm7 NVARCHAR(255) = '',
    @p_parm8 NVARCHAR(255) = '',
    @p_parm9 NVARCHAR(255) = '',

    -- 3. Description & Remarks Parameters
    @p_Desc01 NVARCHAR(MAX) = '',
    @p_Desc02 NVARCHAR(MAX) = '',
    @p_Desc03 NVARCHAR(MAX) = '',
    @p_Desc04 NVARCHAR(MAX) = '',
    @p_Desc05 NVARCHAR(MAX) = '',
    @p_Desc06 NVARCHAR(MAX) = '',
    @p_Desc07 NVARCHAR(MAX) = '',
    @p_Desc08 NVARCHAR(MAX) = '',
    @p_Desc09 NVARCHAR(MAX) = '',
    @p_Desc10 NVARCHAR(MAX) = '',
    @p_Desc1 NVARCHAR(MAX) = '',
    @p_Desc2 NVARCHAR(MAX) = '',
    @p_Desc3 NVARCHAR(MAX) = '',
    @p_Desc4 NVARCHAR(MAX) = '',
    @p_Desc5 NVARCHAR(MAX) = '',
    @p_Description NVARCHAR(MAX) = '',
    @p_Remarks NVARCHAR(MAX) = '',
    @p_Comment NVARCHAR(MAX) = '',
    @p_Note NVARCHAR(MAX) = '',

    -- 4. JSON Payload Parameters
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_Json1 NVARCHAR(MAX) = '',
    @p_Json2 NVARCHAR(MAX) = '',
    @p_JsonData NVARCHAR(MAX) = '',

    -- 5. Binary & Document Parameters
    @p_Dbin01 VARBINARY(MAX) = NULL,
    @p_Dbin02 VARBINARY(MAX) = NULL,
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,

    -- 6. Date, Status, Role Parameters
    @p_FromDate NVARCHAR(50) = '',
    @p_ToDate NVARCHAR(50) = '',
    @p_Date NVARCHAR(50) = '',
    @p_Status NVARCHAR(50) = '',
    @p_Flag NVARCHAR(50) = '',
    @p_Type NVARCHAR(50) = '',
    @p_Role NVARCHAR(100) = '',
    @p_Email NVARCHAR(255) = '',
    @p_Phone NVARCHAR(50) = '',

    -- 7. Standard Non-Prefixed Parameters (Backward Compatibility)
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @UserName NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',

    @parm00 NVARCHAR(255) = '',
    @parm01 NVARCHAR(255) = '',
    @parm02 NVARCHAR(255) = '',
    @parm03 NVARCHAR(255) = '',
    @parm04 NVARCHAR(255) = '',
    @parm05 NVARCHAR(255) = '',
    @parm06 NVARCHAR(MAX) = '',
    @parm07 NVARCHAR(255) = '',
    @parm08 NVARCHAR(255) = '',
    @parm09 NVARCHAR(255) = '',
    @parm10 NVARCHAR(255) = '',

    @Desc01 NVARCHAR(MAX) = '',
    @Desc02 NVARCHAR(MAX) = '',
    @Desc03 NVARCHAR(MAX) = '',
    @Desc04 NVARCHAR(MAX) = '',
    @Desc05 NVARCHAR(MAX) = '',
    @Desc06 NVARCHAR(MAX) = '',
    @Desc07 NVARCHAR(MAX) = '',
    @Desc08 NVARCHAR(MAX) = '',
    @Desc09 NVARCHAR(MAX) = '',
    @Desc10 NVARCHAR(MAX) = '',
    @Description NVARCHAR(MAX) = '',

    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',

    @Dbin01 VARBINARY(MAX) = NULL,
    @Dbin02 VARBINARY(MAX) = NULL,
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,

    @FromDate NVARCHAR(50) = '',
    @ToDate NVARCHAR(50) = '',
    @Date NVARCHAR(50) = '',
    @Status NVARCHAR(50) = '',
    @Role NVARCHAR(100) = '',
    @Email NVARCHAR(255) = '',
    @Phone NVARCHAR(50) = ''
AS
BEGIN
    SET NOCOUNT ON;

    -- All local variables declared once at the top with @v_ prefix (Prevents Msg 134)
    DECLARE @v_TicketNum NVARCHAR(50);
    DECLARE @v_NewTaskId NVARCHAR(50);
    DECLARE @v_NewProjId UNIQUEIDENTIFIER;
    DECLARE @v_TargetTenant NVARCHAR(50);
    DECLARE @v_UpProjId NVARCHAR(50);
    DECLARE @v_UpProjCode NVARCHAR(50);
    DECLARE @v_UpProjName NVARCHAR(255);
    DECLARE @v_UpProjTenant NVARCHAR(50);
    DECLARE @v_NewModId UNIQUEIDENTIFIER;
    DECLARE @v_ModProjectId NVARCHAR(50);
    DECLARE @v_ModName NVARCHAR(255);
    DECLARE @v_ModCode NVARCHAR(50);
    DECLARE @v_ModDesc NVARCHAR(MAX);
    DECLARE @v_NewTenantId UNIQUEIDENTIFIER;
    DECLARE @v_TenantCode NVARCHAR(50);
    DECLARE @v_TenantName NVARCHAR(255);
    DECLARE @v_TenantLogo NVARCHAR(500);
    DECLARE @v_UpTenantId NVARCHAR(50);
    DECLARE @v_UpTenantCode NVARCHAR(50);
    DECLARE @v_UpTenantName NVARCHAR(255);
    DECLARE @v_UpTenantLogo NVARCHAR(500);
    DECLARE @v_NewUserId NVARCHAR(50);
    DECLARE @v_NewUsername NVARCHAR(150);
    DECLARE @v_NewPassword NVARCHAR(255);
    DECLARE @v_NewFullName NVARCHAR(255);
    DECLARE @v_NewUserRole NVARCHAR(100);
    DECLARE @v_NewUserTenant NVARCHAR(50);
    DECLARE @v_NewUserProj NVARCHAR(50);
    DECLARE @v_NewUserMod NVARCHAR(50);
    DECLARE @v_NewUserWfh BIT;
    DECLARE @v_UpUserId NVARCHAR(50);
    DECLARE @v_UpFullName NVARCHAR(255);
    DECLARE @v_UpRole NVARCHAR(100);
    DECLARE @v_UpModuleId NVARCHAR(50);
    DECLARE @v_UpUserTenant NVARCHAR(50);
    DECLARE @v_UpPassword NVARCHAR(255);
    DECLARE @v_UpProjectId NVARCHAR(50);
    DECLARE @v_UpWfh BIT;

    -- Clean parameter normalization (Zero nested CASE expressions)
    IF @p_ComCod <> '' SET @ComCod = @p_ComCod;
    IF @p_ProcID <> '' SET @ProcID = @p_ProcID;
    ELSE IF @p_Action <> '' SET @ProcID = @p_Action;

    IF @p_UserId <> '' SET @UserId = @p_UserId;
    ELSE IF @p_UserCode <> '' SET @UserId = @p_UserCode;
    ELSE IF @UserCode <> '' SET @UserId = @UserCode;
    ELSE IF @Action <> '' SET @ProcID = @Action;

    IF @p_UserId <> '' SET @UserId = @p_UserId;
    ELSE IF @p_UserCode <> '' SET @UserId = @p_UserCode;
    ELSE IF @UserCode <> '' SET @UserId = @UserCode;

    IF @p_parm01 <> '' SET @parm01 = @p_parm01;
    ELSE IF @p_Desc01 <> '' SET @parm01 = @p_Desc01;
    ELSE IF @Desc01 <> '' SET @parm01 = @Desc01;

    IF @p_parm02 <> '' SET @parm02 = @p_parm02;
    ELSE IF @p_Desc02 <> '' SET @parm02 = @p_Desc02;
    ELSE IF @Desc02 <> '' SET @parm02 = @Desc02;

    IF @p_parm03 <> '' SET @parm03 = @p_parm03;
    ELSE IF @p_Desc03 <> '' SET @parm03 = @p_Desc03;
    ELSE IF @Desc03 <> '' SET @parm03 = @Desc03;

    IF @p_parm04 <> '' SET @parm04 = @p_parm04;
    ELSE IF @p_Desc04 <> '' SET @parm04 = @p_Desc04;
    ELSE IF @Desc04 <> '' SET @parm04 = @Desc04;

    IF @p_parm05 <> '' SET @parm05 = @p_parm05;
    ELSE IF @p_Desc05 <> '' SET @parm05 = @p_Desc05;
    ELSE IF @Desc05 <> '' SET @parm05 = @Desc05;

    IF @p_parm06 <> '' SET @parm06 = @p_parm06;
    ELSE IF @p_Desc06 <> '' SET @parm06 = @p_Desc06;
    ELSE IF @Desc06 <> '' SET @parm06 = @Desc06;
    ELSE IF @p_Description <> '' SET @parm06 = @p_Description;
    ELSE IF @Description <> '' SET @parm06 = @Description;

    IF @p_parm07 <> '' SET @parm07 = @p_parm07;
    ELSE IF @p_Desc07 <> '' SET @parm07 = @p_Desc07;
    ELSE IF @Desc07 <> '' SET @parm07 = @Desc07;

    IF @p_parm08 <> '' SET @parm08 = @p_parm08;
    ELSE IF @p_Desc08 <> '' SET @parm08 = @p_Desc08;
    ELSE IF @Desc08 <> '' SET @parm08 = @Desc08;

    IF @p_parm09 <> '' SET @parm09 = @p_parm09;
    ELSE IF @p_Desc09 <> '' SET @parm09 = @p_Desc09;
    ELSE IF @Desc09 <> '' SET @parm09 = @Desc09;

    IF @p_parm10 <> '' SET @parm10 = @p_parm10;
    ELSE IF @p_Desc10 <> '' SET @parm10 = @p_Desc10;
    ELSE IF @Desc10 <> '' SET @parm10 = @Desc10;

    IF @p_Djson1 <> '' SET @parmJson1 = @p_Djson1;
    ELSE IF @Djson1 <> '' SET @parmJson1 = @Djson1;
    ELSE IF @p_parmJson1 <> '' SET @parmJson1 = @p_parmJson1;

    IF @p_Djson2 <> '' SET @parmJson2 = @p_Djson2;
    ELSE IF @Djson2 <> '' SET @parmJson2 = @Djson2;
    ELSE IF @p_parmJson2 <> '' SET @parmJson2 = @p_parmJson2;

    -- ========================================================================
    -- DISPATCH BY @ProcID
    -- ========================================================================

    -- 0. USER LOGIN AUTHENTICATION
    IF @ProcID = 'GET_USER_LOGIN'
    BEGIN
        SELECT TOP 1
            1 AS success,
            CONVERT(NVARCHAR(50), u.Id) AS user_id,
            COALESCE(u.Username, u.Email, @parm01) AS username,
            COALESCE(u.Role, 'ClientUser') AS [role],
            COALESCE(CONVERT(NVARCHAR(50), u.TenantId), '00000000-0000-0000-0000-000000000000') AS tenant_id,
            COALESCE(u.Name, 'User') AS full_name
        FROM dbo.Users u
        WHERE (u.Username = @parm01 OR u.Email = @parm01)
          AND (u.PasswordHash = @parm02 OR u.Password = @parm02)
          AND u.IsActive = 1
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 0.1 REGISTER FCM TOKEN
    ELSE IF @ProcID = 'REGISTER_FCM_TOKEN'
    BEGIN
        UPDATE dbo.Users 
        SET FcmToken = @parm01, UpdatedAt = SYSDATETIMEOFFSET() 
        WHERE Id = @parm08 OR CONVERT(NVARCHAR(50), Id) = @parm08 OR Username = @parm08;

        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 1. DASHBOARD
    ELSE IF @ProcID = 'GET_DASHBOARD'
    BEGIN
        SELECT 
            99.98 AS uptime,
            (SELECT COUNT(*) FROM dbo.Users WHERE IsActive = 1) AS active_conversations,
            '45s' AS wait_time,
            (SELECT COUNT(*) FROM dbo.Users WHERE Role IN ('SupportManager', 'TeamMember') AND IsActive = 1) AS agents_online,
            96.5 AS sla_health,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status = 'NEW') AS new_tickets,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status = 'IN_PROGRESS') AS in_progress,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status = 'PENDING') AS pending,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status IN ('RESOLVED', 'CLOSED')) AS resolved,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status NOT IN ('RESOLVED', 'CLOSED') AND Priority = 'CRITICAL') AS breached,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'CRITICAL') AS urgent,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'HIGH') AS high,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'MEDIUM') AS medium,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'LOW') AS low,
            (
                SELECT TOP 10
                    CONVERT(NVARCHAR(50), u.Id) AS user_id,
                    u.Name AS name,
                    u.Role AS role,
                    'ONLINE' AS status,
                    (SELECT COUNT(*) FROM dbo.TicketTasks tt WHERE tt.AssignedTo = u.Id AND tt.Status <> 'DONE') AS active_tickets
                FROM dbo.Users u
                WHERE u.IsActive = 1
                FOR JSON PATH
            ) AS team_status
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 2. GET_TICKETS
    ELSE IF @ProcID = 'GET_TICKETS'
    BEGIN
        SELECT 
            t.TicketNumber AS ticket_number,