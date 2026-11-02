using Microsoft.Data.SqlClient;

namespace TechnoArtSupprtAPI
{
    public static class DbInitHelper
    {
        public static string? ResolvedMssqlConnectionString { get; set; }

        public static async Task<string> EnsureDatabaseObjectsAsync(IConfiguration configuration)
        {
            var dbType = configuration.GetValue<string>("DatabaseType") ?? "PostgreSQL";
            if (!dbType.Equals("MSSQL", StringComparison.OrdinalIgnoreCase))
            {
                return "PostgreSQL active, MSSQL schema init skipped.";
            }

            var diagnostics = new List<string>();

            // Candidates to try: sa has sysadmin privileges to create DB and grant permissions
            var candidateConnStrs = new List<(string Name, string ConnStr)>();
            
            var saConnStr = configuration.GetConnectionString("MssqlConnStr_sa");
            if (!string.IsNullOrWhiteSpace(saConnStr))
                candidateConnStrs.Add(("MssqlConnStr_sa (SQL Auth sa)", saConnStr));

            var mssqlConnStr = configuration.GetConnectionString("MssqlConnStr");
            if (!string.IsNullOrWhiteSpace(mssqlConnStr))
                candidateConnStrs.Add(("MssqlConnStr (Windows Auth)", mssqlConnStr));

            string targetDatabase = "";

            // STEP 1: Connect to master to discover/create database and grant permissions
            foreach (var (authName, rawConnStr) in candidateConnStrs)
            {
                try
                {
                    var csb = new SqlConnectionStringBuilder(rawConnStr);
                    string originalDb = string.IsNullOrWhiteSpace(csb.InitialCatalog) ? "TASUPORTDB" : csb.InitialCatalog;
                    csb.InitialCatalog = "master";

                    using var masterConn = new SqlConnection(csb.ConnectionString);
                    await masterConn.OpenAsync();
                    diagnostics.Add($"[{authName}] connected to master.");

                    // Query existing user databases
                    var existingDbs = new List<string>();
                    using (var cmdDbs = new SqlCommand("SELECT name FROM sys.databases WHERE name NOT IN ('master','tempdb','model','msdb')", masterConn))
                    using (var rdr = await cmdDbs.ExecuteReaderAsync())
                    {
                        while (await rdr.ReadAsync())
                            existingDbs.Add(rdr.GetString(0));
                    }
                    diagnostics.Add($"Databases on server: [{string.Join(", ", existingDbs)}]");

                    // Determine target database: exact match or partial match
                    string matchedDb = existingDbs.FirstOrDefault(d => string.Equals(d, originalDb, StringComparison.OrdinalIgnoreCase))
                                    ?? existingDbs.FirstOrDefault(d => d.Contains("TASUP", StringComparison.OrdinalIgnoreCase))
                                    ?? existingDbs.FirstOrDefault(d => d.Contains("SUPPORT", StringComparison.OrdinalIgnoreCase))
                                    ?? "";

                    if (string.IsNullOrEmpty(matchedDb))
                    {
                        matchedDb = originalDb;
                        using var cmdCreate = new SqlCommand($"CREATE DATABASE [{matchedDb}]", masterConn);
                        await cmdCreate.ExecuteNonQueryAsync();
                        diagnostics.Add($"Database [{matchedDb}] created.");
                    }

                    targetDatabase = matchedDb;

                    // Grant sysadmin & db_owner to TASDEV12\Administrator so Windows Authentication works seamlessly
                    try
                    {
                        string grantServerAdmin = @"
IF SUSER_ID('TASDEV12\Administrator') IS NOT NULL
BEGIN
    BEGIN TRY
        ALTER SERVER ROLE sysadmin ADD MEMBER [TASDEV12\Administrator];
    END TRY
    BEGIN CATCH END CATCH;
END";
                        using var cmdSys = new SqlCommand(grantServerAdmin, masterConn);
                        await cmdSys.ExecuteNonQueryAsync();
                        diagnostics.Add("Ensured sysadmin role for [TASDEV12\\Administrator].");
                    }
                    catch (Exception exSys)
                    {
                        diagnostics.Add($"sysadmin grant note: {exSys.Message}");
                    }

                    try
                    {
                        string grantDbOwner = $@"
IF SUSER_ID('TASDEV12\Administrator') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [{targetDatabase}].sys.database_principals WHERE name = 'TASDEV12\Administrator')
    BEGIN
        CREATE USER [TASDEV12\Administrator] FOR LOGIN [TASDEV12\Administrator];
    END;
    ALTER ROLE db_owner ADD MEMBER [TASDEV12\Administrator];
END";
                        using var cmdDb = new SqlCommand(grantDbOwner, masterConn);
                        await cmdDb.ExecuteNonQueryAsync();
                        diagnostics.Add($"Granted db_owner on [{targetDatabase}] to [TASDEV12\\Administrator].");
                    }
                    catch (Exception exDb)
                    {
                        diagnostics.Add($"db_owner grant note: {exDb.Message}");
                    }

                    break; // Master configuration step completed
                }
                catch (Exception exMaster)
                {
                    diagnostics.Add($"[{authName}] master connect error: {exMaster.Message}");
                }
            }

            if (string.IsNullOrEmpty(targetDatabase))
            {
                targetDatabase = "TASUPORTDB";
            }

            // STEP 2: Test which connection string actually succeeds to connect DIRECTLY to targetDatabase
            string workingConnStr = "";
            string workingAuth = "";

            // Check Windows Auth first (preferred if permissions granted), then sa
            var directCandidates = new List<(string Name, string ConnStr)>();
            if (!string.IsNullOrWhiteSpace(mssqlConnStr))
                directCandidates.Add(("Windows Auth", mssqlConnStr));
            if (!string.IsNullOrWhiteSpace(saConnStr))
                directCandidates.Add(("SQL Auth (sa)", saConnStr));

            foreach (var (authName, rawConnStr) in directCandidates)
            {
                try
                {
                    var csb = new SqlConnectionStringBuilder(rawConnStr);
                    csb.InitialCatalog = targetDatabase;
                    using var testConn = new SqlConnection(csb.ConnectionString);
                    await testConn.OpenAsync();
                    workingConnStr = csb.ConnectionString;
                    workingAuth = authName;
                    diagnostics.Add($"Direct connection to [{targetDatabase}] SUCCEEDED using [{authName}].");
                    break;
                }
                catch (Exception exDirect)
                {
                    diagnostics.Add($"Direct connect to [{targetDatabase}] using [{authName}] failed: {exDirect.Message}");
                }
            }

            if (string.IsNullOrEmpty(workingConnStr))
            {
                return "MSSQL direct database connection failed for all candidates. Details: " + string.Join(" | ", diagnostics);
            }

            ResolvedMssqlConnectionString = workingConnStr;

            try
            {
                using var conn = new SqlConnection(workingConnStr);
                await conn.OpenAsync();

                // 1. Ensure schemas exist
                string createSchemas = @"
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'auth')
    EXEC('CREATE SCHEMA auth');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'support')
    EXEC('CREATE SCHEMA support');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'notification')
    EXEC('CREATE SCHEMA notification');
";
                using (var cmdSchema = new SqlCommand(createSchemas, conn))
                {
                    await cmdSchema.ExecuteNonQueryAsync();
                }

                // 2. Ensure essential tables and seed data exist
                string createTablesAndSeed = @"
-- 1. Tenants
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tenants' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.tenants (
        tenant_id   UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        code        NVARCHAR(20)  NOT NULL UNIQUE,
        name        NVARCHAR(255) NOT NULL,
        logo_url    NVARCHAR(500) NULL,
        is_active   BIT           NOT NULL DEFAULT 1,
        tenantginf  NVARCHAR(MAX) NULL,
        created_at  DATETIME2     NOT NULL DEFAULT GETDATE()
    );
END

-- 2. Users
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'users' AND schema_id = SCHEMA_ID('auth'))
BEGIN
    CREATE TABLE auth.users (
        user_id       UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        tenant_id     UNIQUEIDENTIFIER NULL,
        username      NVARCHAR(100)    NOT NULL UNIQUE,
        password_hash NVARCHAR(255)    NOT NULL,
        full_name     NVARCHAR(255)    NOT NULL,
        is_active     BIT              NOT NULL DEFAULT 1,
        userginf      NVARCHAR(MAX)    NULL,
        created_at    DATETIME2        NOT NULL DEFAULT GETDATE()
    );
END

-- 3. Roles
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'roles' AND schema_id = SCHEMA_ID('auth'))
BEGIN
    CREATE TABLE auth.roles (
        role_id NVARCHAR(50) PRIMARY KEY,
        name    NVARCHAR(100) NOT NULL
    );
END

-- 4. User Roles
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'user_roles' AND schema_id = SCHEMA_ID('auth'))
BEGIN
    CREATE TABLE auth.user_roles (
        user_id UNIQUEIDENTIFIER NOT NULL,
        role_id NVARCHAR(50)     NOT NULL,
        PRIMARY KEY (user_id, role_id)
    );
END

-- 5. Projects
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'projects' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.projects (
        project_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        tenant_id  UNIQUEIDENTIFIER NULL,
        code       NVARCHAR(20)    NOT NULL,
        name       NVARCHAR(255)   NOT NULL,
        status     NVARCHAR(20)    NOT NULL DEFAULT 'ACTIVE',
        projginf   NVARCHAR(MAX)   NULL,
        created_at DATETIME2       NOT NULL DEFAULT GETDATE(),
        UNIQUE (tenant_id, code)
    );
END

