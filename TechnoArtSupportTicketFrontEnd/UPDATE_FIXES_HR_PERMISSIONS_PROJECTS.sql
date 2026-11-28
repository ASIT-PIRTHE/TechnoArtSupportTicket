USE TASUPORTDB;
GO

-- ============================================================================
-- 1. DYNAMIC ROLE & USER MENU PERMISSION TABLES
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RoleMenuPermissions')
BEGIN
    CREATE TABLE dbo.RoleMenuPermissions (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        RoleKey NVARCHAR(100) NOT NULL,
        ModuleKey NVARCHAR(100) NOT NULL,
        CanView BIT NOT NULL DEFAULT 0,
        CanEdit BIT NOT NULL DEFAULT 0,
        CanDelete BIT NOT NULL DEFAULT 0,
        CanApprove BIT NOT NULL DEFAULT 0,
        UpdatedAt DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT UQ_RoleMenu UNIQUE (RoleKey, ModuleKey)
    );
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserMenuPermissions')
BEGIN
    CREATE TABLE dbo.UserMenuPermissions (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        UserId NVARCHAR(100) NOT NULL,
        ModuleKey NVARCHAR(100) NOT NULL,
        CanView BIT NOT NULL DEFAULT 0,
        CanEdit BIT NOT NULL DEFAULT 0,
        CanDelete BIT NOT NULL DEFAULT 0,
        CanApprove BIT NOT NULL DEFAULT 0,
        UpdatedAt DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT UQ_UserMenu UNIQUE (UserId, ModuleKey)
    );
END
GO

