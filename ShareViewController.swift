import receive_sharing_intent

// Set this class as the iOS Share Extension's principal class.
// It forwards files shared from WhatsApp into the Flutter app.
class ShareViewController: RSIShareViewController {
    override func shouldAutoRedirect() -> Bool { true }
}
