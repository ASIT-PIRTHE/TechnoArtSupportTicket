-- ============================================================================
-- SQL MIGRATION SCRIPT: STANDARDIZE ALL PRIMARY KEYS TO 12-CHAR IDs
-- FORMAT: Prefix (1 char) + YYMM (4 chars) + Sequence (7 digits) = 12 CHARS
-- Example: P26110000001 (November 2026)
--
-- TABLES MIGRATED:
-- 1.  dbo.Projects       (Prefix 'P', e.g. P26110000001)
-- 2.  dbo.ProjectModules (Prefix 'M', e.g. M26110000001)
-- 3.  dbo.Branches       (Prefix 'B', e.g. B26110000001)
-- 4.  dbo.Employees      (Prefix 'E', e.g. E26110000001)
-- 5.  dbo.Tickets        (Prefix 'T', e.g. T26110000001)
-- 6.  dbo.TicketTasks    (Prefix 'K', e.g. K26110000001)
-- 7.  dbo.TicketComments (Prefix 'C', e.g. C26110000001)
-- 8.  dbo.Attendances    (Prefix 'A', e.g. A26110000001)
-- 9.  dbo.LeaveRequests  (Prefix 'L', e.g. L26110000001)
-- 10. dbo.Notices        (Prefix 'N', e.g. N26110000001)
-- 11. dbo.ProjectMembers (Prefix 'R', e.g. R26110000001)
-- 12. dbo.Users          (Prefix 'U', e.g. U26110000001 for GUIDs)
-- ============================================================================

USE TASUPORTDB;
GO