-- ============================================================================
-- 2. DBO.SP_PERMISSION_OPERATIONS (DYNAMIC MATRIX & MENUS)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_permission_operations
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @ProcName NVARCHAR(100) = '',
    @UserId NVARCHAR(100) = '', @UserCode NVARCHAR(100) = '', @UserName NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '', @parm00 NVARCHAR(MAX) = '', @parm01 NVARCHAR(MAX) = '',
    @parm02 NVARCHAR(MAX) = '', @parm03 NVARCHAR(MAX) = '', @parm04 NVARCHAR(MAX) = '',
    @parm05 NVARCHAR(MAX) = '', @parm06 NVARCHAR(MAX) = '', @parm07 NVARCHAR(MAX) = '',
    @parm08 NVARCHAR(MAX) = '', @parm09 NVARCHAR(MAX) = '', @parm10 NVARCHAR(MAX) = '',
    @parm11 NVARCHAR(MAX) = '', @parm12 NVARCHAR(MAX) = '', @parm13 NVARCHAR(MAX) = '',
    @parm14 NVARCHAR(MAX) = '', @parm15 NVARCHAR(MAX) = '', @parm16 NVARCHAR(MAX) = '',
    @parm17 NVARCHAR(MAX) = '', @parm18 NVARCHAR(MAX) = '', @parm19 NVARCHAR(MAX) = '',
    @parm20 NVARCHAR(MAX) = '',
    @Desc01 NVARCHAR(MAX) = '', @Desc02 NVARCHAR(MAX) = '', @Desc03 NVARCHAR(MAX) = '',
    @Desc04 NVARCHAR(MAX) = '', @Desc05 NVARCHAR(MAX) = '', @Desc06 NVARCHAR(MAX) = '',
    @Desc07 NVARCHAR(MAX) = '', @Desc08 NVARCHAR(MAX) = '', @Desc09 NVARCHAR(MAX) = '',
    @Desc10 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '', @parmJson2 NVARCHAR(MAX) = '', @parmJson3 NVARCHAR(MAX) = '',
    @parmJson4 NVARCHAR(MAX) = '', @parmJson5 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL, @parmBin02 VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Action <> '' AND @ProcID = '' SET @ProcID = @Action;

    -- 1. GET_ROLES
    IF @ProcID = 'GET_ROLES'
    BEGIN
        DECLARE @v_RolesJson NVARCHAR(MAX);
        SET @v_RolesJson = (
            SELECT 
                RoleKey AS [Key], 
                RoleKey AS key_name, 
                RoleKey AS RoleKey, 
                DisplayName AS [DisplayName], 
                DisplayName AS display_name, 
                Description AS description, 
                IsSystem AS is_system 
            FROM dbo.Roles 
            ORDER BY RoleKey ASC 
            FOR JSON PATH
        );
        SELECT COALESCE(@v_RolesJson, '[]') AS result_json;
    END

    -- 2. CREATE_ROLE
    ELSE IF @ProcID = 'CREATE_ROLE'
    BEGIN
        DECLARE @v_NewKey NVARCHAR(100) = TRIM(@parm01);
        DECLARE @v_NewName NVARCHAR(150) = TRIM(@parm02);
        DECLARE @v_NewDesc NVARCHAR(MAX) = COALESCE(NULLIF(TRIM(@parm03), ''), '');

        IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleKey = @v_NewKey)
        BEGIN
            INSERT INTO dbo.Roles (RoleKey, DisplayName, Description, IsSystem, CreatedAt)
            VALUES (@v_NewKey, @v_NewName, @v_NewDesc, 0, SYSDATETIMEOFFSET());
        END
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 3. SAVE_ROLE_PERMISSIONS
    ELSE IF @ProcID = 'SAVE_ROLE_PERMISSIONS'
    BEGIN
        DECLARE @v_SaveRoleKey NVARCHAR(100) = TRIM(@parm01);
        IF @v_SaveRoleKey <> '' AND @parmJson1 <> '' AND ISJSON(@parmJson1) = 1
        BEGIN
            DELETE FROM dbo.RoleMenuPermissions WHERE RoleKey = @v_SaveRoleKey;

            INSERT INTO dbo.RoleMenuPermissions (RoleKey, ModuleKey, CanView, CanEdit, CanDelete, CanApprove, UpdatedAt)
            SELECT 
                @v_SaveRoleKey,
                JSON_VALUE(value, '$.ModuleKey'),
                TRY_CAST(JSON_VALUE(value, '$.CanView') AS BIT),
                TRY_CAST(JSON_VALUE(value, '$.CanEdit') AS BIT),
                TRY_CAST(JSON_VALUE(value, '$.CanDelete') AS BIT),
                TRY_CAST(JSON_VALUE(value, '$.CanApprove') AS BIT),
                SYSDATETIMEOFFSET()
            FROM OPENJSON(@parmJson1)
            WHERE JSON_VALUE(value, '$.ModuleKey') IS NOT NULL;
        END
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 4. SAVE_USER_PERMISSIONS
    ELSE IF @ProcID = 'SAVE_USER_PERMISSIONS'
    BEGIN
        DECLARE @v_SaveUserId NVARCHAR(100) = TRIM(@parm01);
        IF @v_SaveUserId <> '' AND @parmJson1 <> '' AND ISJSON(@parmJson1) = 1
        BEGIN
            DELETE FROM dbo.UserMenuPermissions WHERE UserId = @v_SaveUserId;

            INSERT INTO dbo.UserMenuPermissions (UserId, ModuleKey, CanView, CanEdit, CanDelete, CanApprove, UpdatedAt)
            SELECT 
                @v_SaveUserId,
                JSON_VALUE(value, '$.ModuleKey'),
                TRY_CAST(JSON_VALUE(value, '$.CanView') AS BIT),
                TRY_CAST(JSON_VALUE(value, '$.CanEdit') AS BIT),
                TRY_CAST(JSON_VALUE(value, '$.CanDelete') AS BIT),
                TRY_CAST(JSON_VALUE(value, '$.CanApprove') AS BIT),
                SYSDATETIMEOFFSET()
            FROM OPENJSON(@parmJson1)
            WHERE JSON_VALUE(value, '$.ModuleKey') IS NOT NULL;
        END
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END

    -- 5. GET_ROLE_PERMISSIONS
    ELSE IF @ProcID = 'GET_ROLE_PERMISSIONS'
    BEGIN
        DECLARE @v_GetRoleKey NVARCHAR(100) = TRIM(@parm01);
        DECLARE @v_RolePermsJson NVARCHAR(MAX);
        SET @v_RolePermsJson = (
            SELECT 
                ModuleKey,
                ModuleKey AS module_key,
                CanView,
                CanEdit,
                CanDelete,
                CanApprove
            FROM dbo.RoleMenuPermissions
            WHERE RoleKey = @v_GetRoleKey
            FOR JSON PATH
        );
        SELECT COALESCE(@v_RolePermsJson, '[]') AS result_json;
    END

    -- 6. GET_USER_PERMISSIONS
    ELSE IF @ProcID = 'GET_USER_PERMISSIONS'
    BEGIN
        DECLARE @v_QueryUser NVARCHAR(100) = COALESCE(NULLIF(TRIM(@parm01), ''), NULLIF(TRIM(@UserId), ''), NULLIF(TRIM(@UserName), ''));
        DECLARE @v_QueryRole NVARCHAR(100) = COALESCE(NULLIF(TRIM(@parm05), ''), '');
        DECLARE @v_TargetUid NVARCHAR(100) = @v_QueryUser;

        IF @v_QueryUser <> ''
        BEGIN
            SELECT TOP 1 
                @v_TargetUid = CONVERT(NVARCHAR(50), Id),
                @v_QueryRole = CASE WHEN @v_QueryRole = '' THEN COALESCE(Role, '') ELSE @v_QueryRole END
            FROM dbo.Users
            WHERE CONVERT(NVARCHAR(50), Id) = @v_QueryUser OR Username = @v_QueryUser OR Email = @v_QueryUser;
        END

        DECLARE @v_UserPermsJson NVARCHAR(MAX);

        -- SuperAdmin and MD have full access to all menus
        IF LOWER(@v_QueryRole) IN ('superadmin', 'md')
        BEGIN
            SET @v_UserPermsJson = (
                SELECT 
                    m.ModuleKey,
                    m.ModuleKey AS module_key,
                    CAST(1 AS BIT) AS CanView,
                    CAST(1 AS BIT) AS CanEdit,
                    CAST(1 AS BIT) AS CanDelete,
                    CAST(1 AS BIT) AS CanApprove
                FROM (VALUES 
                    ('DASHBOARD'), ('CLIENTS'), ('USERS'), ('PROJECTS'), ('TICKETS'),
                    ('TEAM_WORKLOAD'), ('ATTENDANCE_TERMINAL'), ('ATTENDANCE_APPROVALS'),
                    ('OFFICE_HUBS'), ('OFFICE_TIMING'), ('LEAVES'), ('REPORTS'),
                    ('NOTICES'), ('PERMISSIONS'), ('EXECUTIVE_REPORTS'), ('PAYROLL'),
                    ('KPI'), ('RAISE_TICKET'), ('MY_TICKETS'), ('MY_TASKS'), ('COMPANY_USERS')
                ) AS m(ModuleKey)
                FOR JSON PATH
            );
        END
        ELSE
        BEGIN
            -- Merged effective permissions: User override takes precedence over Role matrix
            SET @v_UserPermsJson = (
                SELECT 
                    COALESCE(u.ModuleKey, r.ModuleKey) AS ModuleKey,
                    COALESCE(u.ModuleKey, r.ModuleKey) AS module_key,
                    COALESCE(u.CanView, r.CanView, 0) AS CanView,
                    COALESCE(u.CanEdit, r.CanEdit, 0) AS CanEdit,
                    COALESCE(u.CanDelete, r.CanDelete, 0) AS CanDelete,
                    COALESCE(u.CanApprove, r.CanApprove, 0) AS CanApprove
                FROM dbo.RoleMenuPermissions r
                FULL OUTER JOIN (
                    SELECT * FROM dbo.UserMenuPermissions WHERE UserId = @v_TargetUid
                ) u ON r.ModuleKey = u.ModuleKey AND r.RoleKey = @v_QueryRole
                WHERE r.RoleKey = @v_QueryRole OR u.UserId = @v_TargetUid
                FOR JSON PATH
            );
        END

        SELECT COALESCE(@v_UserPermsJson, '[]') AS result_json;
    END

    ELSE
    BEGIN
        SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END
