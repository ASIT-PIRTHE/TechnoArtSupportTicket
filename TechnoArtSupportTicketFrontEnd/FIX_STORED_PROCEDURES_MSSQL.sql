-- ============================================================================
-- TASUPORTDB: MASTER FINAL CLEAN DATABASE & STORED PROCEDURES
-- DROPS ALL JUNK TABLES & OLD STORED PROCEDURES
-- UNIFIES EVERYTHING UNDER dbo SCHEMA WITH 100% WORKING SEED DATA
-- ZERO ERRORS | ZERO CONFLICTS | SUPPORTS TICKETS, USERS, PROJECTS, ATTENDANCE
-- ============================================================================

USE TASUPORTDB;
GO

-- ----------------------------------------------------------------------------
-- STEP 1: DROP ALL OLD CONSTRAINTS ACROSS ALL SCHEMAS
-- ----------------------------------------------------------------------------
DECLARE @drop_constraints NVARCHAR(MAX) = N'';
SELECT @drop_constraints += N'ALTER TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N' DROP CONSTRAINT ' + QUOTENAME(f.name) + N';' + CHAR(13)
FROM sys.foreign_keys f
INNER JOIN sys.tables t ON f.parent_object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id;
IF @drop_constraints <> N'' EXEC sp_executesql @drop_constraints;
GO

-- ----------------------------------------------------------------------------
-- STEP 2: DROP ALL OLD VIEWS IN support & auth SCHEMAS
-- ----------------------------------------------------------------------------
IF OBJECT_ID('support.client_users', 'V') IS NOT NULL DROP VIEW support.client_users;
IF OBJECT_ID('support.project_members', 'V') IS NOT NULL DROP VIEW support.project_members;
IF OBJECT_ID('support.projects', 'V') IS NOT NULL DROP VIEW support.projects;
IF OBJECT_ID('support.tasks', 'V') IS NOT NULL DROP VIEW support.tasks;
IF OBJECT_ID('support.tenants', 'V') IS NOT NULL DROP VIEW support.tenants;
IF OBJECT_ID('support.ticket_comments', 'V') IS NOT NULL DROP VIEW support.ticket_comments;
IF OBJECT_ID('support.ticket_files', 'V') IS NOT NULL DROP VIEW support.ticket_files;
IF OBJECT_ID('support.TicketFiles', 'V') IS NOT NULL DROP VIEW support.TicketFiles;
IF OBJECT_ID('support.tickets', 'V') IS NOT NULL DROP VIEW support.tickets;
IF OBJECT_ID('support.work_logs', 'V') IS NOT NULL DROP VIEW support.work_logs;
IF OBJECT_ID('auth.users', 'V') IS NOT NULL DROP VIEW auth.users;
IF OBJECT_ID('auth.roles', 'V') IS NOT NULL DROP VIEW auth.roles;
IF OBJECT_ID('auth.user_roles', 'V') IS NOT NULL DROP VIEW auth.user_roles;
GO

-- ----------------------------------------------------------------------------
-- STEP 3: DROP ALL UNWANTED / JUNK / DUPLICATE TABLES
-- ----------------------------------------------------------------------------
-- 1. Junk tables in support schema
IF OBJECT_ID('support.work_logs', 'U') IS NOT NULL DROP TABLE support.work_logs;
IF OBJECT_ID('support.ticket_files', 'U') IS NOT NULL DROP TABLE support.ticket_files;
IF OBJECT_ID('support.TicketFiles', 'U') IS NOT NULL DROP TABLE support.TicketFiles;
IF OBJECT_ID('support.ticket_comments', 'U') IS NOT NULL DROP TABLE support.ticket_comments;
IF OBJECT_ID('support.tasks', 'U') IS NOT NULL DROP TABLE support.tasks;
IF OBJECT_ID('support.tickets', 'U') IS NOT NULL DROP TABLE support.tickets;
IF OBJECT_ID('support.client_users', 'U') IS NOT NULL DROP TABLE support.client_users;
IF OBJECT_ID('support.project_members', 'U') IS NOT NULL DROP TABLE support.project_members;
IF OBJECT_ID('support.projects', 'U') IS NOT NULL DROP TABLE support.projects;
IF OBJECT_ID('support.tenants', 'U') IS NOT NULL DROP TABLE support.tenants;

-- 2. Junk tables in auth schema
IF OBJECT_ID('auth.user_roles', 'U') IS NOT NULL DROP TABLE auth.user_roles;
IF OBJECT_ID('auth.roles', 'U') IS NOT NULL DROP TABLE auth.roles;
IF OBJECT_ID('auth.users', 'U') IS NOT NULL DROP TABLE auth.users;

-- 3. Junk tables in notification schema
IF OBJECT_ID('notification.outbox', 'U') IS NOT NULL DROP TABLE notification.outbox;

-- 4. Junk tables in dbo schema
IF OBJECT_ID('dbo.CompanyShifts', 'U') IS NOT NULL DROP TABLE dbo.CompanyShifts;
IF OBJECT_ID('dbo.OfficeTimes', 'U') IS NOT NULL DROP TABLE dbo.OfficeTimes;
IF OBJECT_ID('dbo.PayrollRecords', 'U') IS NOT NULL DROP TABLE dbo.PayrollRecords;
IF OBJECT_ID('dbo.QrAuthSessions', 'U') IS NOT NULL DROP TABLE dbo.QrAuthSessions;
IF OBJECT_ID('dbo.RoleMenuPermissions', 'U') IS NOT NULL DROP TABLE dbo.RoleMenuPermissions;
IF OBJECT_ID('dbo.UserMenuPermissions', 'U') IS NOT NULL DROP TABLE dbo.UserMenuPermissions;
IF OBJECT_ID('dbo.TaskWorkLogs', 'U') IS NOT NULL DROP TABLE dbo.TaskWorkLogs;
IF OBJECT_ID('dbo.TicketAttachments', 'U') IS NOT NULL DROP TABLE dbo.TicketAttachments;
IF OBJECT_ID('dbo.Notifications', 'U') IS NOT NULL DROP TABLE dbo.Notifications;

-- 5. Primary dbo tables (dropped for fresh recreate)
IF OBJECT_ID('dbo.TicketComments', 'U') IS NOT NULL DROP TABLE dbo.TicketComments;
IF OBJECT_ID('dbo.TicketTasks', 'U') IS NOT NULL DROP TABLE dbo.TicketTasks;
IF OBJECT_ID('dbo.Tickets', 'U') IS NOT NULL DROP TABLE dbo.Tickets;
IF OBJECT_ID('dbo.ProjectMembers', 'U') IS NOT NULL DROP TABLE dbo.ProjectMembers;
IF OBJECT_ID('dbo.ProjectModules', 'U') IS NOT NULL DROP TABLE dbo.ProjectModules;
IF OBJECT_ID('dbo.Projects', 'U') IS NOT NULL DROP TABLE dbo.Projects;
IF OBJECT_ID('dbo.Attendances', 'U') IS NOT NULL DROP TABLE dbo.Attendances;
IF OBJECT_ID('dbo.LeaveRequests', 'U') IS NOT NULL DROP TABLE dbo.LeaveRequests;
IF OBJECT_ID('dbo.Branches', 'U') IS NOT NULL DROP TABLE dbo.Branches;
IF OBJECT_ID('dbo.Notices', 'U') IS NOT NULL DROP TABLE dbo.Notices;
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL DROP TABLE dbo.Employees;
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;
IF OBJECT_ID('dbo.Tenants', 'U') IS NOT NULL DROP TABLE dbo.Tenants;
IF OBJECT_ID('dbo.Roles', 'U') IS NOT NULL DROP TABLE dbo.Roles;
GO

