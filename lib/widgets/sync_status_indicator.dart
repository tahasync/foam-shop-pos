import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});
  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  String _status = 'syncing...';
  late StreamSubscription<void> _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.snapshotsInSync().listen((_) {
      if (mounted) setState(() => _status = 'synced');
    });
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = _status == 'synced' ? Colors.green : Colors.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(_status, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}