-- 6. Project Members
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'project_members' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.project_members (
        project_id UNIQUEIDENTIFIER NOT NULL,
        user_id    UNIQUEIDENTIFIER NOT NULL,
        role_code  NVARCHAR(50)     NULL,
        is_active  BIT              NOT NULL DEFAULT 1,
        PRIMARY KEY (project_id, user_id)
    );
END

-- 7. Client Users
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'client_users' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.client_users (
        tenant_id UNIQUEIDENTIFIER NOT NULL,
        user_id   UNIQUEIDENTIFIER NOT NULL,
        role      NVARCHAR(50)     NULL,
        PRIMARY KEY (tenant_id, user_id)
    );
END

-- 8. Tickets
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tickets' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.tickets (
        ticket_id     UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        tenant_id     UNIQUEIDENTIFIER NULL,
        project_id    UNIQUEIDENTIFIER NULL,
        ticket_number NVARCHAR(50)     NOT NULL UNIQUE,
        subject       NVARCHAR(255)    NOT NULL,
        status        NVARCHAR(50)     NOT NULL DEFAULT 'NEW',
        priority      NVARCHAR(50)     NOT NULL DEFAULT 'MEDIUM',
        sla_due_at    DATETIME2        NULL,
        created_by    UNIQUEIDENTIFIER NULL,
        assigned_to   UNIQUEIDENTIFIER NULL,
        ticketginf    NVARCHAR(MAX)    NULL,
        created_at    DATETIME2        NOT NULL DEFAULT GETDATE()
    );
END

IF COL_LENGTH('support.tickets', 'progress_percent') IS NULL
    ALTER TABLE support.tickets ADD progress_percent DECIMAL(5,1) NOT NULL DEFAULT 0;

-- 9. Ticket Comments
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ticket_comments' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.ticket_comments (
        comment_id   UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ticket_id    UNIQUEIDENTIFIER NOT NULL,
        user_id      UNIQUEIDENTIFIER NOT NULL,
        comment_text NVARCHAR(MAX)    NOT NULL,
        created_at   DATETIME2        NOT NULL DEFAULT GETDATE()
    );
END

-- 10. Tasks
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tasks' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.tasks (
        task_id    NVARCHAR(50)     PRIMARY KEY,
        ticket_id  UNIQUEIDENTIFIER NULL,
        name       NVARCHAR(255)    NOT NULL,
        status     NVARCHAR(50)     NOT NULL DEFAULT 'TODO',
        assigned_to UNIQUEIDENTIFIER NULL,
        taskginf   NVARCHAR(MAX)    NULL,
        created_at DATETIME2        NOT NULL DEFAULT GETDATE()
    );
END

IF COL_LENGTH('support.tasks', 'rejection_reason') IS NULL
    ALTER TABLE support.tasks ADD rejection_reason NVARCHAR(MAX) NULL;

-- 11. Work Logs
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'work_logs' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.work_logs (
        log_id      UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        task_id     NVARCHAR(50)     NOT NULL,
        user_id     UNIQUEIDENTIFIER NOT NULL,
        hours_spent DECIMAL(5,2)     NULL,
        log_date    DATE             NULL,
        description NVARCHAR(MAX)    NULL,
        created_at  DATETIME2        NOT NULL DEFAULT GETDATE()
    );
END

-- 12. Notification Outbox
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'outbox' AND schema_id = SCHEMA_ID('notification'))
BEGIN
    CREATE TABLE notification.outbox (
        id                    UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        event_type            NVARCHAR(100)  NOT NULL,
        payloadginf           NVARCHAR(MAX)  NULL,
        status                NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
        retry_count           INT            NOT NULL DEFAULT 0,
        created_at            DATETIME2      NOT NULL DEFAULT GETDATE(),
        processing_started_at DATETIME2      NULL,
        processed_at          DATETIME2      NULL
    );
END


-- 13. Ticket Files / Attachments
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ticket_files' AND schema_id = SCHEMA_ID('support'))
BEGIN
    CREATE TABLE support.ticket_files (
        file_id      UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ticket_id    UNIQUEIDENTIFIER NOT NULL,
        file_name    NVARCHAR(255)    NOT NULL,
        mime_type    NVARCHAR(100)    NOT NULL,
        base64_data  NVARCHAR(MAX)    NOT NULL,
        uploaded_by  UNIQUEIDENTIFIER NULL,
        created_at   DATETIME2        NOT NULL DEFAULT GETDATE()
    );
END

IF COL_LENGTH('auth.users', 'last_login_at') IS NULL
    ALTER TABLE auth.users ADD last_login_at DATETIME2 NULL;

-- Seed Roles
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='SuperAdmin') INSERT INTO auth.roles (role_id, name) VALUES ('SuperAdmin', 'Super Admin');
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='MD') INSERT INTO auth.roles (role_id, name) VALUES ('MD', 'Managing Director');
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='SupportManager') INSERT INTO auth.roles (role_id, name) VALUES ('SupportManager', 'Support Manager');
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='ProjectManager') INSERT INTO auth.roles (role_id, name) VALUES ('ProjectManager', 'Project Manager');
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='TeamMember') INSERT INTO auth.roles (role_id, name) VALUES ('TeamMember', 'Team Member');
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='ClientAdmin') INSERT INTO auth.roles (role_id, name) VALUES ('ClientAdmin', 'Client Admin');
IF NOT EXISTS (SELECT 1 FROM auth.roles WHERE role_id='ClientUser') INSERT INTO auth.roles (role_id, name) VALUES ('ClientUser', 'Client User');

-- Seed Tenants
IF NOT EXISTS (SELECT 1 FROM support.tenants WHERE tenant_id = '00000000-0000-0000-0000-000000000000')
    INSERT INTO support.tenants (tenant_id, code, name) VALUES ('00000000-0000-0000-0000-000000000000', 'DEFAULT', 'Global System Tenant');
IF NOT EXISTS (SELECT 1 FROM support.tenants WHERE tenant_id = '11111111-1111-1111-1111-111111111111')
    INSERT INTO support.tenants (tenant_id, code, name) VALUES ('11111111-1111-1111-1111-111111111111', 'STARK', 'Stark Industries');