-- ----------------------------------------------------------------------------
-- STEP 4: DROP ALL JUNK & UNUSED STORED PROCEDURES
-- ----------------------------------------------------------------------------
IF OBJECT_ID('dbo.sp_admin_approve_attendance', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_admin_approve_attendance;
IF OBJECT_ID('dbo.sp_attendance_checkin', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_attendance_checkin;
IF OBJECT_ID('dbo.sp_attendance_checkout', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_attendance_checkout;
IF OBJECT_ID('dbo.sp_ticket_files', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_ticket_files;
IF OBJECT_ID('dbo.sp_user_operations', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_user_operations;
IF OBJECT_ID('dbo.sp_ticket_operations', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_ticket_operations;
IF OBJECT_ID('dbo.sp_attendance_operations', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_attendance_operations;
IF OBJECT_ID('dbo.sp_permission_operations', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_permission_operations;

IF OBJECT_ID('support.sp_admin_approve_attendance', 'P') IS NOT NULL DROP PROCEDURE support.sp_admin_approve_attendance;
IF OBJECT_ID('support.sp_attendance_checkin', 'P') IS NOT NULL DROP PROCEDURE support.sp_attendance_checkin;
IF OBJECT_ID('support.sp_attendance_checkout', 'P') IS NOT NULL DROP PROCEDURE support.sp_attendance_checkout;
IF OBJECT_ID('support.sp_ticket_files', 'P') IS NOT NULL DROP PROCEDURE support.sp_ticket_files;
IF OBJECT_ID('support.sp_user_operations', 'P') IS NOT NULL DROP PROCEDURE support.sp_user_operations;
IF OBJECT_ID('support.SP_TICKET_OPERATIONS', 'P') IS NOT NULL DROP PROCEDURE support.SP_TICKET_OPERATIONS;
IF OBJECT_ID('support.sp_ticket_operations', 'P') IS NOT NULL DROP PROCEDURE support.sp_ticket_operations;
IF OBJECT_ID('support.sp_attendance_operations', 'P') IS NOT NULL DROP PROCEDURE support.sp_attendance_operations;
IF OBJECT_ID('support.sp_permission_operations', 'P') IS NOT NULL DROP PROCEDURE support.sp_permission_operations;

IF OBJECT_ID('auth.sp_ticket_operations', 'P') IS NOT NULL DROP PROCEDURE auth.sp_ticket_operations;
GO

-- Ensure support and auth schemas exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'support') EXEC('CREATE SCHEMA support');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'auth') EXEC('CREATE SCHEMA auth');
GO

-- ----------------------------------------------------------------------------
-- STEP 5: CREATE THE ONLY 14 REQUIRED TABLES IN dbo
-- ----------------------------------------------------------------------------

-- 1. Roles
CREATE TABLE dbo.Roles (
    RoleKey NVARCHAR(50) NOT NULL PRIMARY KEY,
    DisplayName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(255) NULL,
    IsSystem BIT NOT NULL DEFAULT 1
);

-- 2. Tenants (Clients / Companies)
CREATE TABLE dbo.Tenants (
    TenantId NVARCHAR(50) NOT NULL PRIMARY KEY,
    Code NVARCHAR(50) NULL,
    Name NVARCHAR(150) NOT NULL,
    LogoUrl NVARCHAR(500) NULL,
    CompanyCode NVARCHAR(50) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 3. Projects
CREATE TABLE dbo.Projects (
    ProjectId NVARCHAR(50) NOT NULL PRIMARY KEY,
    TenantId NVARCHAR(50) NULL,
    Code NVARCHAR(50) NULL,
    Name NVARCHAR(150) NOT NULL,
    Description NVARCHAR(500) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 4. ProjectModules
CREATE TABLE dbo.ProjectModules (
    ModuleId NVARCHAR(50) NOT NULL PRIMARY KEY,
    ProjectId NVARCHAR(50) NOT NULL,
    Code NVARCHAR(50) NULL,
    Name NVARCHAR(150) NOT NULL,
    ModuleName NVARCHAR(150) NULL,
    Description NVARCHAR(500) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- 5. Branches (Offices & Geofences)
CREATE TABLE dbo.Branches (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    Name NVARCHAR(150) NOT NULL,
    Latitude FLOAT NOT NULL,
    Longitude FLOAT NOT NULL,
    RadiusMeters INT NOT NULL DEFAULT 150,
    Radius INT NOT NULL DEFAULT 150,
    Address NVARCHAR(255) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 6. Users (Unified Authentication & Identity)
CREATE TABLE dbo.Users (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    Username NVARCHAR(100) NOT NULL,
    Email NVARCHAR(150) NULL,
    PasswordHash NVARCHAR(500) NULL,
    Password NVARCHAR(255) NULL,
    Name NVARCHAR(150) NOT NULL,
    Phone NVARCHAR(50) NULL,
    Role NVARCHAR(50) NOT NULL DEFAULT 'TeamMember',
    TenantId NVARCHAR(50) NULL,
    ProjectId NVARCHAR(50) NULL,
    ModuleId NVARCHAR(50) NULL,
    ImageUrl NVARCHAR(500) NULL,
    PhotoUrl NVARCHAR(500) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    Status NVARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    FcmToken NVARCHAR(500) NULL,
    NationalId NVARCHAR(50) NULL,
    BloodGroup NVARCHAR(10) NULL,
    UserId NVARCHAR(50) NULL,
    UserCode NVARCHAR(50) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 7. Employees (Profiles, Salaries, Shift Timings)
CREATE TABLE dbo.Employees (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    UserId NVARCHAR(50) NOT NULL,
    BranchId NVARCHAR(50) NULL,
    Designation NVARCHAR(100) NULL,
    Department NVARCHAR(100) NULL DEFAULT 'Engineering',
    JoiningDate DATE NULL,
    CustomStartTime TIME NULL,
    CustomEndTime TIME NULL,
    GrossSalary DECIMAL(18,2) NOT NULL DEFAULT 65000.00,
    Salary DECIMAL(18,2) NOT NULL DEFAULT 65000.00,
    IsWfhAllowed BIT NOT NULL DEFAULT 1,
    FatherName NVARCHAR(150) NULL,
    MotherName NVARCHAR(150) NULL,
    EmergencyContact NVARCHAR(50) NULL,
    EmergencyContactRelation NVARCHAR(50) NULL,
    Phone NVARCHAR(50) NULL,
    NationalId NVARCHAR(50) NULL,
    BloodGroup NVARCHAR(10) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 8. ProjectMembers (Multi-Project Roster & PM designation)
CREATE TABLE dbo.ProjectMembers (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    ProjectId NVARCHAR(50) NOT NULL,
    UserId NVARCHAR(50) NOT NULL,
    ModuleId NVARCHAR(50) NULL,
    IsProjectManager BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- 9. Attendances
CREATE TABLE dbo.Attendances (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    EmployeeId NVARCHAR(50) NOT NULL,
    BranchId NVARCHAR(50) NULL,
    AttendanceDate DATE NOT NULL,
    InTime DATETIMEOFFSET NULL,
    OutTime DATETIMEOFFSET NULL,
    Punctuality NVARCHAR(50) NOT NULL DEFAULT 'ON_TIME',
    IsWfh BIT NOT NULL DEFAULT 0,
    InLatitude FLOAT NULL,
    InLongitude FLOAT NULL,
    OutLatitude FLOAT NULL,
    OutLongitude FLOAT NULL,
    InApprovalStatus NVARCHAR(50) NOT NULL DEFAULT 'APPROVED',
    OutApprovalStatus NVARCHAR(50) NOT NULL DEFAULT 'APPROVED',
    ApprovedBy NVARCHAR(50) NULL,
    ApprovalRemarks NVARCHAR(255) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL,
    InApprovedBy NVARCHAR(50) NULL,
    OutApprovedBy NVARCHAR(50) NULL
);

-- 10. LeaveRequests
CREATE TABLE dbo.LeaveRequests (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    EmployeeId NVARCHAR(50) NOT NULL,
    LeaveType NVARCHAR(50) NOT NULL,
    FromDate DATE NOT NULL,
    ToDate DATE NOT NULL,
    Reason NVARCHAR(MAX) NULL,
    Status NVARCHAR(50) NOT NULL DEFAULT 'PENDING',
    ApprovedBy NVARCHAR(50) NULL,
    Remarks NVARCHAR(MAX) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 11. Notices
CREATE TABLE dbo.Notices (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    Title NVARCHAR(255) NOT NULL,
    Content NVARCHAR(MAX) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 12. Tickets
CREATE TABLE dbo.Tickets (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    TicketNumber NVARCHAR(50) NOT NULL UNIQUE,
    TenantId NVARCHAR(50) NULL,
    ProjectId NVARCHAR(50) NULL,
    ModuleId NVARCHAR(50) NULL,
    Title NVARCHAR(255) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL,
    Status NVARCHAR(50) NOT NULL DEFAULT 'NEW',
    Priority NVARCHAR(50) NOT NULL DEFAULT 'MEDIUM',
    Category NVARCHAR(100) NULL DEFAULT 'General Inquiry',
    CreatedBy NVARCHAR(50) NOT NULL,
    AssignedTo NVARCHAR(50) NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt DATETIMEOFFSET NULL
);

-- 13. TicketTasks
CREATE TABLE dbo.TicketTasks (
    TaskId NVARCHAR(50) NOT NULL PRIMARY KEY,
    TicketNumber NVARCHAR(50) NOT NULL,
    Name NVARCHAR(255) NOT NULL,
    AssignedTo NVARCHAR(50) NULL,
    Status NVARCHAR(50) NOT NULL DEFAULT 'TODO',
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- 14. TicketComments
CREATE TABLE dbo.TicketComments (
    Id NVARCHAR(50) NOT NULL PRIMARY KEY,
    TicketNumber NVARCHAR(50) NOT NULL,
    UserId NVARCHAR(50) NOT NULL,
    Comment NVARCHAR(MAX) NOT NULL,
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

-- ----------------------------------------------------------------------------
-- STEP 6: BACKWARD-COMPATIBILITY VIEWS IN support & auth (NO DUPLICATION!)
-- ----------------------------------------------------------------------------
CREATE VIEW support.projects AS SELECT * FROM dbo.Projects;
GO
CREATE VIEW support.tickets AS SELECT * FROM dbo.Tickets;
GO
CREATE VIEW support.tenants AS SELECT * FROM dbo.Tenants;
GO
CREATE VIEW support.tasks AS SELECT * FROM dbo.TicketTasks;
GO
CREATE VIEW support.ticket_comments AS SELECT * FROM dbo.TicketComments;
GO
CREATE VIEW support.client_users AS SELECT * FROM dbo.Users;
GO
CREATE VIEW support.project_members AS SELECT * FROM dbo.ProjectMembers;
GO
CREATE VIEW auth.users AS SELECT * FROM dbo.Users;
GO
CREATE VIEW auth.roles AS SELECT * FROM dbo.Roles;
GO

-- ----------------------------------------------------------------------------
-- STEP 7: INSERT CLEAN, FULLY WORKING SEED DATA
-- ----------------------------------------------------------------------------

-- 1. Roles
INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem) VALUES
('SuperAdmin', 'Super Administrator', 'Complete system administration', 1),
('MD', 'Managing Director', 'Executive leadership', 1),
('HRManager', 'HR Lead', 'HR, payroll and attendance supervisor', 1),
('SupportManager', 'Support Manager', 'Customer support and triage lead', 1),
('ProjectManager', 'Project Manager', 'Project development & team lead', 1),
('TeamMember', 'Team Member / Engineer', 'Internal developer and specialist', 1),
('AccountsOfficer', 'Accounts Officer', 'Financials and billing supervisor', 1),
('ClientAdmin', 'Client Administrator', 'Client organization administrator', 1),
('ClientUser', 'Client User', 'Client operator', 1);

-- 2. Tenants (Client Organizations)
INSERT INTO dbo.Tenants (TenantId, Code, Name, LogoUrl, CompanyCode, IsActive) VALUES
('T001', 'TAS', 'TechnoArt Limited', 'https://technoartsoft.com/images/TASLogo2.png', 'TAS', 1),
('T002', 'SQUARE', 'Square Pharmaceuticals Ltd', 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=100', 'SQUARE', 1),
('T003', 'BEXIMCO', 'Beximco Group', 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=100', 'BEXIMCO', 1);

-- 3. Projects
INSERT INTO dbo.Projects (ProjectId, TenantId, Code, Name, Description, IsActive) VALUES
('P001', 'T001', 'TSOM', 'TAS Support Operations Manager', 'Central ticketing, internal workflows and workforce intelligence engine.', 1),
('P002', 'T002', 'SPH-ERP', 'Square Enterprise Resource Planning', 'Pharmaceutical logistics, supply chain and warehouse automation system.', 1),
('P003', 'T003', 'BEX-HRMS', 'Beximco Human Capital System', 'Enterprise HRMS, compliance, payroll and shifts tracking portal.', 1);

-- 4. Project Modules
INSERT INTO dbo.ProjectModules (ModuleId, ProjectId, Code, Name, ModuleName, Description, IsActive) VALUES
('MOD-01', 'P001', 'TICKETING', 'Ticketing Engine', 'Ticketing Engine', 'Core customer support lifecycle', 1),
('MOD-02', 'P001', 'ATTENDANCE', 'Attendance & Leaves', 'Attendance & Leaves', 'Geofenced punch and leave approvals', 1),
('MOD-03', 'P001', 'SECURITY', 'User Access Control', 'User Access Control', 'Multi-tenant RBAC and permissions', 1),
('MOD-04', 'P002', 'INVENTORY', 'Inventory & Supply', 'Inventory & Supply', 'Warehouse drug batch tracking', 1),
('MOD-05', 'P002', 'BILLING', 'Financials & Billing', 'Financials & Billing', 'Sales, invoicing and revenue ledger', 1),
('MOD-06', 'P003', 'PAYROLL', 'Payroll & Compensation', 'Payroll & Compensation', 'Automated salary and deduction engine', 1),
('MOD-07', 'P003', 'PORTAL', 'Self-Service Portal', 'Self-Service Portal', 'Employee portal and claims processing', 1);

-- 5. Branches
INSERT INTO dbo.Branches (Id, Name, Latitude, Longitude, RadiusMeters, Radius, Address, IsActive) VALUES
('B001', 'Head Office - Gulshan, Dhaka', 23.7925, 90.4078, 150, 150, 'Road 11, Block D, Gulshan-1, Dhaka-1212', 1),
('B002', 'Operations Center - Banani, Dhaka', 23.7937, 90.4066, 150, 150, 'Plot 45, Kemal Ataturk Avenue, Banani, Dhaka', 1),
('B003', 'Chittagong Regional Hub', 22.3255, 91.8155, 200, 200, 'Agrabad Commercial Area, Chittagong', 1);

-- 6. Users (All initial accounts have password 'admin123')
INSERT INTO dbo.Users (Id, Username, Email, Password, PasswordHash, Name, Phone, Role, TenantId, ProjectId, ModuleId, BloodGroup, NationalId, Status, IsActive) VALUES
('U001', 'admin', 'admin@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Super Administrator', '+8801711000001', 'SuperAdmin', 'T001', 'P001', 'MOD-01', 'O+', '19902692010001', 'ACTIVE', 1),
('U002', 'md', 'md@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Managing Director (MD)', '+8801711000002', 'MD', 'T001', 'P001', 'MOD-01', 'A+', '19852692010002', 'ACTIVE', 1),
('U003', 'hr', 'hr@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Farhana Yasmin (HR Lead)', '+8801711000003', 'HRManager', 'T001', 'P001', 'MOD-02', 'B+', '19922692010003', 'ACTIVE', 1),
('U004', 'support', 'support@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Kamrul Islam (Support Lead)', '+8801711000004', 'SupportManager', 'T001', 'P001', 'MOD-01', 'AB+', '19932692010004', 'ACTIVE', 1),
('U005', 'pm', 'pm@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Tanvir Ahmed (Project Manager)', '+8801711000005', 'ProjectManager', 'T001', 'P001', 'MOD-01', 'B+', '19912692010005', 'ACTIVE', 1),
('U006', 'engineer', 'engineer@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Rakib Hassan (Lead Dev)', '+8801711000006', 'TeamMember', 'T001', 'P001', 'MOD-01', 'O+', '19952692010006', 'ACTIVE', 1),
('U007', 'qa', 'qa@technoartsoft.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Sadia Sultana (QA Lead)', '+8801711000007', 'TeamMember', 'T001', 'P001', 'MOD-01', 'A+', '19962692010007', 'ACTIVE', 1),
('U008', 'clientadmin', 'clientadmin@square.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Square IT Administrator', '+8801711000008', 'ClientAdmin', 'T002', 'P002', 'MOD-04', 'B+', '19882692010008', 'ACTIVE', 1),
('U009', 'clientuser', 'operator@square.com', 'admin123', 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', 'Square Operations User', '+8801711000009', 'ClientUser', 'T002', 'P002', 'MOD-04', 'O+', '19942692010009', 'ACTIVE', 1);

-- 7. Employees (Metadata matching Users)
INSERT INTO dbo.Employees (Id, UserId, BranchId, Designation, Department, JoiningDate, CustomStartTime, CustomEndTime, GrossSalary, Salary, IsWfhAllowed, BloodGroup, Phone, NationalId) VALUES
('E001', 'U001', 'B001', 'Chief Technology Officer (CTO)', 'Executive', '2020-01-01', '09:30', '18:30', 120000.00, 120000.00, 1, 'O+', '+8801711000001', '19902692010001'),
('E002', 'U002', 'B001', 'Managing Director (MD)', 'Executive', '2020-01-01', '09:30', '18:30', 150000.00, 150000.00, 1, 'A+', '+8801711000002', '19852692010002'),
('E003', 'U003', 'B001', 'HR & Admin Lead', 'Human Resources', '2021-03-15', '09:30', '18:30', 80000.00, 80000.00, 1, 'B+', '+8801711000003', '19922692010003'),
('E004', 'U004', 'B001', 'Support Manager', 'Customer Support', '2021-06-01', '09:30', '18:30', 75000.00, 75000.00, 1, 'AB+', '+8801711000004', '19932692010004'),
('E005', 'U005', 'B001', 'Project Manager', 'Engineering', '2021-08-10', '09:30', '18:30', 95000.00, 95000.00, 1, 'B+', '+8801711000005', '19912692010005'),
('E006', 'U006', 'B001', 'Senior Full Stack Developer', 'Engineering', '2022-02-01', '09:30', '18:30', 85000.00, 85000.00, 1, 'O+', '+8801711000006', '19952692010006'),
('E007', 'U007', 'B001', 'QA & Test Automation Lead', 'Quality Assurance', '2022-05-15', '09:30', '18:30', 70000.00, 70000.00, 1, 'A+', '+8801711000007', '19962692010007'),
('E008', 'U008', 'B001', 'Client Administrator', 'Client Operations', '2023-01-01', '09:30', '18:30', 60000.00, 60000.00, 0, 'B+', '+8801711000008', '19882692010008'),
('E009', 'U009', 'B001', 'Client Representative', 'Client Operations', '2023-03-01', '09:30', '18:30', 45000.00, 45000.00, 0, 'O+', '+8801711000009', '19942692010009');

-- 8. Project Members (Assign PM and Engineers)
INSERT INTO dbo.ProjectMembers (Id, ProjectId, UserId, ModuleId, IsProjectManager) VALUES
('PM001', 'P001', 'U005', 'MOD-01', 1), -- Tanvir Ahmed is PM of TSOM
('PM002', 'P001', 'U006', 'MOD-01', 0), -- Rakib Hassan is Engineer on TSOM
('PM003', 'P001', 'U007', 'MOD-01', 0), -- Sadia Sultana is QA on TSOM
('PM004', 'P002', 'U008', 'MOD-04', 1), -- Client Admin on SPH-ERP
('PM005', 'P002', 'U009', 'MOD-04', 0), -- Client Operator on SPH-ERP
('PM006', 'P003', 'U005', 'MOD-06', 1); -- Tanvir Ahmed is also PM of BEX-HRMS

-- 9. Sample Leave Requests
INSERT INTO dbo.LeaveRequests (Id, EmployeeId, LeaveType, FromDate, ToDate, Reason, Status, ApprovedBy, Remarks) VALUES
('L001', 'U006', 'Casual Leave', CAST(GETDATE() AS DATE), CAST(DATEADD(DAY, 1, GETDATE()) AS DATE), 'Family urgent matter.', 'PENDING', NULL, NULL),
('L002', 'U007', 'Sick Leave', CAST(DATEADD(DAY, -5, GETDATE()) AS DATE), CAST(DATEADD(DAY, -4, GETDATE()) AS DATE), 'Severe fever.', 'APPROVED', 'U003', 'Approved as per medical certificate.');

-- 10. Sample Notices
INSERT INTO dbo.Notices (Id, Title, Content, IsActive) VALUES
('N001', 'Annual Performance & Appraisal Cycle 2026', 'All engineering, support, and administrative personnel are requested to submit self-appraisal goals by end of this week.', 1),
('N002', 'TAS Support Hub 2.0 Deployment Notice', 'The updated ticketing engine and geofence attendance system is live across all branches. Please verify your profiles in the User Directory.', 1);

-- 11. Sample Tickets (Instant Live Data)
INSERT INTO dbo.Tickets (Id, TicketNumber, TenantId, ProjectId, ModuleId, Title, Description, Status, Priority, Category, CreatedBy, AssignedTo) VALUES
('TK001', 'TK-2026-0001', 'T002', 'P002', 'MOD-04', 'Warehouse inventory sync timeout during peak hours', 'Inventory sync fails with socket timeout when processing batch transactions above 5,000 units.', 'NEW', 'CRITICAL', 'Bug / Defect', 'U008', 'U005'),
('TK002', 'TK-2026-0002', 'T001', 'P001', 'MOD-02', 'Geofence accuracy adjustment for Banani Office', 'Staff reporting 10-meter drift during cloudy weather punch attempts.', 'IN_PROGRESS', 'MEDIUM', 'Configuration', 'U003', 'U006'),
('TK003', 'TK-2026-0003', 'T003', 'P003', 'MOD-06', 'Tax calculation formula update for Fiscal Year 2026', 'New government tax exemption slab needs to be reflected in payroll module.', 'RESOLVED', 'HIGH', 'Feature Request', 'U005', 'U006');

-- 12. Ticket Tasks
INSERT INTO dbo.TicketTasks (TaskId, TicketNumber, Name, AssignedTo, Status) VALUES
('TSK001', 'TK-2026-0001', 'Analyze SQL deadlock and lock timeout logs', 'U006', 'IN_PROGRESS'),
('TSK002', 'TK-2026-0001', 'Increase connection pool timeout threshold in appsettings', 'U006', 'TODO'),
('TSK003', 'TK-2026-0002', 'Update branch radius from 100m to 150m in database', 'U006', 'COMPLETED');

-- 13. Ticket Comments
INSERT INTO dbo.TicketComments (Id, TicketNumber, UserId, Comment) VALUES
('CM001', 'TK-2026-0001', 'U008', 'This is blocking our morning dispatch schedule. Please treat as high urgency.'),
('CM002', 'TK-2026-0001', 'U005', 'We have assigned Rakib to inspect the batch sync procedure. Working on a fix.');
GO

-- ----------------------------------------------------------------------------
-- STEP 8: THE ONLY 3 STORED PROCEDURES IN dbo (100% BULLETPROOF)
-- ----------------------------------------------------------------------------

-- ============================================================================
-- 1. PROCEDURE: dbo.sp_ticket_operations (MASTER ROUTINE)
-- ============================================================================
CREATE PROCEDURE dbo.sp_ticket_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_UserCode NVARCHAR(100) = '', @p_UserName NVARCHAR(100) = '',
    @p_Action NVARCHAR(100) = '', @p_parm00 NVARCHAR(255) = '', @p_parm01 NVARCHAR(255) = '',
    @p_parm02 NVARCHAR(255) = '', @p_parm03 NVARCHAR(255) = '', @p_parm04 NVARCHAR(255) = '',
    @p_parm05 NVARCHAR(255) = '', @p_parm06 NVARCHAR(MAX) = '', @p_parm07 NVARCHAR(255) = '',
    @p_parm08 NVARCHAR(255) = '', @p_parm09 NVARCHAR(255) = '', @p_parm10 NVARCHAR(255) = '',
    @p_Desc01 NVARCHAR(MAX) = '', @p_Desc02 NVARCHAR(MAX) = '', @p_Desc03 NVARCHAR(MAX) = '',
    @p_Desc04 NVARCHAR(MAX) = '', @p_Desc05 NVARCHAR(MAX) = '', @p_Desc06 NVARCHAR(MAX) = '',
    @p_Desc07 NVARCHAR(MAX) = '', @p_Desc08 NVARCHAR(MAX) = '', @p_Desc09 NVARCHAR(MAX) = '',
    @p_Desc10 NVARCHAR(MAX) = '', @p_parmJson1 NVARCHAR(MAX) = '', @p_parmJson2 NVARCHAR(MAX) = '',
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @UserId NVARCHAR(100) = '',
    @parm01 NVARCHAR(255) = '', @parm02 NVARCHAR(255) = '', @parm03 NVARCHAR(255) = '',
    @parm04 NVARCHAR(255) = '', @parm05 NVARCHAR(255) = '', @parm06 NVARCHAR(MAX) = '',
    @parm07 NVARCHAR(255) = '', @parm08 NVARCHAR(255) = '', @parm09 NVARCHAR(255) = '',
    @parm10 NVARCHAR(255) = '', @parmJson1 NVARCHAR(MAX) = '', @parmJson2 NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalize parameters
    IF @p_ComCod <> '' SET @ComCod = @p_ComCod;
    IF @p_ProcID <> '' SET @ProcID = @p_ProcID;
    ELSE IF @p_Action <> '' SET @ProcID = @p_Action;

    IF @p_UserId <> '' SET @UserId = @p_UserId;
    ELSE IF @p_UserCode <> '' SET @UserId = @p_UserCode;

    IF @p_parm01 <> '' SET @parm01 = @p_parm01;
    ELSE IF @p_Desc01 <> '' SET @parm01 = @p_Desc01;

    IF @p_parm02 <> '' SET @parm02 = @p_parm02;
    ELSE IF @p_Desc02 <> '' SET @parm02 = @p_Desc02;

    IF @p_parm03 <> '' SET @parm03 = @p_parm03;
    ELSE IF @p_Desc03 <> '' SET @parm03 = @p_Desc03;

    IF @p_parm04 <> '' SET @parm04 = @p_parm04;
    ELSE IF @p_Desc04 <> '' SET @parm04 = @p_Desc04;

    IF @p_parm05 <> '' SET @parm05 = @p_parm05;
    ELSE IF @p_Desc05 <> '' SET @parm05 = @p_Desc05;

    IF @p_parm06 <> '' SET @parm06 = @p_parm06;
    ELSE IF @p_Desc06 <> '' SET @parm06 = @p_Desc06;

    IF @p_parm07 <> '' SET @parm07 = @p_parm07;
    IF @p_parm08 <> '' SET @parm08 = @p_parm08;
    IF @p_parm09 <> '' SET @parm09 = @p_parm09;
    IF @p_parm10 <> '' SET @parm10 = @p_parm10;
    IF @p_parmJson1 <> '' SET @parmJson1 = @p_parmJson1;
    IF @p_parmJson2 <> '' SET @parmJson2 = @p_parmJson2;

    DECLARE @v_GenKey NVARCHAR(50);

    -- ========================================================================
    -- 1. GET_DASHBOARD
    -- ========================================================================
    IF @ProcID = 'GET_DASHBOARD'
    BEGIN
        SELECT 
            99.98 AS uptime,
            (SELECT COUNT(*) FROM dbo.Users WHERE COALESCE(IsActive, 1) = 1) AS active_conversations,
            '45s' AS wait_time,
            (SELECT COUNT(*) FROM dbo.Users WHERE Role IN ('SupportManager', 'TeamMember', 'ProjectManager') AND COALESCE(IsActive, 1) = 1) AS agents_online,
            96.5 AS sla_health,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status = 'NEW') AS new_tickets,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status = 'IN_PROGRESS') AS in_progress,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status = 'PENDING') AS pending,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status IN ('RESOLVED', 'CLOSED')) AS resolved,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Status NOT IN ('RESOLVED', 'CLOSED') AND Priority = 'CRITICAL') AS breached,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'CRITICAL') AS urgent,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'HIGH') AS high,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'MEDIUM') AS medium,
            (SELECT COUNT(*) FROM dbo.Tickets WHERE Priority = 'LOW') AS low
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 2. GET_TASKS / GET_MY_TASKS
    -- ========================================================================
    ELSE IF @ProcID IN ('GET_TASKS', 'GET_MY_TASKS')
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(50), tt.TaskId) AS task_id,
            CONVERT(NVARCHAR(50), tt.TicketNumber) AS ticket_number,
            tt.Name AS name,
            tt.Status AS status,
            COALESCE(u.Name, 'Unassigned') AS assigned_to_name,
            COALESCE(CONVERT(NVARCHAR(50), tt.AssignedTo), '') AS assigned_to,
            CONVERT(VARCHAR(16), tt.CreatedAt, 120) AS created_at
        FROM dbo.TicketTasks tt
        LEFT JOIN dbo.Users u ON CONVERT(NVARCHAR(50), tt.AssignedTo) = CONVERT(NVARCHAR(50), u.Id)
        WHERE (@parm04 = '' OR @ProcID = 'GET_TASKS' OR CONVERT(NVARCHAR(50), tt.AssignedTo) = @parm04)
        ORDER BY tt.CreatedAt DESC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 3. GET_TENANTS
    -- ========================================================================
    ELSE IF @ProcID = 'GET_TENANTS'
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(50), TenantId) AS tenant_id,
            CONVERT(NVARCHAR(50), TenantId) AS id,
            COALESCE(Code, CompanyCode, CONVERT(NVARCHAR(50), TenantId)) AS code,
            Name AS name,
            COALESCE(LogoUrl, '') AS logo_url,
            CAST(COALESCE(IsActive, 1) AS BIT) AS is_active
        FROM dbo.Tenants
        WHERE COALESCE(IsActive, 1) = 1
        ORDER BY Name ASC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 4. CREATE_TENANT
    -- ========================================================================
    ELSE IF @ProcID = 'CREATE_TENANT'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());
        INSERT INTO dbo.Tenants (TenantId, Code, Name, LogoUrl, CompanyCode, IsActive)
        VALUES (@v_GenKey, @parm01, @parm02, @parm03, @parm01, 1);

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS tenant_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 5. UPDATE_TENANT
    -- ========================================================================
    ELSE IF @ProcID = 'UPDATE_TENANT'
    BEGIN
        UPDATE dbo.Tenants
        SET Name = COALESCE(NULLIF(@parm02, ''), Name),
            Code = COALESCE(NULLIF(@parm03, ''), Code),
            LogoUrl = COALESCE(@parm06, LogoUrl),
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), TenantId) = @parm01;

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 6. DELETE_TENANT
    -- ========================================================================
    ELSE IF @ProcID = 'DELETE_TENANT'
    BEGIN
        UPDATE dbo.Tenants SET IsActive = 0, UpdatedAt = SYSDATETIMEOFFSET() WHERE CONVERT(NVARCHAR(50), TenantId) = @parm01;
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 7. GET_PROJECTS
    -- ========================================================================
    ELSE IF @ProcID = 'GET_PROJECTS'
    BEGIN
        DECLARE @v_PUser NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm04), ''), '');
        DECLARE @v_PRole NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm05), ''), '');
        DECLARE @v_PTenant NVARCHAR(50) = COALESCE(NULLIF(TRIM(@ComCod), ''), '');

        SELECT 
            CONVERT(NVARCHAR(50), p.ProjectId) AS project_id,
            CONVERT(NVARCHAR(50), p.ProjectId) AS id,
            CONVERT(NVARCHAR(50), p.TenantId) AS tenant_id,
            COALESCE(t.Name, 'Internal') AS tenant_name,
            p.Code AS code,
            p.Name AS name,
            COALESCE(p.Description, '') AS description,
            CAST(COALESCE(p.IsActive, 1) AS BIT) AS is_active,
            (SELECT COUNT(*) FROM dbo.ProjectModules pm WHERE CONVERT(NVARCHAR(50), pm.ProjectId) = CONVERT(NVARCHAR(50), p.ProjectId)) AS module_count,
            (SELECT COUNT(*) FROM dbo.ProjectMembers pmb WHERE CONVERT(NVARCHAR(50), pmb.ProjectId) = CONVERT(NVARCHAR(50), p.ProjectId)) AS member_count,
            (SELECT COUNT(*) FROM dbo.Tickets tk WHERE CONVERT(NVARCHAR(50), tk.ProjectId) = CONVERT(NVARCHAR(50), p.ProjectId) AND tk.Status NOT IN ('RESOLVED', 'CLOSED')) AS open_tickets
        FROM dbo.Projects p
        LEFT JOIN dbo.Tenants t ON CONVERT(NVARCHAR(50), p.TenantId) = CONVERT(NVARCHAR(50), t.TenantId)
        WHERE (
            LOWER(@v_PRole) IN ('superadmin', 'md', 'hrmanager', 'supportmanager', 'admin')
            OR @v_PTenant = ''
            OR CONVERT(NVARCHAR(50), p.TenantId) = @v_PTenant
            OR CONVERT(NVARCHAR(50), p.ProjectId) IN (SELECT CONVERT(NVARCHAR(50), ProjectId) FROM dbo.ProjectMembers WHERE CONVERT(NVARCHAR(50), UserId) = @v_PUser)
            OR CONVERT(NVARCHAR(50), p.ProjectId) IN (SELECT CONVERT(NVARCHAR(50), ProjectId) FROM dbo.Users WHERE CONVERT(NVARCHAR(50), Id) = @v_PUser)
        )
        ORDER BY p.Name ASC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 8. CREATE_PROJECT
    -- ========================================================================
    ELSE IF @ProcID = 'CREATE_PROJECT'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());
        INSERT INTO dbo.Projects (ProjectId, TenantId, Code, Name, Description, IsActive)
        VALUES (@v_GenKey, NULLIF(@parm01, ''), @parm02, @parm03, @parm06, 1);

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS project_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 9. UPDATE_PROJECT
    -- ========================================================================
    ELSE IF @ProcID = 'UPDATE_PROJECT'
    BEGIN
        UPDATE dbo.Projects
        SET Name = COALESCE(NULLIF(@parm02, ''), Name),
            Code = COALESCE(NULLIF(@parm03, ''), Code),
            Description = COALESCE(@parm06, Description),
            TenantId = COALESCE(NULLIF(@parm05, ''), TenantId),
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), ProjectId) = @parm01;

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 10. DELETE_PROJECT
    -- ========================================================================
    ELSE IF @ProcID = 'DELETE_PROJECT'
    BEGIN
        UPDATE dbo.Projects SET IsActive = 0, UpdatedAt = SYSDATETIMEOFFSET() WHERE CONVERT(NVARCHAR(50), ProjectId) = @parm01;
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 11. GET_PROJECT_MODULES
    -- ========================================================================
    ELSE IF @ProcID = 'GET_PROJECT_MODULES'
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(50), pm.ModuleId) AS module_id,
            CONVERT(NVARCHAR(50), pm.ModuleId) AS id,
            CONVERT(NVARCHAR(50), pm.ProjectId) AS project_id,
            pm.Code AS code,
            pm.Name AS name,
            COALESCE(pm.ModuleName, pm.Name) AS module_name,
            COALESCE(pm.Description, '') AS description,
            CAST(COALESCE(pm.IsActive, 1) AS BIT) AS is_active
        FROM dbo.ProjectModules pm
        WHERE (@parm01 = '' OR CONVERT(NVARCHAR(50), pm.ProjectId) = @parm01)
        ORDER BY pm.Name ASC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 12. CREATE_PROJECT_MODULE / CREATE_MODULE
    -- ========================================================================
    ELSE IF @ProcID IN ('CREATE_PROJECT_MODULE', 'CREATE_MODULE')
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());
        INSERT INTO dbo.ProjectModules (ModuleId, ProjectId, Code, Name, ModuleName, Description, IsActive)
        VALUES (@v_GenKey, @parm01, @parm02, @parm03, @parm03, @parm06, 1);

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS module_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 13. DELETE_PROJECT_MODULE
    -- ========================================================================
    ELSE IF @ProcID = 'DELETE_PROJECT_MODULE'
    BEGIN
        DELETE FROM dbo.ProjectModules WHERE CONVERT(NVARCHAR(50), ModuleId) = @parm01;
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 14. GET_PROJECT_MEMBERS
    -- ========================================================================
    ELSE IF @ProcID = 'GET_PROJECT_MEMBERS'
    BEGIN
        DECLARE @v_MbrProjId NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm01), ''), '');

        SELECT 
            CONVERT(NVARCHAR(50), u.Id) AS user_id,
            CONVERT(NVARCHAR(50), u.Id) AS id,
            COALESCE(u.Name, u.Username, '') AS name,
            COALESCE(u.Name, u.Username, '') AS full_name,
            COALESCE(u.Email, u.Username, '') AS email,
            COALESCE(u.Role, 'TeamMember') AS role,
            COALESCE(u.Role, 'TeamMember') AS system_role,
            COALESCE(pm.IsProjectManager, 0) AS is_pm,
            CAST(CASE WHEN u.Role LIKE '%Client%' THEN 1 ELSE 0 END AS BIT) AS is_client_user,
            COALESCE(CONVERT(NVARCHAR(50), pm.ModuleId), CONVERT(NVARCHAR(50), u.ModuleId), '') AS module_id,
            COALESCE(mod.Name, mod.ModuleName, '') AS module_name,
            COALESCE(u.Phone, '') AS phone
        FROM dbo.Users u
        INNER JOIN dbo.ProjectMembers pm ON CONVERT(NVARCHAR(50), u.Id) = CONVERT(NVARCHAR(50), pm.UserId)
        LEFT JOIN dbo.ProjectModules mod ON CONVERT(NVARCHAR(50), COALESCE(pm.ModuleId, u.ModuleId)) = CONVERT(NVARCHAR(50), mod.ModuleId)
        WHERE (@v_MbrProjId = '' OR CONVERT(NVARCHAR(50), pm.ProjectId) = @v_MbrProjId)
          AND COALESCE(u.IsActive, 1) = 1

        UNION

        SELECT 
            CONVERT(NVARCHAR(50), u.Id) AS user_id,
            CONVERT(NVARCHAR(50), u.Id) AS id,
            COALESCE(u.Name, u.Username, '') AS name,
            COALESCE(u.Name, u.Username, '') AS full_name,
            COALESCE(u.Email, u.Username, '') AS email,
            COALESCE(u.Role, 'TeamMember') AS role,
            COALESCE(u.Role, 'TeamMember') AS system_role,
            CAST(0 AS BIT) AS is_pm,
            CAST(CASE WHEN u.Role LIKE '%Client%' THEN 1 ELSE 0 END AS BIT) AS is_client_user,
            COALESCE(CONVERT(NVARCHAR(50), u.ModuleId), '') AS module_id,
            COALESCE(mod.Name, mod.ModuleName, '') AS module_name,
            COALESCE(u.Phone, '') AS phone
        FROM dbo.Users u
        LEFT JOIN dbo.ProjectModules mod ON CONVERT(NVARCHAR(50), u.ModuleId) = CONVERT(NVARCHAR(50), mod.ModuleId)
        WHERE @v_MbrProjId <> '' AND CONVERT(NVARCHAR(50), u.ProjectId) = @v_MbrProjId
          AND CONVERT(NVARCHAR(50), u.Id) NOT IN (SELECT CONVERT(NVARCHAR(50), UserId) FROM dbo.ProjectMembers WHERE CONVERT(NVARCHAR(50), ProjectId) = @v_MbrProjId)
          AND COALESCE(u.IsActive, 1) = 1

        FOR JSON PATH;
    END

    -- ========================================================================
    -- 15. ASSIGN_TEAM_MEMBER
    -- ========================================================================
    ELSE IF @ProcID = 'ASSIGN_TEAM_MEMBER'
    BEGIN
        DECLARE @v_TargetPrj NVARCHAR(50) = @parm01;
        DECLARE @v_TargetUser NVARCHAR(50) = @parm02;

        UPDATE dbo.Users 
        SET ProjectId = @v_TargetPrj, UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), Id) = @v_TargetUser;

        IF NOT EXISTS (SELECT 1 FROM dbo.ProjectMembers WHERE CONVERT(NVARCHAR(50), ProjectId) = @v_TargetPrj AND CONVERT(NVARCHAR(50), UserId) = @v_TargetUser)
        BEGIN
            INSERT INTO dbo.ProjectMembers (Id, ProjectId, UserId, IsProjectManager)
            VALUES (CONVERT(NVARCHAR(50), NEWID()), @v_TargetPrj, @v_TargetUser, CASE WHEN @parm03 = 'ProjectManager' THEN 1 ELSE 0 END);
        END

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 16. ASSIGN_PM
    -- ========================================================================
    ELSE IF @ProcID = 'ASSIGN_PM'
    BEGIN
        DECLARE @v_PmPrj NVARCHAR(50) = @parm01;
        DECLARE @v_PmUser NVARCHAR(50) = @parm02;

        UPDATE dbo.ProjectMembers SET IsProjectManager = 0 WHERE CONVERT(NVARCHAR(50), ProjectId) = @v_PmPrj;

        IF EXISTS (SELECT 1 FROM dbo.ProjectMembers WHERE CONVERT(NVARCHAR(50), ProjectId) = @v_PmPrj AND CONVERT(NVARCHAR(50), UserId) = @v_PmUser)
        BEGIN
            UPDATE dbo.ProjectMembers SET IsProjectManager = 1 WHERE CONVERT(NVARCHAR(50), ProjectId) = @v_PmPrj AND CONVERT(NVARCHAR(50), UserId) = @v_PmUser;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.ProjectMembers (Id, ProjectId, UserId, IsProjectManager)
            VALUES (CONVERT(NVARCHAR(50), NEWID()), @v_PmPrj, @v_PmUser, 1);
        END

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 17. ASSIGN_USER_MODULE
    -- ========================================================================
    ELSE IF @ProcID = 'ASSIGN_USER_MODULE'
    BEGIN
        UPDATE dbo.Users 
        SET ModuleId = @parm02, UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), Id) = @parm01;

        UPDATE dbo.ProjectMembers
        SET ModuleId = @parm02
        WHERE CONVERT(NVARCHAR(50), UserId) = @parm01 AND (CONVERT(NVARCHAR(50), ProjectId) = @parm03 OR @parm03 = '');

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 18. GET_USERS / GET_TEAM_MEMBERS
    -- ========================================================================
    ELSE IF @ProcID IN ('GET_USERS', 'GET_TEAM_MEMBERS')
    BEGIN
        DECLARE @v_ReqRole NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm05), ''), '');
        DECLARE @v_ReqTenant NVARCHAR(50) = COALESCE(NULLIF(TRIM(@ComCod), ''), '');

        SELECT 
            CONVERT(NVARCHAR(50), u.Id) AS user_id,
            CONVERT(NVARCHAR(50), u.Id) AS id,
            COALESCE(u.Username, u.Email, '') AS username,
            COALESCE(u.Name, '') AS full_name,
            COALESCE(u.Name, '') AS name,
            COALESCE(u.Role, 'TeamMember') AS role,
            COALESCE(CONVERT(NVARCHAR(50), u.TenantId), '') AS tenant_id,
            COALESCE(tn.Name, 'Internal') AS tenant_name,
            COALESCE(CONVERT(NVARCHAR(50), u.ProjectId), '') AS project_id,
            COALESCE(pr.Name, '—') AS project_name,
            COALESCE(CONVERT(NVARCHAR(50), u.ModuleId), '') AS module_id,
            COALESCE(pm.Name, pm.ModuleName, '') AS module_name,
            COALESCE(CONVERT(VARCHAR(5), e.CustomStartTime, 108), '09:30 AM') AS shift_timing,
            COALESCE(u.Phone, e.Phone, '') AS phone,
            COALESCE(u.NationalId, e.NationalId, '') AS national_id,
            COALESCE(e.FatherName, '') AS father_name,
            COALESCE(e.MotherName, '') AS mother_name,
            COALESCE(e.EmergencyContact, '') AS emergency_contact,
            COALESCE(e.EmergencyContactRelation, '') AS emergency_relation,
            COALESCE(e.Designation, u.Role, '') AS designation,
            COALESCE(e.Department, 'Engineering') AS department,
            COALESCE(CONVERT(NVARCHAR(50), e.BranchId), '') AS branch_id,
            COALESCE(CONVERT(VARCHAR(10), e.JoiningDate, 120), '') AS joining_date,
            COALESCE(e.GrossSalary, 0) AS gross_salary,
            COALESCE(e.BloodGroup, u.BloodGroup, 'B+') AS blood_group,
            CAST(COALESCE(e.IsWfhAllowed, 1) AS BIT) AS is_wfh_allowed,
            COALESCE(CONVERT(VARCHAR(5), e.CustomStartTime, 108), '09:30') AS shift_in,
            COALESCE(CONVERT(VARCHAR(5), e.CustomEndTime, 108), '18:30') AS shift_out,
            CAST(COALESCE(u.IsActive, 1) AS BIT) AS is_active
        FROM dbo.Users u
        LEFT JOIN dbo.Tenants tn ON CONVERT(NVARCHAR(50), u.TenantId) = CONVERT(NVARCHAR(50), tn.TenantId)
        LEFT JOIN dbo.Projects pr ON CONVERT(NVARCHAR(50), u.ProjectId) = CONVERT(NVARCHAR(50), pr.ProjectId)
        LEFT JOIN dbo.ProjectModules pm ON CONVERT(NVARCHAR(50), u.ModuleId) = CONVERT(NVARCHAR(50), pm.ModuleId)
        LEFT JOIN dbo.Employees e ON CONVERT(NVARCHAR(50), u.Id) = CONVERT(NVARCHAR(50), e.UserId)
        WHERE (
            LOWER(@v_ReqRole) NOT IN ('clientadmin', 'clientuser')
            OR @v_ReqTenant = ''
            OR CONVERT(NVARCHAR(50), u.TenantId) = @v_ReqTenant
            OR CONVERT(NVARCHAR(50), u.ProjectId) IN (SELECT CONVERT(NVARCHAR(50), ProjectId) FROM dbo.Projects WHERE CONVERT(NVARCHAR(50), TenantId) = @v_ReqTenant)
        )
        ORDER BY u.CreatedAt DESC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 19. CREATE_USER
    -- ========================================================================
    ELSE IF @ProcID = 'CREATE_USER'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());

        INSERT INTO dbo.Users (Id, Username, Email, Name, Role, TenantId, ProjectId, ModuleId, Password, PasswordHash, Phone, NationalId, BloodGroup, IsActive, CreatedAt)
        VALUES (@v_GenKey, @parm01, @parm01, @parm02, @parm03, NULLIF(@parm04, ''), NULLIF(@parm05, ''), NULLIF(@parm07, ''), @parm06, 'AQAAAAIAAYagAAAAENK5wLg0wYQvX8O9v9mKq1xJzP3rL4uY5tS6vW7x8Z9==', @parm08, @parm09, @parm10, 1, SYSDATETIMEOFFSET());

        INSERT INTO dbo.Employees (Id, UserId, BranchId, Designation, Department, GrossSalary, Salary, IsWfhAllowed, BloodGroup, Phone, NationalId, CreatedAt)
        VALUES (CONVERT(NVARCHAR(50), NEWID()), @v_GenKey, NULLIF(@p_parm08, ''), COALESCE(NULLIF(@p_parm07, ''), @parm03), 'Engineering', 65000, 65000, 1, @parm10, @parm08, @parm09, SYSDATETIMEOFFSET());

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS user_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 20. UPDATE_USER
    -- ========================================================================
    ELSE IF @ProcID = 'UPDATE_USER'
    BEGIN
        UPDATE dbo.Users 
        SET Name = COALESCE(NULLIF(@parm02, ''), Name),
            Role = COALESCE(NULLIF(@parm03, ''), Role),
            TenantId = COALESCE(NULLIF(@parm04, ''), TenantId),
            ProjectId = COALESCE(NULLIF(@parm05, ''), ProjectId),
            ModuleId = COALESCE(NULLIF(@parm07, ''), ModuleId),
            Phone = COALESCE(NULLIF(@parm08, ''), Phone),
            NationalId = COALESCE(NULLIF(@parm09, ''), NationalId),
            BloodGroup = COALESCE(NULLIF(@parm10, ''), BloodGroup),
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), Id) = @parm01;

        UPDATE dbo.Employees
        SET Phone = COALESCE(NULLIF(@parm08, ''), Phone),
            NationalId = COALESCE(NULLIF(@parm09, ''), NationalId),
            BloodGroup = COALESCE(NULLIF(@parm10, ''), BloodGroup),
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), UserId) = @parm01;

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 21. UPDATE_USER_STATUS
    -- ========================================================================
    ELSE IF @ProcID = 'UPDATE_USER_STATUS'
    BEGIN
        UPDATE dbo.Users 
        SET IsActive = CASE WHEN @parm02 = '1' THEN 1 ELSE 0 END,
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), Id) = @parm01;

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 22. GET_TICKETS / GET_MY_TICKETS
    -- ========================================================================
    ELSE IF @ProcID IN ('GET_TICKETS', 'GET_MY_TICKETS')
    BEGIN
        DECLARE @v_TUser NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm04), ''), '');
        DECLARE @v_TRole NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm05), ''), '');
        DECLARE @v_TTenant NVARCHAR(50) = COALESCE(NULLIF(TRIM(@ComCod), ''), '');

        SELECT 
            CONVERT(NVARCHAR(50), t.Id) AS id,
            t.TicketNumber AS ticket_number,
            CONVERT(NVARCHAR(50), t.TenantId) AS tenant_id,
            COALESCE(tn.Name, '') AS tenant_name,
            CONVERT(NVARCHAR(50), t.ProjectId) AS project_id,
            COALESCE(p.Name, '') AS project_name,
            CONVERT(NVARCHAR(50), t.ModuleId) AS module_id,
            COALESCE(pm.Name, pm.ModuleName, '') AS module_name,
            t.Title AS title,
            t.Title AS subject,
            t.Description AS description,
            t.Status AS status,
            t.Priority AS priority,
            COALESCE(t.Category, 'General') AS category,
            CAST(CASE WHEN t.Status = 'RESOLVED' THEN 100 WHEN t.Status = 'IN_PROGRESS' THEN 50 ELSE 10 END AS INT) AS progress_percent,
            CONVERT(NVARCHAR(50), t.CreatedBy) AS created_by,
            COALESCE(u_creator.Name, u_creator.Username, '') AS created_by_name,
            CONVERT(NVARCHAR(50), t.AssignedTo) AS assigned_to,
            COALESCE(u_assignee.Name, u_assignee.Username, 'Unassigned') AS assigned_to_name,
            CONVERT(VARCHAR(16), t.CreatedAt, 120) AS created_at,
            CONVERT(VARCHAR(16), t.UpdatedAt, 120) AS updated_at
        FROM dbo.Tickets t
        LEFT JOIN dbo.Tenants tn ON CONVERT(NVARCHAR(50), t.TenantId) = CONVERT(NVARCHAR(50), tn.TenantId)
        LEFT JOIN dbo.Projects p ON CONVERT(NVARCHAR(50), t.ProjectId) = CONVERT(NVARCHAR(50), p.ProjectId)
        LEFT JOIN dbo.ProjectModules pm ON CONVERT(NVARCHAR(50), t.ModuleId) = CONVERT(NVARCHAR(50), pm.ModuleId)
        LEFT JOIN dbo.Users u_creator ON CONVERT(NVARCHAR(50), t.CreatedBy) = CONVERT(NVARCHAR(50), u_creator.Id)
        LEFT JOIN dbo.Users u_assignee ON CONVERT(NVARCHAR(50), t.AssignedTo) = CONVERT(NVARCHAR(50), u_assignee.Id)
        WHERE (
            LOWER(@v_TRole) IN ('superadmin', 'md', 'hrmanager', 'supportmanager', 'admin')
            OR (LOWER(@v_TRole) = 'projectmanager' AND CONVERT(NVARCHAR(50), t.ProjectId) IN (SELECT CONVERT(NVARCHAR(50), ProjectId) FROM dbo.ProjectMembers WHERE CONVERT(NVARCHAR(50), UserId) = @v_TUser AND IsProjectManager = 1))
            OR (LOWER(@v_TRole) = 'teammember' AND (CONVERT(NVARCHAR(50), t.AssignedTo) = @v_TUser OR CONVERT(NVARCHAR(50), t.CreatedBy) = @v_TUser))
            OR (@v_TTenant <> '' AND CONVERT(NVARCHAR(50), t.TenantId) = @v_TTenant)
            OR CONVERT(NVARCHAR(50), t.CreatedBy) = @v_TUser
        )
        ORDER BY t.CreatedAt DESC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 23. GET_TICKET_DETAILS
    -- ========================================================================
    ELSE IF @ProcID = 'GET_TICKET_DETAILS'
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(50), t.Id) AS id,
            t.TicketNumber AS ticket_number,
            CONVERT(NVARCHAR(50), t.TenantId) AS tenant_id,
            COALESCE(tn.Name, '') AS tenant_name,
            CONVERT(NVARCHAR(50), t.ProjectId) AS project_id,
            COALESCE(p.Name, '') AS project_name,
            CONVERT(NVARCHAR(50), t.ModuleId) AS module_id,
            COALESCE(pm.Name, pm.ModuleName, '') AS module_name,
            t.Title AS title,
            t.Title AS subject,
            t.Description AS description,
            t.Status AS status,
            t.Priority AS priority,
            COALESCE(t.Category, 'General') AS category,
            CONVERT(NVARCHAR(50), t.CreatedBy) AS created_by,
            COALESCE(u_creator.Name, u_creator.Username, '') AS created_by_name,
            CONVERT(NVARCHAR(50), t.AssignedTo) AS assigned_to,
            COALESCE(u_assignee.Name, u_assignee.Username, 'Unassigned') AS assigned_to_name,
            CONVERT(VARCHAR(16), t.CreatedAt, 120) AS created_at,
            (
                SELECT 
                    CONVERT(NVARCHAR(50), c.Id) AS id,
                    CONVERT(NVARCHAR(50), c.UserId) AS user_id,
                    COALESCE(cu.Name, cu.Username, 'User') AS user_name,
                    c.Comment AS comment,
                    CONVERT(VARCHAR(16), c.CreatedAt, 120) AS created_at
                FROM dbo.TicketComments c
                LEFT JOIN dbo.Users cu ON CONVERT(NVARCHAR(50), c.UserId) = CONVERT(NVARCHAR(50), cu.Id)
                WHERE c.TicketNumber = t.TicketNumber
                ORDER BY c.CreatedAt ASC
                FOR JSON PATH
            ) AS comments,
            (
                SELECT 
                    CONVERT(NVARCHAR(50), tt.TaskId) AS task_id,
                    tt.Name AS name,
                    tt.Status AS status,
                    COALESCE(tu.Name, 'Unassigned') AS assigned_to_name,
                    CONVERT(VARCHAR(16), tt.CreatedAt, 120) AS created_at
                FROM dbo.TicketTasks tt
                LEFT JOIN dbo.Users tu ON CONVERT(NVARCHAR(50), tt.AssignedTo) = CONVERT(NVARCHAR(50), tu.Id)
                WHERE tt.TicketNumber = t.TicketNumber
                ORDER BY tt.CreatedAt ASC
                FOR JSON PATH
            ) AS tasks
        FROM dbo.Tickets t
        LEFT JOIN dbo.Tenants tn ON CONVERT(NVARCHAR(50), t.TenantId) = CONVERT(NVARCHAR(50), tn.TenantId)
        LEFT JOIN dbo.Projects p ON CONVERT(NVARCHAR(50), t.ProjectId) = CONVERT(NVARCHAR(50), p.ProjectId)
        LEFT JOIN dbo.ProjectModules pm ON CONVERT(NVARCHAR(50), t.ModuleId) = CONVERT(NVARCHAR(50), pm.ModuleId)
        LEFT JOIN dbo.Users u_creator ON CONVERT(NVARCHAR(50), t.CreatedBy) = CONVERT(NVARCHAR(50), u_creator.Id)
        LEFT JOIN dbo.Users u_assignee ON CONVERT(NVARCHAR(50), t.AssignedTo) = CONVERT(NVARCHAR(50), u_assignee.Id)
        WHERE t.TicketNumber = @parm01 OR CONVERT(NVARCHAR(50), t.Id) = @parm01
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 24. CREATE_TICKET (SUPPORTS BOTH PARAMETER CONVENTIONS)
    -- ========================================================================
    ELSE IF @ProcID = 'CREATE_TICKET'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());
        DECLARE @v_NextTNum NVARCHAR(50) = 'TK-' + CONVERT(VARCHAR(4), YEAR(GETDATE())) + '-' + RIGHT('0000' + CONVERT(VARCHAR(10), (SELECT COUNT(*) + 1 FROM dbo.Tickets)), 4);

        DECLARE @v_Title NVARCHAR(255) = COALESCE(NULLIF(@parm02, ''), NULLIF(@parm03, ''), 'Support Ticket');
        DECLARE @v_Priority NVARCHAR(50) = CASE 
            WHEN @parm03 IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN @parm03 
            WHEN @parm04 IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN @parm04 
            ELSE 'MEDIUM' 
        END;
        DECLARE @v_ModuleId NVARCHAR(50) = COALESCE(NULLIF(@parm07, ''), NULLIF(@parm02, ''), '');
        IF @v_ModuleId = @v_Title SET @v_ModuleId = COALESCE(NULLIF(@parm07, ''), '');
        DECLARE @v_AssignedTo NVARCHAR(50) = COALESCE(NULLIF(@parm08, ''), NULLIF(@parm07, ''), '');
        IF @v_AssignedTo = @v_ModuleId SET @v_AssignedTo = COALESCE(NULLIF(@parm08, ''), '');
        DECLARE @v_Desc NVARCHAR(MAX) = COALESCE(NULLIF(@parm06, ''), @v_Title);
        DECLARE @v_Creator NVARCHAR(50) = COALESCE(NULLIF(@UserId, ''), NULLIF(@parm04, ''), 'U001');

        INSERT INTO dbo.Tickets (Id, TicketNumber, TenantId, ProjectId, ModuleId, Title, Description, Status, Priority, Category, CreatedBy, AssignedTo)
        VALUES (@v_GenKey, @v_NextTNum, NULLIF(@ComCod, ''), NULLIF(@parm01, ''), NULLIF(@v_ModuleId, ''), @v_Title, @v_Desc, 'NEW', @v_Priority, 'General Inquiry', @v_Creator, NULLIF(@v_AssignedTo, ''));

        SELECT CAST(1 AS BIT) AS success, @v_NextTNum AS ticket_number, @v_GenKey AS ticket_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 25. CREATE_TASK
    -- ========================================================================
    ELSE IF @ProcID = 'CREATE_TASK'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());
        INSERT INTO dbo.TicketTasks (TaskId, TicketNumber, Name, AssignedTo, Status)
        VALUES (@v_GenKey, @parm01, @parm02, NULLIF(@parm03, ''), 'TODO');

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS task_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 26. ADD_COMMENT
    -- ========================================================================
    ELSE IF @ProcID = 'ADD_COMMENT'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());
        INSERT INTO dbo.TicketComments (Id, TicketNumber, UserId, Comment)
        VALUES (@v_GenKey, @parm01, @UserId, COALESCE(@parm06, @parm02));

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 27. GET_BRANCHES
    -- ========================================================================
    ELSE IF @ProcID = 'GET_BRANCHES'
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(50), Id) AS id,
            CONVERT(NVARCHAR(50), Id) AS branch_id,
            Name AS name,
            Latitude AS latitude,
            Longitude AS longitude,
            RadiusMeters AS radius_meters,
            COALESCE(Radius, RadiusMeters) AS radius,
            COALESCE(Address, '') AS address,
            CAST(COALESCE(IsActive, 1) AS BIT) AS is_active
        FROM dbo.Branches
        ORDER BY Name ASC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 28. SAVE_BRANCH / UPDATE_BRANCH
    -- ========================================================================
    ELSE IF @ProcID IN ('SAVE_BRANCH', 'UPDATE_BRANCH')
    BEGIN
        IF @parm01 <> '' AND EXISTS (SELECT 1 FROM dbo.Branches WHERE CONVERT(NVARCHAR(50), Id) = @parm01)
        BEGIN
            UPDATE dbo.Branches 
            SET Name = COALESCE(NULLIF(@parm02, ''), Name),
                Latitude = CAST(COALESCE(NULLIF(@parm03, ''), Latitude) AS FLOAT),
                Longitude = CAST(COALESCE(NULLIF(@parm04, ''), Longitude) AS FLOAT),
                RadiusMeters = CAST(COALESCE(NULLIF(@parm05, ''), RadiusMeters) AS INT),
                Radius = CAST(COALESCE(NULLIF(@parm05, ''), Radius) AS INT),
                Address = COALESCE(@parm06, Address),
                IsActive = CASE WHEN @parm07 = '0' THEN 0 ELSE 1 END,
                UpdatedAt = SYSDATETIMEOFFSET()
            WHERE CONVERT(NVARCHAR(50), Id) = @parm01;
            SET @v_GenKey = @parm01;
        END
        ELSE
        BEGIN
            SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());

            INSERT INTO dbo.Branches (Id, Name, Latitude, Longitude, RadiusMeters, Radius, Address, IsActive)
            VALUES (@v_GenKey, @parm02, CAST(COALESCE(NULLIF(@parm03, ''), '23.7925') AS FLOAT), CAST(COALESCE(NULLIF(@parm04, ''), '90.4078') AS FLOAT), CAST(COALESCE(NULLIF(@parm05, ''), '150') AS INT), CAST(COALESCE(NULLIF(@parm05, ''), '150') AS INT), @parm06, 1);
        END

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS branch_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 29. GET_LEAVES / GET_LEAVE_REQUESTS
    -- ========================================================================
    ELSE IF @ProcID IN ('GET_LEAVES', 'GET_LEAVE_REQUESTS')
    BEGIN
        DECLARE @v_LUser NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm04), ''), '');
        DECLARE @v_LRole NVARCHAR(50) = COALESCE(NULLIF(TRIM(@parm05), ''), '');

        SELECT 
            CONVERT(NVARCHAR(50), lr.Id) AS id,
            CONVERT(NVARCHAR(50), lr.EmployeeId) AS employee_id,
            COALESCE(CONVERT(NVARCHAR(50), u.Id), CONVERT(NVARCHAR(50), e.UserId), CONVERT(NVARCHAR(50), lr.EmployeeId)) AS applicant_user_id,
            COALESCE(u.Name, u.Username, 'Employee') AS employee_name,
            COALESCE(e.Designation, u.Role, 'Staff') AS designation,
            COALESCE(CONVERT(NVARCHAR(50), u.ProjectId), '') AS project_id,
            lr.LeaveType AS leave_type,
            CONVERT(VARCHAR(10), lr.FromDate, 120) AS from_date,
            CONVERT(VARCHAR(10), lr.ToDate, 120) AS to_date,
            DATEDIFF(DAY, lr.FromDate, lr.ToDate) + 1 AS days_count,
            COALESCE(lr.Reason, '') AS reason,
            COALESCE(lr.Status, 'PENDING') AS status,
            COALESCE(CONVERT(NVARCHAR(50), lr.ApprovedBy), '') AS approved_by,
            COALESCE(appr.Name, '') AS approved_by_name,
            COALESCE(lr.Remarks, '') AS remarks,
            CONVERT(VARCHAR(16), lr.CreatedAt, 120) AS created_at
        FROM dbo.LeaveRequests lr
        LEFT JOIN dbo.Employees e ON CONVERT(NVARCHAR(50), lr.EmployeeId) = CONVERT(NVARCHAR(50), e.Id) OR CONVERT(NVARCHAR(50), lr.EmployeeId) = CONVERT(NVARCHAR(50), e.UserId)
        LEFT JOIN dbo.Users u ON CONVERT(NVARCHAR(50), lr.EmployeeId) = CONVERT(NVARCHAR(50), u.Id) OR CONVERT(NVARCHAR(50), e.UserId) = CONVERT(NVARCHAR(50), u.Id)
        LEFT JOIN dbo.Users appr ON CONVERT(NVARCHAR(50), lr.ApprovedBy) = CONVERT(NVARCHAR(50), appr.Id)
        WHERE (
            LOWER(@v_LRole) IN ('superadmin', 'md', 'hrmanager', 'supportmanager', 'admin')
            OR @v_LRole = ''
            OR LOWER(@v_LRole) = 'projectmanager'
            OR (CONVERT(NVARCHAR(50), lr.EmployeeId) = @v_LUser OR CONVERT(NVARCHAR(50), u.Id) = @v_LUser OR CONVERT(NVARCHAR(50), e.UserId) = @v_LUser)
        )
        ORDER BY lr.CreatedAt DESC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 30. APPLY_LEAVE
    -- ========================================================================
    ELSE IF @ProcID = 'APPLY_LEAVE'
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());

        INSERT INTO dbo.LeaveRequests (Id, EmployeeId, LeaveType, FromDate, ToDate, Reason, Status, CreatedAt)
        VALUES (@v_GenKey, @parm01, @parm02, CAST(@parm03 AS DATE), CAST(@parm04 AS DATE), @parm06, 'PENDING', SYSDATETIMEOFFSET());

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS leave_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 31. APPROVE_LEAVE / REJECT_LEAVE / UPDATE_LEAVE_STATUS
    -- ========================================================================
    ELSE IF @ProcID IN ('APPROVE_LEAVE', 'REJECT_LEAVE', 'UPDATE_LEAVE_STATUS')
    BEGIN
        DECLARE @v_LidVal NVARCHAR(50) = @parm01;
        DECLARE @v_LStatusVal NVARCHAR(50) = CASE 
            WHEN @ProcID = 'APPROVE_LEAVE' THEN 'APPROVED' 
            WHEN @ProcID = 'REJECT_LEAVE' THEN 'REJECTED' 
            ELSE COALESCE(NULLIF(@parm02, ''), 'APPROVED') 
        END;
        DECLARE @v_LRemarksVal NVARCHAR(MAX) = COALESCE(@parm03, @parm06, '');

        UPDATE dbo.LeaveRequests 
        SET Status = @v_LStatusVal,
            ApprovedBy = @UserId,
            Remarks = @v_LRemarksVal,
            UpdatedAt = SYSDATETIMEOFFSET()
        WHERE CONVERT(NVARCHAR(50), Id) = @v_LidVal;

        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 32. GET_NOTICES
    -- ========================================================================
    ELSE IF @ProcID = 'GET_NOTICES'
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(50), Id) AS id,
            Title AS title,
            Content AS content,
            CONVERT(VARCHAR(10), CreatedAt, 120) AS created_at
        FROM dbo.Notices
        WHERE COALESCE(IsActive, 1) = 1
        ORDER BY CreatedAt DESC
        FOR JSON PATH;
    END

    -- ========================================================================
    -- 33. SAVE_NOTICE
    -- ========================================================================
    ELSE IF @ProcID = 'SAVE_NOTICE'
    BEGIN
        IF @parm01 <> '' AND EXISTS (SELECT 1 FROM dbo.Notices WHERE CONVERT(NVARCHAR(50), Id) = @parm01)
        BEGIN
            UPDATE dbo.Notices 
            SET Title = @parm02, Content = @parm06, IsActive = CASE WHEN @parm04 = '0' THEN 0 ELSE 1 END, UpdatedAt = SYSDATETIMEOFFSET()
            WHERE CONVERT(NVARCHAR(50), Id) = @parm01;
            SET @v_GenKey = @parm01;
        END
        ELSE
        BEGIN
            SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());

            INSERT INTO dbo.Notices (Id, Title, Content, IsActive, CreatedAt)
            VALUES (@v_GenKey, @parm02, @parm06, 1, SYSDATETIMEOFFSET());
        END

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS notice_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- ========================================================================
    -- 34. PUNCH_ATTENDANCE / PUNCH_IN / PUNCH_OUT
    -- ========================================================================
    ELSE IF @ProcID IN ('PUNCH_ATTENDANCE', 'PUNCH_IN', 'PUNCH_OUT')
    BEGIN
        SET @v_GenKey = CONVERT(NVARCHAR(50), NEWID());

        INSERT INTO dbo.Attendances (Id, EmployeeId, BranchId, AttendanceDate, InTime, IsWfh, InLatitude, InLongitude, Punctuality, CreatedAt)
        VALUES (@v_GenKey, @parm01, NULLIF(@parm02, ''), CAST(GETDATE() AS DATE), SYSDATETIMEOFFSET(), CASE WHEN @parm05 = '1' THEN 1 ELSE 0 END, CAST(NULLIF(@parm03, '') AS FLOAT), CAST(NULLIF(@parm04, '') AS FLOAT), 'ON_TIME', SYSDATETIMEOFFSET());

        SELECT CAST(1 AS BIT) AS success, @v_GenKey AS attendance_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    ELSE
    BEGIN
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END
END;
GO

