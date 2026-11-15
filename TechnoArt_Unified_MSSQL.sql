-- ============================================================================
-- TECHNOART SOFTWARE - FULL UNIFIED DATABASE SCRIPT (MSSQL)
-- MERGED SYSTEM: Support Ticket System + Attendance PWA System + HRM + KPI + Payroll
-- Compatible with: Microsoft SQL Server 2016, 2019, 2022+ & Azure SQL Database
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. USERS & IDENTITY
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Users', 'U') IS NULL
CREATE TABLE dbo.Users (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Email NVARCHAR(150) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    Name NVARCHAR(150) NOT NULL,
    Phone NVARCHAR(25) NULL,
    Role NVARCHAR(30) NOT NULL DEFAULT 'EMPLOYEE',
    ImageUrl NVARCHAR(500) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
CREATE NONCLUSTERED INDEX IX_Users_Email ON dbo.Users(Email);
CREATE NONCLUSTERED INDEX IX_Users_Role ON dbo.Users(Role);

-- ----------------------------------------------------------------------------
-- 2. BRANCHES & GEOFENCING
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Branches', 'U') IS NULL
CREATE TABLE dbo.Branches (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(100) NOT NULL,
    Latitude FLOAT NOT NULL,
    Longitude FLOAT NOT NULL,
    RadiusMeters INT NOT NULL DEFAULT 100,
    Address NVARCHAR(500) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- ----------------------------------------------------------------------------
-- 3. OFFICE TIMINGS & SHIFTS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.OfficeTimes', 'U') IS NULL
CREATE TABLE dbo.OfficeTimes (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ShiftName NVARCHAR(100) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    GraceMinutes INT NOT NULL DEFAULT 10,
    IsDefault BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- ----------------------------------------------------------------------------
-- 4. EMPLOYEES (Custom Shift, WFH, Salary, Appointment)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Employees', 'U') IS NULL
CREATE TABLE dbo.Employees (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL UNIQUE FOREIGN KEY REFERENCES dbo.Users(Id) ON DELETE CASCADE,
    BranchId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.Branches(Id),
    OfficeTimeId UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES dbo.OfficeTimes(Id),
    EmployeeCode NVARCHAR(50) NOT NULL UNIQUE,
    Designation NVARCHAR(100) NOT NULL,
    Department NVARCHAR(100) NULL,
    BloodGroup NVARCHAR(10) NULL,
    NationalId NVARCHAR(50) NULL,
    IsWfhAllowed BIT NOT NULL DEFAULT 0,
    CustomStartTime TIME NULL,
    CustomEndTime TIME NULL,
    CustomGraceMinutes INT NULL,
    BasicSalary DECIMAL(18, 2) DEFAULT 0.00,
    HourlyRate DECIMAL(18, 2) DEFAULT 0.00,
    JoinDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    AppointmentLetterUrl NVARCHAR(500) NULL,
    AppointmentDate DATE NULL,
    GuardianName NVARCHAR(100) NULL,
    GuardianPhone NVARCHAR(25) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
CREATE NONCLUSTERED INDEX IX_Employees_BranchId ON dbo.Employees(BranchId);
CREATE NONCLUSTERED INDEX IX_Employees_EmployeeCode ON dbo.Employees(EmployeeCode);

-- ----------------------------------------------------------------------------
-- 5. ATTENDANCES (HR Approval & WFH Support)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Attendances', 'U') IS NULL
CREATE TABLE dbo.Attendances (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    EmployeeId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.Employees(Id) ON DELETE CASCADE,
    BranchId UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES dbo.Branches(Id),
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
    ApprovedBy UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    ApprovalRemarks NVARCHAR(500) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Employee_Date UNIQUE (EmployeeId, AttendanceDate)
);
CREATE NONCLUSTERED INDEX IX_Attendances_EmpDate ON dbo.Attendances(EmployeeId, AttendanceDate);
CREATE NONCLUSTERED INDEX IX_Attendances_InStatus ON dbo.Attendances(InApprovalStatus);
CREATE NONCLUSTERED INDEX IX_Attendances_OutStatus ON dbo.Attendances(OutApprovalStatus);

-- ----------------------------------------------------------------------------
-- 6. LEAVES & PERMISSIONS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.LeaveRequests', 'U') IS NULL
CREATE TABLE dbo.LeaveRequests (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    EmployeeId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.Employees(Id) ON DELETE CASCADE,
    LeaveType NVARCHAR(50) NOT NULL DEFAULT 'CASUAL',
    FromDate DATE NOT NULL,
    ToDate DATE NOT NULL,
    Reason NVARCHAR(MAX) NOT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ApprovedBy UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    Remarks NVARCHAR(500) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- ----------------------------------------------------------------------------
-- 7. SUPPORT TICKETING
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.TicketDepartments', 'U') IS NULL
CREATE TABLE dbo.TicketDepartments (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(100) NOT NULL UNIQUE,
    IsActive BIT NOT NULL DEFAULT 1
);

IF OBJECT_ID('dbo.Tickets', 'U') IS NULL
CREATE TABLE dbo.Tickets (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    TicketNumber NVARCHAR(50) NOT NULL UNIQUE,
    DepartmentId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.TicketDepartments(Id),
    CustomerUserId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    AssignedAgentId UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    Subject NVARCHAR(255) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL,
    Priority NVARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    Status NVARCHAR(30) NOT NULL DEFAULT 'OPEN',
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
CREATE NONCLUSTERED INDEX IX_Tickets_Status ON dbo.Tickets(Status);
CREATE NONCLUSTERED INDEX IX_Tickets_Agent ON dbo.Tickets(AssignedAgentId);
CREATE NONCLUSTERED INDEX IX_Tickets_Customer ON dbo.Tickets(CustomerUserId);

IF OBJECT_ID('dbo.TicketReplies', 'U') IS NULL
CREATE TABLE dbo.TicketReplies (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    TicketId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.Tickets(Id) ON DELETE CASCADE,
    SenderUserId UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    Message NVARCHAR(MAX) NOT NULL,
    IsInternalNote BIT NOT NULL DEFAULT 0,
    AttachmentUrl NVARCHAR(500) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
CREATE NONCLUSTERED INDEX IX_TicketReplies_TicketId ON dbo.TicketReplies(TicketId);

-- ----------------------------------------------------------------------------
-- 8. DYNAMIC ROLES & ROLE-BASED MENU PERMISSIONS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.Roles', 'U') IS NULL
CREATE TABLE dbo.Roles (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    RoleKey NVARCHAR(50) UNIQUE NOT NULL,
    DisplayName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    IsSystem BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = 'SuperAdmin')
INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem)
VALUES 
    ('SuperAdmin', 'Super Admin', 'Full unrestricted access', 1),
    ('MD', 'Managing Director', 'Executive command & reports', 1),
    ('SupportManager', 'Support Manager', 'Queue & attendance approvals', 1),
    ('ProjectManager', 'Project Manager', 'Project tracking & rosters', 1),
    ('TeamMember', 'Team Member (Staff / Engineer)', 'Standard employee terminal access', 1),
    ('HRManager', 'HR Manager', 'Attendance, leaves & letters', 0),
    ('AccountsOfficer', 'Accounts Officer', 'Payroll & disbursements', 0),
    ('ClientAdmin', 'Client Admin', 'Tenant organization manager', 1),
    ('ClientUser', 'Client User', 'Client support ticket raiser', 1);

IF OBJECT_ID('dbo.RoleMenuPermissions', 'U') IS NULL
CREATE TABLE dbo.RoleMenuPermissions (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    RoleKey NVARCHAR(50) NOT NULL FOREIGN KEY REFERENCES dbo.Roles(RoleKey) ON DELETE CASCADE,
    MenuKey NVARCHAR(50) NOT NULL,
    CanView BIT NOT NULL DEFAULT 0,
    CanEdit BIT NOT NULL DEFAULT 0,
    CanDelete BIT NOT NULL DEFAULT 0,
    CanApprove BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Role_Menu UNIQUE (RoleKey, MenuKey)
);

-- ----------------------------------------------------------------------------
-- 9. QR CODE INSTANT AUTHENTICATION SESSIONS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.QrAuthSessions', 'U') IS NULL
CREATE TABLE dbo.QrAuthSessions (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    SessionId NVARCHAR(100) UNIQUE NOT NULL,
    Status NVARCHAR(30) NOT NULL DEFAULT 'PENDING',
    AuthenticatedUserId UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES dbo.Users(Id),
    JwtToken NVARCHAR(MAX) NULL,
    DeviceInfo NVARCHAR(255) NULL,
    IpAddress NVARCHAR(50) NULL,
    ExpiresAt DATETIMEOFFSET NOT NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
CREATE NONCLUSTERED INDEX IX_Qr_SessionId ON dbo.QrAuthSessions(SessionId);
GO

-- ============================================================================
-- STORED PROCEDURES (MSSQL)
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_AttendanceCheckIn
    @EmployeeId UNIQUEIDENTIFIER,
    @Latitude FLOAT,
    @Longitude FLOAT,
    @IsWfhRequest BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BranchId UNIQUEIDENTIFIER, @BranchLat FLOAT, @BranchLong FLOAT, @Radius INT;
    DECLARE @WfhAllowed BIT, @StartTime TIME, @GraceMinutes INT, @CurrentTime TIME;
    DECLARE @DistMeters FLOAT, @Punctuality NVARCHAR(20) = 'ON_TIME', @AttendanceId UNIQUEIDENTIFIER;

    SELECT 
        @BranchId = e.BranchId,
        @WfhAllowed = e.IsWfhAllowed,
        @StartTime = COALESCE(e.CustomStartTime, ot.StartTime, CAST('09:30:00' AS TIME)),
        @GraceMinutes = COALESCE(e.CustomGraceMinutes, ot.GraceMinutes, 10),
        @BranchLat = b.Latitude,
        @BranchLong = b.Longitude,
        @Radius = b.RadiusMeters
    FROM dbo.Employees e
    INNER JOIN dbo.Branches b ON e.BranchId = b.Id
    LEFT JOIN dbo.OfficeTimes ot ON e.OfficeTimeId = ot.Id
    WHERE e.Id = @EmployeeId AND e.IsActive = 1;

    IF @BranchId IS NULL
    BEGIN
        SELECT 0 AS Success, 'Active employee profile not found' AS Message;
        RETURN;
    END

    IF @IsWfhRequest = 1
    BEGIN
        IF @WfhAllowed = 0
        BEGIN
            SELECT 0 AS Success, 'Work From Home is not authorized for your profile' AS Message;
            RETURN;
        END
    END
    ELSE
    BEGIN
        DECLARE @R FLOAT = 6371000;
        DECLARE @dLat FLOAT = RADIANS(@Latitude - @BranchLat);
        DECLARE @dLon FLOAT = RADIANS(@Longitude - @BranchLong);
        DECLARE @a FLOAT = SIN(@dLat / 2) * SIN(@dLat / 2) +
                           COS(RADIANS(@BranchLat)) * COS(RADIANS(@Latitude)) *
                           SIN(@dLon / 2) * SIN(@dLon / 2);
        SET @DistMeters = @R * (2 * ATN2(SQRT(@a), SQRT(1 - @a)));

        IF @DistMeters > @Radius
        BEGIN
            SELECT 0 AS Success, CONCAT('Outside office radius (', ROUND(@DistMeters, 1), 'm)') AS Message;
            RETURN;
        END
    END

    IF EXISTS (SELECT 1 FROM dbo.Attendances WHERE EmployeeId = @EmployeeId AND AttendanceDate = CAST(GETDATE() AS DATE))
    BEGIN
        SELECT 0 AS Success, 'Already checked in for today' AS Message;
        RETURN;
    END

    SET @CurrentTime = CAST(GETDATE() AS TIME);
    IF @CurrentTime > DATEADD(MINUTE, @GraceMinutes, @StartTime)
        SET @Punctuality = 'LATE';

    SET @AttendanceId = NEWID();
    INSERT INTO dbo.Attendances (
        Id, EmployeeId, BranchId, AttendanceDate, InTime, Punctuality, 
        IsWfh, InLatitude, InLongitude, InApprovalStatus
    ) VALUES (
        @AttendanceId, @EmployeeId, @BranchId, CAST(GETDATE() AS DATE), SYSDATETIMEOFFSET(), @Punctuality,
        @IsWfhRequest, @Latitude, @Longitude, 'PENDING'
    );

    SELECT 1 AS Success, 'Check-in submitted successfully for HR approval' AS Message, @AttendanceId AS AttendanceId, @Punctuality AS Punctuality;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AttendanceCheckOut
    @EmployeeId UNIQUEIDENTIFIER,
    @Latitude FLOAT,
    @Longitude FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AttendanceId UNIQUEIDENTIFIER;
    DECLARE @IsWfh BIT, @BranchLat FLOAT, @BranchLong FLOAT, @Radius INT, @DistMeters FLOAT;

    SELECT @AttendanceId = a.Id, @IsWfh = a.IsWfh, @BranchLat = b.Latitude, @BranchLong = b.Longitude, @Radius = b.RadiusMeters
    FROM dbo.Attendances a
    INNER JOIN dbo.Branches b ON a.BranchId = b.Id
    WHERE a.EmployeeId = @EmployeeId AND a.AttendanceDate = CAST(GETDATE() AS DATE);

    IF @AttendanceId IS NULL
    BEGIN
        SELECT 0 AS Success, 'No check-in record found for today' AS Message;
        RETURN;
    END

    IF @IsWfh = 0
    BEGIN
        DECLARE @R FLOAT = 6371000;
        DECLARE @dLat FLOAT = RADIANS(@Latitude - @BranchLat);
        DECLARE @dLon FLOAT = RADIANS(@Longitude - @BranchLong);
        DECLARE @a FLOAT = SIN(@dLat / 2) * SIN(@dLat / 2) +
                           COS(RADIANS(@BranchLat)) * COS(RADIANS(@Latitude)) *
                           SIN(@dLon / 2) * SIN(@dLon / 2);
        SET @DistMeters = @R * (2 * ATN2(SQRT(@a), SQRT(1 - @a)));

        IF @DistMeters > @Radius
        BEGIN
            SELECT 0 AS Success, CONCAT('Outside office radius for checkout (', ROUND(@DistMeters, 1), 'm)') AS Message;
            RETURN;
        END
    END

    UPDATE dbo.Attendances
    SET OutTime = SYSDATETIMEOFFSET(),
        OutLatitude = @Latitude,
        OutLongitude = @Longitude,
        OutApprovalStatus = 'PENDING',
        UpdatedAt = SYSDATETIMEOFFSET()
    WHERE Id = @AttendanceId;

    SELECT 1 AS Success, 'Check-out submitted successfully for HR approval' AS Message, @AttendanceId AS AttendanceId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_PermissionOperations
    @ProcId NVARCHAR(50),
    @Param01 NVARCHAR(150) = NULL,
    @Param02 NVARCHAR(150) = NULL,
    @Param03 NVARCHAR(MAX) = NULL,
    @JsonData NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ProcId = 'GET_ROLES'
    BEGIN
        SELECT RoleKey AS [Key], DisplayName, Description, IsSystem
        FROM dbo.Roles
        ORDER BY CreatedAt ASC
        FOR JSON PATH;
    END
    ELSE IF @ProcId = 'CREATE_ROLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = @Param01)
        BEGIN
            UPDATE dbo.Roles 
            SET DisplayName = @Param02, Description = @Param03 
            WHERE RoleKey = @Param01;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem)
            VALUES (@Param01, @Param02, @Param03, 0);
        END
        SELECT 1 AS Success, 'Role created/updated' AS Message;
    END
    ELSE IF @ProcId = 'SAVE_ROLE_PERMISSIONS'
    BEGIN
        DELETE FROM dbo.RoleMenuPermissions WHERE RoleKey = @Param01;
        
        INSERT INTO dbo.RoleMenuPermissions (RoleKey, MenuKey, CanView, CanEdit, CanDelete, CanApprove)
        SELECT 
            @Param01,
            JSON_VALUE(value, '$.ModuleKey'),
            CAST(JSON_VALUE(value, '$.CanView') AS BIT),
            CAST(JSON_VALUE(value, '$.CanEdit') AS BIT),
            CAST(JSON_VALUE(value, '$.CanDelete') AS BIT),
            CAST(JSON_VALUE(value, '$.CanApprove') AS BIT)
        FROM OPENJSON(@JsonData);

        SELECT 1 AS Success, 'Role permissions saved' AS Message;
    END
END;
GO
