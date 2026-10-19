import 'package:attendance/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds the TextFormField inside the [AppTextField] labeled [label].
/// (widgetWithText doesn't match, because the label Text is a sibling of
/// the field, not a descendant of it.)
Finder labeledField(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is AppTextField && widget.label == label,
  ),
  matching: find.byType(TextFormField),
);