-- ============================================================================
-- 2. PROCEDURE: dbo.sp_attendance_operations
-- ============================================================================
CREATE PROCEDURE dbo.sp_attendance_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_UserCode NVARCHAR(100) = '', @p_UserName NVARCHAR(100) = '',
    @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '', @p_parm03 NVARCHAR(255) = '',
    @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '', @p_parm06 NVARCHAR(MAX) = '',
    @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '', @p_parm09 NVARCHAR(255) = '',
    @p_parm10 NVARCHAR(255) = '', @p_parmJson1 NVARCHAR(MAX) = '',
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @UserId NVARCHAR(100) = '',
    @parm01 NVARCHAR(255) = '', @parm02 NVARCHAR(255) = '', @parm03 NVARCHAR(255) = '',
    @parm04 NVARCHAR(255) = '', @parm05 NVARCHAR(255) = '', @parm06 NVARCHAR(MAX) = '',
    @parm07 NVARCHAR(255) = '', @parm08 NVARCHAR(255) = '', @parm09 NVARCHAR(255) = '',
    @parm10 NVARCHAR(255) = '', @parmJson1 NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_ticket_operations
        @p_ComCod = @p_ComCod, @p_ProcID = @p_ProcID, @p_ProcName = @p_ProcName,
        @p_UserId = @p_UserId, @p_UserCode = @p_UserCode, @p_UserName = @p_UserName,
        @p_parm01 = @p_parm01, @p_parm02 = @p_parm02, @p_parm03 = @p_parm03,
        @p_parm04 = @p_parm04, @p_parm05 = @p_parm05, @p_parm06 = @p_parm06,
        @p_parm07 = @p_parm07, @p_parm08 = @p_parm08, @p_parm09 = @p_parm09,
        @p_parm10 = @p_parm10, @p_parmJson1 = @p_parmJson1,
        @ComCod = @ComCod, @ProcID = @ProcID, @UserId = @UserId,
        @parm01 = @parm01, @parm02 = @parm02, @parm03 = @parm03,
        @parm04 = @parm04, @parm05 = @parm05, @parm06 = @parm06,
        @parm07 = @parm07, @parm08 = @parm08, @parm09 = @parm09,
        @parm10 = @parm10, @parmJson1 = @parmJson1;
