/// Represents the client-side delivery status of a message.
enum MessageStatus {
  /// The message is being sent from the client. It has not yet been acknowledged by the server.
  /// UI should show a clock icon.
  sending,

  /// The server has successfully received and stored the message.
  /// UI should show a single grey tick.
  sent,

  /// At least one recipient's device has received the message.
  /// UI should show a double grey tick.
  delivered,

  /// At least one recipient has read the message.
  /// UI should show a double blue tick.
  read,

  /// The message failed to send due to a network error or other issue.
  /// UI should show a warning/error icon.
  failed,
}
