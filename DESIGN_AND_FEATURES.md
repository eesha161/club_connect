# ClubConnect - My App Project 📱

## What is this?

Hey! This is **ClubConnect**, an app I built to help students at my school (and others!) easily find clubs, track their volunteer hours, and just stay involved. I used **Flutter** to build it so it works on both iPhones and Androids because I wanted everyone to be able to use it.

## Why I made this

Honestly, keeping track of club meetings and volunteer hours is a pain. I always forget when meetings are, or I lose that paper sheet where I wrote down my service hours.
So I thought, "Why not make an app for this?"

**The goal is simple:**
- Help students find clubs they actually like.
- Stop using paper sign-in sheets (QR codes are way cooler).
- Make sure nobody loses their volunteer hour records again.

## The Core Stuff (Requirements)

I made sure to hit all the main requirements for the project:

- ✅ **Backend**: Used **Firebase** for the database and auth. It's secure and cloud-based.
- ✅ **Users**: You can sign up, log in, reset passwords, and even use **Google Sign-In**.
- ✅ **Clubs**: You can browse, search, and join clubs. Some are private and need a code.
- ✅ **Events**: There's a full calendar, RSVPs, and I built a **QR code scanner** for check-ins.
- ✅ **Admin Dashboard**: Club leaders have their own special dashboard to manage everything.
- ✅ **UI**: I spent a lot of time making it look professional with a nice green theme.
- ✅ **APIs**: I integrated **6 APIs** including Firebase stuff, Google Sign-In, Google Fonts, and even Google Calendar.

## 12 Extra Features I Added 🌟

I wanted to go above and beyond, so I added a bunch of extra features that weren't strictly required but make the app way better:

**1. Volunteer Hour Tracking** ⏱️
The app automatically calculates your hours when you check in and out of events. You can even export a report for college apps!

**2. Strike System** ⚠️
To stop people from ghosting events, I added a strike system. If you miss 3 events without a reason, you get suspended from volunteering. Keeps people accountable.

**3. Digital Badges** 🏆
Referencing gamification, I added badges you can earn for things like "10 Hours Volunteered" or "First Event." It looks cool on your profile.

**4. QR Code Check-In** 📷
Instead of a paper list, every event has a unique QR code. You just scan it with the app to verify you're there.

**5. Advanced Search** 🔍
You can filter clubs by state, city, and even education level (High School vs College).

**6. Social Features (Chat/Q&A)** 💬
Every club has a comment section where members can ask questions and chat.

**7. Custom Forms** 📝
Clubs can have join applications (questionnaires), and events can have custom registration forms.

**8. Notification Inbox** 🔔
I built a whole notification center in the app so you see reminders and announcements.

**9. Google Calendar Sync** 📅
You can click a button to add club events directly to your personal Google Calendar.

**10. Data Export** 📄
Admins can download attendance lists, and students can download their volunteer history as PDFs.

**11. Multiple Roles** 👥
The app handles different permissions for regular members vs. club admins.

**12. Rate My Event** ⭐
After an event, you can rate it and leave feedback so organizers know how it went.

## Design Concept 🎨

I wanted the app to feel "academic but fresh," so I went with a **Green Theme**.
- **Dark Green**: Represents growth and nature.
- **Light Green**: Makes it feel friendly.

**Fonts I chose:**
- **Headers**: *Playfair Display* (It looks fancy and serious, like a diploma).
- **Body**: *Poppins* (It's super clean and easy to read on phones).

I used a lot of **cards** and **rounded corners** to make it look modern (Material Design 3 style).

## How it works technically

- **Frontend**: Flutter (Dart).
- **Backend**: Firebase Firestore (Real-time database!).
- **Platforms**: iOS and Android (Single codebase).

## Who is this for?

- **Students**: Like me, who need to track hours and find clubs.
- **Club Leaders**: Who are tired of managing spreadsheets.
- **Schools**: To keep track of all student activities in one place.

---

Thanks for checking out my project! I put a lot of work into making the UI look polished and the features actually useful. Hope you like it!
