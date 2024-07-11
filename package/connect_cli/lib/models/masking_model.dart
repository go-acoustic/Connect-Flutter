import 'sensitive_model.dart';

class Masking {
  bool? hasMasking;
  bool? hasCustomMask;
  Sensitive? sensitive;
  List<String>? maskIdList;
  List<String>? maskValueList;
  List<String>? maskAccessibilityIdList;
  List<String>? maskAccessibilityLabelList;
  List<String>? pointerEventList;

  Masking(
      {this.hasMasking,
      this.hasCustomMask,
      this.sensitive,
      this.maskIdList,
      this.maskValueList,
      this.maskAccessibilityIdList,
      this.maskAccessibilityLabelList,
      this.pointerEventList});

  Masking.fromJson(Map<String, dynamic> json) {
    hasMasking = json['HasMasking'];
    hasCustomMask = json['HasCustomMask'];

    sensitive = json['Sensitive'] != null
        ? Sensitive.fromJson(json['Sensitive'])
        : null;

    if (json['MaskIdList'] != null) {
      maskIdList = json['MaskIdList'].cast<String>();
    }

    if (json['MaskValueList'] != null) {
      maskValueList = json['MaskValueList'].cast<String>();
    }

    if (json['MaskAccessibilityIdList'] != null) {
      maskAccessibilityIdList = json['MaskAccessibilityIdList'].cast<String>();
    }

    if (json['MaskAccessibilityLabelList'] != null) {
      maskAccessibilityLabelList =
          json['MaskAccessibilityLabelList'].cast<String>();
    }

    if (json['PointerEventList'] != null) {
      pointerEventList = json['PointerEventList'].cast<String>();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    if (hasMasking != null) {
      data['HasMasking'] = hasMasking;
    }

    if (hasCustomMask != null) {
      data['HasCustomMask'] = hasCustomMask;
    }

    if (sensitive != null) {
      data['Sensitive'] = sensitive!.toJson();
    }

    if (maskIdList != null) {
      data['MaskIdList'] = maskIdList;
    }

    if (maskValueList != null) {
      data['MaskValueList'] = maskValueList;
    }

    if (maskAccessibilityIdList != null) {
      data['MaskAccessibilityIdList'] = maskAccessibilityIdList;
    }

    if (maskAccessibilityLabelList != null) {
      data['MaskAccessibilityLabelList'] = maskAccessibilityLabelList;
    }

    if (pointerEventList != null) {
      data['PointerEventList'] = pointerEventList;
    }

    return data;
  }
}
