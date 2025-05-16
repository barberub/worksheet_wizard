# Worksheet Wizard

A Flutter-based application made to create worksheets easily.
Currently, supports local storage with JSON and cloud storage with Firestore. Cloud storage requires Firebase Authentication login.

# Files

main.dart
 - Initial screen when starting the app.
 - Where most cloud services are initiated.

storage_service.dart
 - Handles storage
   - Cloud and Local

worksheetscreen.dart
 - Worksheet editing screen
   - Cloud saving option when leaving worksheet


# TODO

 - Onboarding
   - How to use the app
   - Tutorial
   - Show how to use the math markdown
 - Preview
   - Zoom in and out
 - Formatting options
   - Dual column
   - Landscape
   - Borders
 - Image support
   - Add graphs
   - Diagrams
   - Tables
   - Custom images
 - True version checking
   - When to display 'save to cloud' option