# Deun Expense Splitting App: Project Plan & Code Overview

This document provides an overview of the Deun Flutter application, its architecture, and a proposed plan for future development and maintenance.

## 1. Application Overview

Deun is a mobile application designed for splitting expenses among groups of people. It allows users to create groups, add friends, record expenses, and track who owes money to whom. The application is built with Flutter and leverages a modern tech stack for a real-time, responsive user experience.

### Core Features:

- **User Authentication:** Sign up, login, and password recovery using Supabase Auth.
- **Group Management:** Create, view, update, and delete groups.
- **Friend Management:** Invite and manage friends.
- **Expense Tracking:** Add, edit, and view expenses within groups.
- **Expense Splitting:** Automatically calculates what each member owes or is owed.
- **Real-time Updates:** Data syncs in real-time across all devices in a group.
- **Push Notifications:** Firebase Cloud Messaging for notifications.
- **Localization:** Support for multiple languages.

## 2. Technical Architecture

The application is well-structured and follows modern Flutter development best practices.

- **Framework:** Flutter 3.x
- **Backend:**
  - **Supabase:** Primary backend for Authentication, PostgreSQL Database, and Real-time subscriptions.
  - **Firebase:** Used for Firebase Core services and Cloud Messaging (FCM).
- **State Management:** `flutter_riverpod` with the `riverpod_generator`. This provides a robust and scalable way to manage application state.
- **Navigation:** `go_router` is used for declarative routing, including nested navigation for the main tabs and modal dialogs for creation/editing tasks.
- **Code Structure:**
  - The `lib` directory is organized by feature (`pages/groups`, `pages/expenses`, etc.).
  - Clear separation between UI (`pages`, `widgets`), state (`provider.dart`), and data models (`*.model.dart`).
  - Reusable UI components are located in the `lib/widgets` directory.
  - Helper functions are in `lib/helper/helper.dart`.
- **Monetization:** `google_mobile_ads` is integrated to display native ads.

## 3. Codebase Highlights & Analysis

### Authentication (`lib/auth_gate.dart`, `lib/pages/auth/`)

- A `StreamBuilder` on `supabase.auth.onAuthStateChange` cleanly separates authenticated users from the login screen.
- On sign-in, user profile data is automatically upserted into a `user` table in Supabase.

### Navigation (`lib/navigation.dart`)

- Uses `go_router`'s `StatefulShellRoute` to create a bottom navigation bar with persistent state across the 'Groups', 'Friends', and 'Settings' tabs.
- Routes are well-defined, passing data between screens using the `extra` parameter.
- Deep linking is set up to handle incoming links.

### State Management (`lib/provider.dart`)

- This is the core of the application's logic.
- It uses Riverpod's code generation (`@riverpod`) for creating providers, which is the recommended modern approach.
- **Key Feature:** It heavily utilizes Supabase Realtime subscriptions. Notifiers listen to `PostgresChanges` and automatically refresh the state, making the UI highly reactive.
- The `ExpenseListNotifier` demonstrates advanced features like pagination (infinite scrolling) and optimistic updates for insert, update, and delete events, which is excellent for user experience.

### UI (`lib/pages/`, `lib/widgets/`)

- The UI is built with standard Flutter widgets.
- `NestedScrollView` and `SliverAppBar` are used to create modern scrolling experiences in detail views.
- Loading states are handled gracefully with `ShimmerCardList` widgets, and empty states with a dedicated `EmptyListWidget`.
- The expense list within a group (`lib/pages/groups/group_detail_list.dart`) is a good example of a complex, state-driven UI, combining pagination, pull-to-refresh, and dynamic item rendering.

## 4. Proposed Project Plan & Future Improvements

The application is in a very good state. The following plan focuses on refactoring for long-term maintainability, improving performance, and adding new features.

### Phase 1: Refactoring & Code Quality

- **[Task] Introduce a Repository Layer:**

  - **Why:** Currently, data fetching logic (`Group.fetchData`, etc.) is in model classes. A dedicated repository layer would better separate data access from data modeling, improving testability and adhering to Clean Architecture principles.
  - **Action:** Create a `repositories` directory. For each data domain (e.g., `groups`, `expenses`), create a repository class (e.g., `GroupRepository`) that handles all communication with Supabase for that domain. The Riverpod providers will then call these repositories instead of static model methods.

- **[Task] Refactor Global Keys:**

  - **Why:** The use of multiple `GlobalKey<ScaffoldMessengerState>` in `main.dart` is not ideal. It creates a dependency on specific scaffold instances and is less flexible than a state-based approach.
  - **Action:** Create a `NotificationService` managed by a Riverpod provider. This service can hold a list of notifications (e.g., snackbar messages). The main app widget can then listen to this provider and display notifications accordingly, removing the need for global keys.

- **[Task] Enhance Real-time Updates:**
  - **Why:** Some notifiers (e.g., `GroupListNotifier`) simply reload the entire list on any change. This can be inefficient.
  - **Action:** Apply the more granular, optimistic update logic seen in `ExpenseListNotifier` to other notifiers like `GroupListNotifier` and `FriendshipListNotifier`. This involves handling `insert`, `update`, and `delete` events individually to avoid unnecessary refetches.

### Phase 2: Feature Enhancements

- **[Feature] User Profile & Settings:**

  - Allow users to update their display name, profile picture, and other settings.
  - Implement a "dark mode" / "light mode" / "system" theme toggle in the settings page.

- **[Feature] Improved Expense Creation:**

  - Add features like splitting by percentage, shares, or exact amounts.
  - Allow attaching receipts (image uploads to Supabase Storage).

- **[Feature] Search & Filtering:**

  - The search functionality in `GroupDetail` is a good start. This could be expanded.
  - Add filtering options to the group list (e.g., filter by groups with outstanding balances).
  - Add a global search to find expenses or groups across the entire app.

- **[Feature] Settle Up & Payments:**
  - Create a "Settle Up" feature that calculates the simplest way for everyone in a group to pay each other back.
  - Integrate with a payment service (e.g., Stripe, PayPal) to allow users to settle debts directly within the app.

### Phase 3: Testing & Deployment

- **[Task] Increase Test Coverage:**

  - Write more unit tests for the business logic in the notifiers and repositories.
  - Write widget tests for complex UI components.
  - Write integration tests for critical user flows (e.g., creating a group, adding an expense, and settling up).

- **[Task] CI/CD Pipeline:**
  - Set up a Continuous Integration/Continuous Deployment (CI/CD) pipeline using GitHub Actions or a similar service.
  - Automate running tests, building the app, and deploying it to the app stores.
