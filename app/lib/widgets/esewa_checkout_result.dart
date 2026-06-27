class EsewaCheckoutResult {
  const EsewaCheckoutResult({
    this.success = false,
    this.cancelled = false,
    this.message,
    this.referenceId,
  });

  final bool success;
  final bool cancelled;
  final String? message;
  final String? referenceId;
}