END;
GO

-- ============================================================================
-- 3. DBO.SP_ATTENDANCE_OPERATIONS (CLEAN ROUTER - FIXES @Djson1 ERROR)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_attendance_operations
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @ProcName NVARCHAR(100) = '',
    @UserId NVARCHAR(100) = '', @UserCode NVARCHAR(100) = '', @UserName NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '', @parm00 NVARCHAR(MAX) = '', @parm01 NVARCHAR(MAX) = '',
    @parm02 NVARCHAR(MAX) = '', @parm03 NVARCHAR(MAX) = '', @parm04 NVARCHAR(MAX) = '',
    @parm05 NVARCHAR(MAX) = '', @parm06 NVARCHAR(MAX) = '', @parm07 NVARCHAR(MAX) = '',
    @parm08 NVARCHAR(MAX) = '', @parm09 NVARCHAR(MAX) = '', @parm10 NVARCHAR(MAX) = '',
    @parm11 NVARCHAR(MAX) = '', @parm12 NVARCHAR(MAX) = '', @parm13 NVARCHAR(MAX) = '',
    @parm14 NVARCHAR(MAX) = '', @parm15 NVARCHAR(MAX) = '', @parm16 NVARCHAR(MAX) = '',
    @parm17 NVARCHAR(MAX) = '', @parm18 NVARCHAR(MAX) = '', @parm19 NVARCHAR(MAX) = '',
    @parm20 NVARCHAR(MAX) = '',
    @Desc01 NVARCHAR(MAX) = '', @Desc02 NVARCHAR(MAX) = '', @Desc03 NVARCHAR(MAX) = '',
    @Desc04 NVARCHAR(MAX) = '', @Desc05 NVARCHAR(MAX) = '', @Desc06 NVARCHAR(MAX) = '',
    @Desc07 NVARCHAR(MAX) = '', @Desc08 NVARCHAR(MAX) = '', @Desc09 NVARCHAR(MAX) = '',
    @Desc10 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '', @parmJson2 NVARCHAR(MAX) = '', @parmJson3 NVARCHAR(MAX) = '',
    @parmJson4 NVARCHAR(MAX) = '', @parmJson5 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL, @parmBin02 VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_ticket_operations
        @ComCod=@ComCod, @ProcID=@ProcID, @ProcName=@ProcName,
        @UserId=@UserId, @UserCode=@UserCode, @UserName=@UserName,
        @Action=@Action, @parm00=@parm00,
        @parm01=@parm01, @parm02=@parm02, @parm03=@parm03, @parm04=@parm04,
        @parm05=@parm05, @parm06=@parm06, @parm07=@parm07, @parm08=@parm08,
        @parm09=@parm09, @parm10=@parm10, @parm11=@parm11, @parm12=@parm12,
        @parm13=@parm13, @parm14=@parm14, @parm15=@parm15, @parm16=@parm16,
        @parm17=@parm17, @parm18=@parm18, @parm19=@parm19, @parm20=@parm20,
        @Desc01=@Desc01, @Desc02=@Desc02, @Desc03=@Desc03, @Desc04=@Desc04,
        @Desc05=@Desc05, @Desc06=@Desc06, @Desc07=@Desc07, @Desc08=@Desc08,
        @Desc09=@Desc09, @Desc10=@Desc10,
        @parmJson1=@parmJson1, @parmJson2=@parmJson2, @parmJson3=@parmJson3,
        @parmJson4=@parmJson4, @parmJson5=@parmJson5,
        @parmBin01=@parmBin01, @parmBin02=@parmBin02;
