# Get In Loser - Web App

A modern web application for planning trips with friends, built with vanilla JavaScript and Firebase.

## 🚀 Features

- ✈️ **Trip Management** - Create and organize trips with friends
- 📅 **Itinerary** - Plan events with dates, times, and locations
- 🎫 **Tickets** - Upload and share tickets, boarding passes, and documents
- 📝 **Shared Notes** - Collaborative note-taking with auto-save
- ✅ **To-Do Lists** - Track tasks with per-member completion
- 💰 **IOUs** - Keep track of who owes what
- 🔗 **Invite Codes** - Easy trip sharing with 6-character codes
- 📱 **PWA** - Installable as a mobile app
- ⚡ **Real-time Sync** - Powered by Firebase Firestore

## 🛠️ Setup Instructions

### 1. Install Dependencies

```bash
cd web
npm install
```

### 2. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **roadrunner-a10d7**
3. Go to Project Settings (⚙️ icon)
4. Scroll to "Your apps" → Web apps
5. If no web app exists, click "Add app" (</>) and register it
6. Copy the Firebase configuration object

7. Update `src/config/firebase-config.js` with your actual values:

```javascript
export const firebaseConfig = {
  apiKey: "YOUR_ACTUAL_API_KEY",
  authDomain: "roadrunner-a10d7.firebaseapp.com",
  projectId: "roadrunner-a10d7",
  storageBucket: "roadrunner-a10d7.firebasestorage.app",
  messagingSenderId: "YOUR_ACTUAL_SENDER_ID",
  appId: "YOUR_ACTUAL_APP_ID"
};
```

### 3. Set Up Firestore Database

1. In Firebase Console → **Firestore Database**
2. Click "Create database"
3. Choose **test mode** (for development)
4. Select your preferred region
5. Click "Enable"

The security rules are already configured in `firestore.rules` and will be deployed automatically.

### 4. Set Up Cloud Storage

1. In Firebase Console → **Storage**
2. Click "Get started"
3. Choose **test mode**
4. Click "Done"

The security rules are already configured in `storage.rules`.

### 5. Run Development Server

```bash
npm run dev
```

This will start the Vite development server at `http://localhost:3000`

### 6. Build for Production

```bash
npm run build
```

This creates an optimized production build in the `dist/` folder.

### 7. Deploy to Firebase Hosting (Optional)

First, install Firebase CLI:

```bash
npm install -g firebase-tools
```

Login and initialize:

```bash
firebase login
firebase init hosting
# Select:
# - Use existing project: roadrunner-a10d7
# - Public directory: dist
# - Single-page app: Yes
# - Set up automatic builds: No
```

Deploy the security rules and hosting:

```bash
npm run build
firebase deploy
```

Your app will be live at: `https://roadrunner-a10d7.web.app`

## 📱 Install as PWA

Once deployed or running locally:

1. **Desktop (Chrome/Edge)**:
   - Click the install icon (⊕) in the address bar
   - Or: Menu → Install Get In Loser

2. **Mobile (iOS Safari)**:
   - Tap the Share button
   - Scroll and tap "Add to Home Screen"

3. **Mobile (Android Chrome)**:
   - Tap the menu (⋮)
   - Tap "Install app" or "Add to Home Screen"

## 🏗️ Project Structure

```
web/
├── public/
│   ├── manifest.json          # PWA manifest
│   └── favicon.svg            # App icon
├── src/
│   ├── config/
│   │   └── firebase-config.js # Firebase configuration
│   ├── services/
│   │   └── firebase.js        # Firebase service layer
│   ├── views/
│   │   ├── home.js           # Home page with trip list
│   │   └── trip-detail.js    # Trip detail with tabs
│   ├── styles.css            # Global styles
│   └── main.js               # App entry point & router
├── firebase.json              # Firebase hosting config
├── firestore.rules            # Firestore security rules
├── storage.rules              # Storage security rules
├── package.json
└── vite.config.js            # Vite build config
```

## 🎨 Features Overview

### Home Page
- View all your trips
- Create new trips
- Join trips with invite codes
- Trips sorted by start date

### Trip Detail Page

**Itinerary Tab**
- Add events with date, time, location, and notes
- Events sorted chronologically
- Delete events

**Tickets Tab**
- Upload images and PDFs
- View/download tickets
- Automatic cloud storage

**Notes Tab**
- Shared notepad for all trip members
- Auto-save after 2 seconds
- Manual save button

**To-Do Tab**
- Create shared tasks
- Each member can check off tasks independently
- Strike-through completed items

**IOUs Tab**
- Track who owes who
- Record amount and description
- Quick overview of all debts

## 🔒 Security Notes

**Current Setup (Development)**
- Security rules allow open read/write for testing
- User IDs are device-based (not authenticated)

**Production Recommendations**
1. Add Firebase Authentication
2. Update security rules to verify authenticated users
3. Restrict operations based on trip membership
4. Add user profiles and avatars

Example production rule:
```
allow read, write: if request.auth != null && 
                    request.auth.uid in resource.data.memberIDs;
```

## 🌐 Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+
- Mobile browsers (iOS Safari, Chrome Android)

## 📝 Development Notes

### No Build Tools Required for Development
The app uses ES modules and runs directly in modern browsers during development.

### Hot Module Replacement
Vite provides instant hot reloading during development.

### Offline Support (Future)
Can be enhanced with Firebase offline persistence and service workers.

## 🐛 Troubleshooting

**Firebase errors on load**
- Make sure you updated `firebase-config.js` with real values
- Check Firebase Console that Firestore and Storage are enabled

**Can't create trips**
- Check browser console for errors
- Verify Firestore security rules are deployed
- Make sure dates are valid

**File uploads fail**
- Check Storage is enabled in Firebase Console
- Verify storage rules are deployed
- Check file size limits (Firebase has 5GB free tier)

**Invite codes don't work**
- Codes are case-insensitive and 6 characters
- Make sure the trip exists in Firestore
- Check browser console for errors

## 🚀 Next Steps

- [ ] Add Firebase Authentication for real user accounts
- [ ] Add user profiles with avatars
- [ ] Real-time updates with Firestore listeners
- [ ] Push notifications for trip updates
- [ ] Map integration for locations
- [ ] Budget tracking feature
- [ ] Photo gallery for trip memories
- [ ] Export trip summary as PDF

## 📄 License

MIT

---

**Built with ❤️ using Firebase and Vite**