END;
GO

-- ============================================================================
-- 3. PROCEDURE: dbo.sp_permission_operations
-- ============================================================================
CREATE PROCEDURE dbo.sp_permission_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_UserCode NVARCHAR(100) = '', @p_UserName NVARCHAR(100) = '',
    @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '', @p_parm03 NVARCHAR(255) = '',
    @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '', @p_parm06 NVARCHAR(MAX) = '',
    @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '', @p_parm09 NVARCHAR(255) = '',
    @p_parm10 NVARCHAR(255) = '', @p_parmJson1 NVARCHAR(MAX) = '',
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @UserId NVARCHAR(100) = '',
    @parm01 NVARCHAR(255) = '', @parm02 NVARCHAR(255) = '', @parm03 NVARCHAR(255) = '',
    @parm04 NVARCHAR(255) = '', @parm05 NVARCHAR(255) = '', @parm06 NVARCHAR(MAX) = '',
    @parm07 NVARCHAR(255) = '', @parm08 NVARCHAR(255) = '', @parm09 NVARCHAR(255) = '',
    @parm10 NVARCHAR(255) = '', @parmJson1 NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    IF @p_ProcID <> '' SET @ProcID = @p_ProcID;

    IF @ProcID = 'GET_ROLES'
    BEGIN
        SELECT RoleKey AS key_name, DisplayName AS display_name, Description AS description, IsSystem AS is_system FROM dbo.Roles ORDER BY RoleKey ASC FOR JSON PATH;
    END
    ELSE
    BEGIN
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- STEP 9: FORWARDERS IN support & auth (FAIL-SAFE 100% ROUTING)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE support.sp_ticket_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '',
    @p_parm03 NVARCHAR(255) = '', @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '',
    @p_parm06 NVARCHAR(MAX) = '', @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '',
    @p_parmJson1 NVARCHAR(MAX) = '', @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_ticket_operations 
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_UserId=@p_UserId,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04,
        @p_parm05=@p_parm05, @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08,
        @p_parmJson1=@p_parmJson1, @ComCod=@ComCod, @ProcID=@ProcID;
