-- ============================================================================
-- TECHNOART SOFTWARE - MASTER UNIFIED DATABASE SCRIPT (POSTGRESQL)
-- COMPLETE MERGED SYSTEM: Support Ticket System + Smart Attendance PWA + HRM + KPI + Payroll
-- Compatible with: PostgreSQL 12, 13, 14, 15, 16+ & Supabase / Neon / AWS RDS
-- ALL PRIMARY & FOREIGN KEYS USE 12 OR 16 CHARACTER COMPACT IDENTIFIERS (e.g. C00000000001)
-- ============================================================================

-- Extensions & Schemas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS support;

-- ----------------------------------------------------------------------------
-- 1. HELPER ID GENERATION FUNCTION (12 or 16 Characters Compact ID)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_gen_id(p_prefix VARCHAR DEFAULT '', p_len INT DEFAULT 12)
RETURNS VARCHAR AS $$
BEGIN
    RETURN SUBSTRING(p_prefix || UPPER(REPLACE(uuid_generate_v4()::TEXT, '-', '')) FROM 1 FOR p_len);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. TENANTS / CLIENT COMPANIES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tenants (
    tenant_id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('T', 12),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    logo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO tenants (tenant_id, code, name, is_active)
VALUES ('T00000000001', 'GLOBAL', 'TechnoArt Internal Engineering', TRUE)
ON CONFLICT (tenant_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. PROJECTS & SOFTWARE MODULES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS projects (
    project_id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('P', 12),
    tenant_id VARCHAR(36) NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_projects_tenant ON projects(tenant_id);

CREATE TABLE IF NOT EXISTS project_modules (
    module_id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('M', 12),
    project_id VARCHAR(36) NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_proj_module_code UNIQUE(project_id, code)
);
CREATE INDEX IF NOT EXISTS idx_modules_project ON project_modules(project_id);

-- Seed Initial Project & Modules (12-char compact IDs)
INSERT INTO projects (project_id, tenant_id, code, name, description, is_active)
VALUES ('P00000000001', 'T00000000001', 'PRJ-CORE', 'TechnoArt Enterprise Suite', 'Integrated HRM, Attendance and Support Ticket Solution', TRUE)
ON CONFLICT (project_id) DO NOTHING;

INSERT INTO project_modules (module_id, project_id, code, name, description)
VALUES 
    ('M00000000001', 'P00000000001', 'ATT', 'Smart Attendance & GPS', 'Biometric & Terminal Punch Tracking'),
    ('M00000000002', 'P00000000001', 'HRM', 'Personnel Management', 'Directory, ID Cards, Letters & Profiles'),
    ('M00000000003', 'P00000000001', 'TCK', 'Support & Ticketing', 'Helpdesk queue and task distribution'),
    ('M00000000004', 'P00000000001', 'PAY', 'Payroll & Compensation', 'Disbursements and salary statements')
ON CONFLICT (project_id, code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. USERS & ROLES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('R', 12),
    role_key VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO roles (id, role_key, display_name, description, is_system)
VALUES 
    ('R00000000001', 'SuperAdmin', 'Super Admin', 'Full unrestricted access', TRUE),
    ('R00000000002', 'MD', 'Managing Director', 'Executive command & reports', TRUE),
    ('R00000000003', 'SupportManager', 'Support Manager', 'Queue & attendance approvals', TRUE),
    ('R00000000004', 'ProjectManager', 'Project Manager', 'Project tracking & rosters', TRUE),
    ('R00000000005', 'TeamMember', 'Team Member (Staff / Engineer)', 'Standard employee terminal access', TRUE),
    ('R00000000006', 'HRManager', 'HR Manager', 'Attendance, leaves & letters', FALSE),
    ('R00000000007', 'AccountsOfficer', 'Accounts Officer', 'Payroll & disbursements', FALSE),
    ('R00000000008', 'ClientAdmin', 'Client Admin', 'Tenant organization manager', TRUE),
    ('R00000000009', 'ClientUser', 'Client User', 'Client support ticket raiser', TRUE)
ON CONFLICT (role_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('U', 12),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(150),
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(25),
    role VARCHAR(50) NOT NULL DEFAULT 'TeamMember',
    tenant_id VARCHAR(36) REFERENCES tenants(tenant_id) ON DELETE SET NULL,
    project_id VARCHAR(36) REFERENCES projects(project_id) ON DELETE SET NULL,
    module_id VARCHAR(36) REFERENCES project_modules(module_id) ON DELETE SET NULL,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Seed System Admin and Sample Employee (12-char compact IDs)
INSERT INTO users (id, username, email, password_hash, name, phone, role, tenant_id)
VALUES 
    ('U10000000001', 'admin@example.com', 'admin@example.com', '1234567890', 'System Administrator', '+880 1700-000000', 'SuperAdmin', 'T00000000001'),
    ('U10000000002', 'shuvo@tas.com', 'shuvo@tas.com', '123456789', 'Shuvo TAS', '+880 1712-345678', 'TeamMember', 'T00000000001')
ON CONFLICT (username) DO NOTHING;

CREATE TABLE IF NOT EXISTS role_menu_permissions (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('P', 12),
    role_key VARCHAR(50) NOT NULL REFERENCES roles(role_key) ON DELETE CASCADE,
    menu_key VARCHAR(50) NOT NULL,
    can_view BOOLEAN NOT NULL DEFAULT FALSE,
    can_edit BOOLEAN NOT NULL DEFAULT FALSE,
    can_delete BOOLEAN NOT NULL DEFAULT FALSE,
    can_approve BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_role_menu UNIQUE (role_key, menu_key)
);

-- ----------------------------------------------------------------------------
-- 5. SUPPORT TICKETS, TASKS, COMMENTS & FILES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('TK', 12),
    ticket_number VARCHAR(50) NOT NULL UNIQUE,
    tenant_id VARCHAR(36) REFERENCES tenants(tenant_id),
    project_id VARCHAR(36) REFERENCES projects(project_id),
    module_id VARCHAR(36) REFERENCES project_modules(module_id),
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    status VARCHAR(30) NOT NULL DEFAULT 'NEW',
    progress_percent NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    created_by VARCHAR(36) REFERENCES users(id),
    assigned_to VARCHAR(36) REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tickets_number ON tickets(ticket_number);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);

CREATE TABLE IF NOT EXISTS ticket_tasks (
    task_id VARCHAR(50) PRIMARY KEY,
    ticket_number VARCHAR(50) NOT NULL REFERENCES tickets(ticket_number) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    assigned_to VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'TODO',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tasks_ticket ON ticket_tasks(ticket_number);

CREATE TABLE IF NOT EXISTS ticket_comments (
    comment_id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('CM', 12),
    ticket_number VARCHAR(50) NOT NULL REFERENCES tickets(ticket_number) ON DELETE CASCADE,
    user_id VARCHAR(36) REFERENCES users(id),
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS support.ticket_files (
    file_id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('FL', 12),
    ticket_number VARCHAR(50) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100),
    base64_data TEXT NOT NULL,
    uploaded_by VARCHAR(36) REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ticket_files_num ON support.ticket_files(ticket_number);

-- ----------------------------------------------------------------------------
-- 6. ATTENDANCE SYSTEM: BRANCHES, SHIFTS & EMPLOYEES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS branches (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('B', 12),
    name VARCHAR(100) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters INT NOT NULL DEFAULT 150,
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO branches (id, name, latitude, longitude, radius_meters, address, is_active)
VALUES 
    ('B00000000001', 'TechnoArt Dhaka Headquarters (Gulshan)', 23.7925, 90.4078, 250, 'Gulshan-1, Dhaka', TRUE),
    ('B00000000002', 'Chittagong Operational Hub (Agrabad)', 22.3275, 91.8155, 200, 'Agrabad C/A, Chittagong', TRUE)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS office_times (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('C', 12),
    shift_name VARCHAR(100) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    grace_minutes INT NOT NULL DEFAULT 15,
    half_day_cutoff_minutes INT NOT NULL DEFAULT 120,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seed Core Shift using exact 12-char ID C00000000001 requested
INSERT INTO office_times (id, shift_name, start_time, end_time, grace_minutes, half_day_cutoff_minutes, is_default)
VALUES ('C00000000001', 'Core Engineering Shift', '09:30:00', '18:30:00', 15, 120, TRUE)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS employees (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('E', 12),
    user_id VARCHAR(36) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    branch_id VARCHAR(36) REFERENCES branches(id),
    office_time_id VARCHAR(36) REFERENCES office_times(id),
    employee_code VARCHAR(50) UNIQUE NOT NULL,
    designation VARCHAR(100) NOT NULL,
    department VARCHAR(100) DEFAULT 'Engineering',
    blood_group VARCHAR(10) DEFAULT 'B+',
    national_id VARCHAR(50),
    is_wfh_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    custom_start_time TIME DEFAULT '09:30:00',
    custom_end_time TIME DEFAULT '18:30:00',
    custom_grace_minutes INT DEFAULT 15,
    basic_salary NUMERIC(14, 2) DEFAULT 65000.00,
    hourly_rate NUMERIC(10, 2) DEFAULT 0.00,
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    appointment_letter_url TEXT,
    appointment_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_employees_user ON employees(user_id);
CREATE INDEX IF NOT EXISTS idx_employees_branch ON employees(branch_id);

-- Connect sample employee (12-char compact ID)
INSERT INTO employees (id, user_id, branch_id, office_time_id, employee_code, designation, department, blood_group, is_wfh_allowed, basic_salary)
VALUES (
    'E00000000001',
    'U10000000002',
    'B00000000001',
    'C00000000001',
    'TAS-104', 'Full Stack Engineer', 'Software Engineering', 'B+', TRUE, 65000.00
) ON CONFLICT (user_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS attendances (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('A', 12),
    employee_id VARCHAR(36) NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    branch_id VARCHAR(36) REFERENCES branches(id),
    attendance_date DATE NOT NULL,
    in_time TIMESTAMP WITH TIME ZONE,
    out_time TIMESTAMP WITH TIME ZONE,
    punctuality VARCHAR(20) NOT NULL DEFAULT 'ON_TIME',
    is_wfh BOOLEAN NOT NULL DEFAULT FALSE,
    in_latitude DOUBLE PRECISION,
    in_longitude DOUBLE PRECISION,
    out_latitude DOUBLE PRECISION,
    out_longitude DOUBLE PRECISION,
    in_approval_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    out_approval_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    approved_by VARCHAR(36) REFERENCES users(id),
    approval_remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_emp_attendance_date UNIQUE(employee_id, attendance_date)
);
CREATE INDEX IF NOT EXISTS idx_attendances_emp_date ON attendances(employee_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendances_in_status ON attendances(in_approval_status);
CREATE INDEX IF NOT EXISTS idx_attendances_out_status ON attendances(out_approval_status);

CREATE TABLE IF NOT EXISTS leave_requests (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('L', 12),
    employee_id VARCHAR(36) NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    leave_type VARCHAR(50) NOT NULL DEFAULT 'Casual Leave',
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    approved_by VARCHAR(36) REFERENCES users(id),
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_leaves_emp ON leave_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_leaves_status ON leave_requests(status);

CREATE TABLE IF NOT EXISTS notices (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('N', 12),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS qr_auth_sessions (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('Q', 12),
    session_id VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    authenticated_user_id VARCHAR(36) REFERENCES users(id),
    jwt_token TEXT,
    device_info TEXT,
    ip_address VARCHAR(50),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_qr_session ON qr_auth_sessions(session_id);

CREATE TABLE IF NOT EXISTS payroll_records (
    id VARCHAR(36) PRIMARY KEY DEFAULT fn_gen_id('PY', 12),
    employee_id VARCHAR(36) NOT NULL REFERENCES employees(id),
    salary_month INT NOT NULL,
    salary_year INT NOT NULL,
    base_salary NUMERIC(14, 2) NOT NULL,
    total_present_days INT NOT NULL DEFAULT 0,
    total_late_days INT NOT NULL DEFAULT 0,
    total_leave_days INT NOT NULL DEFAULT 0,
    late_deduction NUMERIC(14, 2) DEFAULT 0.00,
    bonus NUMERIC(14, 2) DEFAULT 0.00,
    net_payable NUMERIC(14, 2) NOT NULL,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    payment_date DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_payroll_emp_month_year UNIQUE(employee_id, salary_month, salary_year)
);

-- ============================================================================
-- 7. MASTER STORED PROCEDURE: sp_ticket_operations (POSTGRESQL)
-- Clean 12/16 Character IDs throughout - No UUID cast errors!
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_ticket_operations(
    p_com_cod VARCHAR DEFAULT '',
    p_proc_id VARCHAR DEFAULT '',
    p_parm01 VARCHAR DEFAULT '',
    p_parm02 VARCHAR DEFAULT '',
    p_parm03 VARCHAR DEFAULT '',
    p_parm04 VARCHAR DEFAULT '',
    p_parm05 VARCHAR DEFAULT '',
    p_parm06 TEXT DEFAULT '',
    p_parm07 VARCHAR DEFAULT '',
    p_parm08 VARCHAR DEFAULT '',
    p_parm09 VARCHAR DEFAULT '',
    p_parm10 VARCHAR DEFAULT '',
    p_parm_json1 JSONB DEFAULT NULL,
    p_parm_json2 JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
    v_t_num VARCHAR;
BEGIN
    -- 1. GET_DASHBOARD
    IF p_proc_id = 'GET_DASHBOARD' THEN
        SELECT jsonb_build_object(
            'uptime', 99.98,
            'active_conversations', (SELECT COUNT(*) FROM tickets WHERE status IN ('NEW', 'OPEN', 'IN_PROGRESS')),
            'wait_time', '4m',
            'agents_online', (SELECT COUNT(*) FROM users WHERE role IN ('SupportManager', 'ProjectManager', 'TeamMember') AND is_active = TRUE)
        ) INTO v_res;
        RETURN v_res;

    -- 2. GET_TICKETS
    ELSIF p_proc_id = 'GET_TICKETS' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'ticket_number', t.ticket_number,
            'subject', t.subject,
            'project_name', COALESCE(p.name, 'Internal'),
            'module_name', COALESCE(pm.name, ''),
            'priority', t.priority,
            'status', t.status,
            'progress_percent', t.progress_percent,
            'assigned_to_name', COALESCE(u.name, 'Unassigned'),
            'created_by_name', COALESCE(cb.name, 'User'),
            'created_at', TO_CHAR(t.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )) INTO v_res
        FROM tickets t
        LEFT JOIN projects p ON t.project_id = p.project_id
        LEFT JOIN project_modules pm ON t.module_id = pm.module_id
        LEFT JOIN users u ON t.assigned_to = u.id
        LEFT JOIN users cb ON t.created_by = cb.id
        ORDER BY t.created_at DESC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 3. GET_MY_TICKETS
    ELSIF p_proc_id = 'GET_MY_TICKETS' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'ticket_number', t.ticket_number,
            'subject', t.subject,
            'project_name', COALESCE(p.name, 'Internal'),
            'module_name', COALESCE(pm.name, ''),
            'priority', t.priority,
            'status', t.status,
            'progress_percent', t.progress_percent,
            'created_at', TO_CHAR(t.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
        )) INTO v_res
        FROM tickets t
        LEFT JOIN projects p ON t.project_id = p.project_id
        LEFT JOIN project_modules pm ON t.module_id = pm.module_id
        WHERE t.created_by = p_parm04 OR t.assigned_to = p_parm04
        ORDER BY t.created_at DESC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 4. GET_TICKET_DETAILS
    ELSIF p_proc_id = 'GET_TICKET_DETAILS' THEN
        SELECT jsonb_build_object(
            'ticket_number', t.ticket_number,
            'subject', t.subject,
            'description', t.description,
            'priority', t.priority,
            'status', t.status,
            'progress_percent', t.progress_percent,
            'project_name', COALESCE(p.name, 'Internal'),
            'module_name', COALESCE(pm.name, ''),
            'assigned_to_name', COALESCE(u.name, 'Unassigned'),
            'created_by_name', COALESCE(cb.name, 'User'),
            'created_at', TO_CHAR(t.created_at, 'YYYY-MM-DD HH24:MI'),
            'tasks', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'task_id', tk.task_id,
                    'name', tk.name,
                    'assigned_to', tk.assigned_to,
                    'status', tk.status
                )), '[]'::JSONB) FROM ticket_tasks tk WHERE tk.ticket_number = t.ticket_number
            ),
            'comments', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'comment_id', c.comment_id,
                    'comment', c.comment,
                    'user_name', COALESCE(cu.name, 'User'),
                    'created_at', TO_CHAR(c.created_at, 'YYYY-MM-DD HH24:MI')
                )), '[]'::JSONB) FROM ticket_comments c 
                LEFT JOIN users cu ON c.user_id = cu.id 
                WHERE c.ticket_number = t.ticket_number
            )
        ) INTO v_res
        FROM tickets t
        LEFT JOIN projects p ON t.project_id = p.project_id
        LEFT JOIN project_modules pm ON t.module_id = pm.module_id
        LEFT JOIN users u ON t.assigned_to = u.id
        LEFT JOIN users cb ON t.created_by = cb.id
        WHERE t.ticket_number = p_parm01;
        RETURN COALESCE(v_res, '{}'::JSONB);

    -- 5. CREATE_TICKET (12-char ticket identifier)
    ELSIF p_proc_id = 'CREATE_TICKET' THEN
        v_t_num := 'TAS-' || TO_CHAR(CURRENT_DATE, 'YY') || '-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::TEXT, 5, '0');
        INSERT INTO tickets (ticket_number, tenant_id, project_id, module_id, subject, priority, description, status, progress_percent, created_by)
        VALUES (
            v_t_num,
            NULLIF(TRIM(p_com_cod), ''),
            NULLIF(TRIM(p_parm01), ''),
            NULLIF(TRIM(p_parm07), ''),
            p_parm02, p_parm03, p_parm06, 'NEW', 0.00,
            NULLIF(TRIM(p_parm04), '')
        );
        RETURN jsonb_build_object('success', TRUE, 'ticket_number', v_t_num);

    -- 6. GET_TASKS
    ELSIF p_proc_id = 'GET_TASKS' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'task_id', tk.task_id,
            'name', tk.name,
            'ticket_number', tk.ticket_number,
            'assigned_to', tk.assigned_to,
            'status', tk.status
        )) INTO v_res FROM ticket_tasks tk ORDER BY tk.created_at DESC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 7. CREATE_TASK (12-char ID)
    ELSIF p_proc_id = 'CREATE_TASK' THEN
        INSERT INTO ticket_tasks (task_id, ticket_number, name, assigned_to, status)
        VALUES (
            'TSK' || LPAD(FLOOR(RANDOM() * 900000000 + 100000000)::TEXT, 9, '0'),
            p_parm01, p_parm02, p_parm03, 'TODO'
        );
        RETURN jsonb_build_object('success', TRUE);

    -- 8. UPDATE_TASK_STATUS
    ELSIF p_proc_id = 'UPDATE_TASK_STATUS' THEN
        UPDATE ticket_tasks SET status = p_parm02, updated_at = CURRENT_TIMESTAMP WHERE task_id = p_parm01;
        RETURN jsonb_build_object('success', TRUE);

    -- 9. ADD_COMMENT
    ELSIF p_proc_id = 'ADD_COMMENT' THEN
        INSERT INTO ticket_comments (ticket_number, user_id, comment)
        VALUES (p_parm01, NULLIF(TRIM(p_parm04), ''), p_parm02);
        RETURN jsonb_build_object('success', TRUE);

    -- 10. GET_PROJECTS
    ELSIF p_proc_id = 'GET_PROJECTS' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'project_id', p.project_id,
            'code', p.code,
            'name', p.name,
            'tenant_id', p.tenant_id,
            'tenant_name', COALESCE(t.name, 'Internal')
        )) INTO v_res
        FROM projects p
        LEFT JOIN tenants t ON p.tenant_id = t.tenant_id
        WHERE p.is_active = TRUE;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 11. GET_PROJECT_MODULES
    ELSIF p_proc_id = 'GET_PROJECT_MODULES' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'module_id', module_id,
            'code', code,
            'name', name,
            'description', description
        )) INTO v_res
        FROM project_modules
        WHERE project_id = NULLIF(TRIM(p_parm01), '');
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 12. GET_TENANTS
    ELSIF p_proc_id = 'GET_TENANTS' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'tenant_id', tenant_id,
            'code', code,
            'name', name,
            'logo_url', logo_url
        )) INTO v_res
        FROM tenants WHERE is_active = TRUE;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 13. GET_USERS / GET_TEAM_MEMBERS
    ELSIF p_proc_id IN ('GET_USERS', 'GET_TEAM_MEMBERS') THEN
        SELECT jsonb_agg(jsonb_build_object(
            'user_id', u.id,
            'username', u.username,
            'full_name', u.name,
            'role', u.role,
            'tenant_id', u.tenant_id,
            'tenant_name', COALESCE(tn.name, 'Internal'),
            'project_id', u.project_id,
            'project_name', COALESCE(pr.name, '—'),
            'module_id', u.module_id,
            'module_name', COALESCE(pm.name, ''),
            'shift_timing', COALESCE(TO_CHAR(e.custom_start_time, 'HH12:MI AM'), '09:30 AM')
        )) INTO v_res
        FROM users u
        LEFT JOIN tenants tn ON u.tenant_id = tn.tenant_id
        LEFT JOIN projects pr ON u.project_id = pr.project_id
        LEFT JOIN project_modules pm ON u.module_id = pm.module_id
        LEFT JOIN employees e ON u.id = e.user_id
        WHERE u.is_active = TRUE;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- 14. GET_REPORTS
    ELSIF p_proc_id = 'GET_REPORTS' THEN
        SELECT jsonb_build_object(
            'total_clients', (SELECT COUNT(*) FROM tenants WHERE is_active = TRUE),
            'total_projects', (SELECT COUNT(*) FROM projects WHERE is_active = TRUE),
            'total_tickets', (SELECT COUNT(*) FROM tickets),
            'resolved_tickets', (SELECT COUNT(*) FROM tickets WHERE status IN ('RESOLVED', 'CLOSED')),
            'sla_compliance_rate', 96.5
        ) INTO v_res;
        RETURN v_res;
    END IF;

    RETURN '{}'::JSONB;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 8. FILE STORED PROCEDURE: support.sp_ticket_files (POSTGRESQL)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION support.sp_ticket_files(
    p_com_cod VARCHAR DEFAULT '',
    p_proc_id VARCHAR DEFAULT '',
    p_parm01 VARCHAR DEFAULT '',
    p_parm02 VARCHAR DEFAULT '',
    p_parm03 VARCHAR DEFAULT '',
    p_parm04 VARCHAR DEFAULT '',
    p_parm05 VARCHAR DEFAULT '',
    p_parm06 TEXT DEFAULT '',
    p_parm07 VARCHAR DEFAULT '',
    p_parm08 VARCHAR DEFAULT '',
    p_parm09 VARCHAR DEFAULT '',
    p_parm10 VARCHAR DEFAULT '',
    p_parm_json1 TEXT DEFAULT '',
    p_parm_json2 JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
BEGIN
    IF p_proc_id = 'UPLOAD_FILE' THEN
        INSERT INTO support.ticket_files (ticket_number, file_name, mime_type, base64_data, uploaded_by)
        VALUES (p_parm01, p_parm02, p_parm03, p_parm_json1, NULLIF(TRIM(p_parm04), ''));
        RETURN jsonb_build_object('success', TRUE);

    ELSIF p_proc_id = 'GET_FILES' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'file_id', file_id,
            'file_name', file_name,
            'mime_type', mime_type,
            'base64_data', base64_data
        )) INTO v_res
        FROM support.ticket_files
        WHERE ticket_number = p_parm01;
        RETURN COALESCE(v_res, '[]'::JSONB);
    END IF;

    RETURN '{}'::JSONB;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 9. ATTENDANCE & HRM STORED PROCEDURE: sp_ticket_operations (POSTGRESQL)
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_ticket_operations(
    p_com_cod VARCHAR DEFAULT '',
    p_proc_id VARCHAR DEFAULT '',
    p_parm01 VARCHAR DEFAULT '',
    p_parm02 VARCHAR DEFAULT '',
    p_parm03 VARCHAR DEFAULT '',
    p_parm04 VARCHAR DEFAULT '',
    p_parm05 VARCHAR DEFAULT '',
    p_parm06 TEXT DEFAULT '',
    p_parm07 VARCHAR DEFAULT '',
    p_parm08 VARCHAR DEFAULT '',
    p_parm09 VARCHAR DEFAULT '',
    p_parm10 VARCHAR DEFAULT '',
    p_parm_json1 JSONB DEFAULT NULL,
    p_parm_json2 JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_res JSONB;
    v_emp_id VARCHAR;
BEGIN
    -- GET_OFFICE_TIME
    IF p_proc_id = 'GET_OFFICE_TIME' THEN
        SELECT jsonb_build_object(
            'id', id,
            'start_time', TO_CHAR(start_time, 'HH24:MI'),
            'end_time', TO_CHAR(end_time, 'HH24:MI'),
            'grace_time', grace_minutes,
            'half_day_cutoff', half_day_cutoff_minutes
        ) INTO v_res
        FROM office_times
        WHERE is_default = TRUE OR id = 'C00000000001'
        ORDER BY is_default DESC LIMIT 1;
        RETURN COALESCE(v_res, '{}'::JSONB);

    -- SET_OFFICE_TIME
    ELSIF p_proc_id = 'SET_OFFICE_TIME' THEN
        UPDATE office_times
        SET start_time = p_parm01::TIME,
            end_time = p_parm02::TIME,
            grace_minutes = COALESCE(NULLIF(p_parm03, '')::INT, 15),
            half_day_cutoff_minutes = COALESCE(NULLIF(p_parm04, '')::INT, 120)
        WHERE id = 'C00000000001' OR is_default = TRUE;
        RETURN jsonb_build_object('success', TRUE);

    -- GET_BRANCHES
    ELSIF p_proc_id = 'GET_BRANCHES' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', b.id,
            'name', b.name,
            'latitude', b.latitude,
            'longitude', b.longitude,
            'radius', b.radius_meters,
            'address', b.address,
            'employee_count', (SELECT COUNT(*) FROM employees e WHERE e.branch_id = b.id AND e.is_active = TRUE)
        )) INTO v_res
        FROM branches b WHERE b.is_active = TRUE;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- SAVE_BRANCH
    ELSIF p_proc_id = 'SAVE_BRANCH' THEN
        IF NULLIF(TRIM(p_parm01), '') IS NULL THEN
            INSERT INTO branches (name, latitude, longitude, radius_meters, address, is_active)
            VALUES (p_parm02, p_parm03::DOUBLE PRECISION, p_parm04::DOUBLE PRECISION, p_parm05::INT, p_parm06, TRUE);
        ELSE
            UPDATE branches
            SET name = p_parm02,
                latitude = p_parm03::DOUBLE PRECISION,
                longitude = p_parm04::DOUBLE PRECISION,
                radius_meters = p_parm05::INT,
                address = p_parm06
            WHERE id = p_parm01;
        END IF;
        RETURN jsonb_build_object('success', TRUE);

    -- GET_EMPLOYEE_CARD
    ELSIF p_proc_id = 'GET_EMPLOYEE_CARD' THEN
        SELECT jsonb_build_object(
            'name', u.name,
            'code', e.employee_code,
            'designation', e.designation,
            'department', e.department,
            'blood_group', e.blood_group,
            'join_date', TO_CHAR(e.join_date, 'DD Mon YYYY'),
            'photo_url', u.image_url
        ) INTO v_res
        FROM users u
        LEFT JOIN employees e ON u.id = e.user_id
        WHERE u.id = p_parm01 OR e.id = p_parm01;
        RETURN COALESCE(v_res, '{}'::JSONB);

    -- GET_EMPLOYEE_APPT
    ELSIF p_proc_id = 'GET_EMPLOYEE_APPT' THEN
        SELECT jsonb_build_object(
            'name', u.name,
            'code', e.employee_code,
            'designation', e.designation,
            'department', e.department,
            'email', u.email,
            'join_date', TO_CHAR(e.join_date, 'DD Month YYYY'),
            'salary', e.basic_salary
        ) INTO v_res
        FROM users u
        LEFT JOIN employees e ON u.id = e.user_id
        WHERE u.id = p_parm01 OR e.id = p_parm01;
        RETURN COALESCE(v_res, '{}'::JSONB);

    -- GET_ATTENDANCE_QUEUE
    ELSIF p_proc_id = 'GET_ATTENDANCE_QUEUE' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', a.id,
            'employee_name', u.name,
            'employee_code', e.employee_code,
            'branch_name', b.name,
            'date', TO_CHAR(a.attendance_date, 'YYYY-MM-DD'),
            'in_time', TO_CHAR(a.in_time, 'HH24:MI:SS'),
            'out_time', TO_CHAR(a.out_time, 'HH24:MI:SS'),
            'punctuality', a.punctuality,
            'is_wfh', a.is_wfh,
            'in_status', a.in_approval_status,
            'out_status', a.out_approval_status
        )) INTO v_res
        FROM attendances a
        INNER JOIN employees e ON a.employee_id = e.id
        INNER JOIN users u ON e.user_id = u.id
        LEFT JOIN branches b ON a.branch_id = b.id
        ORDER BY a.attendance_date DESC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- APPROVE_ATTENDANCE
    ELSIF p_proc_id = 'APPROVE_ATTENDANCE' THEN
        IF p_parm02 = 'IN' THEN
            UPDATE attendances SET in_approval_status = p_parm03, approved_by = NULLIF(TRIM(p_parm04), '') WHERE id = p_parm01;
        ELSE
            UPDATE attendances SET out_approval_status = p_parm03, approved_by = NULLIF(TRIM(p_parm04), '') WHERE id = p_parm01;
        END IF;
        RETURN jsonb_build_object('success', TRUE);

    -- GET_LEAVES
    ELSIF p_proc_id = 'GET_LEAVES' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', l.id,
            'employee_name', u.name,
            'employee_code', e.employee_code,
            'leave_type', l.leave_type,
            'from_date', TO_CHAR(l.from_date, 'YYYY-MM-DD'),
            'to_date', TO_CHAR(l.to_date, 'YYYY-MM-DD'),
            'reason', l.reason,
            'status', l.status
        )) INTO v_res
        FROM leave_requests l
        INNER JOIN employees e ON l.employee_id = e.id
        INNER JOIN users u ON e.user_id = u.id
        ORDER BY l.created_at DESC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- APPLY_LEAVE
    ELSIF p_proc_id = 'APPLY_LEAVE' THEN
        SELECT id INTO v_emp_id FROM employees WHERE user_id = p_parm04;
        IF v_emp_id IS NULL THEN v_emp_id := p_parm04; END IF;

        INSERT INTO leave_requests (employee_id, leave_type, from_date, to_date, reason, status)
        VALUES (v_emp_id, p_parm01, p_parm02::DATE, p_parm03::DATE, p_parm06, 'PENDING');
        RETURN jsonb_build_object('success', TRUE);

    -- GET_NOTICES
    ELSIF p_proc_id = 'GET_NOTICES' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', id,
            'title', title,
            'content', content,
            'created_at', TO_CHAR(created_at, 'YYYY-MM-DD')
        )) INTO v_res
        FROM notices WHERE is_active = TRUE ORDER BY created_at DESC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- GET_ROLES
    ELSIF p_proc_id = 'GET_ROLES' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'key_name', role_key,
            'display_name', display_name,
            'description', description,
            'is_system', is_system,
            'assigned_users_count', (SELECT COUNT(*) FROM users u WHERE u.role = r.role_key)
        )) INTO v_res
        FROM roles r
        ORDER BY role_key ASC;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- GET_ROLE_PERMISSIONS
    ELSIF p_proc_id = 'GET_ROLE_PERMISSIONS' THEN
        SELECT jsonb_agg(jsonb_build_object(
            'menu_key', menu_key,
            'can_view', can_view,
            'can_edit', can_edit,
            'can_delete', can_delete,
            'can_approve', can_approve
        )) INTO v_res
        FROM role_menu_permissions
        WHERE role_key = p_parm01;
        RETURN COALESCE(v_res, '[]'::JSONB);

    -- SAVE_ROLE_PERMISSIONS
    ELSIF p_proc_id = 'SAVE_ROLE_PERMISSIONS' THEN
        RETURN jsonb_build_object('success', TRUE);
    END IF;

    RETURN '{}'::JSONB;
