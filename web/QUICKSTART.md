# 🚀 Quick Start Guide

Get your web app running in 5 minutes!

## Prerequisites
- Node.js 16+ installed
- Your Firebase project: **roadrunner-a10d7**

## Steps

### 1. Install Dependencies
```bash
cd /Users/taylordrew/Documents/getinloser2/web
npm install
```

### 2. Get Firebase Config

1. Go to https://console.firebase.google.com/project/roadrunner-a10d7/settings/general
2. Scroll to "Your apps" → "Web apps"
3. Click "Add app" (</>) if you don't have one
4. Copy the `firebaseConfig` object

### 3. Update Configuration

Edit `src/config/firebase-config.js` and replace with your actual values:

```javascript
export const firebaseConfig = {
  apiKey: "AIza...",           // ← Your real key
  authDomain: "roadrunner-a10d7.firebaseapp.com",
  projectId: "roadrunner-a10d7",
  storageBucket: "roadrunner-a10d7.firebasestorage.app",
  messagingSenderId: "123...",  // ← Your real ID
  appId: "1:123..."            // ← Your real ID
};
```

### 4. Enable Firestore

1. Go to https://console.firebase.google.com/project/roadrunner-a10d7/firestore
2. Click "Create database"
3. Select **Start in test mode**
4. Choose a region (e.g., us-central)
5. Click "Enable"

### 5. Enable Storage

1. Go to https://console.firebase.google.com/project/roadrunner-a10d7/storage
2. Click "Get started"
3. Select **Start in test mode**
4. Click "Done"

### 6. Run the App!

```bash
npm run dev
```

Open http://localhost:3000 in your browser 🎉

## What You Can Do

✅ Create a trip
✅ Join a trip with invite code
✅ Add events to itinerary
✅ Upload tickets
✅ Write shared notes
✅ Create to-dos
✅ Track IOUs

## Deploy to Web (Optional)

```bash
# Build
npm run build

# Deploy to Firebase Hosting
npm install -g firebase-tools
firebase login
firebase init hosting  # Select roadrunner-a10d7, dist folder
firebase deploy
```

Your app will be live at: https://roadrunner-a10d7.web.app

## Troubleshooting

**"Firebase not configured" error?**
→ Update `src/config/firebase-config.js` with real values from Firebase Console

**Can't create trips?**
→ Make sure Firestore is enabled in test mode

**File uploads fail?**
→ Make sure Storage is enabled in test mode

**Need help?**
→ Check the browser console for error messages
→ Read the full README.md

---

That's it! You're ready to plan trips! 🚀✈️
