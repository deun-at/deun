// Please see this file for the latest firebase-js-sdk version:
// https://github.com/firebase/flutterfire/blob/master/packages/firebase_core/firebase_core_web/lib/src/firebase_sdk_version.dart
importScripts("https://www.gstatic.com/firebasejs/10.11.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.11.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDEPxovASHn7LYzAdX3_U04HGuwqUkPmKg",
  authDomain: "deun-66067.firebaseapp.com",
  databaseURL: "...",
  projectId: "deun-66067",
  storageBucket: "deun-66067.firebasestorage.app",
  messagingSenderId: "772955736601",
  appId: "1:772955736601:web:726b71f0a311d9a7843888",
});

const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((message) => {
  console.log("onBackgroundMessage", message);
});