-- Seed Admin User (admin / admin)
IF NOT EXISTS (SELECT 1 FROM auth.users WHERE user_id = 'AAAA0000-0000-0000-0000-000000000000' OR username = 'admin')
BEGIN
    INSERT INTO auth.users (user_id, tenant_id, username, password_hash, full_name)
    VALUES ('AAAA0000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'admin', 'admin', 'System Admin');
    IF NOT EXISTS (SELECT 1 FROM auth.user_roles WHERE user_id='AAAA0000-0000-0000-0000-000000000000' AND role_id='SuperAdmin')
        INSERT INTO auth.user_roles (user_id, role_id) VALUES ('AAAA0000-0000-0000-0000-000000000000', 'SuperAdmin');
END

-- Seed Project Manager User (pm / pm123)
IF NOT EXISTS (SELECT 1 FROM auth.users WHERE user_id = 'BBBB0000-0000-0000-0000-000000000000' OR username = 'pm')
BEGIN
    INSERT INTO auth.users (user_id, tenant_id, username, password_hash, full_name)
    VALUES ('BBBB0000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'pm', 'pm123', 'Project Manager');
    IF NOT EXISTS (SELECT 1 FROM auth.user_roles WHERE user_id='BBBB0000-0000-0000-0000-000000000000' AND role_id='ProjectManager')
        INSERT INTO auth.user_roles (user_id, role_id) VALUES ('BBBB0000-0000-0000-0000-000000000000', 'ProjectManager');
END

-- Seed Client User (client / client123)
IF NOT EXISTS (SELECT 1 FROM auth.users WHERE user_id = 'CCCC0000-0000-0000-0000-000000000000' OR username = 'client')
BEGIN
    INSERT INTO auth.users (user_id, tenant_id, username, password_hash, full_name)
    VALUES ('CCCC0000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'client', 'client123', 'Client Admin');
    IF NOT EXISTS (SELECT 1 FROM auth.user_roles WHERE user_id='CCCC0000-0000-0000-0000-000000000000' AND role_id='ClientAdmin')
        INSERT INTO auth.user_roles (user_id, role_id) VALUES ('CCCC0000-0000-0000-0000-000000000000', 'ClientAdmin');
END
";
                using (var cmdTables = new SqlCommand(createTablesAndSeed, conn))
                {
                    await cmdTables.ExecuteNonQueryAsync();
                }

                // 3. Ensure support.sp_ticket_files and SP_TICKET_OPERATIONS are created or altered
                string spFilesSql = @"
CREATE OR ALTER PROCEDURE support.sp_ticket_files
    @p_ComCod  NVARCHAR(100)  = '',
    @p_ProcID  NVARCHAR(100)  = '',
    @p_Djson1  NVARCHAR(MAX)  = '{}',
    @p_Djson2  NVARCHAR(MAX)  = '{}',
    @p_Dbin01  VARBINARY(MAX) = NULL,
    @p_Desc01  NVARCHAR(MAX)  = '',
    @p_Desc02  NVARCHAR(MAX)  = '',
    @p_Desc03  NVARCHAR(MAX)  = '',
    @p_Desc04  NVARCHAR(MAX)  = '',
    @p_Desc05  NVARCHAR(MAX)  = '',
    @p_Desc06  NVARCHAR(MAX)  = '',
    @p_Desc07  NVARCHAR(MAX)  = '',
    @p_Desc08  NVARCHAR(MAX)  = '',
    @p_Desc09  NVARCHAR(MAX)  = '',
    @p_Desc10  NVARCHAR(MAX)  = ''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_user_id UNIQUEIDENTIFIER = COALESCE(TRY_CAST(NULLIF(@p_Desc08,'') AS UNIQUEIDENTIFIER), TRY_CAST(NULLIF(@p_Desc04,'') AS UNIQUEIDENTIFIER));

    IF @p_ProcID = 'UPLOAD_FILE'
    BEGIN
        DECLARE @v_up_ticket_id UNIQUEIDENTIFIER;
        SELECT @v_up_ticket_id = ticket_id FROM support.tickets WHERE ticket_number = @p_Desc01;
        IF @v_up_ticket_id IS NOT NULL
        BEGIN
            DECLARE @v_new_file_id UNIQUEIDENTIFIER = NEWID();
            INSERT INTO support.ticket_files (file_id, ticket_id, file_name, mime_type, base64_data, uploaded_by)
            VALUES (@v_new_file_id, @v_up_ticket_id, @p_Desc02, @p_Desc03, @p_Djson1, @v_user_id);

            SELECT (SELECT CAST(1 AS BIT) AS success, CAST(@v_new_file_id AS NVARCHAR(36)) AS file_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END
        SELECT '{""error"":""Ticket not found""}' AS result_json;
        RETURN;
    END

    IF @p_ProcID = 'GET_FILES'
    BEGIN
        SELECT ISNULL((
            SELECT 
                CAST(f.file_id AS NVARCHAR(36)) AS file_id,
                f.file_name,
                f.mime_type,
                f.base64_data,
                CONVERT(NVARCHAR(30), f.created_at, 126) AS created_at
            FROM support.ticket_files f
            JOIN support.tickets t ON f.ticket_id = t.ticket_id
            WHERE t.ticket_number = @p_Desc01
            ORDER BY f.created_at ASC
            FOR JSON PATH
        ), '[]') AS result_json;
        RETURN;
    END

    SELECT '{""error"":""Operation Not Configured""}' AS result_json;
END;
GO

-- 4. Main Operations Procedure: support.SP_TICKET_OPERATIONS
";
                using (var cmdFiles = new SqlCommand(spFilesSql, conn))
                {
                    cmdFiles.CommandTimeout = 60;
                    await cmdFiles.ExecuteNonQueryAsync();
                }

                string spSql = @"
CREATE OR ALTER PROCEDURE support.SP_TICKET_OPERATIONS
    @p_ComCod  NVARCHAR(100)  = '',
    @p_ProcID  NVARCHAR(100)  = '',
    @p_Djson1  NVARCHAR(MAX)  = '{}',
    @p_Djson2  NVARCHAR(MAX)  = '{}',
    @p_Dbin01  VARBINARY(MAX) = NULL,
    @p_Desc01  NVARCHAR(MAX)  = '',
    @p_Desc02  NVARCHAR(MAX)  = '',
    @p_Desc03  NVARCHAR(MAX)  = '',
    @p_Desc04  NVARCHAR(MAX)  = '',
    @p_Desc05  NVARCHAR(MAX)  = '',
    @p_Desc06  NVARCHAR(MAX)  = '',
    @p_Desc07  NVARCHAR(MAX)  = '',
    @p_Desc08  NVARCHAR(MAX)  = '',
    @p_Desc09  NVARCHAR(MAX)  = '',
    @p_Desc10  NVARCHAR(MAX)  = ''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_tenant_id    UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_ComCod,'') AS UNIQUEIDENTIFIER);
    DECLARE @v_user_id      UNIQUEIDENTIFIER = COALESCE(TRY_CAST(NULLIF(@p_Desc08,'') AS UNIQUEIDENTIFIER), TRY_CAST(NULLIF(@p_Desc04,'') AS UNIQUEIDENTIFIER));
    DECLARE @v_role         NVARCHAR(50)     = COALESCE(NULLIF(@p_Desc09,''), NULLIF(@p_Desc05,''), 'SuperAdmin');

    DECLARE @ErrorMsg NVARCHAR(MAX);

    BEGIN TRY

        -- --------------------------------------------------------
        -- LOGIN
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_USER_LOGIN'
        BEGIN
            UPDATE auth.users SET last_login_at = GETDATE() WHERE username = @p_Desc01;

            SELECT (
                SELECT
                    CAST(1 AS BIT)                                  AS success,
                    CAST(u.user_id AS NVARCHAR(36))                 AS user_id,
                    CAST(u.tenant_id AS NVARCHAR(36))               AS tenant_id,
                    u.username                                       AS username,
                    r.role_id                                        AS [role],
                    u.full_name                                      AS full_name,
                    ISNULL(t.logo_url,'')                            AS logo_url
                FROM auth.users u
                JOIN auth.user_roles r ON u.user_id = r.user_id
                LEFT JOIN support.tenants t ON u.tenant_id = t.tenant_id
                WHERE u.username = @p_Desc01
                  AND u.password_hash = @p_Desc02
                  AND u.is_active = 1
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET TENANTS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_TENANTS'
        BEGIN
            SELECT ISNULL((
                SELECT
                    CAST(tenant_id AS NVARCHAR(36)) AS tenant_id,
                    code, name,
                    ISNULL(logo_url,'')             AS logo_url,
                    CONVERT(NVARCHAR(30), created_at, 126) AS created_at
                FROM support.tenants
                ORDER BY name
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CREATE TENANT
        -- --------------------------------------------------------
        IF @p_ProcID = 'CREATE_TENANT'
        BEGIN
            DECLARE @v_new_tenant_id UNIQUEIDENTIFIER = NEWID();
            INSERT INTO support.tenants (tenant_id, code, name, logo_url)
            VALUES (@v_new_tenant_id, @p_Desc01, @p_Desc02, NULLIF(@p_Desc03,''));

            SELECT (
                SELECT CAST(1 AS BIT) AS success, CAST(@v_new_tenant_id AS NVARCHAR(36)) AS tenant_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- UPDATE TENANT
        -- --------------------------------------------------------
        IF @p_ProcID = 'UPDATE_TENANT'
        BEGIN
            DECLARE @v_up_tenant_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc01,'') AS UNIQUEIDENTIFIER);
            DECLARE @v_logo NVARCHAR(MAX) = COALESCE(NULLIF(@p_Desc04,''), NULLIF(@p_Desc03,''));

            UPDATE support.tenants
            SET code = ISNULL(NULLIF(@p_Desc02,''), code),
                name = ISNULL(NULLIF(@p_Desc03,''), name),
                logo_url = COALESCE(@v_logo, logo_url)
            WHERE tenant_id = @v_up_tenant_id;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- DELETE TENANT
        -- --------------------------------------------------------
        IF @p_ProcID = 'DELETE_TENANT'
        BEGIN
            DECLARE @v_del_tenant_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc01,'') AS UNIQUEIDENTIFIER);
            
            IF EXISTS (SELECT 1 FROM support.tickets WHERE tenant_id = @v_del_tenant_id)
            BEGIN
                SELECT '{""success"":false,""error"":""Cannot delete client because there are existing support tickets linked to this company. Please close/archive the tickets first.""}' AS result_json;
                RETURN;
            END

            -- Delete project members, projects and non-admin users for this tenant
            DELETE FROM support.project_members WHERE project_id IN (SELECT project_id FROM support.projects WHERE tenant_id = @v_del_tenant_id);
            DELETE FROM support.projects WHERE tenant_id = @v_del_tenant_id;
            DELETE FROM auth.user_roles WHERE user_id IN (SELECT user_id FROM auth.users WHERE tenant_id = @v_del_tenant_id);
            DELETE FROM auth.users WHERE tenant_id = @v_del_tenant_id;
            DELETE FROM support.tenants WHERE tenant_id = @v_del_tenant_id;

            SELECT '{""success"":true}' AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET USERS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_USERS'
        BEGIN
            SELECT ISNULL((
                SELECT
                    CAST(u.user_id AS NVARCHAR(36))             AS user_id,
                    u.username,
                    u.full_name,
                    r.role_id                                    AS [role],
                    CAST(u.tenant_id AS NVARCHAR(36))           AS tenant_id,
                    ISNULL(t.name,'Internal')                   AS tenant_name,
                    (SELECT TOP 1 CAST(pm.project_id AS NVARCHAR(36)) FROM support.project_members pm WHERE pm.user_id = u.user_id AND pm.is_active = 1) AS project_id,
                    (SELECT TOP 1 p.name FROM support.project_members pm JOIN support.projects p ON pm.project_id = p.project_id WHERE pm.user_id = u.user_id AND pm.is_active = 1) AS project_name,
                    (SELECT TOP 1 CAST(um.module_id AS NVARCHAR(36)) FROM support.user_modules um WHERE um.user_id = u.user_id) AS module_id,
                    (SELECT TOP 1 m.name FROM support.user_modules um JOIN support.project_modules m ON um.module_id = m.module_id WHERE um.user_id = u.user_id) AS module_name
                FROM auth.users u
                LEFT JOIN auth.user_roles r ON u.user_id = r.user_id
                LEFT JOIN support.tenants t ON u.tenant_id = t.tenant_id
                WHERE
                    (@v_role IN ('SuperAdmin','MD','SupportManager','ProjectManager'))
                    OR (
                        @v_role = 'ClientAdmin'
                        AND (u.tenant_id = @v_tenant_id OR @v_tenant_id IS NULL OR @v_tenant_id = '00000000-0000-0000-0000-000000000000')
                    )
                ORDER BY u.full_name
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CREATE USER (Employee Insert)
        -- --------------------------------------------------------
        IF @p_ProcID = 'CREATE_USER'
        BEGIN
            IF EXISTS (SELECT 1 FROM auth.users WHERE username = @p_Desc01)
            BEGIN
                SELECT '{""success"":false,""error"":""Username already exists""}' AS result_json;
                RETURN;
            END

            DECLARE @v_new_user_id UNIQUEIDENTIFIER = NEWID();
            DECLARE @v_user_tenant_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc05,'') AS UNIQUEIDENTIFIER);
            IF @v_user_tenant_id IS NULL OR NOT EXISTS (SELECT 1 FROM support.tenants WHERE tenant_id = @v_user_tenant_id)
                SET @v_user_tenant_id = '00000000-0000-0000-0000-000000000000';

            DECLARE @v_new_user_role NVARCHAR(50) = ISNULL(NULLIF(@p_Desc04,''), 'TeamMember');

            INSERT INTO auth.users (user_id, username, password_hash, full_name, tenant_id)
            VALUES (@v_new_user_id, @p_Desc01, @p_Desc02, @p_Desc03, @v_user_tenant_id);

            INSERT INTO auth.user_roles (user_id, role_id)
            VALUES (@v_new_user_id, @v_new_user_role);

            -- Optionally link to project
            IF @p_Desc06 IS NOT NULL AND @p_Desc06 <> ''
            BEGIN
                DECLARE @v_link_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc06 AS UNIQUEIDENTIFIER);
                IF @v_link_proj_id IS NOT NULL AND EXISTS (SELECT 1 FROM support.projects WHERE project_id = @v_link_proj_id)
                BEGIN
                    DECLARE @v_assign_proj_role NVARCHAR(50) = CASE WHEN @v_new_user_role = 'ProjectManager' THEN 'PROJECT_MANAGER' ELSE 'TEAM_MEMBER' END;
                    IF NOT EXISTS (SELECT 1 FROM support.project_members WHERE project_id = @v_link_proj_id AND user_id = @v_new_user_id)
                        INSERT INTO support.project_members (project_id, user_id, role_code, is_active)
                        VALUES (@v_link_proj_id, @v_new_user_id, @v_assign_proj_role, 1);
                    
                    -- Module Assignment for this user in this project
                    IF @p_Desc07 IS NOT NULL AND @p_Desc07 <> ''
                    BEGIN
                        DECLARE @v_cu_mod_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc07 AS UNIQUEIDENTIFIER);
                        IF @v_cu_mod_id IS NOT NULL AND EXISTS (SELECT 1 FROM support.project_modules WHERE module_id = @v_cu_mod_id)
                        BEGIN
                            DELETE FROM support.user_modules WHERE user_id = @v_new_user_id;
                            INSERT INTO support.user_modules (user_id, module_id, project_id)
                            VALUES (@v_new_user_id, @v_cu_mod_id, @v_link_proj_id);
                        END
                    END
                END
            END

            SELECT (
                SELECT CAST(1 AS BIT) AS success, CAST(@v_new_user_id AS NVARCHAR(36)) AS user_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- UPDATE USER (Employee Update / Password Change)
        -- --------------------------------------------------------
        IF @p_ProcID = 'UPDATE_USER'
        BEGIN
            DECLARE @v_edit_user_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc01,'') AS UNIQUEIDENTIFIER);
            DECLARE @v_edit_tenant UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc05,'') AS UNIQUEIDENTIFIER);
            DECLARE @v_new_pwd NVARCHAR(255) = NULLIF(@p_Desc06,'');

            UPDATE auth.users
            SET full_name = ISNULL(NULLIF(@p_Desc02,''), full_name),
                tenant_id = ISNULL(@v_edit_tenant, tenant_id),
                password_hash = ISNULL(@v_new_pwd, password_hash)
            WHERE user_id = @v_edit_user_id;

            -- Update role if provided
            IF @p_Desc03 IS NOT NULL AND @p_Desc03 <> ''
            BEGIN
                DELETE FROM auth.user_roles WHERE user_id = @v_edit_user_id;
                INSERT INTO auth.user_roles (user_id, role_id) VALUES (@v_edit_user_id, @p_Desc03);
            END

            -- Optionally update or add project assignment if provided
            IF @p_Desc07 IS NOT NULL AND @p_Desc07 <> ''
            BEGIN
                DECLARE @v_edit_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc07 AS UNIQUEIDENTIFIER);
                IF @v_edit_proj_id IS NOT NULL AND EXISTS (SELECT 1 FROM support.projects WHERE project_id = @v_edit_proj_id)
                BEGIN
                    DECLARE @v_up_role NVARCHAR(50) = CASE WHEN @p_Desc03 = 'ProjectManager' THEN 'PROJECT_MANAGER' ELSE 'TEAM_MEMBER' END;
                    IF NOT EXISTS (SELECT 1 FROM support.project_members WHERE project_id = @v_edit_proj_id AND user_id = @v_edit_user_id)
                        INSERT INTO support.project_members (project_id, user_id, role_code, is_active)
                        VALUES (@v_edit_proj_id, @v_edit_user_id, @v_up_role, 1);
                    ELSE
                        UPDATE support.project_members SET role_code = @v_up_role, is_active = 1
                        WHERE project_id = @v_edit_proj_id AND user_id = @v_edit_user_id;

                    -- Module Assignment for this user in this project
                    IF @p_Desc08 IS NOT NULL AND @p_Desc08 <> ''
                    BEGIN
                        DECLARE @v_uu_mod_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc08 AS UNIQUEIDENTIFIER);
                        IF @v_uu_mod_id IS NOT NULL AND EXISTS (SELECT 1 FROM support.project_modules WHERE module_id = @v_uu_mod_id)
                        BEGIN
                            DELETE FROM support.user_modules WHERE user_id = @v_edit_user_id;
                            INSERT INTO support.user_modules (user_id, module_id, project_id)
                            VALUES (@v_edit_user_id, @v_uu_mod_id, @v_edit_proj_id);
                        END
                    END
                END
            END

            SELECT (
                SELECT CAST(1 AS BIT) AS success
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET TEAM MEMBERS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_TEAM_MEMBERS'
        BEGIN
            DECLARE @v_gtm_proj_id UNIQUEIDENTIFIER = NULL;
            IF @p_Desc01 IS NOT NULL AND @p_Desc01 <> ''
            BEGIN
                SELECT @v_gtm_proj_id = project_id FROM support.tickets WHERE ticket_number = @p_Desc01;
                IF @v_gtm_proj_id IS NULL
                    SET @v_gtm_proj_id = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            END

            IF @v_gtm_proj_id IS NOT NULL AND EXISTS (SELECT 1 FROM support.project_members WHERE project_id = @v_gtm_proj_id AND is_active = 1)
            BEGIN
                SELECT ISNULL((
                    SELECT
                        CAST(u.user_id AS NVARCHAR(36)) AS user_id,
                        u.full_name,
                        pm.role_code AS [role]
                    FROM support.project_members pm
                    JOIN auth.users u ON pm.user_id = u.user_id
                    WHERE pm.project_id = @v_gtm_proj_id AND pm.is_active = 1
                    ORDER BY pm.role_code DESC, u.full_name
                    FOR JSON PATH
                ), '[]') AS result_json;
                RETURN;
            END
            ELSE
            BEGIN
                SELECT ISNULL((
                    SELECT
                        CAST(u.user_id AS NVARCHAR(36)) AS user_id,
                        u.full_name,
                        r.role_id AS [role]
                    FROM auth.users u
                    JOIN auth.user_roles r ON u.user_id = r.user_id
                    WHERE r.role_id IN ('SuperAdmin','MD','SupportManager','ProjectManager','TeamMember')
                    ORDER BY u.full_name
                    FOR JSON PATH
                ), '[]') AS result_json;
                RETURN;
            END
        END

        -- --------------------------------------------------------
        -- DASHBOARD
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_DASHBOARD'
        BEGIN
            SELECT (
                SELECT
                    (SELECT COUNT(*) FROM support.tickets WHERE [status] = 'NEW')           AS new_tickets,
                    (SELECT COUNT(*) FROM support.tasks   WHERE [status] = 'IN_PROGRESS')   AS in_progress,
                    (SELECT COUNT(*) FROM support.tasks   WHERE [status] = 'TODO')          AS pending,
                    (SELECT COUNT(*) FROM support.tasks   WHERE [status] = 'COMPLETED')     AS resolved,
                    (SELECT COUNT(*) FROM support.tickets WHERE sla_due_at < GETDATE() AND [status] != 'CLOSED') AS breached,
                    (SELECT COUNT(DISTINCT ticket_id) FROM support.ticket_comments)         AS active_conversations,
                    '5m'                                                                     AS wait_time,
                    CAST(COALESCE(NULLIF((SELECT COUNT(*) FROM auth.users u JOIN auth.user_roles r ON u.user_id = r.user_id WHERE r.role_id IN ('TeamMember','ProjectManager','SupportManager','SuperAdmin','MD') AND u.is_active = 1 AND u.last_login_at >= DATEADD(minute, -30, GETDATE())), 0), 1) AS INT) AS agents_online,
                    CAST(CASE 
                        WHEN (SELECT COUNT(*) FROM support.tickets) = 0 THEN 100.0 
                        ELSE ((SELECT COUNT(*) FROM support.tickets WHERE sla_due_at IS NULL OR sla_due_at >= GETDATE() OR [status] IN ('CLOSED','RESOLVED')) * 100.0 / NULLIF((SELECT COUNT(*) FROM support.tickets), 0))
                    END AS DECIMAL(5,1)) AS sla_health
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- EXECUTIVE REPORTS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_REPORTS'
        BEGIN
            SELECT (
                SELECT
                    (SELECT COUNT(*) FROM support.tenants WHERE tenant_id != '00000000-0000-0000-0000-000000000000') AS total_clients,
                    (SELECT COUNT(*) FROM support.projects) AS total_projects,
                    (SELECT COUNT(*) FROM support.tickets) AS total_tickets,
                    (SELECT COUNT(*) FROM support.tickets WHERE [status] IN ('CLOSED', 'RESOLVED')) AS resolved_tickets,
                    CAST(CASE 
                        WHEN (SELECT COUNT(*) FROM support.tickets) = 0 THEN 100.0 
                        ELSE ((SELECT COUNT(*) FROM support.tickets WHERE sla_due_at IS NULL OR sla_due_at >= GETDATE() OR [status] IN ('CLOSED','RESOLVED')) * 100.0 / NULLIF((SELECT COUNT(*) FROM support.tickets),0))
                    END AS DECIMAL(5,1)) AS sla_compliance_rate,
                    JSON_QUERY((
                        SELECT
                            (SELECT COUNT(*) FROM support.tickets WHERE priority = 'CRITICAL') AS [CRITICAL],
                            (SELECT COUNT(*) FROM support.tickets WHERE priority = 'HIGH')     AS [HIGH],
                            (SELECT COUNT(*) FROM support.tickets WHERE priority = 'MEDIUM')   AS [MEDIUM],
                            (SELECT COUNT(*) FROM support.tickets WHERE priority = 'LOW')      AS [LOW]
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )) AS tickets_by_priority,
                    JSON_QUERY((
                        SELECT
                            ISNULL(t.name, 'Internal') AS client_name,
                            t.code AS client_code,
                            (SELECT COUNT(*) FROM support.projects p WHERE p.tenant_id = t.tenant_id) AS active_projects,
                            (SELECT COUNT(*) FROM support.tickets tk WHERE tk.tenant_id = t.tenant_id) AS total_tickets,
                            (SELECT COUNT(*) FROM support.tickets tk WHERE tk.tenant_id = t.tenant_id AND tk.[status] NOT IN ('CLOSED', 'RESOLVED')) AS open_tickets,
                            CASE WHEN t.is_active = 1 THEN 'Active' ELSE 'Inactive' END AS [status]
                        FROM support.tenants t
                        WHERE t.tenant_id != '00000000-0000-0000-0000-000000000000'
                        ORDER BY t.name
                        FOR JSON PATH
                    )) AS client_summary,
                    JSON_QUERY((
                        SELECT
                            u.full_name,
                            (SELECT COUNT(*) FROM support.tasks ts WHERE ts.assigned_to = u.user_id) AS tasks_assigned,
                            (SELECT COUNT(*) FROM support.tasks ts WHERE ts.assigned_to = u.user_id AND ts.[status] IN ('COMPLETED', 'APPROVED')) AS tasks_completed
                        FROM auth.users u
                        JOIN auth.user_roles r ON u.user_id = r.user_id
                        WHERE r.role_id IN ('TeamMember', 'ProjectManager') AND u.is_active = 1
                        ORDER BY tasks_assigned DESC, u.full_name
                        FOR JSON PATH
                    )) AS team_performance
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET PROJECTS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_PROJECTS'
        BEGIN
            SELECT ISNULL((
                SELECT
                    CAST(p.project_id AS NVARCHAR(36)) AS project_id,
                    p.code,
                    p.name,
                    CAST(p.tenant_id AS NVARCHAR(36)) AS tenant_id,
                    ISNULL(t.name, 'Internal') AS tenant_name,
                    ISNULL((SELECT TOP 1 u.full_name FROM support.project_members pm JOIN auth.users u ON pm.user_id = u.user_id WHERE pm.project_id = p.project_id AND pm.role_code = 'PROJECT_MANAGER' AND pm.is_active = 1), 'Unassigned') AS pm_name,
                    ISNULL((SELECT COUNT(*) FROM support.tickets tk WHERE tk.project_id = p.project_id), 0) AS ticket_count,
                    ISNULL((SELECT COUNT(*) FROM support.tasks tsk JOIN support.tickets tk ON tsk.ticket_id = tk.ticket_id WHERE tk.project_id = p.project_id), 0) AS task_count,
                    CAST(CASE 
                        WHEN (SELECT COUNT(*) FROM support.tasks tsk JOIN support.tickets tk ON tsk.ticket_id = tk.ticket_id WHERE tk.project_id = p.project_id) = 0 THEN 0
                        ELSE (SELECT COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM support.tasks tsk2 JOIN support.tickets tk2 ON tsk2.ticket_id = tk2.ticket_id WHERE tk2.project_id = p.project_id), 0)
                              FROM support.tasks tsk JOIN support.tickets tk ON tsk.ticket_id = tk.ticket_id WHERE tk.project_id = p.project_id AND tsk.[status] IN ('COMPLETED', 'APPROVED'))
                    END AS DECIMAL(5,1)) AS progress_percent
                FROM support.projects p
                LEFT JOIN support.tenants t ON p.tenant_id = t.tenant_id
                WHERE
                    (@v_role IN ('SuperAdmin','MD','SupportManager'))
                    OR (@v_role IN ('ClientAdmin', 'ClientUser') AND (p.tenant_id = @v_tenant_id OR @v_tenant_id IS NULL OR @v_tenant_id = '00000000-0000-0000-0000-000000000000'))
                    OR (@v_role = 'TeamMember' AND (p.tenant_id = @v_tenant_id OR @v_tenant_id = '00000000-0000-0000-0000-000000000000' OR EXISTS (SELECT 1 FROM support.project_members pm WHERE pm.project_id = p.project_id AND pm.user_id = @v_user_id)))
                    OR EXISTS (
                        SELECT 1 FROM support.project_members pm
                        WHERE pm.project_id = p.project_id AND pm.user_id = @v_user_id
                    )
                ORDER BY p.name
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CREATE PROJECT
        -- --------------------------------------------------------
        IF @p_ProcID = 'CREATE_PROJECT'
        BEGIN
            DECLARE @v_new_proj_id UNIQUEIDENTIFIER = NEWID();
            DECLARE @v_proj_tenant_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_ComCod,'') AS UNIQUEIDENTIFIER);
            IF @v_proj_tenant_id IS NULL OR NOT EXISTS (SELECT 1 FROM support.tenants WHERE tenant_id = @v_proj_tenant_id)
                SET @v_proj_tenant_id = '00000000-0000-0000-0000-000000000000';

            INSERT INTO support.projects (project_id, code, name, tenant_id)
            VALUES (@v_new_proj_id, @p_Desc01, @p_Desc02, @v_proj_tenant_id);

            -- Automatically add creator as PROJECT_MANAGER if PM role
            IF @v_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE user_id = @v_user_id)
            BEGIN
                INSERT INTO support.project_members (project_id, user_id, role_code, is_active)
                VALUES (@v_new_proj_id, @v_user_id, 'PROJECT_MANAGER', 1);
            END

            SELECT (
                SELECT CAST(1 AS BIT) AS success, CAST(@v_new_proj_id AS NVARCHAR(36)) AS project_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- UPDATE PROJECT
        -- --------------------------------------------------------
        IF @p_ProcID = 'UPDATE_PROJECT'
        BEGIN
            DECLARE @v_up_proj_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc01,'') AS UNIQUEIDENTIFIER);
            DECLARE @v_up_proj_tenant UNIQUEIDENTIFIER = COALESCE(TRY_CAST(NULLIF(@p_Desc04,'') AS UNIQUEIDENTIFIER), TRY_CAST(NULLIF(@p_ComCod,'') AS UNIQUEIDENTIFIER));

            UPDATE support.projects
            SET code = ISNULL(NULLIF(@p_Desc02,''), code),
                name = ISNULL(NULLIF(@p_Desc03,''), name),
                tenant_id = ISNULL(@v_up_proj_tenant, tenant_id)
            WHERE project_id = @v_up_proj_id;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- ASSIGN TEAM MEMBER TO PROJECT
        -- --------------------------------------------------------
        IF @p_ProcID = 'ASSIGN_TEAM_MEMBER'
        BEGIN
            DECLARE @v_at_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            DECLARE @v_at_user_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc02 AS UNIQUEIDENTIFIER);

            IF NOT EXISTS (SELECT 1 FROM support.project_members WHERE project_id=@v_at_proj_id AND user_id=@v_at_user_id)
                INSERT INTO support.project_members (project_id, user_id, role_code, is_active)
                VALUES (@v_at_proj_id, @v_at_user_id, 'TEAM_MEMBER', 1);
            ELSE
                UPDATE support.project_members SET role_code = 'TEAM_MEMBER', is_active = 1
                WHERE project_id=@v_at_proj_id AND user_id=@v_at_user_id;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- ASSIGN PROJECT MANAGER
        -- --------------------------------------------------------
        IF @p_ProcID = 'ASSIGN_PM'
        BEGIN
            DECLARE @v_apm_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            DECLARE @v_apm_user_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc02 AS UNIQUEIDENTIFIER);

            -- Demote any previous PROJECT_MANAGER on this project to TEAM_MEMBER
            UPDATE support.project_members 
            SET role_code = 'TEAM_MEMBER' 
            WHERE project_id = @v_apm_proj_id AND role_code = 'PROJECT_MANAGER';

            IF NOT EXISTS (SELECT 1 FROM support.project_members WHERE project_id=@v_apm_proj_id AND user_id=@v_apm_user_id)
                INSERT INTO support.project_members (project_id, user_id, role_code, is_active)
                VALUES (@v_apm_proj_id, @v_apm_user_id, 'PROJECT_MANAGER', 1);
            ELSE
                UPDATE support.project_members SET role_code = 'PROJECT_MANAGER', is_active = 1
                WHERE project_id=@v_apm_proj_id AND user_id=@v_apm_user_id;

            -- Also update open tickets for this project to be assigned to this PM
            UPDATE support.tickets
            SET assigned_to = @v_apm_user_id
            WHERE project_id = @v_apm_proj_id AND [status] IN ('NEW', 'ASSIGNED', 'IN_PROGRESS');

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- REASSIGN TICKET PM / ASSIGNEE
        -- --------------------------------------------------------
        IF @p_ProcID = 'ASSIGN_TICKET_PM'
        BEGIN
            DECLARE @v_atpm_user_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc02,'') AS UNIQUEIDENTIFIER);
            UPDATE support.tickets
            SET assigned_to = @v_atpm_user_id,
                [status] = CASE WHEN [status] = 'NEW' THEN 'ASSIGNED' ELSE [status] END
            WHERE ticket_number = @p_Desc01;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- REMOVE PROJECT MEMBER
        -- --------------------------------------------------------
        IF @p_ProcID = 'REMOVE_PROJECT_MEMBER'
        BEGIN
            DECLARE @v_rpm_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            DECLARE @v_rpm_user_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc02 AS UNIQUEIDENTIFIER);

            DELETE FROM support.project_members
            WHERE project_id = @v_rpm_proj_id AND user_id = @v_rpm_user_id;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET PROJECT MEMBERS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_PROJECT_MEMBERS'
        BEGIN
            DECLARE @v_gpm_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            SELECT ISNULL((
                SELECT
                    CAST(pm.user_id AS NVARCHAR(36)) AS user_id,
                    u.full_name,
                    u.username,
                    r.role_id AS system_role,
                    pm.role_code AS [role],
                    CASE 
                        WHEN pm.role_code = 'PROJECT_MANAGER' THEN 'Project Manager'
                        WHEN r.role_id IN ('ClientAdmin', 'ClientUser') THEN 'Client Representative (' + r.role_id + ')'
                        ELSE 'Developer / Team Member'
                    END AS project_role_display,
                    CASE WHEN r.role_id IN ('ClientAdmin', 'ClientUser') THEN 1 ELSE 0 END AS is_client_user,
                    (SELECT TOP 1 m.name FROM support.user_modules um JOIN support.project_modules m ON um.module_id = m.module_id WHERE um.user_id = u.user_id AND um.project_id = @v_gpm_proj_id) AS module_name
                FROM support.project_members pm
                JOIN auth.users u ON pm.user_id = u.user_id
                LEFT JOIN auth.user_roles r ON u.user_id = r.user_id
                WHERE pm.project_id = @v_gpm_proj_id AND pm.is_active = 1
                ORDER BY pm.role_code DESC, u.full_name
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET TICKETS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_TICKETS'
        BEGIN
            SELECT ISNULL((
                SELECT
                    t.ticket_number,
                    t.subject,
                    t.priority,
                    t.[status],
                    CONVERT(NVARCHAR(30), t.created_at, 126) AS created_at,
                    CONVERT(NVARCHAR(30), t.sla_due_at, 126) AS sla_due_at,
                    ISNULL(t.progress_percent, 0.0) AS progress_percent,
                    ISNULL(p.name, 'Internal') AS project_name,
                    ISNULL(m.name, 'General') AS module_name,
                    CAST(t.module_id AS NVARCHAR(36)) AS module_id,
                    ISNULL(u.full_name, 'Unknown') AS created_by_name,
                    ISNULL(pm_u.full_name, 'Unassigned') AS assigned_to_name
                FROM support.tickets t
                LEFT JOIN support.projects p ON t.project_id = p.project_id
                LEFT JOIN support.project_modules m ON t.module_id = m.module_id
                LEFT JOIN auth.users u ON t.created_by = u.user_id
                LEFT JOIN auth.users pm_u ON t.assigned_to = pm_u.user_id
                WHERE
                    (@v_role IN ('SuperAdmin','MD','SupportManager'))
                    OR (@v_role = 'ProjectManager' AND (
                        t.assigned_to = @v_user_id
                        OR EXISTS (SELECT 1 FROM support.project_members pm WHERE pm.project_id = t.project_id AND pm.user_id = @v_user_id)
                    ))
                    OR (@v_role = 'TeamMember' AND (
                        t.created_by = @v_user_id
                        OR EXISTS (SELECT 1 FROM support.project_members pm WHERE pm.project_id = t.project_id AND pm.user_id = @v_user_id)
                    ))
                    OR (@v_role IN ('ClientAdmin', 'ClientUser') AND (t.tenant_id = @v_tenant_id OR @v_tenant_id IS NULL OR @v_tenant_id = '00000000-0000-0000-0000-000000000000'))
                ORDER BY t.created_at DESC
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET MY TICKETS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_MY_TICKETS'
        BEGIN
            SELECT ISNULL((
                SELECT
                    t.ticket_number,
                    t.subject,
                    t.priority,
                    t.[status],
                    CONVERT(NVARCHAR(30), t.created_at, 126) AS created_at,
                    CONVERT(NVARCHAR(30), t.sla_due_at, 126) AS sla_due_at,
                    ISNULL(t.progress_percent, 0.0) AS progress_percent,
                    ISNULL(p.name, 'Internal') AS project_name,
                    ISNULL(m.name, 'General') AS module_name,
                    CAST(t.module_id AS NVARCHAR(36)) AS module_id,
                    ISNULL(pm_u.full_name, 'Unassigned') AS assigned_to_name
                FROM support.tickets t
                LEFT JOIN support.projects p ON t.project_id = p.project_id
                LEFT JOIN support.project_modules m ON t.module_id = m.module_id
                LEFT JOIN auth.users pm_u ON t.assigned_to = pm_u.user_id
                WHERE (t.created_by = @v_user_id)
                   OR (t.tenant_id = @v_tenant_id AND @v_tenant_id != '00000000-0000-0000-0000-000000000000')
                   OR (@v_role IN ('SuperAdmin','MD','SupportManager'))
                ORDER BY t.created_at DESC
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET TICKET DETAILS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_TICKET_DETAILS'
        BEGIN
            SELECT (
                SELECT
                    t.ticket_number,
                    t.subject,
                    t.[status],
                    t.priority,
                    CONVERT(NVARCHAR(30), t.created_at, 126) AS created_at,
                    CONVERT(NVARCHAR(30), t.sla_due_at, 126) AS sla_due_at,
                    ISNULL(t.progress_percent, 0.0) AS progress_percent,
                    ISNULL(p.name, 'Internal') AS project_name,
                    ISNULL(m.name, 'General') AS module_name,
                    CAST(t.module_id AS NVARCHAR(36)) AS module_id,
                    ISNULL(u.full_name, 'Unknown') AS created_by_name,
                    ISNULL(pm_u.full_name, 'Unassigned') AS assigned_to_name,
                    CAST(t.assigned_to AS NVARCHAR(36)) AS assigned_to_id,
                    ISNULL(JSON_VALUE(t.ticketginf, '$.detailed_description'), '') AS [description],
                    (SELECT ts.task_id, ts.name, ts.[status], ISNULL(tu.full_name, 'Unassigned') AS assigned_to_name
                     FROM support.tasks ts
                     LEFT JOIN auth.users tu ON ts.assigned_to = tu.user_id
                     WHERE ts.ticket_id = t.ticket_id FOR JSON PATH) AS tasks,
                    (SELECT c.comment_text, CONVERT(NVARCHAR(30),c.created_at,126) AS created_at, u.full_name AS user_name
                     FROM support.ticket_comments c
                     JOIN auth.users u ON c.user_id = u.user_id
                     WHERE c.ticket_id = t.ticket_id FOR JSON PATH) AS comments
                FROM support.tickets t
                LEFT JOIN support.projects p ON t.project_id = p.project_id
                LEFT JOIN support.project_modules m ON t.module_id = m.module_id
                LEFT JOIN auth.users u ON t.created_by = u.user_id
                LEFT JOIN auth.users pm_u ON t.assigned_to = pm_u.user_id
                WHERE t.ticket_number = @p_Desc01
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CREATE TICKET
        -- --------------------------------------------------------
        IF @p_ProcID = 'CREATE_TICKET'
        BEGIN
            DECLARE @v_ticket_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            DECLARE @v_pcode NVARCHAR(20) = 'PRJ';
            SELECT @v_pcode = code FROM support.projects WHERE project_id = @v_ticket_proj_id;

            DECLARE @v_pm_user_id UNIQUEIDENTIFIER = NULL;
            SELECT TOP 1 @v_pm_user_id = user_id
            FROM support.project_members
            WHERE project_id = @v_ticket_proj_id AND role_code = 'PROJECT_MANAGER' AND is_active = 1;

            DECLARE @v_init_status NVARCHAR(50) = CASE WHEN @v_pm_user_id IS NOT NULL THEN 'ASSIGNED' ELSE 'NEW' END;

            DECLARE @v_t_seq INT;
            SELECT @v_t_seq = COUNT(*) + 1 FROM support.tickets WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE);

            DECLARE @v_ticket_num NVARCHAR(50) = @v_pcode + '-' + CONVERT(NVARCHAR(8), GETDATE(), 112) + '-' + RIGHT('000000' + CAST(@v_t_seq AS NVARCHAR), 6);

            DECLARE @v_sla_hours INT = CASE @p_Desc03
                WHEN 'CRITICAL' THEN 2
                WHEN 'HIGH'     THEN 4
                WHEN 'MEDIUM'   THEN 24
                ELSE 72
            END;

            DECLARE @v_ticket_id UNIQUEIDENTIFIER = NEWID();

            DECLARE @v_ticket_module_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc07,'') AS UNIQUEIDENTIFIER);
            IF @v_ticket_module_id IS NULL AND @p_Djson1 IS NOT NULL
            BEGIN
                SET @v_ticket_module_id = TRY_CAST(NULLIF(JSON_VALUE(@p_Djson1, '$.module_id'),'') AS UNIQUEIDENTIFIER);
            END

            INSERT INTO support.tickets (
                ticket_id, tenant_id, project_id, module_id, ticket_number, subject, [status], priority,
                sla_due_at, ticketginf, created_by, assigned_to, progress_percent
            ) VALUES (
                @v_ticket_id, @v_tenant_id, @v_ticket_proj_id, @v_ticket_module_id, @v_ticket_num, @p_Desc02, @v_init_status, @p_Desc03,
                DATEADD(hour, @v_sla_hours, GETDATE()), @p_Djson1, @v_user_id, @v_pm_user_id, 0.0
            );

            SELECT (
                SELECT CAST(1 AS BIT) AS success, @v_ticket_num AS ticket_number, CAST(@v_ticket_id AS NVARCHAR(36)) AS ticket_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CREATE TASK
        -- --------------------------------------------------------
        IF @p_ProcID = 'CREATE_TASK'
        BEGIN
            DECLARE @v_new_task_id NVARCHAR(50) = 'TSK-' + CAST(ABS(CHECKSUM(NEWID())) % 90000 + 10000 AS NVARCHAR);
            DECLARE @v_ct_ticket_id UNIQUEIDENTIFIER;

            SELECT @v_ct_ticket_id = ticket_id FROM support.tickets WHERE ticket_number = @p_Desc01;

            INSERT INTO support.tasks (task_id, ticket_id, name, [status], assigned_to)
            VALUES (@v_new_task_id, @v_ct_ticket_id, @p_Desc02, 'TODO', TRY_CAST(NULLIF(@p_Desc03,'') AS UNIQUEIDENTIFIER));

            -- Transition ticket to IN_PROGRESS if NEW or ASSIGNED
            UPDATE support.tickets
            SET [status] = CASE WHEN [status] IN ('NEW', 'ASSIGNED') THEN 'IN_PROGRESS' ELSE [status] END
            WHERE ticket_id = @v_ct_ticket_id;

            -- Recalculate ticket progress percentage
            DECLARE @v_t_total INT, @v_t_comp INT;
            SELECT @v_t_total = COUNT(*),
                   @v_t_comp = COUNT(CASE WHEN [status] IN ('COMPLETED', 'APPROVED') THEN 1 END)
            FROM support.tasks WHERE ticket_id = @v_ct_ticket_id;

            UPDATE support.tickets
            SET progress_percent = CASE WHEN @v_t_total = 0 THEN 0.0 ELSE CAST((@v_t_comp * 100.0 / @v_t_total) AS DECIMAL(5,1)) END
            WHERE ticket_id = @v_ct_ticket_id;

            SELECT (
                SELECT CAST(1 AS BIT) AS success, @v_new_task_id AS task_id
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- UPDATE TASK STATUS
        -- --------------------------------------------------------
        IF @p_ProcID = 'UPDATE_TASK_STATUS'
        BEGIN
            UPDATE support.tasks SET [status] = @p_Desc02 WHERE task_id = @p_Desc01;

            DECLARE @v_parent_ticket_id UNIQUEIDENTIFIER;
            SELECT @v_parent_ticket_id = ticket_id FROM support.tasks WHERE task_id = @p_Desc01;

            IF @v_parent_ticket_id IS NOT NULL
            BEGIN
                DECLARE @v_tot_tasks INT, @v_done_tasks INT;
                SELECT @v_tot_tasks = COUNT(*),
                       @v_done_tasks = COUNT(CASE WHEN [status] IN ('COMPLETED', 'APPROVED') THEN 1 END)
                FROM support.tasks WHERE ticket_id = @v_parent_ticket_id;

                DECLARE @v_calc_prog DECIMAL(5,1) = CASE WHEN @v_tot_tasks = 0 THEN 0.0 ELSE CAST((@v_done_tasks * 100.0 / @v_tot_tasks) AS DECIMAL(5,1)) END;

                IF @v_tot_tasks > 0 AND @v_done_tasks = @v_tot_tasks
                BEGIN
                    UPDATE support.tickets
                    SET [status] = 'CLOSED', progress_percent = 100.0
                    WHERE ticket_id = @v_parent_ticket_id;
                END
                ELSE
                BEGIN
                    UPDATE support.tickets
                    SET progress_percent = @v_calc_prog,
                        [status] = CASE WHEN [status] = 'CLOSED' THEN 'IN_PROGRESS' 
                                        WHEN [status] IN ('NEW', 'ASSIGNED') THEN 'IN_PROGRESS' 
                                        ELSE [status] END
                    WHERE ticket_id = @v_parent_ticket_id;
                END
            END

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- APPROVE TASK (PM Action)
        -- --------------------------------------------------------
        IF @p_ProcID = 'APPROVE_TASK'
        BEGIN
            UPDATE support.tasks SET [status] = 'APPROVED' WHERE task_id = @p_Desc01;

            DECLARE @v_appr_ticket_id UNIQUEIDENTIFIER;
            SELECT @v_appr_ticket_id = ticket_id FROM support.tasks WHERE task_id = @p_Desc01;

            IF @v_appr_ticket_id IS NOT NULL
            BEGIN
                DECLARE @v_at_tot INT, @v_at_done INT;
                SELECT @v_at_tot = COUNT(*),
                       @v_at_done = COUNT(CASE WHEN [status] IN ('COMPLETED', 'APPROVED') THEN 1 END)
                FROM support.tasks WHERE ticket_id = @v_appr_ticket_id;

                DECLARE @v_appr_prog DECIMAL(5,1) = CASE WHEN @v_at_tot = 0 THEN 0.0 ELSE CAST((@v_at_done * 100.0 / @v_at_tot) AS DECIMAL(5,1)) END;

                IF @v_at_tot > 0 AND @v_at_done = @v_at_tot
                BEGIN
                    UPDATE support.tickets
                    SET [status] = 'CLOSED', progress_percent = 100.0
                    WHERE ticket_id = @v_appr_ticket_id;
                END
                ELSE
                BEGIN
                    UPDATE support.tickets
                    SET progress_percent = @v_appr_prog
                    WHERE ticket_id = @v_appr_ticket_id;
                END
            END

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- REJECT TASK (PM Action)
        -- --------------------------------------------------------
        IF @p_ProcID = 'REJECT_TASK'
        BEGIN
            UPDATE support.tasks
            SET [status] = 'REJECTED',
                rejection_reason = @p_Desc02,
                taskginf = JSON_MODIFY(ISNULL(taskginf,'{}'), '$.rejection_reason', @p_Desc02)
            WHERE task_id = @p_Desc01;

            DECLARE @v_rej_ticket_id UNIQUEIDENTIFIER;
            SELECT @v_rej_ticket_id = ticket_id FROM support.tasks WHERE task_id = @p_Desc01;

            IF @v_rej_ticket_id IS NOT NULL
            BEGIN
                DECLARE @v_rt_tot INT, @v_rt_done INT;
                SELECT @v_rt_tot = COUNT(*),
                       @v_rt_done = COUNT(CASE WHEN [status] IN ('COMPLETED', 'APPROVED') THEN 1 END)
                FROM support.tasks WHERE ticket_id = @v_rej_ticket_id;

                DECLARE @v_rej_prog DECIMAL(5,1) = CASE WHEN @v_rt_tot = 0 THEN 0.0 ELSE CAST((@v_rt_done * 100.0 / @v_rt_tot) AS DECIMAL(5,1)) END;

                UPDATE support.tickets
                SET progress_percent = @v_rej_prog,
                    [status] = CASE WHEN [status] = 'CLOSED' THEN 'IN_PROGRESS' ELSE [status] END
                WHERE ticket_id = @v_rej_ticket_id;
            END

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- ADD COMMENT
        -- --------------------------------------------------------
        IF @p_ProcID = 'ADD_COMMENT'
        BEGIN
            INSERT INTO support.ticket_comments (ticket_id, user_id, comment_text)
            SELECT ticket_id, @v_user_id, @p_Desc02 FROM support.tickets WHERE ticket_number = @p_Desc01;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- UPDATE TICKET STATUS
        -- --------------------------------------------------------
        IF @p_ProcID = 'UPDATE_TICKET_STATUS'
        BEGIN
            UPDATE support.tickets
            SET [status] = @p_Desc02,
                progress_percent = CASE WHEN @p_Desc02 = 'CLOSED' THEN 100.0 ELSE progress_percent END
            WHERE ticket_number = @p_Desc01;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CLOSE TICKET
        -- --------------------------------------------------------
        IF @p_ProcID = 'CLOSE_TICKET'
        BEGIN
            UPDATE support.tickets
            SET [status] = 'CLOSED', progress_percent = 100.0
            WHERE ticket_number = @p_Desc01;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET TASKS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_TASKS'
        BEGIN
            SELECT ISNULL((
                SELECT
                    ts.task_id,
                    ts.name,
                    ts.[status],
                    ISNULL(u.full_name,'Unassigned') AS assigned_to,
                    t.ticket_number
                FROM support.tasks ts
                LEFT JOIN auth.users u ON ts.assigned_to = u.user_id
                LEFT JOIN support.tickets t ON ts.ticket_id = t.ticket_id
                WHERE
                    (@v_role IN ('SuperAdmin','MD','SupportManager'))
                    OR (@v_role = 'ProjectManager' AND (
                        ts.assigned_to = @v_user_id
                        OR t.assigned_to = @v_user_id
                        OR EXISTS (SELECT 1 FROM support.project_members pm WHERE pm.project_id = t.project_id AND pm.user_id = @v_user_id)
                    ))
                    OR (@v_role = 'TeamMember' AND ts.assigned_to = @v_user_id)
                ORDER BY ts.created_at DESC
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- GET TASK DETAILS
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_TASK_DETAILS'
        BEGIN
            SELECT (
                SELECT
                    ts.task_id,
                    ts.name,
                    ts.[status],
                    ISNULL(ts.rejection_reason, JSON_VALUE(ts.taskginf, '$.rejection_reason')) AS rejection_reason,
                    ISNULL(u.full_name,'Unassigned') AS assigned_to,
                    t.ticket_number,
                    (SELECT w.hours_spent AS hours, w.hours_spent, CONVERT(NVARCHAR(10), w.log_date, 120) AS [date], CONVERT(NVARCHAR(10), w.log_date, 120) AS log_date, w.description
                     FROM support.work_logs w WHERE w.task_id = ts.task_id FOR JSON PATH) AS work_logs
                FROM support.tasks ts
                LEFT JOIN auth.users u ON ts.assigned_to = u.user_id
                LEFT JOIN support.tickets t ON ts.ticket_id = t.ticket_id
                WHERE ts.task_id = @p_Desc01
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- ADD WORK LOG
        -- --------------------------------------------------------
        IF @p_ProcID = 'ADD_WORK_LOG'
        BEGIN
            INSERT INTO support.work_logs (task_id, user_id, hours_spent, log_date, description)
            VALUES (@p_Desc01, @v_user_id, TRY_CAST(@p_Desc02 AS DECIMAL(5,2)), TRY_CAST(@p_Desc03 AS DATE), @p_Desc06);

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- FILE OPERATIONS: UPLOAD_FILE & GET_FILES
        -- --------------------------------------------------------
        IF @p_ProcID = 'UPLOAD_FILE'
        BEGIN
            DECLARE @v_f_ticket_id UNIQUEIDENTIFIER;
            SELECT @v_f_ticket_id = ticket_id FROM support.tickets WHERE ticket_number = @p_Desc01;
            IF @v_f_ticket_id IS NOT NULL
            BEGIN
                DECLARE @v_f_new_id UNIQUEIDENTIFIER = NEWID();
                INSERT INTO support.ticket_files (file_id, ticket_id, file_name, mime_type, base64_data, uploaded_by)
                VALUES (@v_f_new_id, @v_f_ticket_id, @p_Desc02, @p_Desc03, @p_Djson1, @v_user_id);

                SELECT (SELECT CAST(1 AS BIT) AS success, CAST(@v_f_new_id AS NVARCHAR(36)) AS file_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
                RETURN;
            END
            SELECT '{""error"":""Ticket not found""}' AS result_json;
            RETURN;
        END

        IF @p_ProcID = 'GET_FILES'
        BEGIN
            SELECT ISNULL((
                SELECT 
                    CAST(f.file_id AS NVARCHAR(36)) AS file_id,
                    f.file_name,
                    f.mime_type,
                    f.base64_data,
                    CONVERT(NVARCHAR(30), f.created_at, 126) AS created_at
                FROM support.ticket_files f
                JOIN support.tickets t ON f.ticket_id = t.ticket_id
                WHERE t.ticket_number = @p_Desc01
                ORDER BY f.created_at ASC
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- REGISTER FCM TOKEN
        -- --------------------------------------------------------
    
        -- --------------------------------------------------------
        -- GET PROJECT MODULES
        -- --------------------------------------------------------
        IF @p_ProcID = 'GET_PROJECT_MODULES'
        BEGIN
            DECLARE @v_gpm_mod_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            SELECT ISNULL((
                SELECT
                    CAST(m.module_id AS NVARCHAR(36)) AS module_id,
                    CAST(m.project_id AS NVARCHAR(36)) AS project_id,
                    m.name,
                    m.code,
                    m.description,
                    (SELECT COUNT(*) FROM support.user_modules um WHERE um.module_id = m.module_id) AS assigned_users_count,
                    (SELECT COUNT(*) FROM support.tickets t WHERE t.module_id = m.module_id) AS tickets_count
                FROM support.project_modules m
                WHERE (m.project_id = @v_gpm_mod_proj_id OR @v_gpm_mod_proj_id IS NULL)
                  AND m.is_active = 1
                ORDER BY m.name
                FOR JSON PATH
            ), '[]') AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- CREATE PROJECT MODULE
        -- --------------------------------------------------------
        IF @p_ProcID = 'CREATE_PROJECT_MODULE'
        BEGIN
            DECLARE @v_cpm_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            DECLARE @v_new_mod_id UNIQUEIDENTIFIER = NEWID();

            IF @v_cpm_proj_id IS NOT NULL AND EXISTS (SELECT 1 FROM support.projects WHERE project_id = @v_cpm_proj_id)
            BEGIN
                INSERT INTO support.project_modules (module_id, project_id, name, code, description, is_active)
                VALUES (@v_new_mod_id, @v_cpm_proj_id, @p_Desc02, @p_Desc03, @p_Desc04, 1);

                SELECT (SELECT CAST(1 AS BIT) AS success, CAST(@v_new_mod_id AS NVARCHAR(36)) AS module_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
                RETURN;
            END
            SELECT '{""success"":false,""error"":""Invalid Project""}' AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- DELETE PROJECT MODULE
        -- --------------------------------------------------------
        IF @p_ProcID = 'DELETE_PROJECT_MODULE'
        BEGIN
            DECLARE @v_dpm_mod_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            IF @v_dpm_mod_id IS NOT NULL
            BEGIN
                UPDATE support.project_modules SET is_active = 0 WHERE module_id = @v_dpm_mod_id;
                DELETE FROM support.user_modules WHERE module_id = @v_dpm_mod_id;
                SELECT '{""success"":true}' AS result_json;
                RETURN;
            END
            SELECT '{""success"":false,""error"":""Invalid Module ID""}' AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- ASSIGN USER TO MODULE
        -- --------------------------------------------------------
        IF @p_ProcID = 'ASSIGN_USER_MODULE'
        BEGIN
            DECLARE @v_aum_user_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc01 AS UNIQUEIDENTIFIER);
            DECLARE @v_aum_mod_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc02 AS UNIQUEIDENTIFIER);
            DECLARE @v_aum_proj_id UNIQUEIDENTIFIER = TRY_CAST(@p_Desc03 AS UNIQUEIDENTIFIER);

            IF @v_aum_proj_id IS NULL AND @v_aum_mod_id IS NOT NULL
                SELECT @v_aum_proj_id = project_id FROM support.project_modules WHERE module_id = @v_aum_mod_id;

            IF @v_aum_user_id IS NOT NULL AND @v_aum_mod_id IS NOT NULL
            BEGIN
                DELETE FROM support.user_modules WHERE user_id = @v_aum_user_id AND project_id = @v_aum_proj_id;
                INSERT INTO support.user_modules (user_id, module_id, project_id)
                VALUES (@v_aum_user_id, @v_aum_mod_id, @v_aum_proj_id);

                -- Also ensure user is in project_members
                IF NOT EXISTS (SELECT 1 FROM support.project_members WHERE project_id = @v_aum_proj_id AND user_id = @v_aum_user_id)
                    INSERT INTO support.project_members (project_id, user_id, role_code, is_active)
                    VALUES (@v_aum_proj_id, @v_aum_user_id, 'TEAM_MEMBER', 1);

                SELECT '{""success"":true}' AS result_json;
                RETURN;
            END
            SELECT '{""success"":false,""error"":""Invalid user or module""}' AS result_json;
            RETURN;
        END

    IF @p_ProcID = 'REGISTER_FCM_TOKEN'
        BEGIN
            DECLARE @v_fcm_user_id UNIQUEIDENTIFIER = TRY_CAST(NULLIF(@p_Desc08,'') AS UNIQUEIDENTIFIER);
            UPDATE auth.users
            SET userginf = JSON_MODIFY(ISNULL(userginf,'{}'), '$.fcm_token', @p_Desc01)
            WHERE user_id = @v_fcm_user_id;

            SELECT (SELECT CAST(1 AS BIT) AS success FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS result_json;
            RETURN;
        END

        -- --------------------------------------------------------
        -- FALLBACK
        -- --------------------------------------------------------
        SELECT ('{""error"":""Operation Not Configured: ' + ISNULL(@p_ProcID,'NULL') + '""}') AS result_json;

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = ERROR_MESSAGE();
        SELECT ('{""errornumber"":' + CAST(ERROR_NUMBER() AS NVARCHAR) +
                ',""errorseverity"":' + CAST(ERROR_SEVERITY() AS NVARCHAR) +
                ',""errorstate"":' + CAST(ERROR_STATE() AS NVARCHAR) +
                ',""errorprocedure"":""' + ISNULL(ERROR_PROCEDURE(),'') + '""' +
                ',""errorline"":' + CAST(ERROR_LINE() AS NVARCHAR) +
                ',""errormessage"":""' + REPLACE(@ErrorMsg, '""', '') + '""}') AS result_json;
    END CATCH
END;
";
                using (var cmdSp = new SqlCommand(spSql, conn))
                {
                    cmdSp.CommandTimeout = 60;
                    await cmdSp.ExecuteNonQueryAsync();
                }

                return $"MSSQL Initialized successfully on [{targetDatabase}] using [{workingAuth}]. Schemas, tables, seed data, and SP_TICKET_OPERATIONS deployed. Diagnostics: {string.Join(" -> ", diagnostics)}";
            }
            catch (Exception ex)
            {
                return $"Error updating MSSQL procedure: {ex.Message} | Diagnostics: {string.Join(" -> ", diagnostics)}";
            }
        }
    }
}
