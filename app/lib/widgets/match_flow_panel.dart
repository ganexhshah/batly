import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/match_flow_state.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/match_flow_service.dart';
import 'match_flow_phases.dart';

/// Polls match-flow state and renders the active phase UI for Custom Room / Lone Wolf.
class MatchFlowPanel extends StatefulWidget {
  const MatchFlowPanel({
    super.key,
    required this.tournamentId,
    this.initial,
    this.isReady = false,
    this.onToggleReady,
    this.roomIdController,
    this.roomPassController,
    this.onSaveRoom,
    this.savingRoom = false,
    this.onFlowUpdated,
    this.onSnack,
  });

  final int tournamentId;
  final MatchFlowState? initial;
  final bool isReady;
  final ValueChanged<bool>? onToggleReady;
  final TextEditingController? roomIdController;
  final TextEditingController? roomPassController;
  final VoidCallback? onSaveRoom;
  final bool savingRoom;
  final void Function(MatchFlowState flow)? onFlowUpdated;
  final void Function(String message, {required bool isError})? onSnack;

  @override
  State<MatchFlowPanel> createState() => _MatchFlowPanelState();
}

class _MatchFlowPanelState extends State<MatchFlowPanel> {
  MatchFlowState _flow = const MatchFlowState();
  bool _busy = false;
  XFile? _proofImage;
  TextEditingController? _localRoomIdController;
  TextEditingController? _localRoomPassController;

  bool get _hasScreenshot => _proofImage != null;

  @override
  void initState() {
    super.initState();
    _flow = widget.initial ?? const MatchFlowState();
    if (widget.roomIdController == null) {
      _localRoomIdController = TextEditingController();
    }
    if (widget.roomPassController == null) {
      _localRoomPassController = TextEditingController();
    }
    if (_flow.applies) {
      _startPolling();
    }
  }

  @override
  void didUpdateWidget(MatchFlowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != null &&
        widget.initial!.phase != oldWidget.initial?.phase &&
        widget.initial!.phase != _flow.phase) {
      setState(() => _flow = widget.initial!);
    }
  }

  @override
  void dispose() {
    MatchFlowService.instance.stopPolling(tournamentId: widget.tournamentId);
    _localRoomIdController?.dispose();
    _localRoomPassController?.dispose();
    super.dispose();
  }

  void _startPolling() {
    MatchFlowService.instance.startPolling(
      tournamentId: widget.tournamentId,
      initial: _flow.applies ? _flow : null,
      onUpdate: (state) {
        if (!mounted) return;
        setState(() => _flow = state);
        widget.onFlowUpdated?.call(state);
      },
      onError: (error) {
        widget.onSnack?.call(
          'Match flow sync failed. Retrying…',
          isError: true,
        );
      },
    );
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() call, {
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    final res = await call();
    if (!mounted) return;
    setState(() => _busy = false);
    final flow = res['match_flow'];
    if (flow is MatchFlowState) {
      setState(() => _flow = flow);
      widget.onFlowUpdated?.call(flow);
    }
    if (res['success'] == true) {
      widget.onSnack?.call(successMessage, isError: false);
    } else {
      widget.onSnack?.call(res['message'] as String? ?? 'Action failed', isError: true);
    }
  }

  Future<void> _confirmInGame() => _runAction(
        () => ApiService.confirmInGame(widget.tournamentId),
        successMessage: 'In-game join confirmed.',
      );

  Future<void> _stopMatch() => _runAction(
        () => ApiService.stopMatchFlow(widget.tournamentId),
        successMessage: 'Stop recorded.',
      );

  Future<void> _acknowledgeStop() => _runAction(
        () => ApiService.acknowledgeMatchStop(widget.tournamentId),
        successMessage: 'Match end acknowledged.',
      );

  Future<void> _vote(String claim) => _runAction(
        () => ApiService.voteMatchWinner(widget.tournamentId, claim: claim),
        successMessage: 'Vote recorded.',
      );

  Future<void> _pickProofImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _proofImage = picked);
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (url.contains('://localhost') || url.contains('://127.0.0.1')) {
        try {
          final uri = Uri.parse(url);
          return '${ApiConfig.baseUrl}${uri.path}';
        } catch (_) {
          return url;
        }
      }
      return url;
    }
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConfig.baseUrl}/$cleanPath';
  }

  Future<void> _submitProof() async {
    final image = _proofImage;
    if (image == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await image.readAsBytes();
      final upload = await ApiService.sendTournamentChatMessage(
        widget.tournamentId,
        imageBytes: bytes,
        imageFilename: image.name,
      );
      if (!mounted) return;

      if (upload['success'] != true) {
        setState(() => _busy = false);
        widget.onSnack?.call(
          upload['error'] as String? ?? 'Failed to upload proof image',
          isError: true,
        );
        return;
      }

      final message = upload['message'];
      final imageUrl = message is Map ? message['image_url'] as String? : null;
      final proofUrl = _resolveImageUrl(imageUrl);
      if (proofUrl.isEmpty) {
        setState(() => _busy = false);
        widget.onSnack?.call('Upload succeeded but image URL was missing', isError: true);
        return;
      }

      await _runAction(
        () => ApiService.submitMatchFlowProof(widget.tournamentId, [proofUrl]),
        successMessage: 'Proof submitted for review.',
      );
      if (mounted) setState(() => _proofImage = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSnack?.call('Failed to upload proof: $e', isError: true);
    }
  }

  Widget _buildPhase() {
    switch (_flow.phase) {
      case MatchFlowState.phaseWaitingReady:
        return MatchReadyPhase(
          flow: _flow,
          isReady: widget.isReady,
          busy: _busy,
          onToggleReady: widget.onToggleReady ?? (_) {},
        );
      case MatchFlowState.phaseSharingCodes:
        return MatchShareCodesPhase(
          flow: _flow,
          roomIdController: widget.roomIdController ?? _localRoomIdController!,
          roomPassController: widget.roomPassController ?? _localRoomPassController!,
          saving: widget.savingRoom,
          onSave: widget.onSaveRoom ?? () {},
        );
      case MatchFlowState.phaseWaitingInGame:
        return MatchInGamePhase(
          flow: _flow,
          busy: _busy,
          onConfirm: _confirmInGame,
        );
      case MatchFlowState.phaseLive:
        return MatchLivePhase(
          flow: _flow,
          busy: _busy,
          onStop: _stopMatch,
        );
      case MatchFlowState.phaseAdminStopReview:
        return MatchStopNoticePhase(
          flow: _flow,
          busy: _busy,
          onAcknowledge: _acknowledgeStop,
        );
      case MatchFlowState.phaseResultVote:
        return MatchResultVotePhase(
          flow: _flow,
          busy: _busy,
          onVote: _vote,
        );
      case MatchFlowState.phaseProofReview:
        return MatchProofPhase(
          flow: _flow,
          busy: _busy,
          hasScreenshot: _hasScreenshot,
          onPickScreenshot: _pickProofImage,
          onClearScreenshot: () => setState(() => _proofImage = null),
          onSubmit: _submitProof,
        );
      case MatchFlowState.phaseCompleted:
        return MatchCompletedPhase(flow: _flow);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_flow.applies) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildPhase(),
    );
  }
}