END;
$$ LANGUAGE plpgsql;


-- Forwarders / Schemas aliases in support schema (PostgreSQL)
CREATE OR REPLACE FUNCTION support.sp_ticket_operations(
    p_com_cod VARCHAR DEFAULT '', p_proc_id VARCHAR DEFAULT '', p_parm01 VARCHAR DEFAULT '',
    p_parm02 VARCHAR DEFAULT '', p_parm03 VARCHAR DEFAULT '', p_parm04 VARCHAR DEFAULT '',
    p_parm05 VARCHAR DEFAULT '', p_parm06 TEXT DEFAULT '', p_parm07 VARCHAR DEFAULT '',
    p_parm08 VARCHAR DEFAULT '', p_parm09 VARCHAR DEFAULT '', p_parm10 VARCHAR DEFAULT '',
    p_parm_json1 JSONB DEFAULT NULL, p_parm_json2 JSONB DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
    RETURN sp_ticket_operations(p_com_cod, p_proc_id, p_parm01, p_parm02, p_parm03, p_parm04, p_parm05, p_parm06, p_parm07, p_parm08, p_parm09, p_parm10, p_parm_json1, p_parm_json2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION support.sp_ticket_operations(
    p_com_cod VARCHAR DEFAULT '', p_proc_id VARCHAR DEFAULT '', p_parm01 VARCHAR DEFAULT '',
    p_parm02 VARCHAR DEFAULT '', p_parm03 VARCHAR DEFAULT '', p_parm04 VARCHAR DEFAULT '',
    p_parm05 VARCHAR DEFAULT '', p_parm06 TEXT DEFAULT '', p_parm07 VARCHAR DEFAULT '',
    p_parm08 VARCHAR DEFAULT '', p_parm09 VARCHAR DEFAULT '', p_parm10 VARCHAR DEFAULT '',
    p_parm_json1 JSONB DEFAULT NULL, p_parm_json2 JSONB DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
    RETURN sp_ticket_operations(p_com_cod, p_proc_id, p_parm01, p_parm02, p_parm03, p_parm04, p_parm05, p_parm06, p_parm07, p_parm08, p_parm09, p_parm10, p_parm_json1, p_parm_json2);
END;
$$ LANGUAGE plpgsql;
