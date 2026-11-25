import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

/// The app's one icon set: Lucide at a light stroke (weight 300), so every icon shares one
/// line weight. Change the import above to retune the whole app.
abstract final class AppIcon {
  // Content types.
  static const link = LucideIcons300.link;
  static const text = LucideIcons300.text;
  static const wifi = LucideIcons300.wifi;
  static const user = LucideIcons300.user;
  static const mail = LucideIcons300.mail;
  static const phone = LucideIcons300.phone;
  static const message = LucideIcons300.messageSquare;
  static const pin = LucideIcons300.mapPin;
  static const calendar = LucideIcons300.calendar;
  static const bag = LucideIcons300.shoppingBag;

  // Navigation.
  static const home = LucideIcons300.house;
  static const scan = LucideIcons300.scanQrCode;
  static const create = LucideIcons300.squarePlus;
  static const history = LucideIcons300.history;
  static const settings = LucideIcons300.settings;

  // Actions.
  static const copy = LucideIcons300.copy;
  static const share = LucideIcons300.share2;
  static const export = LucideIcons300.share;
  static const download = LucideIcons300.download;
  static const open = LucideIcons300.externalLink;
  static const search = LucideIcons300.search;
  static const globe = LucideIcons300.globe;
  static const trash = LucideIcons300.trash2;
  static const edit = LucideIcons300.pencil;
  static const remake = LucideIcons300.copyPlus;
  static const map = LucideIcons300.map;
  static const calendarAdd = LucideIcons300.calendarCheck;
  static const userAdd = LucideIcons300.userPlus;
  static const key = LucideIcons300.keyRound;
  static const qr = LucideIcons300.qrCode;
  static const more = LucideIcons300.ellipsisVertical;
  static const close = LucideIcons300.x;
  static const check = LucideIcons300.check;
  static const checkCircle = LucideIcons300.circleCheck;
  static const chevron = LucideIcons300.chevronRight;
  static const eye = LucideIcons300.eye;
  static const eyeOff = LucideIcons300.eyeOff;
  static const star = LucideIcons300.star;

  /// Lucide has no filled star; the favourited state keeps Material's filled glyph so
  /// "on" reads at a glance. The only icon outside the set.
  static const starFilled = Icons.star_rounded;

  // Scanner and status.
  static const flash = LucideIcons300.zap;
  static const flashOff = LucideIcons300.zapOff;
  static const zoomIn = LucideIcons300.zoomIn;
  static const zoomOut = LucideIcons300.zoomOut;
  static const focus = LucideIcons300.focus;
  static const switchCamera = LucideIcons300.switchCamera;
  static const images = LucideIcons300.images;
  static const camera = LucideIcons300.camera;
  static const imageOff = LucideIcons300.imageOff;
  static const wifiOff = LucideIcons300.wifiOff;
  static const warning = LucideIcons300.triangleAlert;
  static const alert = LucideIcons300.circleAlert;
  static const ban = LucideIcons300.ban;

  // Settings.
  static const sound = LucideIcons300.volume2;
  static const vibrate = LucideIcons300.vibrate;
  static const browser = LucideIcons300.appWindow;
  static const stamp = LucideIcons300.stamp;
  static const lock = LucideIcons300.lock;
  static const file = LucideIcons300.fileText;
}
