import 'package:google_fonts/google_fonts.dart'; // NEW
import 'package:flutter/material.dart';
import 'package:club_connect/screens/profile_screen.dart';
import 'package:club_connect/screens/inbox_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/services/inbox_service.dart'; // NEW
import 'package:club_connect/models/user_profile.dart'; // Ensure you have this import

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showProfile;
  final bool showInbox;

  final bool automaticallyImplyLeading;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.showProfile = true,
    this.showInbox = true,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      centerTitle: false,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      actions: [
        if (actions != null) ...actions!,
        
        // Inbox Button with Badge
        if (showInbox)
           StreamBuilder<int>(
             stream: FirebaseAuth.instance.currentUser != null 
                 ? InboxService().getUnreadCountStream(FirebaseAuth.instance.currentUser!.uid)
                 : Stream.value(0),
             builder: (context, snapshot) {
               final count = snapshot.data ?? 0;
               return IconButton(
                 icon: Badge(
                   isLabelVisible: count > 0,
                   label: Text('$count'),
                   child: const Icon(Icons.mail_outline),
                 ),
                 tooltip: 'Inbox',
                 onPressed: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const InboxScreen()),
                   );
                 },
               );
             }
          ),

        // Profile Button 
        if (showProfile)
          StreamBuilder<UserProfile?>(
             stream: FirebaseAuth.instance.currentUser != null 
                 ? UserService().getProfileStream(FirebaseAuth.instance.currentUser!.uid)
                 : Stream.value(null),
             builder: (context, snapshot) {
               // If we have a profile pic, show avatar. Otherwise show icon.
               if (snapshot.hasData && snapshot.data!.photoUrl != null && snapshot.data!.photoUrl!.isNotEmpty) {
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(snapshot.data!.photoUrl!),
                        onBackgroundImageError: (_, __) => {}, // invalid url handle
                        child: null,
                      ),
                    ),
                  );
               }
               
               return IconButton(
                 icon: const Icon(Icons.account_circle),
                 tooltip: 'Profile',
                 onPressed: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const ProfileScreen()),
                   );
                 },
               );
             }
          ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
