// ignore_for_file: non_constant_identifier_names

import 'package:cards/features/nfc_tag/presentation/widgets/confirm_action_dialog.dart';
import 'package:cards/firebase/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

Color selectDark = const Color.fromARGB(255, 0, 176, 158);
Color selectLight = const Color.fromARGB(255, 79, 220, 154);
const blue = Color(0xFF0066CC);
const orange = Color(0xFFFF6600);

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)!.settings.name;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final photoUrl = _auth.currentUser?.photoURL;

    print(routeName);

    Widget MyListTile({
      required String title,
      required IconData icon,
      required String myRouteName,
      required bool selected,
    }) {
      return Container(
        width: 250,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
                colors: selected
                    ? [blue, blue]
                    : [
                        Colors.transparent,
                        Colors.transparent,
                      ])),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minLeadingWidth: 30,
          leading: Icon(icon, color: selected ? Colors.white : Colors.black38),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black38,
              fontSize: 15,
              // fontFamily: font1,
            ),
          ),
          onTap: () {
            if (routeName != myRouteName && myRouteName.isNotEmpty) {
              Navigator.of(context).pushReplacementNamed(myRouteName);
            }
          },
        ),
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: Container(
        margin: const EdgeInsets.only(left: 15, top: 50),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Show fallback if the image fails to load
                                  return Center(
                                    child: Icon(Icons.person,
                                        size: 40, color: Colors.grey.shade400),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  (loadingProgress
                                                          .expectedTotalBytes ??
                                                      1)
                                              : null,
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Icon(Icons.person,
                                    size: 40, color: Colors.grey.shade400),
                              ),
                      ),
                    ),
                    // Positioned(
                    //     bottom: -5,
                    //     right: -5,
                    //     child: Container(
                    //         padding: const EdgeInsets.all(5),
                    //         decoration: BoxDecoration(
                    //             color: Colors.white,
                    //             borderRadius: BorderRadius.circular(20)),
                    //         child: Icon(
                    //           Icons.edit,
                    //           size: 20,
                    //           color: orange,
                    //         )))
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Center(
                child: Text(_auth.currentUser?.displayName ?? "User",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
              ),
              // SizedBox(
              //   height: 3,
              // ),
              // Center(
              //   child: Text(_auth.currentUser?.email ?? "User",
              //       style: TextStyle(
              //           fontSize: 12,
              //           fontWeight: FontWeight.bold,
              //           color: Colors.grey[500])),
              // ),
              const SizedBox(
                height: 30,
              ),
              MyListTile(
                  title: "Home",
                  icon: FluentIcons.home_32_filled,
                  myRouteName: "",
                  selected: routeName == "/home"),
              MyListTile(
                  title: "Analytics",
                  icon: FluentIcons.data_area_20_filled,
                  myRouteName: "",
                  selected: routeName == "/analysis"),
              MyListTile(
                  title: "Subscription",
                  icon: FluentIcons.premium_32_filled,
                  myRouteName: "",
                  selected: routeName == "/logs"),
              MyListTile(
                  title: "Account",
                  icon: FluentIcons.person_48_filled,
                  myRouteName: "",
                  selected: routeName == "/settings"),
              Spacer(),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: EdgeInsets.all(5),
                    color: Colors.transparent,
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => ConfirmActionDialog(
                            title: "Logout",
                            description:
                                "Are you sure you want to log out of your account?",
                            cancelText: "Stay Logged In",
                            confirmText: "Logout",
                            icon: Icons.logout,
                            iconBgColor: Colors.orange,
                            confirmButtonColor: Colors.red,
                            onCancel: () {},
                            onConfirm: () {
                              AuthService().logout(context);
                            },
                          ),
                        );
                      },
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                          color: orange, // makes it stand out
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => ConfirmActionDialog(
                          title: "Delete Item?",
                          description:
                              "This action cannot be undone. Are you sure?",
                          cancelText: "No, Keep",
                          confirmText: "Yes, Delete",
                          icon: Icons.delete_forever,
                          iconBgColor: Colors.red,
                          cancelButtonColor: Colors.white,
                          confirmButtonColor: Colors.red,
                          onCancel: () {
                            print("object");
                          },
                          onConfirm: () {
                            AuthService().deleteAccount(context);
                          },
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: EdgeInsets.all(5),
                      child: Icon(Icons.delete_forever, color: Colors.red[400]),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 50,
              )
            ]),
      ),
    );
  }
}