END;
GO

-- Forwarders in schemas
CREATE OR ALTER PROCEDURE support.sp_attendance_operations
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @ProcName NVARCHAR(100) = '',
    @UserId NVARCHAR(100) = '', @UserCode NVARCHAR(100) = '', @UserName NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '', @parm00 NVARCHAR(MAX) = '', @parm01 NVARCHAR(MAX) = '',
    @parm02 NVARCHAR(MAX) = '', @parm03 NVARCHAR(MAX) = '', @parm04 NVARCHAR(MAX) = '',
    @parm05 NVARCHAR(MAX) = '', @parm06 NVARCHAR(MAX) = '', @parm07 NVARCHAR(MAX) = '',
    @parm08 NVARCHAR(MAX) = '', @parm09 NVARCHAR(MAX) = '', @parm10 NVARCHAR(MAX) = '',
    @parm11 NVARCHAR(MAX) = '', @parm12 NVARCHAR(MAX) = '', @parm13 NVARCHAR(MAX) = '',
    @parm14 NVARCHAR(MAX) = '', @parm15 NVARCHAR(MAX) = '', @parm16 NVARCHAR(MAX) = '',
    @parm17 NVARCHAR(MAX) = '', @parm18 NVARCHAR(MAX) = '', @parm19 NVARCHAR(MAX) = '',
    @parm20 NVARCHAR(MAX) = '',
    @Desc01 NVARCHAR(MAX) = '', @Desc02 NVARCHAR(MAX) = '', @Desc03 NVARCHAR(MAX) = '',
    @Desc04 NVARCHAR(MAX) = '', @Desc05 NVARCHAR(MAX) = '', @Desc06 NVARCHAR(MAX) = '',
    @Desc07 NVARCHAR(MAX) = '', @Desc08 NVARCHAR(MAX) = '', @Desc09 NVARCHAR(MAX) = '',
    @Desc10 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '', @parmJson2 NVARCHAR(MAX) = '', @parmJson3 NVARCHAR(MAX) = '',
    @parmJson4 NVARCHAR(MAX) = '', @parmJson5 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL, @parmBin02 VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_attendance_operations
        @ComCod=@ComCod, @ProcID=@ProcID, @ProcName=@ProcName,
        @UserId=@UserId, @UserCode=@UserCode, @UserName=@UserName,
        @Action=@Action, @parm00=@parm00,
        @parm01=@parm01, @parm02=@parm02, @parm03=@parm03, @parm04=@parm04,
        @parm05=@parm05, @parm06=@parm06, @parm07=@parm07, @parm08=@parm08,
        @parm09=@parm09, @parm10=@parm10, @parm11=@parm11, @parm12=@parm12,
        @parm13=@parm13, @parm14=@parm14, @parm15=@parm15, @parm16=@parm16,
        @parm17=@parm17, @parm18=@parm18, @parm19=@parm19, @parm20=@parm20,
        @Desc01=@Desc01, @Desc02=@Desc02, @Desc03=@Desc03, @Desc04=@Desc04,
        @Desc05=@Desc05, @Desc06=@Desc06, @Desc07=@Desc07, @Desc08=@Desc08,
        @Desc09=@Desc09, @Desc10=@Desc10,
        @parmJson1=@parmJson1, @parmJson2=@parmJson2, @parmJson3=@parmJson3,
        @parmJson4=@parmJson4, @parmJson5=@parmJson5,
        @parmBin01=@parmBin01, @parmBin02=@parmBin02;