BEGIN TRANSACTION;
BEGIN TRY

    DECLARE @CurYYMM VARCHAR(4) = RIGHT(CONVERT(VARCHAR(4), YEAR(GETDATE())), 2) + RIGHT('0' + CONVERT(VARCHAR(2), MONTH(GETDATE())), 2);
    PRINT '>> Starting ID Migration with Current YYMM: ' + @CurYYMM;

    -- ------------------------------------------------------------------------
    -- 1. MIGRATE PROJECTS (P + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.Projects...';
    IF OBJECT_ID('tempdb..#Map_Projects') IS NOT NULL DROP TABLE #Map_Projects;
    CREATE TABLE #Map_Projects (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedProjects AS (
        SELECT ProjectId, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, ProjectId ASC) AS RowNum
        FROM dbo.Projects
        WHERE LEN(ProjectId) <> 12 OR ProjectId NOT LIKE 'P[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Projects (OldId, NewId)
    SELECT ProjectId, 'P' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedProjects;

    -- Cascade references
    UPDATE m SET ProjectId = map.NewId FROM dbo.ProjectModules m INNER JOIN #Map_Projects map ON CONVERT(NVARCHAR(50), m.ProjectId) = map.OldId;
    UPDATE t SET ProjectId = map.NewId FROM dbo.Tickets t INNER JOIN #Map_Projects map ON CONVERT(NVARCHAR(50), t.ProjectId) = map.OldId;
    UPDATE pm SET ProjectId = map.NewId FROM dbo.ProjectMembers pm INNER JOIN #Map_Projects map ON CONVERT(NVARCHAR(50), pm.ProjectId) = map.OldId;
    UPDATE u SET ProjectId = map.NewId FROM dbo.Users u INNER JOIN #Map_Projects map ON CONVERT(NVARCHAR(50), u.ProjectId) = map.OldId;
    UPDATE p SET ProjectId = map.NewId FROM dbo.Projects p INNER JOIN #Map_Projects map ON CONVERT(NVARCHAR(50), p.ProjectId) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' projects.';

    -- ------------------------------------------------------------------------
    -- 2. MIGRATE PROJECT MODULES (M + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.ProjectModules...';
    IF OBJECT_ID('tempdb..#Map_Modules') IS NOT NULL DROP TABLE #Map_Modules;
    CREATE TABLE #Map_Modules (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedModules AS (
        SELECT ModuleId, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, ModuleId ASC) AS RowNum
        FROM dbo.ProjectModules
        WHERE LEN(ModuleId) <> 12 OR ModuleId NOT LIKE 'M[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Modules (OldId, NewId)
    SELECT ModuleId, 'M' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedModules;

    -- Cascade references
    UPDATE t SET ModuleId = map.NewId FROM dbo.Tickets t INNER JOIN #Map_Modules map ON CONVERT(NVARCHAR(50), t.ModuleId) = map.OldId;
    UPDATE pm SET ModuleId = map.NewId FROM dbo.ProjectMembers pm INNER JOIN #Map_Modules map ON CONVERT(NVARCHAR(50), pm.ModuleId) = map.OldId;
    UPDATE u SET ModuleId = map.NewId FROM dbo.Users u INNER JOIN #Map_Modules map ON CONVERT(NVARCHAR(50), u.ModuleId) = map.OldId;
    UPDATE m SET ModuleId = map.NewId FROM dbo.ProjectModules m INNER JOIN #Map_Modules map ON CONVERT(NVARCHAR(50), m.ModuleId) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' project modules.';

    -- ------------------------------------------------------------------------
    -- 3. MIGRATE BRANCHES (B + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.Branches...';
    IF OBJECT_ID('tempdb..#Map_Branches') IS NOT NULL DROP TABLE #Map_Branches;
    CREATE TABLE #Map_Branches (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedBranches AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.Branches
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'B[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Branches (OldId, NewId)
    SELECT Id, 'B' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedBranches;

    -- Cascade references
    UPDATE e SET BranchId = map.NewId FROM dbo.Employees e INNER JOIN #Map_Branches map ON CONVERT(NVARCHAR(50), e.BranchId) = map.OldId;
    UPDATE a SET BranchId = map.NewId FROM dbo.Attendances a INNER JOIN #Map_Branches map ON CONVERT(NVARCHAR(50), a.BranchId) = map.OldId;
    UPDATE b SET Id = map.NewId FROM dbo.Branches b INNER JOIN #Map_Branches map ON CONVERT(NVARCHAR(50), b.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' branches.';

    -- ------------------------------------------------------------------------
    -- 4. MIGRATE EMPLOYEES (E + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.Employees...';
    IF OBJECT_ID('tempdb..#Map_Employees') IS NOT NULL DROP TABLE #Map_Employees;
    CREATE TABLE #Map_Employees (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedEmployees AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.Employees
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'E[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Employees (OldId, NewId)
    SELECT Id, 'E' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedEmployees;

    -- Cascade references
    UPDATE a SET EmployeeId = map.NewId FROM dbo.Attendances a INNER JOIN #Map_Employees map ON CONVERT(NVARCHAR(50), a.EmployeeId) = map.OldId;
    UPDATE lr SET EmployeeId = map.NewId FROM dbo.LeaveRequests lr INNER JOIN #Map_Employees map ON CONVERT(NVARCHAR(50), lr.EmployeeId) = map.OldId;
    UPDATE e SET Id = map.NewId FROM dbo.Employees e INNER JOIN #Map_Employees map ON CONVERT(NVARCHAR(50), e.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' employees.';

    -- ------------------------------------------------------------------------
    -- 5. MIGRATE TICKETS (T + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.Tickets...';
    IF OBJECT_ID('tempdb..#Map_Tickets') IS NOT NULL DROP TABLE #Map_Tickets;
    CREATE TABLE #Map_Tickets (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedTickets AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.Tickets
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'T[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Tickets (OldId, NewId)
    SELECT Id, 'T' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedTickets;

    UPDATE t SET Id = map.NewId FROM dbo.Tickets t INNER JOIN #Map_Tickets map ON CONVERT(NVARCHAR(50), t.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' tickets.';

    -- ------------------------------------------------------------------------
    -- 6. MIGRATE TICKET TASKS (K + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.TicketTasks...';
    IF OBJECT_ID('tempdb..#Map_Tasks') IS NOT NULL DROP TABLE #Map_Tasks;
    CREATE TABLE #Map_Tasks (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedTasks AS (
        SELECT TaskId, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, TaskId ASC) AS RowNum
        FROM dbo.TicketTasks
        WHERE LEN(TaskId) <> 12 OR TaskId NOT LIKE 'K[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Tasks (OldId, NewId)
    SELECT TaskId, 'K' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedTasks;

    UPDATE tt SET TaskId = map.NewId FROM dbo.TicketTasks tt INNER JOIN #Map_Tasks map ON CONVERT(NVARCHAR(50), tt.TaskId) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' ticket tasks.';

    -- ------------------------------------------------------------------------
    -- 7. MIGRATE TICKET COMMENTS (C + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.TicketComments...';
    IF OBJECT_ID('tempdb..#Map_Comments') IS NOT NULL DROP TABLE #Map_Comments;
    CREATE TABLE #Map_Comments (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedComments AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.TicketComments
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'C[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Comments (OldId, NewId)
    SELECT Id, 'C' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedComments;

    UPDATE tc SET Id = map.NewId FROM dbo.TicketComments tc INNER JOIN #Map_Comments map ON CONVERT(NVARCHAR(50), tc.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' ticket comments.';

    -- ------------------------------------------------------------------------
    -- 8. MIGRATE ATTENDANCES (A + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.Attendances...';
    IF OBJECT_ID('tempdb..#Map_Attendances') IS NOT NULL DROP TABLE #Map_Attendances;
    CREATE TABLE #Map_Attendances (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedAttendances AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY AttendanceDate ASC, Id ASC) AS RowNum
        FROM dbo.Attendances
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'A[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Attendances (OldId, NewId)
    SELECT Id, 'A' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedAttendances;

    UPDATE a SET Id = map.NewId FROM dbo.Attendances a INNER JOIN #Map_Attendances map ON CONVERT(NVARCHAR(50), a.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' attendances.';

    -- ------------------------------------------------------------------------
    -- 9. MIGRATE LEAVE REQUESTS (L + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.LeaveRequests...';
    IF OBJECT_ID('tempdb..#Map_LeaveRequests') IS NOT NULL DROP TABLE #Map_LeaveRequests;
    CREATE TABLE #Map_LeaveRequests (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedLeaveRequests AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY FromDate ASC, Id ASC) AS RowNum
        FROM dbo.LeaveRequests
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'L[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_LeaveRequests (OldId, NewId)
    SELECT Id, 'L' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedLeaveRequests;

    UPDATE lr SET Id = map.NewId FROM dbo.LeaveRequests lr INNER JOIN #Map_LeaveRequests map ON CONVERT(NVARCHAR(50), lr.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' leave requests.';

    -- ------------------------------------------------------------------------
    -- 10. MIGRATE NOTICES (N + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.Notices...';
    IF OBJECT_ID('tempdb..#Map_Notices') IS NOT NULL DROP TABLE #Map_Notices;
    CREATE TABLE #Map_Notices (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedNotices AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.Notices
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'N[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Notices (OldId, NewId)
    SELECT Id, 'N' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedNotices;

    UPDATE n SET Id = map.NewId FROM dbo.Notices n INNER JOIN #Map_Notices map ON CONVERT(NVARCHAR(50), n.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' notices.';

    -- ------------------------------------------------------------------------
    -- 11. MIGRATE PROJECT MEMBERS (R + YYMM + 7 digits)
    -- ------------------------------------------------------------------------
    PRINT '>> Migrating dbo.ProjectMembers...';
    IF OBJECT_ID('tempdb..#Map_Members') IS NOT NULL DROP TABLE #Map_Members;
    CREATE TABLE #Map_Members (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedMembers AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.ProjectMembers
        WHERE LEN(Id) <> 12 OR Id NOT LIKE 'R[0-9][0-9][0-9][0-9]%'
    )
    INSERT INTO #Map_Members (OldId, NewId)
    SELECT Id, 'R' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedMembers;

    UPDATE pm SET Id = map.NewId FROM dbo.ProjectMembers pm INNER JOIN #Map_Members map ON CONVERT(NVARCHAR(50), pm.Id) = map.OldId;
    PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' project members.';

    -- ------------------------------------------------------------------------
    -- 12. MIGRATE GUID USERS (U + YYMM + 7 digits) - Preserving U001, U002 etc.
    -- ------------------------------------------------------------------------
    PRINT '>> Checking dbo.Users for GUID IDs...';
    IF OBJECT_ID('tempdb..#Map_Users') IS NOT NULL DROP TABLE #Map_Users;
    CREATE TABLE #Map_Users (OldId NVARCHAR(50), NewId NVARCHAR(50));

    ;WITH NumberedUsers AS (
        SELECT Id, ROW_NUMBER() OVER (ORDER BY CreatedAt ASC, Id ASC) AS RowNum
        FROM dbo.Users
        WHERE LEN(Id) > 12 -- GUIDs are 36 chars
    )
    INSERT INTO #Map_Users (OldId, NewId)
    SELECT Id, 'U' + @CurYYMM + RIGHT('0000000' + CAST(RowNum AS VARCHAR(10)), 7)
    FROM NumberedUsers;

    IF EXISTS (SELECT 1 FROM #Map_Users)
    BEGIN
        UPDATE e SET UserId = map.NewId FROM dbo.Employees e INNER JOIN #Map_Users map ON CONVERT(NVARCHAR(50), e.UserId) = map.OldId;
        UPDATE pm SET UserId = map.NewId FROM dbo.ProjectMembers pm INNER JOIN #Map_Users map ON CONVERT(NVARCHAR(50), pm.UserId) = map.OldId;
        UPDATE tc SET UserId = map.NewId FROM dbo.TicketComments tc INNER JOIN #Map_Users map ON CONVERT(NVARCHAR(50), tc.UserId) = map.OldId;
        UPDATE t SET CreatedBy = map.NewId FROM dbo.Tickets t INNER JOIN #Map_Users map ON CONVERT(NVARCHAR(50), t.CreatedBy) = map.OldId;
        UPDATE t SET AssignedTo = map.NewId FROM dbo.Tickets t INNER JOIN #Map_Users map ON CONVERT(NVARCHAR(50), t.AssignedTo) = map.OldId;
        UPDATE u SET Id = map.NewId, UserId = map.NewId FROM dbo.Users u INNER JOIN #Map_Users map ON CONVERT(NVARCHAR(50), u.Id) = map.OldId;
        PRINT '   Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' GUID users.';
    END

    COMMIT TRANSACTION;
    PRINT '>> All 12-character ID migrations completed successfully!';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '>> MIGRATION FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
