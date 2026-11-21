# SOFE4640U_Assignment3
Flutter Food Ordering Application using Dart and SQLite

## Pizza Pizza Food Ordering Application

A Flutter-based food ordering and daily budget planning application developed using Dart and SQLite. The application allows users to manage restaurant menu items, plan daily food orders, and track spending within a selected budget.

## Technologies Used

- **Flutter:** Cross-platform application framework
- **Dart:** Application programming language
- **SQLite (sqflite):** Local database for food items and saved orders
- **Android Studio:** Development and testing environment
- **GitHub:** Version control and source code management

## Application Features

1. **Food Menu Management:** View, add, update, and delete food items.
2. **Automatic Database Seeding:** Initializes the SQLite database with 20 predefined food items on first installation.
3. **Daily Budget Planning:** Select food items while ensuring the total cost does not exceed the daily budget.
4. **Order Management:** Create, view, update, and delete saved order plans.
5. **Date-Based Search:** Search for saved orders using a selected date.
6. **Order Sorting:** Display saved order plans in descending date order.
7. **Historical Item Preservation:** Preserve food item names and original prices in saved orders even when those items are deleted from the menu.
8. **Menu Search and Filtering:** Search food items by name and filter results by category.

## SQLite Database Structure

The application uses three database tables:

- **food_items:** Stores food names, categories, and prices.
- **order_plans:** Stores order dates and daily target budgets.
- **order_items:** Stores the food items associated with each saved order, including their original names and prices.

The database is created automatically when the application first runs, and the 20 initial food items are inserted during database initialization.

All data is stored locally using SQLite. Firebase is not required.

## How to Run the Application

### Requirements

- Flutter SDK
- Android Studio
- Android emulator or compatible Android device

### Installation Steps

1. Clone the repository:

   `git clone https://github.com/Muji90/SOFE4640U_Assignment3.git`

2. Open the `SOFE4640U_Assignment3` folder in Android Studio.
3. Open the terminal in the project directory.
4. Install dependencies:

   `flutter pub get`

5. Start an Android emulator.
6. Run the application:

   `flutter run`

If Flutter encounters a Dart Development Service connection issue in the development environment, the following command can be tried:

`flutter run --no-dds`

### Build Release APK

`flutter build apk --release`

The generated APK is located at:

`build/app/outputs/flutter-apk/app-release.apk`

## Testing

The application was manually tested on a Pixel 7 Android emulator.

The following functionality was verified:

- Automatic loading of the 20 seeded menu items
- Adding, updating, and deleting food items
- Daily budget calculations and budget-exceeded validation
- Creating and updating order plans
- Searching orders by date
- Displaying orders in descending date order
- Deleting saved orders
- Preserving historical food items
- Food menu searching and category filtering

The project also contains SQLite integration test code. Automated integration-test execution encountered test-runner connection issues and has not been confirmed as passing.

Static analysis completed with no issues, and the Android release APK was built successfully.

## GitHub Version Control

The repository contains six commits documenting the initial project setup, application implementation, bug fixes, database testing support, historical item preservation, and menu searching and filtering.

## Repository

https://github.com/Muji90/SOFE4640U_Assignment3
