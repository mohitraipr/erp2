import 'package:flutter/material.dart';

import '../services/api_client.dart';

String errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is Exception) {
    return error.toString();
  }
  return 'Unexpected error: $error';
}

bool isUnauthorizedError(Object error) {
  return error is ApiException && error.statusCode == 401;
}

void showErrorSnackBar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(errorMessage(error)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required Widget content,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
