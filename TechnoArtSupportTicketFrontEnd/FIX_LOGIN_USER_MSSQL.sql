-- ============================================================================
-- TECHNOART SOFTWARE - INSTANT FIX FOR LOGIN AUTHENTICATION (MSSQL)
-- DATABASE: TASUPORTDB
-- Solves "Invalid username or password" caused by:
-- 1. Schema mismatch (support.Users vs dbo.Users)
-- 2. Singular vs Plural table name (User vs Users)
-- 3. Column name mismatch (Password vs PasswordHash, Username vs Email vs UserId)
-- 4. Inactive flag or missing role
-- ============================================================================

USE TASUPORTDB;
GO

-- 1. Ensure support schema exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'support')
BEGIN
    EXEC('CREATE SCHEMA support');
END
GO

-- 2. Ensure dbo.Users has all compatible column aliases
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL
BEGIN
    -- Add Password column if missing (for APIs expecting Password instead of PasswordHash)
    IF COL_LENGTH('dbo.Users', 'Password') IS NULL
        ALTER TABLE dbo.Users ADD Password NVARCHAR(255) NULL;

    -- Add PasswordHash column if missing
    IF COL_LENGTH('dbo.Users', 'PasswordHash') IS NULL
        ALTER TABLE dbo.Users ADD PasswordHash NVARCHAR(255) NULL;

    -- Add UserId column alias if missing
    IF COL_LENGTH('dbo.Users', 'UserId') IS NULL
        ALTER TABLE dbo.Users ADD UserId NVARCHAR(100) NULL;

    -- Add UserCode column alias if missing
    IF COL_LENGTH('dbo.Users', 'UserCode') IS NULL
        ALTER TABLE dbo.Users ADD UserCode NVARCHAR(100) NULL;

    -- Add UserName column alias if missing
    IF COL_LENGTH('dbo.Users', 'UserName') IS NULL
        ALTER TABLE dbo.Users ADD UserName NVARCHAR(100) NULL;

    -- Add Status column if missing
    IF COL_LENGTH('dbo.Users', 'Status') IS NULL
        ALTER TABLE dbo.Users ADD Status NVARCHAR(50) DEFAULT 'ACTIVE';

    -- Add IsActive column if missing
    IF COL_LENGTH('dbo.Users', 'IsActive') IS NULL
        ALTER TABLE dbo.Users ADD IsActive BIT DEFAULT 1;
END
GO

-- 3. Upsert Admin User with all possible aliases matching 'admin@example.com' / '1234567890'
IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = 'admin@example.com' OR Email = 'admin@example.com')
BEGIN
    UPDATE dbo.Users
    SET 
        Username = 'admin@example.com',
        UserName = 'admin@example.com',
        Email = 'admin@example.com',
        UserId = 'admin@example.com',
        UserCode = 'ADMIN01',
        Password = '1234567890',
        PasswordHash = '1234567890',
        Role = 'SuperAdmin',
        IsActive = 1,
        Status = 'ACTIVE',
        Name = 'System Administrator'
    WHERE Username = 'admin@example.com' OR Email = 'admin@example.com';
END
ELSE
BEGIN
    INSERT INTO dbo.Users (Id, UserId, Username, UserName, Email, UserCode, Password, PasswordHash, Name, Role, IsActive, Status)
    VALUES (
        'U10000000001',
        'admin@example.com',
        'admin@example.com',
        'admin@example.com',
        'admin@example.com',
        'ADMIN01',
        '1234567890',
        '1234567890',
        'System Administrator',
        'SuperAdmin',
        1,
        'ACTIVE'
    );
END
GO

-- Also ensure 'shuvo@tas.com' with password '123456789' is properly configured
IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = 'shuvo@tas.com' OR Email = 'shuvo@tas.com')
BEGIN
    UPDATE dbo.Users
    SET 
        Username = 'shuvo@tas.com',
        UserName = 'shuvo@tas.com',
        Email = 'shuvo@tas.com',
        UserId = 'shuvo@tas.com',
        UserCode = 'TAS-104',
        Password = '123456789',
        PasswordHash = '123456789',
        Role = 'TeamMember',
        IsActive = 1,
        Status = 'ACTIVE',
        Name = 'Shuvo TAS'
    WHERE Username = 'shuvo@tas.com' OR Email = 'shuvo@tas.com';
END
ELSE
BEGIN
    INSERT INTO dbo.Users (Id, UserId, Username, UserName, Email, UserCode, Password, PasswordHash, Name, Role, IsActive, Status)
    VALUES (
        'U10000000002',
        'shuvo@tas.com',
        'shuvo@tas.com',
        'shuvo@tas.com',
        'shuvo@tas.com',
        'TAS-104',
        '123456789',
        '123456789',
        'Shuvo TAS',
        'TeamMember',
        1,
        'ACTIVE'
    );
END
GO

-- 4. Create support.Users view so queries to support.Users succeed
IF OBJECT_ID('support.Users', 'V') IS NOT NULL DROP VIEW support.Users;
GO
CREATE VIEW support.Users AS SELECT * FROM dbo.Users;
GO

-- 5. Create dbo.User and support.User views for singular table queries
IF OBJECT_ID('dbo.User', 'V') IS NOT NULL DROP VIEW dbo.User;
GO
CREATE VIEW dbo.User AS SELECT * FROM dbo.Users;
GO

IF OBJECT_ID('support.User', 'V') IS NOT NULL DROP VIEW support.User;
GO
CREATE VIEW support.User AS SELECT * FROM dbo.Users;
GO

-- Verify User Records
SELECT Id, UserId, Username, Email, Password, PasswordHash, Role, IsActive, Status 
FROM dbo.Users 
WHERE Username IN ('admin@example.com', 'shuvo@tas.com');
GO

-- Test Login Stored Procedure directly (Should return JSON with success: 1 in both styles)
IF OBJECT_ID('support.SP_TICKET_OPERATIONS', 'P') IS NOT NULL
BEGIN
    PRINT 'Testing call style 1 (API Desc style):';
    EXEC support.SP_TICKET_OPERATIONS @p_ProcID = 'GET_USER_LOGIN', @p_Desc01 = 'admin@example.com', @p_Desc02 = '1234567890';

    PRINT 'Testing call style 2 (parm style):';
    EXEC support.SP_TICKET_OPERATIONS @p_ProcID = 'GET_USER_LOGIN', @p_parm01 = 'admin@example.com', @p_parm02 = '1234567890';
END
GO
