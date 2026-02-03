// // // lib/features/nfc_tag/presentation/pages/home_page.dart
// //
// // import 'package:cards/features/nfc_tag/presentation/widgets/confirm_action_dialog.dart';
// // import 'package:cards/features/nfc_tag/utils/drawer.dart';
// // import 'package:cards/firebase/auth_services.dart';
// // import 'package:cards/features/nfc_tag/presentation/widgets/alert_bar.dart';
// // import 'package:fluentui_system_icons/fluentui_system_icons.dart';
// // import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import 'package:nfc_manager/nfc_manager.dart';
// // import 'package:lottie/lottie.dart';
// //
// // import '../viewmodels/home_view_model.dart';
// // import '../widgets/animated_button.dart';
// //
// // import '../widgets/validation_dialog.dart';
// // import '../widgets/confirm_clear_dialog.dart';
// // import 'enter_url_page.dart';
// //
// // class HomePage extends StatefulWidget {
// //   static const routeName = '/home';
// //   const HomePage({super.key});
// //
// //   @override
// //   State<HomePage> createState() => _HomePageState();
// // }
// //
// // class _HomePageState extends State<HomePage> {
// //   final _urlController = TextEditingController();
// //   late final HomeViewModel _vm;
// //   bool _nfcAvailable = false;
// //   bool _scanningDialogShowing = false;
// //
// //   static const blue = Color(0xFF0066CC);
// //   static const orange = Color(0xFFFF6600);
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // 1) Check NFC capability
// //     NfcManager.instance.isAvailable().then((v) {
// //       setState(() => _nfcAvailable = v);
// //     });
// //
// //     // 2) Grab the VM and listen for state changes
// //     _vm = context.read<HomeViewModel>();
// //     _vm.addListener(_onVmStateChanged);
// //   }
// //
// //   @override
// //   void dispose() {
// //     _vm.removeListener(_onVmStateChanged);
// //     _urlController.dispose();
// //     super.dispose();
// //   }
// //
// //   // Whenever vm.state changes, show or hide the scanning dialog, then show result.
// //   void _onVmStateChanged() {
// //     switch (_vm.state) {
// //       case ViewState.busy:
// //         if (!_scanningDialogShowing) {
// //           _scanningDialogShowing = true;
// //           showDialog(
// //             context: context,
// //             barrierDismissible: false,
// //             builder: (_) => AlertDialog(
// //               title: const Text('Scanning NFC Tag'),
// //               content: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   // replaced spinner with Lottie animation
// //                   Lottie.asset(
// //                     'assets/scanner.json',
// //                     width: 150,
// //                     height: 150,
// //                     repeat: true,
// //                     fit: BoxFit.contain,
// //                   ),
// //                   const SizedBox(height: 12),
// //                   const Text('Hold your device close to the NFC card'),
// //                 ],
// //               ),
// //             ),
// //           );
// //         }
// //         break;
// //
// //       case ViewState.success:
// //       case ViewState.error:
// //         if (_scanningDialogShowing) {
// //           Navigator.of(context, rootNavigator: true)
// //               .pop(); // close scanning dialog
// //           _scanningDialogShowing = false;
// //         }
// //
// //         if (_vm.state == ViewState.success) {
// //           if (_vm.lastAction == NfcAction.write) {
// //             _alert('Success', 'Card written successfully!');
// //           } else if (_vm.lastAction == NfcAction.clear) {
// //             _alert('Success', 'Card cleared successfully!');
// //           } else {
// //             _alert('Success', 'Operation completed!');
// //           }
// //         } else {
// //           // Special case: empty card when clearing
// //           if (_vm.errorMessage == 'EMPTY_TAG') {
// //             _alert('Info', 'Card has nothing to clear — it is already empty.');
// //           } else {
// //             _alert('Error', _vm.errorMessage ?? 'Unknown error');
// //           }
// //         }
// //         break;
// //
// //       case ViewState.idle:
// //         // nothing
// //         break;
// //     }
// //   }
// //
// //   void _snack(String msg) =>
// //       ShowAlertBar().alertDialog(context, msg, Colors.orange);
// //
// //   Future<void> _alert(String title, String msg) => showDialog(
// //         context: context,
// //         builder: (_) => AlertDialog(
// //           title: Text(title),
// //           content: Text(msg),
// //           actions: [
// //             TextButton(
// //               onPressed: () => Navigator.pop(context),
// //               child: const Text('OK'),
// //             )
// //           ],
// //         ),
// //       );
// //
// //   Future<void> _showEnterUrl() async {
// //     _urlController.clear();
// //
// //     // 1) Full-screen URL entry
// //     final tappedSet = await Navigator.push<bool>(
// //       context,
// //       MaterialPageRoute(
// //         builder: (_) => EnterUrlPage(controller: _urlController),
// //       ),
// //     );
// //     if (tappedSet != true) return;
// //
// //     // 2) Check non-empty
// //     final url = _urlController.text.trim();
// //     if (url.isEmpty) return _snack('URL cannot be empty');
// //
// //     // 3) Validate reachability exactly as before
// //     final proceed = await showDialog<bool>(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (_) => ValidationDialog(
// //         url: url,
// //         validator: _vm.checkUrl,
// //       ),
// //     );
// //     if (proceed == true) {
// //       _vm.onWrite(url);
// //     }
// //   }
// //
// //   Future<void> _showConfirmClear() async {
// //     final confirm = await showDialog<bool>(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (_) => const ConfirmClearDialog(),
// //     );
// //     if (confirm == true) {
// //       _vm.onClear();
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     if (!_nfcAvailable) {
// //       return PopScope(
// //         canPop: false,
// //         child: Scaffold(
// //           appBar: AppBar(
// //             backgroundColor: Colors.transparent,
// //             elevation: 0,
// //             actions: [
// //               PopupMenuButton<String>(
// //                 icon: const Icon(Icons.more_vert, color: Colors.black),
// //                 onSelected: (value) {
// //                   if (value == 'logout') {
// //                     showDialog(
// //                       context: context,
// //                       builder: (_) => ConfirmActionDialog(
// //                         title: "Logout",
// //                         description:
// //                             "Are you sure you want to log out of your account?",
// //                         cancelText: "Stay Logged In",
// //                         confirmText: "Logout",
// //                         icon: Icons.logout,
// //                         iconBgColor: Colors.orange,
// //                         confirmButtonColor: Colors.red,
// //                         onCancel: () {},
// //                         onConfirm: () {
// //                           AuthService().logout(context);
// //                         },
// //                       ),
// //                     );
// //                   } else if (value == 'delete') {
// //                     showDialog(
// //                       context: context,
// //                       builder: (_) => ConfirmActionDialog(
// //                         title: "Delete Item?",
// //                         description:
// //                             "This action cannot be undone. Are you sure?",
// //                         cancelText: "No, Keep",
// //                         confirmText: "Yes, Delete",
// //                         icon: Icons.delete_forever,
// //                         iconBgColor: Colors.red,
// //                         cancelButtonColor: Colors.white,
// //                         confirmButtonColor: Colors.red,
// //                         onCancel: () {
// //                           print("object");
// //                         },
// //                         onConfirm: () {
// //                           AuthService().deleteAccount(context);
// //                         },
// //                       ),
// //                     );
// //                   }
// //                 },
// //                 itemBuilder: (context) => [
// //                   const PopupMenuItem(
// //                     value: 'logout',
// //                     child: Row(
// //                       children: [
// //                         Icon(Icons.logout, color: Colors.black54),
// //                         SizedBox(width: 10),
// //                         Text("Logout"),
// //                       ],
// //                     ),
// //                   ),
// //                   const PopupMenuItem(
// //                     value: 'delete',
// //                     child: Row(
// //                       children: [
// //                         Icon(Icons.delete_forever, color: Colors.red),
// //                         SizedBox(width: 10),
// //                         Text("Delete Account"),
// //                       ],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ],
// //           ),
// //           body: Center(
// //             child: Container(
// //               margin: EdgeInsets.all(20),
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 crossAxisAlignment: CrossAxisAlignment.center,
// //                 children: [
// //                   Icon(
// //                     Icons.cancel,
// //                     size: 70,
// //                     color: Colors.red,
// //                   ),
// //                   SizedBox(
// //                     height: 40,
// //                   ),
// //                   Text(
// //                     "Couldn't find NFC in your device. Make sure that you have your NFC feature enabled in Settings. And Restart the app.",
// //                     textAlign: TextAlign.center,
// //                     style: TextStyle(
// //                       fontSize: 16,
// //                       color: Colors.black87,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       );
// //     }
// //
// //     return PopScope(
// //       canPop: false,
// //       child: Scaffold(
// //         backgroundColor: Colors.white,
// //         drawerEnableOpenDragGesture: false,
// //         drawer: MyDrawer(),
// //         appBar: AppBar(
// //           leading: Builder(
// //             builder: (context) => IconButton(
// //               icon: const Icon(FluentIcons.more_vertical_20_filled,
// //                   color: Colors.black),
// //               onPressed: () => Scaffold.of(context).openDrawer(),
// //             ),
// //           ),
// //           backgroundColor: Colors.transparent,
// //           elevation: 0,
// //         ),
// //         body: SafeArea(
// //           child: Center(
// //             child: Column(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 const Image(
// //                   image: AssetImage('assets/logo_1.png'),
// //                   width: 200,
// //                   height: 200,
// //                   fit: BoxFit.contain,
// //                 ),
// //                 const SizedBox(height: 40),
// //                 AnimatedButton(
// //                   color: blue,
// //                   icon: Icons.edit,
// //                   label: 'WRITE URL',
// //                   onTap: _showEnterUrl,
// //                 ),
// //                 const SizedBox(height: 20),
// //                 AnimatedButton(
// //                   color: orange,
// //                   icon: Icons.cancel,
// //                   label: 'CLEAR URL',
// //                   onTap: _showConfirmClear,
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// // lib/features/nfc_tag/presentation/pages/home_page.dart
//
// import 'package:cards/features/nfc_tag/presentation/widgets/confirm_action_dialog.dart';
// import 'package:cards/features/nfc_tag/utils/drawer.dart';
// import 'package:cards/firebase/auth_services.dart';
// import 'package:cards/features/nfc_tag/presentation/widgets/alert_bar.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:fluentui_system_icons/fluentui_system_icons.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:nfc_manager/nfc_manager.dart';
// import 'package:lottie/lottie.dart';
//
// import '../viewmodels/home_view_model.dart';
// import '../widgets/animated_button.dart';
//
// import '../widgets/validation_dialog.dart';
// import '../widgets/confirm_clear_dialog.dart';
// import 'enter_url_page.dart';
//
// class HomePage extends StatefulWidget {
//   static const routeName = '/home';
//   const HomePage({super.key});
//
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   final _urlController = TextEditingController();
//   late final HomeViewModel _vm;
//   bool _nfcAvailable = false;
//   bool _scanningDialogShowing = false;
//
//   static const blue = Color(0xFF0066CC);
//   static const orange = Color(0xFFFF6600);
//   static const black = Color(0xFF111111);
//
//   @override
//   void initState() {
//     super.initState();
//     // 1) Check NFC capability
//     NfcManager.instance.isAvailable().then((v) {
//       if (!mounted) return;
//       setState(() => _nfcAvailable = v);
//     });
//
//     // 2) Grab the VM and listen for state changes
//     _vm = context.read<HomeViewModel>();
//     _vm.addListener(_onVmStateChanged);
//   }
//
//   @override
//   void dispose() {
//     _vm.removeListener(_onVmStateChanged);
//     _urlController.dispose();
//     super.dispose();
//   }
//
//   // Whenever vm.state changes, show or hide the scanning dialog, then show result.
//   void _onVmStateChanged() {
//     switch (_vm.state) {
//       case ViewState.busy:
//         if (!_scanningDialogShowing) {
//           _scanningDialogShowing = true;
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (_) => AlertDialog(
//               title: const Text('Scanning NFC Tag'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // replaced spinner with Lottie animation
//                   Lottie.asset(
//                     'assets/scanner.json',
//                     width: 150,
//                     height: 150,
//                     repeat: true,
//                     fit: BoxFit.contain,
//                   ),
//                   const SizedBox(height: 12),
//                   const Text('Hold your device close to the NFC card'),
//                 ],
//               ),
//             ),
//           );
//         }
//         break;
//
//       case ViewState.success:
//       case ViewState.error:
//         if (_scanningDialogShowing) {
//           Navigator.of(context, rootNavigator: true)
//               .pop(); // close scanning dialog
//           _scanningDialogShowing = false;
//         }
//
//         if (_vm.state == ViewState.success) {
//           if (_vm.lastAction == NfcAction.write) {
//             _alert('Success', 'Card written successfully!');
//           } else if (_vm.lastAction == NfcAction.clear) {
//             _alert('Success', 'Card cleared successfully!');
//           } else {
//             _alert('Success', 'Operation completed!');
//           }
//         } else {
//           // Special case: empty card when clearing
//           if (_vm.errorMessage == 'EMPTY_TAG') {
//             _alert('Info', 'Card has nothing to clear — it is already empty.');
//           } else {
//             _alert('Error', _vm.errorMessage ?? 'Unknown error');
//           }
//         }
//         break;
//
//       case ViewState.idle:
//       // nothing
//         break;
//     }
//   }
//
//   void _snack(String msg) =>
//       ShowAlertBar().alertDialog(context, msg, Colors.orange);
//
//   Future<void> _alert(String title, String msg) => showDialog(
//     context: context,
//     builder: (_) => AlertDialog(
//       title: Text(title),
//       content: Text(msg),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('OK'),
//         )
//       ],
//     ),
//   );
//
//   // ---------------------------------------------------------------------------
//   // VIEW SLOTS (direct Firestore; temporary per your request)
//   // ---------------------------------------------------------------------------
//
//   int _asInt(dynamic v) {
//     if (v is int) return v;
//     if (v is num) return v.toInt();
//     return 0;
//   }
//
//   String _asString(dynamic v) => v == null ? '-' : v.toString();
//
//   String _fmtTs(dynamic ts) {
//     if (ts is Timestamp) return ts.toDate().toString();
//     return _asString(ts);
//   }
//
//   Future<DocumentSnapshot<Map<String, dynamic>>?> _getAccountDoc() async {
//     final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
//     if (email == null || email.isEmpty) return null;
//
//     final q = await FirebaseFirestore.instance
//         .collection('accounts')
//         .where('shopifyEmail', isEqualTo: email)
//         .limit(1)
//         .get();
//
//     if (q.docs.isEmpty) return null;
//     return q.docs.first;
//   }
//
//   Future<void> _showSlotsDialog() async {
//     return showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Account Overview'),
//         content: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
//           future: _getAccountDoc(),
//           builder: (context, snap) {
//             if (snap.connectionState == ConnectionState.waiting) {
//               return const SizedBox(
//                 height: 90,
//                 child: Center(child: CircularProgressIndicator()),
//               );
//             }
//
//             final doc = snap.data;
//             if (doc == null || !doc.exists) {
//               return const Text(
//                 'No account record found for this email yet.\n\n'
//                     'This usually means Shopify has not sent the paid-order webhook for this customer, '
//                     'or the signed-in email does not match the Shopify email on the order.',
//               );
//             }
//
//             final data = doc.data() ?? {};
//
//             final planStatus = _asString(data['planStatus']);
//
//             final slotsAvailable = _asInt(data['slotsAvailable']);
//             final slotsUsed = _asInt(data['slotsUsed']);
//
//             final slotsPurchasedTotal = _asInt(data['slotsPurchasedTotal']);
//             final slotsRefundedTotal = _asInt(data['slotsRefundedTotal']);
//             final slotsNet = _asInt(data['slotsNet']);
//
//             final entitlementUpdatedAt = data['entitlementUpdatedAt'];
//             final updatedAt = data['updatedAt'];
//
//             final statusColor =
//             planStatus.toLowerCase() == 'active' ? Colors.green : orange;
//
//             Widget metricRow(String label, String value,
//                 {Color? valueColor, FontWeight? weight}) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 3),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         label,
//                         style: const TextStyle(fontSize: 13),
//                       ),
//                     ),
//                     Text(
//                       value,
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight: weight ?? FontWeight.w600,
//                         color: valueColor ?? Colors.black,
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }
//
//             return SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       const Text(
//                         'Plan Status: ',
//                         style: TextStyle(fontSize: 13),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 10, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: statusColor.withOpacity(0.12),
//                           borderRadius: BorderRadius.circular(20),
//                           border: Border.all(color: statusColor),
//                         ),
//                         child: Text(
//                           planStatus,
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                             color: statusColor,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   const Divider(),
//
//                   const Text(
//                     'Wristband Slots',
//                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
//                   ),
//                   const SizedBox(height: 8),
//
//                   metricRow('Available slots', '$slotsAvailable',
//                       valueColor: slotsAvailable > 0 ? Colors.green : orange),
//                   metricRow('Used slots (activated)', '$slotsUsed'),
//                   metricRow('Net slots', '$slotsNet'),
//
//                   const SizedBox(height: 10),
//                   const Divider(),
//
//                   const Text(
//                     'Purchase Totals (from Shopify)',
//                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
//                   ),
//                   const SizedBox(height: 8),
//
//                   metricRow('Purchased total', '$slotsPurchasedTotal'),
//                   metricRow('Refunded total', '$slotsRefundedTotal'),
//
//                   const SizedBox(height: 10),
//                   const Divider(),
//
//                   const Text(
//                     'Bracelets Assigned',
//                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
//                   ),
//                   const SizedBox(height: 8),
//
//                   metricRow('Assigned to teams/operators', 'Not available yet',
//                       valueColor: orange),
//                   const SizedBox(height: 6),
//                   const Text(
//                     'Note: This requires a wristbands inventory in Firestore (per-wristband records + team/operator assignment). '
//                         'Right now we only have slot totals mirrored from Shopify.',
//                     style: TextStyle(fontSize: 12, color: Colors.black54),
//                   ),
//
//                   const SizedBox(height: 12),
//                   const Divider(),
//
//                   Text(
//                     'Entitlements updated: ${_fmtTs(entitlementUpdatedAt)}',
//                     style: const TextStyle(fontSize: 12, color: Colors.black54),
//                   ),
//                   Text(
//                     'Last updated: ${_fmtTs(updatedAt)}',
//                     style: const TextStyle(fontSize: 12, color: Colors.black54),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ---------------------------------------------------------------------------
//
//   Future<void> _showEnterUrl() async {
//     _urlController.clear();
//
//     // 1) Full-screen URL entry
//     final tappedSet = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => EnterUrlPage(controller: _urlController),
//       ),
//     );
//     if (tappedSet != true) return;
//
//     // 2) Check non-empty
//     final url = _urlController.text.trim();
//     if (url.isEmpty) return _snack('URL cannot be empty');
//
//     // 3) Validate reachability exactly as before
//     final proceed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => ValidationDialog(
//         url: url,
//         validator: _vm.checkUrl,
//       ),
//     );
//     if (proceed == true) {
//       _vm.onWrite(url);
//     }
//   }
//
//   Future<void> _showConfirmClear() async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const ConfirmClearDialog(),
//     );
//     if (confirm == true) {
//       _vm.onClear();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_nfcAvailable) {
//       return PopScope(
//         canPop: false,
//         child: Scaffold(
//           appBar: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             actions: [
//               PopupMenuButton<String>(
//                 icon: const Icon(Icons.more_vert, color: Colors.black),
//                 onSelected: (value) {
//                   if (value == 'logout') {
//                     showDialog(
//                       context: context,
//                       builder: (_) => ConfirmActionDialog(
//                         title: "Logout",
//                         description:
//                         "Are you sure you want to log out of your account?",
//                         cancelText: "Stay Logged In",
//                         confirmText: "Logout",
//                         icon: Icons.logout,
//                         iconBgColor: Colors.orange,
//                         confirmButtonColor: Colors.red,
//                         onCancel: () {},
//                         onConfirm: () {
//                           AuthService().logout(context);
//                         },
//                       ),
//                     );
//                   } else if (value == 'delete') {
//                     showDialog(
//                       context: context,
//                       builder: (_) => ConfirmActionDialog(
//                         title: "Delete Item?",
//                         description:
//                         "This action cannot be undone. Are you sure?",
//                         cancelText: "No, Keep",
//                         confirmText: "Yes, Delete",
//                         icon: Icons.delete_forever,
//                         iconBgColor: Colors.red,
//                         cancelButtonColor: Colors.white,
//                         confirmButtonColor: Colors.red,
//                         onCancel: () {
//                           print("object");
//                         },
//                         onConfirm: () {
//                           AuthService().deleteAccount(context);
//                         },
//                       ),
//                     );
//                   }
//                 },
//                 itemBuilder: (context) => [
//                   const PopupMenuItem(
//                     value: 'logout',
//                     child: Row(
//                       children: [
//                         Icon(Icons.logout, color: Colors.black54),
//                         SizedBox(width: 10),
//                         Text("Logout"),
//                       ],
//                     ),
//                   ),
//                   const PopupMenuItem(
//                     value: 'delete',
//                     child: Row(
//                       children: [
//                         Icon(Icons.delete_forever, color: Colors.red),
//                         SizedBox(width: 10),
//                         Text("Delete Account"),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           body: Center(
//             child: Container(
//               margin: EdgeInsets.all(20),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.cancel,
//                     size: 70,
//                     color: Colors.red,
//                   ),
//                   SizedBox(
//                     height: 40,
//                   ),
//                   Text(
//                     "Couldn't find NFC in your device. Make sure that you have your NFC feature enabled in Settings. And Restart the app.",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 16,
//                       color: Colors.black87,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       );
//     }
//
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         drawerEnableOpenDragGesture: false,
//         drawer: MyDrawer(),
//         appBar: AppBar(
//           leading: Builder(
//             builder: (context) => IconButton(
//               icon: const Icon(FluentIcons.more_vertical_20_filled,
//                   color: Colors.black),
//               onPressed: () => Scaffold.of(context).openDrawer(),
//             ),
//           ),
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//         ),
//         body: SafeArea(
//           child: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Image(
//                   image: AssetImage('assets/logo_1.png'),
//                   width: 200,
//                   height: 200,
//                   fit: BoxFit.contain,
//                 ),
//                 const SizedBox(height: 24),
//
//                 // ✅ NEW BUTTON (direct Firestore)
//                 AnimatedButton(
//                   color: black,
//                   icon: Icons.dashboard_outlined,
//                   label: 'VIEW SLOTS',
//                   onTap: _showSlotsDialog,
//                 ),
//                 const SizedBox(height: 20),
//
//                 const SizedBox(height: 20),
//                 AnimatedButton(
//                   color: blue,
//                   icon: Icons.edit,
//                   label: 'WRITE URL',
//                   onTap: _showEnterUrl,
//                 ),
//                 const SizedBox(height: 20),
//                 AnimatedButton(
//                   color: orange,
//                   icon: Icons.cancel,
//                   label: 'CLEAR URL',
//                   onTap: _showConfirmClear,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
// lib/features/nfc_tag/presentation/pages/home_page.dart

import 'package:cards/features/nfc_tag/presentation/widgets/confirm_action_dialog.dart';
import 'package:cards/features/nfc_tag/utils/drawer.dart';
import 'package:cards/firebase/auth_services.dart';
import 'package:cards/features/nfc_tag/presentation/widgets/alert_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart'; // ✅ kDebugMode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:lottie/lottie.dart';

import '../viewmodels/home_view_model.dart';
import '../widgets/animated_button.dart';
import '../widgets/validation_dialog.dart';
import '../widgets/confirm_clear_dialog.dart';
import 'enter_url_page.dart';

class HomePage extends StatefulWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  late final HomeViewModel _vm;

  bool _nfcAvailable = false;

  /// ✅ If true, we simulate NFC write/clear and store in Firestore
  bool _simulatorMode = false;

  bool _scanningDialogShowing = false;

  static const blue = Color(0xFF0066CC);
  static const orange = Color(0xFFFF6600);
  static const black = Color(0xFF111111);

  @override
  void initState() {
    super.initState();

    // 1) Check NFC capability (Simulator will return false)
    NfcManager.instance.isAvailable().then((v) {
      if (!mounted) return;
      setState(() {
        _nfcAvailable = v;

        // ✅ Auto-enable simulator mode on Debug builds if NFC is missing
        if (!_nfcAvailable && kDebugMode) {
          _simulatorMode = true;
        }
      });
    });

    // 2) Grab the VM and listen for real NFC flows
    _vm = context.read<HomeViewModel>();
    _vm.addListener(_onVmStateChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmStateChanged);
    _urlController.dispose();
    super.dispose();
  }

  // ---------------------------
  // Real NFC flow dialog handling (VM)
  // ---------------------------

  void _onVmStateChanged() {
    switch (_vm.state) {
      case ViewState.busy:
        if (!_scanningDialogShowing) {
          _scanningDialogShowing = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Scanning NFC Tag'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/scanner.json',
                    width: 150,
                    height: 150,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text('Hold your device close to the NFC card'),
                ],
              ),
            ),
          );
        }
        break;

      case ViewState.success:
      case ViewState.error:
        if (_scanningDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          _scanningDialogShowing = false;
        }

        if (_vm.state == ViewState.success) {
          if (_vm.lastAction == NfcAction.write) {
            _alert('Success', 'Card written successfully!');
          } else if (_vm.lastAction == NfcAction.clear) {
            _alert('Success', 'Card cleared successfully!');
          } else {
            _alert('Success', 'Operation completed!');
          }
        } else {
          if (_vm.errorMessage == 'EMPTY_TAG') {
            _alert('Info', 'Card has nothing to clear — it is already empty.');
          } else {
            _alert('Error', _vm.errorMessage ?? 'Unknown error');
          }
        }
        break;

      case ViewState.idle:
        break;
    }
  }

  void _snack(String msg) =>
      ShowAlertBar().alertDialog(context, msg, Colors.orange);

  Future<void> _alert(String title, String msg) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        )
      ],
    ),
  );

  // ---------------------------
  // Simulator-mode storage helpers (Firestore)
  // ---------------------------

  Future<void> _writeSimTagUrl(String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    await FirebaseFirestore.instance
        .collection('sim_nfc_tags')
        .doc(uid)
        .set(
      <String, dynamic>{
        'url': url,
        'mode': 'simulated',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _clearSimTagUrl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    await FirebaseFirestore.instance
        .collection('sim_nfc_tags')
        .doc(uid)
        .set(
      <String, dynamic>{
        'url': '',
        'mode': 'simulated',
        'updatedAt': FieldValue.serverTimestamp(),
        'clearedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _showSimScanDialog({required String title, required String note}) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/scanner.json',
              width: 150,
              height: 150,
              repeat: true,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(note),
          ],
        ),
      ),
    );

    // Simulate a short scan delay
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ---------------------------
  // VIEW SLOTS (your existing code unchanged)
  // ---------------------------

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _asString(dynamic v) => v == null ? '-' : v.toString();

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) return ts.toDate().toString();
    return _asString(ts);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getAccountDoc() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;

    final q = await FirebaseFirestore.instance
        .collection('accounts')
        .where('shopifyEmail', isEqualTo: email)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return q.docs.first;
  }

  Future<void> _showSlotsDialog() async {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Account Overview'),
        content: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: _getAccountDoc(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final doc = snap.data;
            if (doc == null || !doc.exists) {
              return const Text(
                'No account record found for this email yet.\n\n'
                    'This usually means Shopify has not sent the paid-order webhook for this customer, '
                    'or the signed-in email does not match the Shopify email on the order.',
              );
            }

            final data = doc.data() ?? {};
            final planStatus = _asString(data['planStatus']);

            final slotsAvailable = _asInt(data['slotsAvailable']);
            final slotsUsed = _asInt(data['slotsUsed']);

            final slotsPurchasedTotal = _asInt(data['slotsPurchasedTotal']);
            final slotsRefundedTotal = _asInt(data['slotsRefundedTotal']);
            final slotsNet = _asInt(data['slotsNet']);

            final entitlementUpdatedAt = data['entitlementUpdatedAt'];
            final updatedAt = data['updatedAt'];

            final statusColor =
            planStatus.toLowerCase() == 'active' ? Colors.green : orange;

            Widget metricRow(String label, String value,
                {Color? valueColor, FontWeight? weight}) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: weight ?? FontWeight.w600,
                        color: valueColor ?? Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Plan Status: ', style: TextStyle(fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          planStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text('Wristband Slots',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  metricRow('Available slots', '$slotsAvailable',
                      valueColor: slotsAvailable > 0 ? Colors.green : orange),
                  metricRow('Used slots (activated)', '$slotsUsed'),
                  metricRow('Net slots', '$slotsNet'),
                  const SizedBox(height: 10),
                  const Divider(),
                  const Text('Purchase Totals (from Shopify)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  metricRow('Purchased total', '$slotsPurchasedTotal'),
                  metricRow('Refunded total', '$slotsRefundedTotal'),
                  const SizedBox(height: 12),
                  const Divider(),
                  Text('Entitlements updated: ${_fmtTs(entitlementUpdatedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  Text('Last updated: ${_fmtTs(updatedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // URL entry + validation + action
  // ---------------------------

  Future<void> _showEnterUrl() async {
    _urlController.clear();

    final tappedSet = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EnterUrlPage(controller: _urlController)),
    );
    if (tappedSet != true) return;

    final url = _urlController.text.trim();
    if (url.isEmpty) return _snack('URL cannot be empty');

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValidationDialog(
        url: url,
        validator: _vm.checkUrl,
      ),
    );


  }

  Future<void> _showConfirmClear() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConfirmClearDialog(),
    );

    if (confirm == true) {
      if (_simulatorMode) {
        await _showSimScanDialog(
          title: 'Simulating NFC Clear',
          note: 'Simulator Mode: clearing stored URL in Firestore',
        );
        await _clearSimTagUrl();
        await _alert('Success', '(Simulated) Card cleared successfully!');
      } else {
        _vm.onClear();
      }
    }
  }

  // ---------------------------
  // UI
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    final canUseNfcActions = _nfcAvailable || _simulatorMode;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        drawerEnableOpenDragGesture: false,
        drawer: MyDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(FluentIcons.more_vertical_20_filled, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // ✅ Debug-only toggle (optional)
            if (kDebugMode && !_nfcAvailable)
              TextButton(
                onPressed: () => setState(() => _simulatorMode = !_simulatorMode),
                child: Text(
                  _simulatorMode ? 'SIM ON' : 'SIM OFF',
                  style: TextStyle(color: _simulatorMode ? Colors.green : Colors.black),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Image(
                  image: AssetImage('assets/logo_1.png'),
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),



                if (!_nfcAvailable && !_simulatorMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.35)),
                      ),
                      child: const Text(
                        "NFC is not available on this device. Enable NFC in Settings (if supported) "
                            "or use Simulator Mode (debug) to test write/clear flows.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                AnimatedButton(
                  color: black,
                  icon: Icons.dashboard_outlined,
                  label: 'VIEW SLOTS',
                  onTap: _showSlotsDialog,
                ),
                const SizedBox(height: 20),

                AnimatedButton(
                  color: blue,
                  icon: Icons.edit,
                  label: _simulatorMode ? 'WRITE URL (SIM)' : 'WRITE URL',
                  onTap: canUseNfcActions ? _showEnterUrl : () => _snack('NFC not available'),
                ),
                const SizedBox(height: 20),

                AnimatedButton(
                  color: orange,
                  icon: Icons.cancel,
                  label: _simulatorMode ? 'CLEAR URL (SIM)' : 'CLEAR URL',
                  onTap: canUseNfcActions ? _showConfirmClear : () => _snack('NFC not available'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