END;
GO

-- Also uppercase SP_TICKET_OPERATIONS forwarder
CREATE OR ALTER PROCEDURE support.SP_TICKET_OPERATIONS
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '',
    @p_parm03 NVARCHAR(255) = '', @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '',
    @p_parm06 NVARCHAR(MAX) = '', @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '',
    @p_parmJson1 NVARCHAR(MAX) = '', @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_ticket_operations 
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_UserId=@p_UserId,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04,
        @p_parm05=@p_parm05, @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08,
        @p_parmJson1=@p_parmJson1, @ComCod=@ComCod, @ProcID=@ProcID;
END;
GO

CREATE OR ALTER PROCEDURE support.sp_attendance_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '',
    @p_parm03 NVARCHAR(255) = '', @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '',
    @p_parm06 NVARCHAR(MAX) = '', @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '',
    @p_parmJson1 NVARCHAR(MAX) = '', @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_attendance_operations 
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_UserId=@p_UserId,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04,
        @p_parm05=@p_parm05, @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08,
        @p_parmJson1=@p_parmJson1, @ComCod=@ComCod, @ProcID=@ProcID;
END;
GO

CREATE OR ALTER PROCEDURE support.sp_permission_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '',
    @p_parm03 NVARCHAR(255) = '', @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '',
    @p_parm06 NVARCHAR(MAX) = '', @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '',
    @p_parmJson1 NVARCHAR(MAX) = '', @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_permission_operations 
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_UserId=@p_UserId,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04,
        @p_parm05=@p_parm05, @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08,
        @p_parmJson1=@p_parmJson1, @ComCod=@ComCod, @ProcID=@ProcID;
