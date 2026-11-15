-- ============================================================================
-- TECHNOART SOFTWARE - UPDATE ALL USER PASSWORDS TO SHA-256 HASH & FIX LOGIN
-- Database: TASUPORTDB
-- All passwords set to: admin123 (Hashed using SHA-256)
-- Hash value: 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
-- ============================================================================

USE TASUPORTDB;
GO

PRINT '1. Updating PasswordHash with SHA-256 for all existing users...';

-- Update PasswordHash column with lowercase SHA-256 hash of 'admin123'
UPDATE dbo.Users
SET 
    PasswordHash = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'admin123'), 2)),
    Password = 'admin123',
    IsActive = 1,
    UpdatedAt = SYSDATETIMEOFFSET();

PRINT '2. Ensuring Employees table has matching credentials...';
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
BEGIN
    UPDATE e
    SET e.IsActive = 1, e.UpdatedAt = SYSDATETIMEOFFSET()
    FROM dbo.Employees e
    INNER JOIN dbo.Users u ON e.UserId = u.Id OR CONVERT(NVARCHAR(50), e.UserId) = CONVERT(NVARCHAR(50), u.Id);
END
GO

PRINT '3. Displaying verified user credentials across all roles:';
SELECT 
    u.Id AS [User_ID],
    u.Username AS [Login_Username],
    u.Email AS [Login_Email],
    u.Role AS [System_Role],
    u.PasswordHash AS [SHA256_PasswordHash],
    u.Password AS [PlainText_Password],
    COALESCE(e.Designation, u.Role) AS [Designation],
    u.IsActive AS [IsActive]
FROM dbo.Users u
LEFT JOIN dbo.Employees e ON u.Id = e.UserId OR CONVERT(NVARCHAR(50), u.Id) = CONVERT(NVARCHAR(50), e.UserId)
ORDER BY u.Id ASC;
GO

PRINT '============================================================================';
PRINT 'ALL USER PASSWORDS UPDATED TO SHA-256 SUCCESSFULLY!';
PRINT 'Common Password for all accounts: admin123';
PRINT '============================================================================';
GO
