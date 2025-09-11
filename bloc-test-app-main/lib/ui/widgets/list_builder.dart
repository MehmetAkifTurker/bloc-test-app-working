// import 'dart:developer';

// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag/db_tag_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag/db_tag_event.dart';
// import 'package:water_boiler_rfid_labeler/data/models/db_tag.dart';
// import 'package:water_boiler_rfid_labeler/data/models/optimized_tag_box_scan.dart';
// import 'package:water_boiler_rfid_labeler/data/models/optimized_tag_rfid_scan.dart';
// import 'package:water_boiler_rfid_labeler/data/models/tag_epc.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/rfid_db_tag_list_screen/_rfid_db_tag_list_methods.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// import '../../data/models/variables.dart';

// class ListBuilder<T> extends StatelessWidget {
//   final List<T> items;

//   const ListBuilder({super.key, required this.items});

//   @override
//   Widget build(BuildContext context) {
//     dynamic tag;
//     String epc;
//     DBTag? foundDBTag;
//     bool isExist = false;
//     bool isMaster = false;
//     bool isMasterAssigned = true;
//     bool isExpired = false;
//     bool isNoteExist = false;
//     return ListView.builder(
//       itemCount: items.length,
//       itemBuilder: (context, index) {
//         log('List added');
//         final item = items[index];
//         if (item is OptimizedTagRfidScan) {
//           tag = item.originalTag;
//           foundDBTag = item.originalDBTag;
//           isExist = item.existsInDB && foundDBTag != null;
//           isMaster = item.isMaster;
//           isMasterAssigned = item.isMasterAssigned;
//           isExpired = item.isExpired;
//           isNoteExist = foundDBTag?.note.isNotEmpty ?? false;
//         } else if (item is OptimizedTagBoxScan) {
//           tag = item.originalTag;
//           foundDBTag = item.originalDBTag;
//           isExist = item.existsInDB && foundDBTag != null;
//           isMaster = item.isMaster;
//           isMasterAssigned = item.isMasterAssigned;
//           isExpired = item.isExpired;
//           isNoteExist = foundDBTag?.note.isNotEmpty ?? false;
//         } else if (item is TagEpc) {
//           tag = item;
//         } else if (item is DBTag) {
//           tag = item;
//           isExist = true;
//           isMaster = item.isMaster();
//           isMasterAssigned = item.isMasterAssigned();
//           isExpired = item.isExpired();
//           foundDBTag = tag;
//           isNoteExist = foundDBTag?.note.isNotEmpty ?? false;
//         }

//         epc = tag.epc.replaceAll(RegExp('EPC:'), '');

//         return Container(
//           decoration: isExpired
//               ? BoxDecoration(
//                   border: Border.all(style: BorderStyle.none),
//                   color: listColorBackgroundExpired,
//                 )
//               : null,
//           color: isExist ? null : listColorBackgroundNotExistInDB,
//           child: ListTile(
//             iconColor: (isMasterAssigned && !isExpired)
//                 ? listColorIconAndTextNormal
//                 : listColorIconAndTextExpiredOrMasterNotAssigned,
//             textColor: (isMasterAssigned && !isExpired)
//                 ? listColorIconAndTextNormal
//                 : listColorIconAndTextExpiredOrMasterNotAssigned,
//             leading: isExist
//                 ? isMaster
//                     ? Icon(
//                         FontAwesomeIcons.box,
//                         color: listColorIconAndTextNormal,
//                       )
//                     : Icon(
//                         Icons.build,
//                         color: (isMasterAssigned && !isExpired)
//                             ? listColorIconAndTextNormal
//                             : listColorIconAndTextExpiredOrMasterNotAssigned,
//                       )
//                 : Icon(
//                     Icons.question_mark,
//                     color: listColorIconAndTextNormal,
//                   ),
//             title: isExist
//                 ? Text(
//                     'PN : ${foundDBTag?.pn}',
//                     overflow: TextOverflow.ellipsis,
//                   )
//                 : Text(
//                     epc,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//             subtitle: isExist
//                 ? Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Text(
//                       //   'EPC : ${foundDBTag?.epc}',
//                       //   overflow: TextOverflow.ellipsis,
//                       // ),
//                       Text(
//                         'SN: ${foundDBTag?.sn}',
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       Text(
//                         'Desc: ${foundDBTag?.desc}',
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   )
//                 : null,
//             trailing: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Flexible(child: Text('No : ${(index + 1).toString()}')),
//                 Flexible(
//                   child: foundDBTag != null
//                       ? isMasterAssigned
//                           ? Text(foundDBTag!.selectedBox)
//                           : const Text('No box assigned')
//                       : const SizedBox.shrink(),
//                 ),
//                 Flexible(
//                   child: foundDBTag != null
//                       ? isExpired
//                           ? const Text('Expired')
//                           : Text(getExpirationText(foundDBTag))
//                       : const SizedBox.shrink(),
//                 ),
//                 Flexible(
//                     child: isNoteExist
//                         ? const Icon(Icons.notes)
//                         : const SizedBox.shrink()),
//               ],
//             ),
//             onTap: () {
//               final item = items[index];

//               log('Item type ${item.toString()}');

//               if (item is OptimizedTagRfidScan) {
//                 tag = item.originalTag;
//                 foundDBTag = item.originalDBTag;
//                 isExist = item.existsInDB && foundDBTag != null;
//               } else if (item is OptimizedTagBoxScan) {
//                 tag = item.originalTag;
//                 foundDBTag = item.originalDBTag;
//                 isExist = item.existsInDB && foundDBTag != null;
//               } else if (item is TagEpc) {
//                 tag = item;
//               } else if (item is DBTag) {
//                 tag = item;
//                 isExist = true;
//               }

//               if (item is OptimizedTagRfidScan) {
//                 if (isExist) {
//                   showDialogBoxUpdate(context: context, tag: foundDBTag!);
//                 } else {
//                   showDialogBoxNew(context: context, tag: tag);
//                 }
//               } else if (item is OptimizedTagBoxScan) {
//                 if (isExist) {
//                   showDialogBoxUpdate(context: context, tag: foundDBTag!);
//                 } else {
//                   showDialogBoxNew(context: context, tag: tag);
//                 }
//               } else if (item is DBTag) {
//                 showDialogBoxUpdate(context: context, tag: tag);
//               } else if (item is TagEpc) {
//                 showDialogBoxNew(context: context, tag: tag);
//               }
//             },
//             onLongPress: () {
//               final item = items[index];
//               if (item is DBTag) {
//                 context.read<DBTagBloc>().add(DBDeleteTag(uid: item.id));
//               }
//             },
//           ),
//         );
//       },
//     );
//   }
// }

// String getExpirationText(DBTag? foundDBTag) {
//   if (foundDBTag == null || foundDBTag.expDate.isEmpty) {
//     return '';
//   }

//   try {
//     final expDate = DateTime.parse(foundDBTag.expDate);
//     final daysRemaining = expDate.difference(DateTime.now()).inDays;
//     return 'Exp day no: $daysRemaining';
//   } catch (e) {
//     log('Error parsing expDate: $e');
//     return '';
//   }
// }
