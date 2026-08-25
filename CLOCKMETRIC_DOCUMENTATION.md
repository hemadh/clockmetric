# ClockMetric Project Documentation

## 1. Project Purpose

ClockMetric is an employee time-tracking and workforce management application.

The goal is to give businesses a simple way to manage employee working time, projects, screenshots, activity, leave and reports.

---

## 2. User Roles

ClockMetric currently has two main roles.

### Admin

The Admin manages the workspace.

The Admin can manage employees, projects, timesheets, screenshots, activity, leave, reports and billing.

Admins do not use the employee timer.

### Employee

Employees belong to a workspace.

Employees can work on projects assigned to them and use the timer to record their working time.

---

## 3. Main Features

ClockMetric currently includes:

- Dashboard
- Employee time tracker
- Projects
- Employee management
- Timesheets
- Screenshots
- Keyboard activity
- Leave management
- Weekly reports
- Billing and subscription status
- Employee and Admin roles
- Workspace-based accounts
- Trial expiry protection
- Persistent login
- Application update functionality

---

## 4. Technology

Frontend:
Flutter / Dart

Backend:
Supabase

Supabase is used for:
- Authentication
- Database
- Storage
- Workspace data
- Employee data
- Project data
- Time tracking data
- Screenshots
- Subscription state

Main desktop platform:
Windows

ClockMetric also has web access intended for administrators.

---

## 5. Basic Workflow

A business uses ClockMetric through a workspace.

Basic flow:

Admin
↓
Workspace
↓
Employees
↓
Projects
↓
Employee selects project
↓
Employee starts timer
↓
ClockMetric records working time and activity
↓
Employee stops timer
↓
Admin reviews the information

---

## 6. Timer

Employees select an assigned project before starting their timer.

When the timer starts, ClockMetric creates a time entry.

While the timer is running, ClockMetric can capture monitoring information such as screenshots and activity.

When the employee stops the timer, the time entry is saved.

Admins cannot start employee timers.

---

## 7. Screenshots and Activity

ClockMetric can capture screenshots while an employee timer is running.

The system also records keyboard activity for workforce activity reporting.

Activity information should describe observable activity and should not make unsupported assumptions about employee behaviour.

Privacy and monitoring requirements must be reviewed before commercial launch.

---

## 8. Workspaces

Each company or team operates inside a workspace.

Employees, projects, time entries and other business information should belong to the correct workspace.

Users from one workspace must not be able to access another workspace's private information.

---

## 9. Subscription

ClockMetric currently supports internal subscription states.

Current planned model:

- 14-day free trial
- A$5 per active employee per month
- Workspace-level subscription

Important subscription states include:

- Trialing
- Active
- Past Due
- Cancelled

During an active trial, employees can use ClockMetric normally.

When the trial expires, employees are blocked from using ClockMetric.

The Admin can still access ClockMetric and is directed to Billing so the subscription can be managed.

For a cancelled paid subscription, access can continue until the current paid billing period ends.

Real payment processing is not yet connected.

---

## 10. Important Business Rules

- Admins cannot start employee timers.
- Employees must belong to a workspace.
- Employees can work only on projects available to them.
- Employees must select a project before starting a timer.
- Expired workspaces block employee access.
- Admins retain access to Billing when subscription access is blocked.
- Disabled employees should stop counting as billable seats from the appropriate future billing period.
- Workspace data must remain separated between businesses.

---

## 11. Important Code Areas

`main.dart`
Handles application startup, authentication, workspace loading, subscription access checks and application routing.

`dashboard_v2_screen.dart`
Main ClockMetric dashboard and navigation.

`timer_screen.dart`
Employee timer interface and timer access protection.

`billing_screen.dart`
Displays trial, subscription, employee count and billing information.

`services/`
Contains application services such as time-entry, screenshot and other supporting logic.

---

## 12. Database

Important Supabase tables currently include:

- profiles
- workspaces
- projects
- project_members
- time_entries
- screenshots

Additional tables may exist for other ClockMetric features.

Database structure and RLS policies should be fully documented and audited before commercial launch.

---

## 13. Current Billing Fields

The workspace currently contains subscription information including:

- subscription_status
- trial_started_at
- trial_ends_at
- current_period_end
- price_per_employee

These values control the ClockMetric billing interface and access rules.

---

## 14. Before Commercial Launch

Important remaining work includes:

- Complete employee onboarding/invitations
- Complete new workspace onboarding
- Connect real payment processing
- Finalize subscription management
- Security and Supabase RLS audit
- Privacy Policy
- Terms of Service
- Employee monitoring disclosure
- Production reliability testing
- Final Windows installer
- Code signing
- Commercial website
- Backup/recovery planning
- Final billing/tax decisions

---

## 15. Documentation Rule

Whenever an important feature or business rule changes, update this document.

Do not rely only on verbal explanations.

A new developer should read this document before making major changes to ClockMetric.