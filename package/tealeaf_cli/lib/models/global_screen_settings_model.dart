import 'masking_model.dart';

class GlobalScreenSettings {
  bool? screenChange;
  String? displayName;
  int? captureLayoutDelay;
  bool? screenShot;
  int? numberOfWebViews;
  bool? captureUserEvents;
  bool? captureScreenVisits;
  int? captureLayoutOn;
  int? captureScreenshotOn;
  Masking? masking;

  GlobalScreenSettings(
      {this.screenChange,
      this.displayName,
      this.captureLayoutDelay,
      this.screenShot,
      this.numberOfWebViews,
      this.captureUserEvents,
      this.captureScreenVisits,
      this.captureLayoutOn,
      this.captureScreenshotOn,
      this.masking});

  GlobalScreenSettings.fromJson(Map<String, dynamic> json) {
    screenChange = json['ScreenChange'];
    displayName = json['DisplayName'];
    captureLayoutDelay = json['CaptureLayoutDelay'];
    screenShot = json['ScreenShot'];
    numberOfWebViews = json['NumberOfWebViews'];
    captureUserEvents = json['CaptureUserEvents'];
    captureScreenVisits = json['CaptureScreenVisits'];
    captureLayoutOn = json['CaptureLayoutOn'];
    captureScreenshotOn = json['CaptureScreenshotOn'];
    masking =
        json['Masking'] != null ? Masking.fromJson(json['Masking']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    if (screenChange != null) {
      data['ScreenChange'] = screenChange;
    }

    if (displayName != null) {
      data['DisplayName'] = displayName;
    }

    if (captureLayoutDelay != null) {
      data['CaptureLayoutDelay'] = captureLayoutDelay;
    }

    if (screenShot != null) {
      data['ScreenShot'] = screenShot;
    }

    if (numberOfWebViews != null) {
      data['NumberOfWebViews'] = numberOfWebViews;
    }

    if (captureUserEvents != null) {
      data['CaptureUserEvents'] = captureUserEvents;
    }

    if (captureScreenVisits != null) {
      data['CaptureScreenVisits'] = captureScreenVisits;
    }

    if (captureLayoutOn != null) {
      data['CaptureLayoutOn'] = captureLayoutOn;
    }

    if (captureScreenshotOn != null) {
      data['CaptureScreenshotOn'] = captureScreenshotOn;
    }

    if (masking != null) {
      data['Masking'] = masking!.toJson();
    }
    return data;
  }
}