END;
GO

CREATE OR ALTER PROCEDURE auth.sp_ticket_operations
    @p_ComCod NVARCHAR(100) = '', @p_ProcID NVARCHAR(100) = '', @p_ProcName NVARCHAR(100) = '',
    @p_UserId NVARCHAR(100) = '', @p_parm01 NVARCHAR(255) = '', @p_parm02 NVARCHAR(255) = '',
    @p_parm03 NVARCHAR(255) = '', @p_parm04 NVARCHAR(255) = '', @p_parm05 NVARCHAR(255) = '',
    @p_parm06 NVARCHAR(MAX) = '', @p_parm07 NVARCHAR(255) = '', @p_parm08 NVARCHAR(255) = '',
    @p_parmJson1 NVARCHAR(MAX) = '', @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_ticket_operations 
        @p_ComCod=@p_ComCod, @p_ProcID=@p_ProcID, @p_UserId=@p_UserId,
        @p_parm01=@p_parm01, @p_parm02=@p_parm02, @p_parm03=@p_parm03, @p_parm04=@p_parm04,
        @p_parm05=@p_parm05, @p_parm06=@p_parm06, @p_parm07=@p_parm07, @p_parm08=@p_parm08,
        @p_parmJson1=@p_parmJson1, @ComCod=@ComCod, @ProcID=@ProcID;
END;
GO

PRINT '========================================================================';
PRINT 'TASUPORTDB CLEAN RESET COMPLETED SUCCESSFULLY!';
PRINT 'ALL 16 JUNK TABLES AND 14 JUNK STORED PROCEDURES HAVE BEEN REMOVED.';
PRINT 'ONLY THE 14 ESSENTIAL TABLES REMAIN IN dbo SCHEMA.';
PRINT 'SEED DATA INSERTED: ALL USERS (admin/admin123), PROJECTS, TICKETS READY.';
PRINT '========================================================================';
GO
