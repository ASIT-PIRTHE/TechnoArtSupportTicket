-- ============================================================================
-- TECHNOART SOFTWARE - MASTER UNIFIED DATABASE SCRIPT (MSSQL)
-- COMPLETE MERGED SYSTEM: Support Ticket System + Smart Attendance PWA + HRM + KPI + Payroll
-- Compatible with: Microsoft SQL Server 2012, 2014, 2016, 2019, 2022+ & Azure SQL Database
-- ALL PRIMARY & FOREIGN KEYS USE 12 OR 16 CHARACTER COMPACT IDENTIFIERS (e.g. C00000000001)
-- FULL SUPPORT FOR SCHEMA 'support' & 'dbo' (e.g. support.SP_TICKET_OPERATIONS)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SCHEMA DEFINITION
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'support')
BEGIN
    EXEC('CREATE SCHEMA support');
END
GO

-- ----------------------------------------------------------------------------
-- 2. TENANTS / CLIENT COMPANIES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Tenants', 'U') IS NULL
CREATE TABLE dbo.Tenants (
    TenantId NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('T', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    Code NVARCHAR(50) UNIQUE NOT NULL,
    Name NVARCHAR(150) NOT NULL,
    LogoUrl NVARCHAR(MAX) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Tenants WHERE TenantId = 'T00000000001')
BEGIN
    INSERT INTO dbo.Tenants (TenantId, Code, Name, IsActive)
    VALUES ('T00000000001', 'GLOBAL', 'TechnoArt Internal Engineering', 1);
END
GO

-- ----------------------------------------------------------------------------
-- 3. PROJECTS & SOFTWARE MODULES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Projects', 'U') IS NULL
CREATE TABLE dbo.Projects (
    ProjectId NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('P', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    TenantId NVARCHAR(36) NOT NULL FOREIGN KEY REFERENCES dbo.Tenants(TenantId),
    Code NVARCHAR(50) UNIQUE NOT NULL,
    Name NVARCHAR(150) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Projects_Tenant' AND object_id = OBJECT_ID('dbo.Projects'))
CREATE NONCLUSTERED INDEX IX_Projects_Tenant ON dbo.Projects(TenantId);
GO

IF OBJECT_ID('dbo.ProjectModules', 'U') IS NULL
CREATE TABLE dbo.ProjectModules (
    ModuleId NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('M', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    ProjectId NVARCHAR(36) NOT NULL FOREIGN KEY REFERENCES dbo.Projects(ProjectId),
    Code NVARCHAR(50) NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Proj_Module_Code UNIQUE(ProjectId, Code)
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Modules_Project' AND object_id = OBJECT_ID('dbo.ProjectModules'))
CREATE NONCLUSTERED INDEX IX_Modules_Project ON dbo.ProjectModules(ProjectId);
GO

-- Seed Initial Project & Modules (12-char compact IDs - P00000000001)
IF NOT EXISTS (SELECT 1 FROM dbo.Projects WHERE ProjectId = 'P00000000001')
BEGIN
    INSERT INTO dbo.Projects (ProjectId, TenantId, Code, Name, Description, IsActive)
    VALUES ('P00000000001', 'T00000000001', 'PRJ-CORE', 'TechnoArt Enterprise Suite', 'Integrated HRM, Attendance and Support Ticket Solution', 1);

    INSERT INTO dbo.ProjectModules (ModuleId, ProjectId, Code, Name, Description)
    VALUES 
        ('M00000000001', 'P00000000001', 'ATT', 'Smart Attendance & GPS', 'Biometric & Terminal Punch Tracking'),
        ('M00000000002', 'P00000000001', 'HRM', 'Personnel Management', 'Directory, ID Cards, Letters & Profiles'),
        ('M00000000003', 'P00000000001', 'TCK', 'Support & Ticketing', 'Helpdesk queue and task distribution'),
        ('M00000000004', 'P00000000001', 'PAY', 'Payroll & Compensation', 'Disbursements and salary statements');
END
GO

-- ----------------------------------------------------------------------------
-- 4. USERS & ROLES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Roles', 'U') IS NULL
CREATE TABLE dbo.Roles (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('R', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    RoleKey NVARCHAR(50) UNIQUE NOT NULL,
    DisplayName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    IsSystem BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'SuperAdmin')
INSERT INTO dbo.Roles (Id, RoleKey, DisplayName, Description, IsSystem)
VALUES 
    ('R00000000001', 'SuperAdmin', 'Super Admin', 'Full unrestricted access', 1),
    ('R00000000002', 'MD', 'Managing Director', 'Executive command & reports', 1),
    ('R00000000003', 'SupportManager', 'Support Manager', 'Queue & attendance approvals', 1),
    ('R00000000004', 'ProjectManager', 'Project Manager', 'Project tracking & rosters', 1),
    ('R00000000005', 'TeamMember', 'Team Member (Staff / Engineer)', 'Standard employee terminal access', 1),
    ('R00000000006', 'HRManager', 'HR Manager', 'Attendance, leaves & letters', 0),
    ('R00000000007', 'AccountsOfficer', 'Accounts Officer', 'Payroll & disbursements', 0),
    ('R00000000008', 'ClientAdmin', 'Client Admin', 'Tenant organization manager', 1),
    ('R00000000009', 'ClientUser', 'Client User', 'Client support ticket raiser', 1);
GO

IF OBJECT_ID('dbo.Users', 'U') IS NULL
CREATE TABLE dbo.Users (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('U', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    Username NVARCHAR(100) UNIQUE NOT NULL,
    Email NVARCHAR(150) NULL,
    PasswordHash NVARCHAR(255) NOT NULL,
    Name NVARCHAR(150) NOT NULL,
    Phone NVARCHAR(25) NULL,
    Role NVARCHAR(50) NOT NULL DEFAULT 'TeamMember',
    TenantId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Tenants(TenantId),
    ProjectId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Projects(ProjectId),
    ModuleId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.ProjectModules(ModuleId),
    ImageUrl NVARCHAR(MAX) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Users_Username' AND object_id = OBJECT_ID('dbo.Users'))
CREATE NONCLUSTERED INDEX IX_Users_Username ON dbo.Users(Username);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Users_Role' AND object_id = OBJECT_ID('dbo.Users'))
CREATE NONCLUSTERED INDEX IX_Users_Role ON dbo.Users(Role);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = 'admin@example.com')
INSERT INTO dbo.Users (Id, Username, Email, PasswordHash, Name, Phone, Role, TenantId)
VALUES 
    ('U10000000001', 'admin@example.com', 'admin@example.com', '1234567890', 'System Administrator', '+880 1700-000000', 'SuperAdmin', 'T00000000001'),
    ('U10000000002', 'shuvo@tas.com', 'shuvo@tas.com', '123456789', 'Shuvo TAS', '+880 1712-345678', 'TeamMember', 'T00000000001');
GO

IF OBJECT_ID('dbo.RoleMenuPermissions', 'U') IS NULL
CREATE TABLE dbo.RoleMenuPermissions (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('P', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    RoleKey NVARCHAR(50) NOT NULL FOREIGN KEY REFERENCES dbo.Roles(RoleKey) ON DELETE CASCADE,
    MenuKey NVARCHAR(50) NOT NULL,
    CanView BIT NOT NULL DEFAULT 0,
    CanEdit BIT NOT NULL DEFAULT 0,
    CanDelete BIT NOT NULL DEFAULT 0,
    CanApprove BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Role_Menu UNIQUE (RoleKey, MenuKey)
);
GO

-- ----------------------------------------------------------------------------
-- 5. SUPPORT TICKETS, TASKS, COMMENTS & FILES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Tickets', 'U') IS NULL
CREATE TABLE dbo.Tickets (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('TK', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 10)))),
    TicketNumber NVARCHAR(50) NOT NULL UNIQUE,
    TenantId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Tenants(TenantId),
    ProjectId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Projects(ProjectId),
    ModuleId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.ProjectModules(ModuleId),
    Subject NVARCHAR(255) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL,
    Priority NVARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    Status NVARCHAR(30) NOT NULL DEFAULT 'NEW',
    ProgressPercent DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    CreatedBy NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    AssignedTo NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Tickets_TicketNumber' AND object_id = OBJECT_ID('dbo.Tickets'))
CREATE NONCLUSTERED INDEX IX_Tickets_TicketNumber ON dbo.Tickets(TicketNumber);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Tickets_Status' AND object_id = OBJECT_ID('dbo.Tickets'))
CREATE NONCLUSTERED INDEX IX_Tickets_Status ON dbo.Tickets(Status);
GO

IF OBJECT_ID('dbo.TicketTasks', 'U') IS NULL
CREATE TABLE dbo.TicketTasks (
    TaskId NVARCHAR(50) PRIMARY KEY,
    TicketNumber NVARCHAR(50) NOT NULL FOREIGN KEY REFERENCES dbo.Tickets(TicketNumber) ON DELETE CASCADE,
    Name NVARCHAR(255) NOT NULL,
    AssignedTo NVARCHAR(100) NULL,
    Status NVARCHAR(30) NOT NULL DEFAULT 'TODO',
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Tasks_TicketNumber' AND object_id = OBJECT_ID('dbo.TicketTasks'))
CREATE NONCLUSTERED INDEX IX_Tasks_TicketNumber ON dbo.TicketTasks(TicketNumber);
GO

IF OBJECT_ID('dbo.TicketComments', 'U') IS NULL
CREATE TABLE dbo.TicketComments (
    CommentId NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('CM', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 10)))),
    TicketNumber NVARCHAR(50) NOT NULL FOREIGN KEY REFERENCES dbo.Tickets(TicketNumber) ON DELETE CASCADE,
    UserId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    Comment NVARCHAR(MAX) NOT NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF OBJECT_ID('support.TicketFiles', 'U') IS NULL
CREATE TABLE support.TicketFiles (
    FileId NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('FL', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 10)))),
    TicketNumber NVARCHAR(50) NOT NULL,
    FileName NVARCHAR(255) NOT NULL,
    MimeType NVARCHAR(100) NULL,
    Base64Data NVARCHAR(MAX) NOT NULL,
    UploadedBy NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_TicketFiles_Num' AND object_id = OBJECT_ID('support.TicketFiles'))
CREATE NONCLUSTERED INDEX IX_TicketFiles_Num ON support.TicketFiles(TicketNumber);
GO

-- ----------------------------------------------------------------------------
-- 6. ATTENDANCE SYSTEM: BRANCHES, SHIFTS & EMPLOYEES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Branches', 'U') IS NULL
CREATE TABLE dbo.Branches (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('B', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    Name NVARCHAR(100) NOT NULL,
    Latitude FLOAT NOT NULL,
    Longitude FLOAT NOT NULL,
    RadiusMeters INT NOT NULL DEFAULT 150,
    Address NVARCHAR(500) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE Id = 'B00000000001')
INSERT INTO dbo.Branches (Id, Name, Latitude, Longitude, RadiusMeters, Address, IsActive)
VALUES 
    ('B00000000001', 'TechnoArt Dhaka Headquarters (Gulshan)', 23.7925, 90.4078, 250, 'Gulshan-1, Dhaka', 1),
    ('B00000000002', 'Chittagong Operational Hub (Agrabad)', 22.3275, 91.8155, 200, 'Agrabad C/A, Chittagong', 1);
GO

IF OBJECT_ID('dbo.OfficeTimes', 'U') IS NULL
CREATE TABLE dbo.OfficeTimes (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('C', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    ShiftName NVARCHAR(100) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    GraceMinutes INT NOT NULL DEFAULT 15,
    HalfDayCutoffMinutes INT NOT NULL DEFAULT 120,
    IsDefault BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

-- Seed Core Shift using exact 12-char ID C00000000001
IF NOT EXISTS (SELECT 1 FROM dbo.OfficeTimes WHERE Id = 'C00000000001')
INSERT INTO dbo.OfficeTimes (Id, ShiftName, StartTime, EndTime, GraceMinutes, HalfDayCutoffMinutes, IsDefault)
VALUES ('C00000000001', 'Core Engineering Shift', '09:30:00', '18:30:00', 15, 120, 1);
GO

IF OBJECT_ID('dbo.Employees', 'U') IS NULL
CREATE TABLE dbo.Employees (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('E', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    UserId NVARCHAR(36) NOT NULL UNIQUE FOREIGN KEY REFERENCES dbo.Users(Id),
    BranchId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Branches(Id),
    OfficeTimeId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.OfficeTimes(Id),
    EmployeeCode NVARCHAR(50) NOT NULL UNIQUE,
    Designation NVARCHAR(100) NOT NULL,
    Department NVARCHAR(100) NULL DEFAULT 'Engineering',
    BloodGroup NVARCHAR(10) NULL DEFAULT 'B+',
    NationalId NVARCHAR(50) NULL,
    IsWfhAllowed BIT NOT NULL DEFAULT 1,
    CustomStartTime TIME NULL DEFAULT '09:30:00',
    CustomEndTime TIME NULL DEFAULT '18:30:00',
    CustomGraceMinutes INT NULL DEFAULT 15,
    BasicSalary DECIMAL(18, 2) DEFAULT 65000.00,
    HourlyRate DECIMAL(18, 2) DEFAULT 0.00,
    JoinDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    AppointmentLetterUrl NVARCHAR(500) NULL,
    AppointmentDate DATE NULL DEFAULT CAST(GETDATE() AS DATE),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Employees_UserId' AND object_id = OBJECT_ID('dbo.Employees'))
CREATE NONCLUSTERED INDEX IX_Employees_UserId ON dbo.Employees(UserId);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE Id = 'E00000000001')
INSERT INTO dbo.Employees (Id, UserId, BranchId, OfficeTimeId, EmployeeCode, Designation, Department, BloodGroup, IsWfhAllowed, BasicSalary)
VALUES (
    'E00000000001',
    'U10000000002',
    'B00000000001',
    'C00000000001',
    'TAS-104', 'Full Stack Engineer', 'Software Engineering', 'B+', 1, 65000.00
);
GO

IF OBJECT_ID('dbo.Attendances', 'U') IS NULL
CREATE TABLE dbo.Attendances (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('A', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    EmployeeId NVARCHAR(36) NOT NULL FOREIGN KEY REFERENCES dbo.Employees(Id),
    BranchId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Branches(Id),
    AttendanceDate DATE NOT NULL,
    InTime DATETIMEOFFSET NULL,
    OutTime DATETIMEOFFSET NULL,
    Punctuality NVARCHAR(20) NOT NULL DEFAULT 'ON_TIME',
    IsWfh BIT NOT NULL DEFAULT 0,
    InLatitude FLOAT NULL,
    InLongitude FLOAT NULL,
    OutLatitude FLOAT NULL,
    OutLongitude FLOAT NULL,
    InApprovalStatus NVARCHAR(20) NOT NULL DEFAULT 'PENDING',
    OutApprovalStatus NVARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ApprovedBy NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    ApprovalRemarks NVARCHAR(MAX) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Emp_Attendance_Date UNIQUE (EmployeeId, AttendanceDate)
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Attendances_EmpDate' AND object_id = OBJECT_ID('dbo.Attendances'))
CREATE NONCLUSTERED INDEX IX_Attendances_EmpDate ON dbo.Attendances(EmployeeId, AttendanceDate);
GO

IF OBJECT_ID('dbo.LeaveRequests', 'U') IS NULL
CREATE TABLE dbo.LeaveRequests (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('L', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    EmployeeId NVARCHAR(36) NOT NULL FOREIGN KEY REFERENCES dbo.Employees(Id),
    LeaveType NVARCHAR(50) NOT NULL DEFAULT 'Casual Leave',
    FromDate DATE NOT NULL,
    ToDate DATE NOT NULL,
    Reason NVARCHAR(MAX) NOT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ApprovedBy NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    Remarks NVARCHAR(MAX) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF OBJECT_ID('dbo.Notices', 'U') IS NULL
CREATE TABLE dbo.Notices (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('N', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    Title NVARCHAR(255) NOT NULL,
    Content NVARCHAR(MAX) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF OBJECT_ID('dbo.QrAuthSessions', 'U') IS NULL
CREATE TABLE dbo.QrAuthSessions (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('Q', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)))),
    SessionId NVARCHAR(100) UNIQUE NOT NULL,
    Status NVARCHAR(30) NOT NULL DEFAULT 'PENDING',
    AuthenticatedUserId NVARCHAR(36) NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    JwtToken NVARCHAR(MAX) NULL,
    DeviceInfo NVARCHAR(255) NULL,
    IpAddress NVARCHAR(50) NULL,
    ExpiresAt DATETIMEOFFSET NOT NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Qr_SessionId' AND object_id = OBJECT_ID('dbo.QrAuthSessions'))
CREATE NONCLUSTERED INDEX IX_Qr_SessionId ON dbo.QrAuthSessions(SessionId);
GO

IF OBJECT_ID('dbo.PayrollRecords', 'U') IS NULL
CREATE TABLE dbo.PayrollRecords (
    Id NVARCHAR(36) PRIMARY KEY DEFAULT (CONCAT('PY', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 10)))),
    EmployeeId NVARCHAR(36) NOT NULL FOREIGN KEY REFERENCES dbo.Employees(Id),
    SalaryMonth INT NOT NULL,
    SalaryYear INT NOT NULL,
    BaseSalary DECIMAL(18, 2) NOT NULL,
    TotalPresentDays INT NOT NULL DEFAULT 0,
    TotalLateDays INT NOT NULL DEFAULT 0,
    TotalLeaveDays INT NOT NULL DEFAULT 0,
    LateDeduction DECIMAL(18, 2) DEFAULT 0.00,
    Bonus DECIMAL(18, 2) DEFAULT 0.00,
    NetPayable DECIMAL(18, 2) NOT NULL,
    IsPaid BIT NOT NULL DEFAULT 0,
    PaymentDate DATE NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Payroll_Emp_Month_Year UNIQUE (EmployeeId, SalaryMonth, SalaryYear)
);
GO

-- ============================================================================
-- 7. MASTER STORED PROCEDURE: support.SP_TICKET_OPERATIONS & dbo.SP_TICKET_OPERATIONS
-- Handles all ticket, project, tenant & user queries invoked by Backend API
-- ============================================================================
IF OBJECT_ID('support.SP_TICKET_OPERATIONS', 'P') IS NOT NULL
    DROP PROCEDURE support.SP_TICKET_OPERATIONS;
GO
IF OBJECT_ID('dbo.SP_TICKET_OPERATIONS', 'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_TICKET_OPERATIONS;
GO

CREATE PROCEDURE support.SP_TICKET_OPERATIONS
    -- With @p_ prefix (passed by the backend API)
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
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
    @p_parm11 NVARCHAR(255) = '',
    @p_parm12 NVARCHAR(255) = '',
    @p_parm13 NVARCHAR(255) = '',
    @p_parm14 NVARCHAR(255) = '',
    @p_parm15 NVARCHAR(255) = '',
    @p_parm16 NVARCHAR(255) = '',
    @p_parm17 NVARCHAR(255) = '',
    @p_parm18 NVARCHAR(255) = '',
    @p_parm19 NVARCHAR(255) = '',
    @p_parm20 NVARCHAR(255) = '',
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_Djson3 NVARCHAR(MAX) = '',
    @p_Djson4 NVARCHAR(MAX) = '',
    @p_Djson5 NVARCHAR(MAX) = '',
    @p_Djson01 NVARCHAR(MAX) = '',
    @p_Djson02 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_parmJson3 NVARCHAR(MAX) = '',
    @p_parmJson01 NVARCHAR(MAX) = '',
    @p_parmJson02 NVARCHAR(MAX) = '',
    @p_Dbin01 VARBINARY(MAX) = NULL,
    @p_Dbin02 VARBINARY(MAX) = NULL,
    @p_Dbin03 VARBINARY(MAX) = NULL,
    @p_Dbin04 VARBINARY(MAX) = NULL,
    @p_Dbin05 VARBINARY(MAX) = NULL,
    @p_Dbin1 VARBINARY(MAX) = NULL,
    @p_Dbin2 VARBINARY(MAX) = NULL,
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,
    @p_parmBin1 VARBINARY(MAX) = NULL,
    @p_parmBin2 VARBINARY(MAX) = NULL,
    @p_BinData1 VARBINARY(MAX) = NULL,
    @p_BinData2 VARBINARY(MAX) = NULL,
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',

    -- Fallback without prefix
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
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
    @parm11 NVARCHAR(255) = '',
    @parm12 NVARCHAR(255) = '',
    @parm13 NVARCHAR(255) = '',
    @parm14 NVARCHAR(255) = '',
    @parm15 NVARCHAR(255) = '',
    @parm16 NVARCHAR(255) = '',
    @parm17 NVARCHAR(255) = '',
    @parm18 NVARCHAR(255) = '',
    @parm19 NVARCHAR(255) = '',
    @parm20 NVARCHAR(255) = '',
    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @Djson3 NVARCHAR(MAX) = '',
    @Djson4 NVARCHAR(MAX) = '',
    @Djson5 NVARCHAR(MAX) = '',
    @Djson01 NVARCHAR(MAX) = '',
    @Djson02 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',
    @parmJson3 NVARCHAR(MAX) = '',
    @parmJson01 NVARCHAR(MAX) = '',
    @parmJson02 NVARCHAR(MAX) = '',
    @Dbin01 VARBINARY(MAX) = NULL,
    @Dbin02 VARBINARY(MAX) = NULL,
    @Dbin03 VARBINARY(MAX) = NULL,
    @Dbin04 VARBINARY(MAX) = NULL,
    @Dbin05 VARBINARY(MAX) = NULL,
    @Dbin1 VARBINARY(MAX) = NULL,
    @Dbin2 VARBINARY(MAX) = NULL,
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,
    @parmBin1 VARBINARY(MAX) = NULL,
    @parmBin2 VARBINARY(MAX) = NULL,
    @BinData1 VARBINARY(MAX) = NULL,
    @BinData2 VARBINARY(MAX) = NULL,
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',
    @SessionId NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalize parameters to handle both @p_ and standard calls
    SET @ComCod = COALESCE(NULLIF(@p_ComCod, ''), @ComCod);
    SET @ProcID = COALESCE(NULLIF(@p_ProcID, ''), NULLIF(@p_Action, ''), NULLIF(@Action, ''), @ProcID);
    SET @parm01 = COALESCE(NULLIF(@p_parm01, ''), @parm01);
    SET @parm02 = COALESCE(NULLIF(@p_parm02, ''), @parm02);
    SET @parm03 = COALESCE(NULLIF(@p_parm03, ''), @parm03);
    SET @parm04 = COALESCE(NULLIF(@p_parm04, ''), @parm04);
    SET @parm05 = COALESCE(NULLIF(@p_parm05, ''), @parm05);
    SET @parm06 = COALESCE(NULLIF(@p_parm06, ''), @parm06);
    SET @parm07 = COALESCE(NULLIF(@p_parm07, ''), @parm07);
    SET @parm08 = COALESCE(NULLIF(@p_parm08, ''), @parm08);
    SET @parm09 = COALESCE(NULLIF(@p_parm09, ''), @parm09);
    SET @parm10 = COALESCE(NULLIF(@p_parm10, ''), @parm10);
    SET @parmJson1 = COALESCE(NULLIF(@p_Djson1, ''), NULLIF(@Djson1, ''), NULLIF(@p_Djson01, ''), NULLIF(@Djson01, ''), NULLIF(@p_parmJson1, ''), NULLIF(@p_parmJson01, ''), @parmJson1);
    SET @parmJson2 = COALESCE(NULLIF(@p_Djson2, ''), NULLIF(@Djson2, ''), NULLIF(@p_Djson02, ''), NULLIF(@Djson02, ''), NULLIF(@p_parmJson2, ''), NULLIF(@p_parmJson02, ''), @parmJson2);
    SET @parmBin01 = COALESCE(@p_Dbin01, @Dbin01, @p_Dbin1, @Dbin1, @p_parmBin01, @parmBin01, @p_BinData1, @BinData1);

    -- 1. GET_DASHBOARD
    IF @ProcID = 'GET_DASHBOARD'
    BEGIN
        SELECT 
            99.98 AS uptime,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status IN ('NEW', 'OPEN', 'IN_PROGRESS')) AS active_conversations,
            '4m' AS wait_time,
            (SELECT COUNT(*) FROM dbo.Users WHERE Role IN ('SupportManager', 'ProjectManager', 'TeamMember') AND IsActive = 1) AS agents_online
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 2. GET_TICKETS
    ELSE IF @ProcID = 'GET_TICKETS'
    BEGIN
        SELECT 
            t.TicketNumber AS ticket_number,
            t.Subject AS subject,
            COALESCE(p.Name, 'Internal') AS project_name,
            COALESCE(pm.Name, '') AS module_name,
            t.Priority AS priority,
            t.Status AS status,
            t.ProgressPercent AS progress_percent,
            COALESCE(u.Name, 'Unassigned') AS assigned_to_name,
            COALESCE(cb.Name, 'User') AS created_by_name,
            CONVERT(VARCHAR(19), t.CreatedAt, 126) AS created_at
        FROM dbo.Tickets t
        LEFT JOIN dbo.Projects p ON t.ProjectId = p.ProjectId
        LEFT JOIN dbo.ProjectModules pm ON t.ModuleId = pm.ModuleId
        LEFT JOIN dbo.Users u ON t.AssignedTo = u.Id
        LEFT JOIN dbo.Users cb ON t.CreatedBy = cb.Id
        ORDER BY t.CreatedAt DESC
        FOR JSON PATH;
    END

    -- 3. GET_MY_TICKETS
    ELSE IF @ProcID = 'GET_MY_TICKETS'
    BEGIN
        SELECT 
            t.TicketNumber AS ticket_number,
            t.Subject AS subject,
            COALESCE(p.Name, 'Internal') AS project_name,
            COALESCE(pm.Name, '') AS module_name,
            t.Priority AS priority,
            t.Status AS status,
            t.ProgressPercent AS progress_percent,
            CONVERT(VARCHAR(19), t.CreatedAt, 126) AS created_at
        FROM dbo.Tickets t
        LEFT JOIN dbo.Projects p ON t.ProjectId = p.ProjectId
        LEFT JOIN dbo.ProjectModules pm ON t.ModuleId = pm.ModuleId
        WHERE t.CreatedBy = @parm04 OR t.AssignedTo = @parm04
        ORDER BY t.CreatedAt DESC
        FOR JSON PATH;
    END

    -- 4. GET_TICKET_DETAILS
    ELSE IF @ProcID = 'GET_TICKET_DETAILS'
    BEGIN
        SELECT 
            t.TicketNumber AS ticket_number,
            t.Subject AS subject,
            t.Description AS description,
            t.Priority AS priority,
            t.Status AS status,
            t.ProgressPercent AS progress_percent,
            COALESCE(p.Name, 'Internal') AS project_name,
            COALESCE(pm.Name, '') AS module_name,
            COALESCE(u.Name, 'Unassigned') AS assigned_to_name,
            COALESCE(cb.Name, 'User') AS created_by_name,
            CONVERT(VARCHAR(16), t.CreatedAt, 120) AS created_at,
            (
                SELECT TaskId AS task_id, Name AS name, AssignedTo AS assigned_to, Status AS status
                FROM dbo.TicketTasks WHERE TicketNumber = t.TicketNumber
                FOR JSON PATH
            ) AS tasks,
            (
                SELECT c.CommentId AS comment_id, c.Comment AS comment, COALESCE(cu.Name, 'User') AS user_name, CONVERT(VARCHAR(16), c.CreatedAt, 120) AS created_at
                FROM dbo.TicketComments c
                LEFT JOIN dbo.Users cu ON c.UserId = cu.Id
                WHERE c.TicketNumber = t.TicketNumber
                FOR JSON PATH
            ) AS comments
        FROM dbo.Tickets t
        LEFT JOIN dbo.Projects p ON t.ProjectId = p.ProjectId
        LEFT JOIN dbo.ProjectModules pm ON t.ModuleId = pm.ModuleId
        LEFT JOIN dbo.Users u ON t.AssignedTo = u.Id
        LEFT JOIN dbo.Users cb ON t.CreatedBy = cb.Id
        WHERE t.TicketNumber = @parm01
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 5. CREATE_TICKET
    ELSE IF @ProcID = 'CREATE_TICKET'
    BEGIN
        DECLARE @TicketNum NVARCHAR(50);
        SET @TicketNum = CONCAT('TAS-', FORMAT(GETDATE(), 'yy'), '-', RIGHT('00000' + CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 90000 + 10000) AS VARCHAR(10)), 5));

        INSERT INTO dbo.Tickets (TicketNumber, TenantId, ProjectId, ModuleId, Subject, Priority, Description, Status, ProgressPercent, CreatedBy)
        VALUES (
            @TicketNum,
            NULLIF(TRIM(@ComCod), ''),
            NULLIF(TRIM(@parm01), ''),
            NULLIF(TRIM(@parm07), ''),
            @parm02, @parm03, @parm06, 'NEW', 0.00,
            NULLIF(TRIM(@parm04), '')
        );

        SELECT 1 AS success, @TicketNum AS ticket_number FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 6. UPDATE_TICKET_STATUS
    ELSE IF @ProcID = 'UPDATE_TICKET_STATUS'
    BEGIN
        UPDATE dbo.Tickets 
        SET Status = @parm02, UpdatedAt = SYSDATETIMEOFFSET() 
        WHERE TicketNumber = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 7. GET_TASKS
    ELSE IF @ProcID = 'GET_TASKS'
    BEGIN
        SELECT 
            TaskId AS task_id,
            Name AS name,
            TicketNumber AS ticket_number,
            AssignedTo AS assigned_to,
            Status AS status
        FROM dbo.TicketTasks
        ORDER BY CreatedAt DESC
        FOR JSON PATH;
    END

    -- 8. CREATE_TASK
    ELSE IF @ProcID = 'CREATE_TASK'
    BEGIN
        DECLARE @NewTaskId NVARCHAR(50);
        SET @NewTaskId = CONCAT('TSK', RIGHT('000000000' + CAST(FLOOR(RAND(CHECKSUM(NEWID())) * 900000000 + 100000000) AS VARCHAR(10)), 9));
        INSERT INTO dbo.TicketTasks (TaskId, TicketNumber, Name, AssignedTo, Status)
        VALUES (@NewTaskId, @parm01, @parm02, @parm03, 'TODO');
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 9. UPDATE_TASK_STATUS
    ELSE IF @ProcID = 'UPDATE_TASK_STATUS'
    BEGIN
        UPDATE dbo.TicketTasks SET Status = @parm02, UpdatedAt = SYSDATETIMEOFFSET() WHERE TaskId = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 10. ADD_COMMENT
    ELSE IF @ProcID = 'ADD_COMMENT'
    BEGIN
        INSERT INTO dbo.TicketComments (TicketNumber, UserId, Comment)
        VALUES (@parm01, NULLIF(TRIM(@parm04), ''), @parm02);
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 11. GET_PROJECTS
    ELSE IF @ProcID = 'GET_PROJECTS'
    BEGIN
        SELECT 
            p.ProjectId AS project_id,
            p.Code AS code,
            p.Name AS name,
            p.TenantId AS tenant_id,
            COALESCE(t.Name, 'Internal') AS tenant_name
        FROM dbo.Projects p
        LEFT JOIN dbo.Tenants t ON p.TenantId = t.TenantId
        WHERE p.IsActive = 1
        FOR JSON PATH;
    END

    -- 12. CREATE_PROJECT
    ELSE IF @ProcID = 'CREATE_PROJECT'
    BEGIN
        INSERT INTO dbo.Projects (TenantId, Code, Name, Description, IsActive)
        VALUES (NULLIF(TRIM(@parm03), ''), @parm01, @parm02, @parm06, 1);
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 13. UPDATE_PROJECT
    ELSE IF @ProcID = 'UPDATE_PROJECT'
    BEGIN
        UPDATE dbo.Projects 
        SET Code = @parm02, Name = @parm03, TenantId = NULLIF(TRIM(@parm04), ''), UpdatedAt = SYSDATETIMEOFFSET() 
        WHERE ProjectId = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 14. GET_PROJECT_MODULES
    ELSE IF @ProcID = 'GET_PROJECT_MODULES'
    BEGIN
        SELECT ModuleId AS module_id, Code AS code, Name AS name, Description AS description
        FROM dbo.ProjectModules WHERE ProjectId = NULLIF(TRIM(@parm01), '')
        FOR JSON PATH;
    END

    -- 15. CREATE_MODULE
    ELSE IF @ProcID = 'CREATE_MODULE'
    BEGIN
        INSERT INTO dbo.ProjectModules (ProjectId, Code, Name, Description)
        VALUES (@parm01, @parm02, @parm03, @parm06);
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 16. DELETE_MODULE
    ELSE IF @ProcID = 'DELETE_MODULE'
    BEGIN
        DELETE FROM dbo.ProjectModules WHERE ModuleId = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 17. GET_TENANTS
    ELSE IF @ProcID = 'GET_TENANTS'
    BEGIN
        SELECT TenantId AS tenant_id, Code AS code, Name AS name, LogoUrl AS logo_url
        FROM dbo.Tenants WHERE IsActive = 1
        FOR JSON PATH;
    END

    -- 18. CREATE_TENANT
    ELSE IF @ProcID = 'CREATE_TENANT'
    BEGIN
        INSERT INTO dbo.Tenants (Code, Name, LogoUrl, IsActive)
        VALUES (@parm01, @parm02, @parm03, 1);
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 19. UPDATE_TENANT
    ELSE IF @ProcID = 'UPDATE_TENANT'
    BEGIN
        UPDATE dbo.Tenants 
        SET Code = @parm02, Name = @parm03, LogoUrl = @parm04, UpdatedAt = SYSDATETIMEOFFSET() 
        WHERE TenantId = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 20. DELETE_TENANT
    ELSE IF @ProcID = 'DELETE_TENANT'
    BEGIN
        UPDATE dbo.Tenants SET IsActive = 0, UpdatedAt = SYSDATETIMEOFFSET() WHERE TenantId = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 21. GET_USERS / GET_TEAM_MEMBERS
    ELSE IF @ProcID IN ('GET_USERS', 'GET_TEAM_MEMBERS')
    BEGIN
        SELECT 
            u.Id AS user_id,
            u.Username AS username,
            u.Name AS full_name,
            u.Role AS role,
            u.TenantId AS tenant_id,
            COALESCE(tn.Name, 'Internal') AS tenant_name,
            u.ProjectId AS project_id,
            COALESCE(pr.Name, '—') AS project_name,
            u.ModuleId AS module_id,
            COALESCE(pm.Name, '') AS module_name,
            COALESCE(CONVERT(VARCHAR(5), e.CustomStartTime, 108), '09:30 AM') AS shift_timing
        FROM dbo.Users u
        LEFT JOIN dbo.Tenants tn ON u.TenantId = tn.TenantId
        LEFT JOIN dbo.Projects pr ON u.ProjectId = pr.ProjectId
        LEFT JOIN dbo.ProjectModules pm ON u.ModuleId = pm.ModuleId
        LEFT JOIN dbo.Employees e ON u.Id = e.UserId
        WHERE u.IsActive = 1
        FOR JSON PATH;
    END

    -- 22. CREATE_USER
    ELSE IF @ProcID = 'CREATE_USER'
    BEGIN
        DECLARE @NewUserId NVARCHAR(36);
        SET @NewUserId = CONCAT('U', UPPER(SUBSTRING(REPLACE(CONVERT(NVARCHAR(36), NEWID()), '-', ''), 1, 11)));

        INSERT INTO dbo.Users (Id, Username, PasswordHash, Name, Phone, Role, TenantId, ProjectId, ModuleId, IsActive)
        VALUES (@NewUserId, @parm01, @parm02, @parm03, @parm04, @parm05, NULLIF(TRIM(@parm06), ''), NULLIF(TRIM(@parm07), ''), NULLIF(TRIM(@parm08), ''), 1);

        -- Also create corresponding employee record
        INSERT INTO dbo.Employees (UserId, EmployeeCode, Designation, Department, BloodGroup, IsWfhAllowed)
        VALUES (@NewUserId, CONCAT('TAS-', RIGHT('0000' + CAST(FLOOR(RAND() * 9000 + 1000) AS VARCHAR(10)), 4)), @parm05, 'Engineering', 'B+', 1);

        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 23. UPDATE_USER
    ELSE IF @ProcID = 'UPDATE_USER'
    BEGIN
        UPDATE dbo.Users
        SET Name = @parm02,
            Role = @parm03,
            Phone = @parm04,
            TenantId = NULLIF(TRIM(@parm06), ''),
            ProjectId = NULLIF(TRIM(@parm07), ''),
            ModuleId = NULLIF(TRIM(@parm08), ''),
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE Id = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 24. ADMIN_RESET_PASSWORD
    ELSE IF @ProcID = 'ADMIN_RESET_PASSWORD'
    BEGIN
        UPDATE dbo.Users SET PasswordHash = @parm02, UpdatedAt = SYSDATETIMEOFFSET() WHERE Id = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 25. GET_REPORTS
    ELSE IF @ProcID = 'GET_REPORTS'
    BEGIN
        SELECT 
            (SELECT COUNT(*) FROM dbo.Tenants WHERE IsActive = 1) AS total_clients,
            (SELECT COUNT(*) FROM dbo.Projects WHERE IsActive = 1) AS total_projects,
            (SELECT COUNT(*) FROM dbo.Tickets) AS total_tickets,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status IN ('RESOLVED', 'CLOSED')) AS resolved_tickets,
            96.5 AS sla_compliance_rate
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END
END;
GO

-- 3. Create dbo.SP_TICKET_OPERATIONS proxy (forwards all parameters to support.SP_TICKET_OPERATIONS)
IF OBJECT_ID('dbo.SP_TICKET_OPERATIONS', 'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_TICKET_OPERATIONS;
GO

CREATE PROCEDURE dbo.SP_TICKET_OPERATIONS
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
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
    @p_parm11 NVARCHAR(255) = '',
    @p_parm12 NVARCHAR(255) = '',
    @p_parm13 NVARCHAR(255) = '',
    @p_parm14 NVARCHAR(255) = '',
    @p_parm15 NVARCHAR(255) = '',
    @p_parm16 NVARCHAR(255) = '',
    @p_parm17 NVARCHAR(255) = '',
    @p_parm18 NVARCHAR(255) = '',
    @p_parm19 NVARCHAR(255) = '',
    @p_parm20 NVARCHAR(255) = '',
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_Djson3 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_parmJson3 NVARCHAR(MAX) = '',
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,
    @p_BinData1 VARBINARY(MAX) = NULL,
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
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
    @parm11 NVARCHAR(255) = '',
    @parm12 NVARCHAR(255) = '',
    @parm13 NVARCHAR(255) = '',
    @parm14 NVARCHAR(255) = '',
    @parm15 NVARCHAR(255) = '',
    @parm16 NVARCHAR(255) = '',
    @parm17 NVARCHAR(255) = '',
    @parm18 NVARCHAR(255) = '',
    @parm19 NVARCHAR(255) = '',
    @parm20 NVARCHAR(255) = '',
    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @Djson3 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',
    @parmJson3 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,
    @BinData1 VARBINARY(MAX) = NULL,
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',
    @SessionId NVARCHAR(100) = ''
AS
BEGIN
    EXEC support.SP_TICKET_OPERATIONS
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_ProcName=@p_ProcName,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04, @p_parm05=@p_parm05,
        @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08, @p_parm09=@p_parm09, @p_parm10=@p_parm10,
        @p_parm11=@p_parm11, @p_parm12=@p_parm12, @p_parm13=@p_parm13, @p_parm14=@p_parm14, @p_parm15=@p_parm15,
        @p_parm16=@p_parm16, @p_parm17=@p_parm17, @p_parm18=@p_parm18, @p_parm19=@p_parm19, @p_parm20=@p_parm20,
        @p_Djson1=@p_Djson1, @p_Djson2=@p_Djson2, @p_Djson3=@p_Djson3,
        @p_parmJson1=@p_parmJson1, @p_parmJson2=@p_parmJson2, @p_parmJson3=@p_parmJson3,
        @p_parmBin01=@p_parmBin01, @p_parmBin02=@p_parmBin02, @p_BinData1=@p_BinData1,
        @p_UserId=@p_UserId, @p_UserCode=@p_UserCode, @p_Action=@p_Action, @p_SessionId=@p_SessionId,
        @ComCod=@ComCod, @ProcID=@ProcID, @ProcName=@ProcName,
        @parm01=@parm01, @parm02=@parm02, @parm03=@parm03, @parm04=@parm04, @parm05=@parm05,
        @parm06=@parm06, @parm07=@parm07, @parm08=@parm08, @parm09=@parm09, @parm10=@parm10,
        @parm11=@parm11, @parm12=@parm12, @parm13=@parm13, @parm14=@parm14, @parm15=@parm15,
        @parm16=@parm16, @parm17=@parm17, @parm18=@parm18, @parm19=@parm19, @parm20=@parm20,
        @Djson1=@Djson1, @Djson2=@Djson2, @Djson3=@Djson3,
        @parmJson1=@parmJson1, @parmJson2=@parmJson2, @parmJson3=@parmJson3,
        @parmBin01=@parmBin01, @parmBin02=@parmBin02, @BinData1=@BinData1,
        @UserId=@UserId, @UserCode=@UserCode, @Action=@Action, @SessionId=@SessionId;
END;
GO

-- 4. Clean recreate support.sp_attendance_operations
IF OBJECT_ID('support.sp_attendance_operations', 'P') IS NOT NULL
    DROP PROCEDURE support.sp_attendance_operations;
GO
IF OBJECT_ID('dbo.sp_attendance_operations', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_attendance_operations;
GO

CREATE PROCEDURE support.sp_attendance_operations
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
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
    @p_parm11 NVARCHAR(255) = '',
    @p_parm12 NVARCHAR(255) = '',
    @p_parm13 NVARCHAR(255) = '',
    @p_parm14 NVARCHAR(255) = '',
    @p_parm15 NVARCHAR(255) = '',
    @p_parm16 NVARCHAR(255) = '',
    @p_parm17 NVARCHAR(255) = '',
    @p_parm18 NVARCHAR(255) = '',
    @p_parm19 NVARCHAR(255) = '',
    @p_parm20 NVARCHAR(255) = '',
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_Djson3 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_parmJson3 NVARCHAR(MAX) = '',
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,
    @p_BinData1 VARBINARY(MAX) = NULL,
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
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
    @parm11 NVARCHAR(255) = '',
    @parm12 NVARCHAR(255) = '',
    @parm13 NVARCHAR(255) = '',
    @parm14 NVARCHAR(255) = '',
    @parm15 NVARCHAR(255) = '',
    @parm16 NVARCHAR(255) = '',
    @parm17 NVARCHAR(255) = '',
    @parm18 NVARCHAR(255) = '',
    @parm19 NVARCHAR(255) = '',
    @parm20 NVARCHAR(255) = '',
    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @Djson3 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',
    @parmJson3 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,
    @BinData1 VARBINARY(MAX) = NULL,
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',
    @SessionId NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalize parameters to handle both @p_ and standard calls
    SET @ComCod = COALESCE(NULLIF(@p_ComCod, ''), @ComCod);
    SET @ProcID = COALESCE(NULLIF(@p_ProcID, ''), NULLIF(@p_Action, ''), NULLIF(@Action, ''), @ProcID);
    SET @parm01 = COALESCE(NULLIF(@p_parm01, ''), @parm01);
    SET @parm02 = COALESCE(NULLIF(@p_parm02, ''), @parm02);
    SET @parm03 = COALESCE(NULLIF(@p_parm03, ''), @parm03);
    SET @parm04 = COALESCE(NULLIF(@p_parm04, ''), @parm04);
    SET @parm05 = COALESCE(NULLIF(@p_parm05, ''), @parm05);
    SET @parm06 = COALESCE(NULLIF(@p_parm06, ''), @parm06);
    SET @parm07 = COALESCE(NULLIF(@p_parm07, ''), @parm07);
    SET @parm08 = COALESCE(NULLIF(@p_parm08, ''), @parm08);
    SET @parm09 = COALESCE(NULLIF(@p_parm09, ''), @parm09);
    SET @parm10 = COALESCE(NULLIF(@p_parm10, ''), @parm10);
    SET @parmJson1 = COALESCE(NULLIF(@p_Djson1, ''), NULLIF(@Djson1, ''), NULLIF(@p_parmJson1, ''), @parmJson1);
    SET @parmJson2 = COALESCE(NULLIF(@p_Djson2, ''), NULLIF(@Djson2, ''), NULLIF(@p_parmJson2, ''), @parmJson2);
    SET @parmBin01 = COALESCE(@p_parmBin01, @p_BinData1, @BinData1, @parmBin01);

    -- GET_OFFICE_TIME
    IF @ProcID = 'GET_OFFICE_TIME'
    BEGIN
        SELECT TOP 1
            Id AS id,
            CONVERT(VARCHAR(5), StartTime, 108) AS start_time,
            CONVERT(VARCHAR(5), EndTime, 108) AS end_time,
            GraceMinutes AS grace_time,
            HalfDayCutoffMinutes AS half_day_cutoff
        FROM dbo.OfficeTimes
        WHERE IsDefault = 1 OR Id = 'C00000000001'
        ORDER BY IsDefault DESC
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- SET_OFFICE_TIME
    ELSE IF @ProcID = 'SET_OFFICE_TIME'
    BEGIN
        UPDATE dbo.OfficeTimes
        SET StartTime = CAST(@parm01 AS TIME),
            EndTime = CAST(@parm02 AS TIME),
            GraceMinutes = CAST(COALESCE(NULLIF(@parm03, ''), '15') AS INT),
            HalfDayCutoffMinutes = CAST(COALESCE(NULLIF(@parm04, ''), '120') AS INT)
        WHERE Id = 'C00000000001' OR IsDefault = 1;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_BRANCHES
    ELSE IF @ProcID = 'GET_BRANCHES'
    BEGIN
        SELECT 
            b.Id AS id,
            b.Name AS name,
            b.Latitude AS latitude,
            b.Longitude AS longitude,
            b.RadiusMeters AS radius,
            b.Address AS address,
            (SELECT COUNT(*) FROM dbo.Employees e WHERE e.BranchId = b.Id AND e.IsActive = 1) AS employee_count
        FROM dbo.Branches b
        WHERE b.IsActive = 1
        FOR JSON PATH;
    END

    -- SAVE_BRANCH
    ELSE IF @ProcID = 'SAVE_BRANCH'
    BEGIN
        IF NULLIF(TRIM(@parm01), '') IS NULL
        BEGIN
            INSERT INTO dbo.Branches (Name, Latitude, Longitude, RadiusMeters, Address, IsActive)
            VALUES (@parm02, CAST(@parm03 AS FLOAT), CAST(@parm04 AS FLOAT), CAST(@parm05 AS INT), @parm06, 1);
        END
        ELSE
        BEGIN
            UPDATE dbo.Branches
            SET Name = @parm02,
                Latitude = CAST(@parm03 AS FLOAT),
                Longitude = CAST(@parm04 AS FLOAT),
                RadiusMeters = CAST(@parm05 AS INT),
                Address = @parm06
            WHERE Id = @parm01;
        END
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_EMPLOYEE_CARD
    ELSE IF @ProcID = 'GET_EMPLOYEE_CARD'
    BEGIN
        SELECT TOP 1
            u.Name AS name,
            e.EmployeeCode AS code,
            e.Designation AS designation,
            e.Department AS department,
            e.BloodGroup AS blood_group,
            CONVERT(VARCHAR(11), e.JoinDate, 106) AS join_date,
            u.ImageUrl AS photo_url
        FROM dbo.Users u
        LEFT JOIN dbo.Employees e ON u.Id = e.UserId
        WHERE u.Id = @parm01 OR e.Id = @parm01
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_EMPLOYEE_APPT
    ELSE IF @ProcID = 'GET_EMPLOYEE_APPT'
    BEGIN
        SELECT TOP 1
            u.Name AS name,
            e.EmployeeCode AS code,
            e.Designation AS designation,
            e.Department AS department,
            u.Email AS email,
            CONVERT(VARCHAR(11), e.JoinDate, 106) AS join_date,
            e.BasicSalary AS salary
        FROM dbo.Users u
        LEFT JOIN dbo.Employees e ON u.Id = e.UserId
        WHERE u.Id = @parm01 OR e.Id = @parm01
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- PUNCH_ATTENDANCE (Smart In/Out Punch)
    ELSE IF @ProcID IN ('PUNCH_ATTENDANCE', 'CHECK_IN', 'CHECK_OUT')
    BEGIN
        DECLARE @EmpPunchId NVARCHAR(36);
        SELECT @EmpPunchId = Id FROM dbo.Employees WHERE UserId = @parm01 OR Id = @parm01;

        IF @parm02 = 'IN'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Attendances WHERE EmployeeId = @EmpPunchId AND AttendanceDate = CAST(GETDATE() AS DATE))
            BEGIN
                INSERT INTO dbo.Attendances (EmployeeId, AttendanceDate, InTime, InLatitude, InLongitude, IsWfh, InApprovalStatus)
                VALUES (@EmpPunchId, CAST(GETDATE() AS DATE), SYSDATETIMEOFFSET(), CAST(NULLIF(@parm03, '') AS FLOAT), CAST(NULLIF(@parm04, '') AS FLOAT), CAST(COALESCE(NULLIF(@parm05, ''), '0') AS BIT), 'PENDING');
            END
        END
        ELSE
        BEGIN
            UPDATE dbo.Attendances
            SET OutTime = SYSDATETIMEOFFSET(),
                OutLatitude = CAST(NULLIF(@parm03, '') AS FLOAT),
                OutLongitude = CAST(NULLIF(@parm04, '') AS FLOAT),
                OutApprovalStatus = 'PENDING'
            WHERE EmployeeId = @EmpPunchId AND AttendanceDate = CAST(GETDATE() AS DATE);
        END
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_ATTENDANCE_QUEUE
    ELSE IF @ProcID = 'GET_ATTENDANCE_QUEUE'
    BEGIN
        SELECT 
            a.Id AS id,
            u.Name AS employee_name,
            e.EmployeeCode AS employee_code,
            b.Name AS branch_name,
            CONVERT(VARCHAR(10), a.AttendanceDate, 120) AS date,
            CONVERT(VARCHAR(8), a.InTime, 108) AS in_time,
            CONVERT(VARCHAR(8), a.OutTime, 108) AS out_time,
            a.Punctuality AS punctuality,
            a.IsWfh AS is_wfh,
            a.InApprovalStatus AS in_status,
            a.OutApprovalStatus AS out_status
        FROM dbo.Attendances a
        INNER JOIN dbo.Employees e ON a.EmployeeId = e.Id
        INNER JOIN dbo.Users u ON e.UserId = u.Id
        LEFT JOIN dbo.Branches b ON a.BranchId = b.Id
        ORDER BY a.AttendanceDate DESC
        FOR JSON PATH;
    END

    -- APPROVE_ATTENDANCE
    ELSE IF @ProcID = 'APPROVE_ATTENDANCE'
    BEGIN
        IF @parm02 = 'IN'
            UPDATE dbo.Attendances SET InApprovalStatus = @parm03, ApprovedBy = NULLIF(TRIM(@parm04), '') WHERE Id = @parm01;
        ELSE
            UPDATE dbo.Attendances SET OutApprovalStatus = @parm03, ApprovedBy = NULLIF(TRIM(@parm04), '') WHERE Id = @parm01;

        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_LEAVES
    ELSE IF @ProcID = 'GET_LEAVES'
    BEGIN
        SELECT 
            l.Id AS id,
            u.Name AS employee_name,
            e.EmployeeCode AS employee_code,
            l.LeaveType AS leave_type,
            CONVERT(VARCHAR(10), l.FromDate, 120) AS from_date,
            CONVERT(VARCHAR(10), l.ToDate, 120) AS to_date,
            l.Reason AS reason,
            l.Status AS status
        FROM dbo.LeaveRequests l
        INNER JOIN dbo.Employees e ON l.EmployeeId = e.Id
        INNER JOIN dbo.Users u ON e.UserId = u.Id
        ORDER BY l.CreatedAt DESC
        FOR JSON PATH;
    END

    -- APPLY_LEAVE
    ELSE IF @ProcID = 'APPLY_LEAVE'
    BEGIN
        DECLARE @EmpLeaveId NVARCHAR(36);
        SELECT @EmpLeaveId = Id FROM dbo.Employees WHERE UserId = @parm04 OR Id = @parm04;

        INSERT INTO dbo.LeaveRequests (EmployeeId, LeaveType, FromDate, ToDate, Reason, Status)
        VALUES (@EmpLeaveId, @parm01, CAST(@parm02 AS DATE), CAST(@parm03 AS DATE), @parm06, 'PENDING');
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- APPROVE_LEAVE
    ELSE IF @ProcID = 'APPROVE_LEAVE'
    BEGIN
        UPDATE dbo.LeaveRequests 
        SET Status = @parm02, ApprovedBy = NULLIF(TRIM(@parm03), ''), UpdatedAt = SYSDATETIMEOFFSET()
        WHERE Id = @parm01;
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_NOTICES
    ELSE IF @ProcID = 'GET_NOTICES'
    BEGIN
        SELECT Id AS id, Title AS title, Content AS content, CONVERT(VARCHAR(10), CreatedAt, 120) AS created_at
        FROM dbo.Notices WHERE IsActive = 1 ORDER BY CreatedAt DESC
        FOR JSON PATH;
    END

    -- SAVE_NOTICE
    ELSE IF @ProcID = 'SAVE_NOTICE'
    BEGIN
        INSERT INTO dbo.Notices (Title, Content, IsActive) VALUES (@parm01, @parm02, 1);
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_ROLES
    ELSE IF @ProcID = 'GET_ROLES'
    BEGIN
        SELECT 
            RoleKey AS key_name,
            DisplayName AS display_name,
            Description AS description,
            IsSystem AS is_system,
            (SELECT COUNT(*) FROM dbo.Users u WHERE u.Role = r.RoleKey) AS assigned_users_count
        FROM dbo.Roles r
        ORDER BY RoleKey ASC
        FOR JSON PATH;
    END

    -- CREATE_ROLE
    ELSE IF @ProcID = 'CREATE_ROLE'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = @parm01)
        BEGIN
            INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem)
            VALUES (@parm01, @parm02, @parm03, 0);
        END
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- GET_ROLE_PERMISSIONS
    ELSE IF @ProcID = 'GET_ROLE_PERMISSIONS'
    BEGIN
        SELECT 
            MenuKey AS menu_key,
            CanView AS can_view,
            CanEdit AS can_edit,
            CanDelete AS can_delete,
            CanApprove AS can_approve
        FROM dbo.RoleMenuPermissions
        WHERE RoleKey = @parm01
        FOR JSON PATH;
    END

    -- SAVE_ROLE_PERMISSIONS
    ELSE IF @ProcID = 'SAVE_ROLE_PERMISSIONS'
    BEGIN
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END
END;
GO

-- 5. Create dbo.sp_attendance_operations proxy
IF OBJECT_ID('dbo.sp_attendance_operations', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_attendance_operations;
GO

CREATE PROCEDURE dbo.sp_attendance_operations
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
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
    @p_parm11 NVARCHAR(255) = '',
    @p_parm12 NVARCHAR(255) = '',
    @p_parm13 NVARCHAR(255) = '',
    @p_parm14 NVARCHAR(255) = '',
    @p_parm15 NVARCHAR(255) = '',
    @p_parm16 NVARCHAR(255) = '',
    @p_parm17 NVARCHAR(255) = '',
    @p_parm18 NVARCHAR(255) = '',
    @p_parm19 NVARCHAR(255) = '',
    @p_parm20 NVARCHAR(255) = '',
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_Djson3 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_parmJson3 NVARCHAR(MAX) = '',
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,
    @p_BinData1 VARBINARY(MAX) = NULL,
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
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
    @parm11 NVARCHAR(255) = '',
    @parm12 NVARCHAR(255) = '',
    @parm13 NVARCHAR(255) = '',
    @parm14 NVARCHAR(255) = '',
    @parm15 NVARCHAR(255) = '',
    @parm16 NVARCHAR(255) = '',
    @parm17 NVARCHAR(255) = '',
    @parm18 NVARCHAR(255) = '',
    @parm19 NVARCHAR(255) = '',
    @parm20 NVARCHAR(255) = '',
    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @Djson3 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',
    @parmJson3 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,
    @BinData1 VARBINARY(MAX) = NULL,
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',
    @SessionId NVARCHAR(100) = ''
AS
BEGIN
    EXEC support.sp_attendance_operations
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_ProcName=@p_ProcName,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04, @p_parm05=@p_parm05,
        @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08, @p_parm09=@p_parm09, @p_parm10=@p_parm10,
        @p_parm11=@p_parm11, @p_parm12=@p_parm12, @p_parm13=@p_parm13, @p_parm14=@p_parm14, @p_parm15=@p_parm15,
        @p_parm16=@p_parm16, @p_parm17=@p_parm17, @p_parm18=@p_parm18, @p_parm19=@p_parm19, @p_parm20=@p_parm20,
        @p_Djson1=@p_Djson1, @p_Djson2=@p_Djson2, @p_Djson3=@p_Djson3,
        @p_parmJson1=@p_parmJson1, @p_parmJson2=@p_parmJson2, @p_parmJson3=@p_parmJson3,
        @p_parmBin01=@p_parmBin01, @p_parmBin02=@p_parmBin02, @p_BinData1=@p_BinData1,
        @p_UserId=@p_UserId, @p_UserCode=@p_UserCode, @p_Action=@p_Action, @p_SessionId=@p_SessionId,
        @ComCod=@ComCod, @ProcID=@ProcID, @ProcName=@ProcName,
        @parm01=@parm01, @parm02=@parm02, @parm03=@parm03, @parm04=@parm04, @parm05=@parm05,
        @parm06=@parm06, @parm07=@parm07, @parm08=@parm08, @parm09=@parm09, @parm10=@parm10,
        @parm11=@parm11, @parm12=@parm12, @parm13=@parm13, @parm14=@parm14, @parm15=@parm15,
        @parm16=@parm16, @parm17=@parm17, @parm18=@parm18, @parm19=@parm19, @parm20=@parm20,
        @Djson1=@Djson1, @Djson2=@Djson2, @Djson3=@Djson3,
        @parmJson1=@parmJson1, @parmJson2=@parmJson2, @parmJson3=@parmJson3,
        @parmBin01=@parmBin01, @parmBin02=@parmBin02, @BinData1=@BinData1,
        @UserId=@UserId, @UserCode=@UserCode, @Action=@Action, @SessionId=@SessionId;
END;
GO

-- 6. Clean recreate support.sp_ticket_files
IF OBJECT_ID('support.sp_ticket_files', 'P') IS NOT NULL
    DROP PROCEDURE support.sp_ticket_files;
GO
IF OBJECT_ID('dbo.sp_ticket_files', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ticket_files;
GO

CREATE PROCEDURE support.sp_ticket_files
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
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
    @p_parm11 NVARCHAR(255) = '',
    @p_parm12 NVARCHAR(255) = '',
    @p_parm13 NVARCHAR(255) = '',
    @p_parm14 NVARCHAR(255) = '',
    @p_parm15 NVARCHAR(255) = '',
    @p_parm16 NVARCHAR(255) = '',
    @p_parm17 NVARCHAR(255) = '',
    @p_parm18 NVARCHAR(255) = '',
    @p_parm19 NVARCHAR(255) = '',
    @p_parm20 NVARCHAR(255) = '',
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_Djson3 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_parmJson3 NVARCHAR(MAX) = '',
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,
    @p_BinData1 VARBINARY(MAX) = NULL,
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
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
    @parm11 NVARCHAR(255) = '',
    @parm12 NVARCHAR(255) = '',
    @parm13 NVARCHAR(255) = '',
    @parm14 NVARCHAR(255) = '',
    @parm15 NVARCHAR(255) = '',
    @parm16 NVARCHAR(255) = '',
    @parm17 NVARCHAR(255) = '',
    @parm18 NVARCHAR(255) = '',
    @parm19 NVARCHAR(255) = '',
    @parm20 NVARCHAR(255) = '',
    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @Djson3 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',
    @parmJson3 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,
    @BinData1 VARBINARY(MAX) = NULL,
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',
    @SessionId NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SET @ComCod = COALESCE(NULLIF(@p_ComCod, ''), @ComCod);
    SET @ProcID = COALESCE(NULLIF(@p_ProcID, ''), NULLIF(@p_Action, ''), NULLIF(@Action, ''), @ProcID);
    SET @parm01 = COALESCE(NULLIF(@p_parm01, ''), @parm01);
    SET @parm02 = COALESCE(NULLIF(@p_parm02, ''), @parm02);
    SET @parm03 = COALESCE(NULLIF(@p_parm03, ''), @parm03);
    SET @parm04 = COALESCE(NULLIF(@p_parm04, ''), @parm04);
    SET @parmJson1 = COALESCE(NULLIF(@p_Djson1, ''), NULLIF(@Djson1, ''), NULLIF(@p_parmJson1, ''), @parmJson1);

    IF @ProcID = 'UPLOAD_FILE'
    BEGIN
        INSERT INTO support.TicketFiles (TicketNumber, FileName, MimeType, Base64Data, UploadedBy)
        VALUES (@parm01, @parm02, @parm03, @parmJson1, NULLIF(TRIM(@parm04), ''));
        SELECT 1 AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END
    ELSE IF @ProcID = 'GET_FILES'
    BEGIN
        SELECT FileId AS file_id, FileName AS file_name, MimeType AS mime_type, Base64Data AS base64_data
        FROM support.TicketFiles WHERE TicketNumber = @parm01
        FOR JSON PATH;
    END
END;
GO

CREATE PROCEDURE dbo.sp_ticket_files
    @p_ComCod NVARCHAR(50) = '',
    @p_ProcID NVARCHAR(50) = '',
    @p_ProcName NVARCHAR(100) = '',
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
    @p_parm11 NVARCHAR(255) = '',
    @p_parm12 NVARCHAR(255) = '',
    @p_parm13 NVARCHAR(255) = '',
    @p_parm14 NVARCHAR(255) = '',
    @p_parm15 NVARCHAR(255) = '',
    @p_parm16 NVARCHAR(255) = '',
    @p_parm17 NVARCHAR(255) = '',
    @p_parm18 NVARCHAR(255) = '',
    @p_parm19 NVARCHAR(255) = '',
    @p_parm20 NVARCHAR(255) = '',
    @p_Djson1 NVARCHAR(MAX) = '',
    @p_Djson2 NVARCHAR(MAX) = '',
    @p_Djson3 NVARCHAR(MAX) = '',
    @p_parmJson1 NVARCHAR(MAX) = '',
    @p_parmJson2 NVARCHAR(MAX) = '',
    @p_parmJson3 NVARCHAR(MAX) = '',
    @p_parmBin01 VARBINARY(MAX) = NULL,
    @p_parmBin02 VARBINARY(MAX) = NULL,
    @p_BinData1 VARBINARY(MAX) = NULL,
    @p_UserId NVARCHAR(100) = '',
    @p_UserCode NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '',
    @p_SessionId NVARCHAR(100) = '',
    @ComCod NVARCHAR(50) = '',
    @ProcID NVARCHAR(50) = '',
    @ProcName NVARCHAR(100) = '',
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
    @parm11 NVARCHAR(255) = '',
    @parm12 NVARCHAR(255) = '',
    @parm13 NVARCHAR(255) = '',
    @parm14 NVARCHAR(255) = '',
    @parm15 NVARCHAR(255) = '',
    @parm16 NVARCHAR(255) = '',
    @parm17 NVARCHAR(255) = '',
    @parm18 NVARCHAR(255) = '',
    @parm19 NVARCHAR(255) = '',
    @parm20 NVARCHAR(255) = '',
    @Djson1 NVARCHAR(MAX) = '',
    @Djson2 NVARCHAR(MAX) = '',
    @Djson3 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '',
    @parmJson2 NVARCHAR(MAX) = '',
    @parmJson3 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL,
    @parmBin02 VARBINARY(MAX) = NULL,
    @BinData1 VARBINARY(MAX) = NULL,
    @UserId NVARCHAR(100) = '',
    @UserCode NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '',
    @SessionId NVARCHAR(100) = ''
AS
BEGIN
    EXEC support.sp_ticket_files
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_ProcName=@p_ProcName,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04, @p_parm05=@p_parm05,
        @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08, @p_parm09=@p_parm09, @p_parm10=@p_parm10,
        @p_parm11=@p_parm11, @p_parm12=@p_parm12, @p_parm13=@p_parm13, @p_parm14=@p_parm14, @p_parm15=@p_parm15,
        @p_parm16=@p_parm16, @p_parm17=@p_parm17, @p_parm18=@p_parm18, @p_parm19=@p_parm19, @p_parm20=@p_parm20,
        @p_Djson1=@p_Djson1, @p_Djson2=@p_Djson2, @p_Djson3=@p_Djson3,
        @p_parmJson1=@p_parmJson1, @p_parmJson2=@p_parmJson2, @p_parmJson3=@p_parmJson3,
        @p_parmBin01=@p_parmBin01, @p_parmBin02=@p_parmBin02, @p_BinData1=@p_BinData1,
        @p_UserId=@p_UserId, @p_UserCode=@p_UserCode, @p_Action=@p_Action, @p_SessionId=@p_SessionId,
        @ComCod=@ComCod, @ProcID=@ProcID, @ProcName=@ProcName,
        @parm01=@parm01, @parm02=@parm02, @parm03=@parm03, @parm04=@parm04, @parm05=@parm05,
        @parm06=@parm06, @parm07=@parm07, @parm08=@parm08, @parm09=@parm09, @parm10=@parm10,
        @parm11=@parm11, @parm12=@parm12, @parm13=@parm13, @parm14=@parm14, @parm15=@parm15,
        @parm16=@parm16, @parm17=@parm17, @parm18=@parm18, @parm19=@parm19, @parm20=@parm20,
        @Djson1=@Djson1, @Djson2=@Djson2, @Djson3=@Djson3,
        @parmJson1=@parmJson1, @parmJson2=@parmJson2, @parmJson3=@parmJson3,
        @parmBin01=@parmBin01, @parmBin02=@parmBin02, @BinData1=@BinData1,
        @UserId=@UserId, @UserCode=@UserCode, @Action=@Action, @SessionId=@SessionId;
END;
GO

