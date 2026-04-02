<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into the Haiku iOS app (SwiftUI). The PostHog iOS SDK is installed via Swift Package Manager, initialized at app launch with lifecycle event capture enabled, and 35 custom events span the full user journey — from onboarding through daily task management to Pro subscription conversion.

## Events instrumented

| Event | Description | File |
|---|---|---|
| `app_session_started` | App launched and PostHog SDK initialized | `clock/clockApp.swift` |
| `onboarding_completed` | User finishes onboarding with goal, task, and notification preference | `clock/OnboardingView.swift` |
| `onboarding_skipped` | User skips onboarding from any page | `clock/OnboardingView.swift` |
| `onboarding_notification_accepted` | User accepts notification reminders during onboarding | `clock/OnboardingView.swift` |
| `onboarding_notification_skipped` | User skips notification prompts during onboarding | `clock/OnboardingView.swift` |
| `task_created` | User schedules a new task on the clock | `clock/AddTaskView.swift` |
| `task_updated` | User edits and saves an existing task | `clock/AddTaskView.swift` |
| `task_deleted` | User swipe-deletes a task from the clock view | `clock/ContentView.swift` |
| `manual_color_selected` | User manually picks a task color | `clock/AddTaskView.swift` |
| `category_deleted` | User deletes a task category via context menu | `clock/AddTaskView.swift` |
| `tab_changed` | User switches tabs (Clock, Weekly, To-Do, Analytics, Profile) | `clock/ContentView.swift` |
| `date_changed` | User navigates to a different date via chevron or swipe | `clock/ContentView.swift` |
| `brain_dump_task_added` | User adds a quick task to the Brain Dump list | `clock/TodoView.swift` |
| `brain_dump_task_completed` | User marks a Brain Dump task as completed | `clock/TodoView.swift` |
| `brain_dump_task_reactivated` | User unchecks a previously completed Brain Dump task | `clock/TodoView.swift` |
| `brain_dump_task_deleted` | User swipe-deletes a Brain Dump task | `clock/TodoView.swift` |
| `brain_dump_task_scheduled` | User schedules a Brain Dump task onto the clock | `clock/TodoView.swift` |
| `brain_dump_selection_mode_toggled` | User toggles multi-select mode in Brain Dump | `clock/TodoView.swift` |
| `brain_dump_list_cleared` | User clears completed Brain Dump tasks | `clock/TodoView.swift` |
| `bulk_import_completed` | User bulk-imports tasks into Brain Dump via paste | `clock/BulkImportView.swift` |
| `paywall_viewed` | User sees the Haiku Pro paywall | `clock/HaikuProView.swift` |
| `paywall_dismissed` | User dismisses the paywall without purchasing | `clock/HaikuProView.swift` |
| `purchase_initiated` | User taps the CTA to start a subscription purchase | `clock/HaikuProView.swift` |
| `purchase_completed` | User's Pro entitlement becomes active | `clock/StoreManager.swift` |
| `purchase_failed` | A purchase attempt threw an error | `clock/HaikuProView.swift` |
| `purchase_restored` | User restores a previous Pro purchase | `clock/StoreManager.swift` |
| `upgrade_banner_clicked` | Free user taps the Upgrade banner in Settings | `clock/ProfileSettingsView.swift` |
| `pro_feature_denied` | Free user tries to access a Pro-only feature | `clock/ProfileSettingsView.swift` |
| `upgrade_custom_notification_clicked` | Free user taps custom notifications (Pro feature) | `clock/ProfileSettingsView.swift` |
| `upgrade_apple_calendar_clicked` | Free user taps Apple Calendar sync (Pro feature) | `clock/ProfileSettingsView.swift` |
| `upgrade_google_signin_clicked` | Free user taps Google Calendar sync (Pro feature) | `clock/ProfileSettingsView.swift` |
| `google_signout_clicked` | Pro user signs out of Google Calendar | `clock/ProfileSettingsView.swift` |
| `theme_changed` | User switches the app visual theme | `clock/ProfileSettingsView.swift` |
| `clock_format_toggled` | User toggles between 12-hour and 24-hour clock | `clock/ProfileSettingsView.swift` |
| `testflight_free_unlock_clicked` | Reviewer/tester unlocks Pro for free in sandbox mode | `clock/HaikuProView.swift` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events instrumented:

- **Dashboard — Analytics basics**: https://us.posthog.com/project/366120/dashboard/1423010
- **Onboarding Funnel** (app launch → onboarding completed): https://us.posthog.com/project/366120/insights/yRssndtN
- **Pro Subscription Conversion Funnel** (paywall viewed → initiated → completed): https://us.posthog.com/project/366120/insights/xEv6JLho
- **Daily Task Creation (DAU)** (unique users creating tasks per day): https://us.posthog.com/project/366120/insights/tlexV3RO
- **Pro Upgrade Intent** (upgrade touches, paywall views, purchase initiations): https://us.posthog.com/project/366120/insights/IIAZdWbO
- **Feature Engagement: Tasks & Brain Dump** (clock tasks vs brain dump adds/completions): https://us.posthog.com/project/366120/insights/deA2hbZp

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
