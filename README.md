# TabSnap

**Scan receipts. Split smarter.**

TabSnap is a Flutter and Firebase mobile app that makes shared expense splitting faster, more accurate, and less manual. Instead of typing every item into a bill-splitting app, users can scan a receipt, review extracted items, assign items to participants, and instantly calculate who owes what.

---

## Overview

Splitting real-world bills is often frustrating.

Most expense-sharing apps work well for simple totals, but they become inefficient when:
- different people ordered different items
- grocery bills contain many shared and non-shared products
- users want faster entry with fewer mistakes
- one person pays and others need clear, fair balances

TabSnap solves this by combining **OCR-based receipt scanning** with **item-level expense assignment** and **real-time balance updates**.

---

## Problem

Shared expense tracking is still too manual.

Current workflows often require users to:
- enter each item by hand
- split totals equally even when usage was uneven
- recheck math manually
- manage confusion across friends and groups

For real receipts, especially grocery bills and group meals, this creates friction and errors.

---

## Solution

TabSnap simplifies the workflow into a few clear steps:

1. Scan a receipt
2. Extract items and prices using OCR
3. Review and correct extracted items if needed
4. Assign items to the people who used them
5. Select who paid
6. Save the expense and update balances

This makes the process faster, more transparent, and more accurate.

---

## Core Features

### Receipt Scanning
Capture a receipt and extract line items and prices using OCR.

### Item Review
Users can review extracted items before splitting to ensure accuracy.

### Item-Level Assignment
Assign each item to one or more participants instead of relying only on equal splitting.

### Smart Split Calculation
The app calculates how much each person owes based on actual item assignment.

### Real-Time Sync
Expenses, balances, and activity updates sync across connected users in real time.

### Friends and Groups
Organize shared expenses across direct friends and recurring groups.

### Activity Tracking
Track saved expenses and settlement-related activity over time.

### Settlement Support
Record payment settlement flows and maintain clean bilateral balances.

---

## How It Works

### Example Flow
- A user scans a grocery receipt
- TabSnap extracts all detected items and prices
- The user assigns each item to the correct people
- The user selects who paid
- The app calculates each person’s share
- The expense is saved to the cloud
- Connected users see updated balances and activity

---

## Tech Stack

### Frontend
- Flutter
- Dart

### Backend
- Firebase Authentication
- Cloud Firestore

### OCR
- Google ML Kit Text Recognition

### State / Data Flow
- Firestore real-time listeners
- app-level service-driven architecture

---

## Architecture Summary

TabSnap follows a client-cloud architecture:

- **Flutter** handles UI, local interaction, and flow control
- **Firebase Auth** manages identity
- **Firestore** stores users, groups, expenses, activities, and balances
- **OCR services** process receipt text into structured item data
- **Real-time listeners** keep users synchronized across devices

A key design principle in the app is **bilateral balance logic**, which ensures users only see direct financial relationships instead of confusing indirect group debt.

---

## Current Status

TabSnap is currently a **working MVP in active development**.

### Implemented
- authentication and onboarding flow
- OCR-based receipt scanning
- receipt item review
- item assignment flow
- split summary calculation
- expense saving
- real-time sync
- friend and group structures
- activity tracking
- bilateral debt filtering

### In Progress / Planned
- stronger onboarding and friend connection experience
- QR-based quick add refinement
- improved group membership flows
- better home dashboard financial clarity
- more polished settlement experience
- broader real-user testing
- OCR reliability improvements across more receipt formats

---

## Project Structure

```bash
lib/
├── main.dart
├── firebase_options.dart
├── models/
├── router/
├── screens/
│   ├── auth/
│   ├── main/
│   ├── groups/
│   ├── expense/
│   ├── friends/
│   ├── settle/
│   ├── profile/
│   └── activity/
├── services/
├── utils/
└── widgets/