END;
GO

CREATE OR ALTER PROCEDURE support.sp_permission_operations
    @ComCod NVARCHAR(100) = '', @ProcID NVARCHAR(100) = '', @ProcName NVARCHAR(100) = '',
    @UserId NVARCHAR(100) = '', @UserCode NVARCHAR(100) = '', @UserName NVARCHAR(100) = '',
    @Action NVARCHAR(100) = '', @parm00 NVARCHAR(MAX) = '', @parm01 NVARCHAR(MAX) = '',
    @parm02 NVARCHAR(MAX) = '', @parm03 NVARCHAR(MAX) = '', @parm04 NVARCHAR(MAX) = '',
    @parm05 NVARCHAR(MAX) = '', @parm06 NVARCHAR(MAX) = '', @parm07 NVARCHAR(MAX) = '',
    @parm08 NVARCHAR(MAX) = '', @parm09 NVARCHAR(MAX) = '', @parm10 NVARCHAR(MAX) = '',
    @parm11 NVARCHAR(MAX) = '', @parm12 NVARCHAR(MAX) = '', @parm13 NVARCHAR(MAX) = '',
    @parm14 NVARCHAR(MAX) = '', @parm15 NVARCHAR(MAX) = '', @parm16 NVARCHAR(MAX) = '',
    @parm17 NVARCHAR(MAX) = '', @parm18 NVARCHAR(MAX) = '', @parm19 NVARCHAR(MAX) = '',
    @parm20 NVARCHAR(MAX) = '',
    @Desc01 NVARCHAR(MAX) = '', @Desc02 NVARCHAR(MAX) = '', @Desc03 NVARCHAR(MAX) = '',
    @Desc04 NVARCHAR(MAX) = '', @Desc05 NVARCHAR(MAX) = '', @Desc06 NVARCHAR(MAX) = '',
    @Desc07 NVARCHAR(MAX) = '', @Desc08 NVARCHAR(MAX) = '', @Desc09 NVARCHAR(MAX) = '',
    @Desc10 NVARCHAR(MAX) = '',
    @parmJson1 NVARCHAR(MAX) = '', @parmJson2 NVARCHAR(MAX) = '', @parmJson3 NVARCHAR(MAX) = '',
    @parmJson4 NVARCHAR(MAX) = '', @parmJson5 NVARCHAR(MAX) = '',
    @parmBin01 VARBINARY(MAX) = NULL, @parmBin02 VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_permission_operations
        @ComCod=@ComCod, @ProcID=@ProcID, @ProcName=@ProcName,
        @UserId=@UserId, @UserCode=@UserCode, @UserName=@UserName,
        @Action=@Action, @parm00=@parm00,
        @parm01=@parm01, @parm02=@parm02, @parm03=@parm03, @parm04=@parm04,
        @parm05=@parm05, @parm06=@parm06, @parm07=@parm07, @parm08=@parm08,
        @parm09=@parm09, @parm10=@parm10, @parm11=@parm11, @parm12=@parm12,
        @parm13=@parm13, @parm14=@parm14, @parm15=@parm15, @parm16=@parm16,
        @parm17=@parm17, @parm18=@parm18, @parm19=@parm19, @parm20=@parm20,
        @Desc01=@Desc01, @Desc02=@Desc02, @Desc03=@Desc03, @Desc04=@Desc04,
        @Desc05=@Desc05, @Desc06=@Desc06, @Desc07=@Desc07, @Desc08=@Desc08,
        @Desc09=@Desc09, @Desc10=@Desc10,
        @parmJson1=@parmJson1, @parmJson2=@parmJson2, @parmJson3=@parmJson3,
        @parmJson4=@parmJson4, @parmJson5=@parmJson5,
        @parmBin01=@parmBin01, @parmBin02=@parmBin02;
END;
GO

PRINT 'Update script successfully executed!';
GO
