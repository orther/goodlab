"""
Custom Django email backend for InvenTree that doesn't persist SMTP connections.

This backend extends Django's SMTP EmailBackend but forces it to create a fresh
connection for each email batch, preventing "please run connect() first" errors
that occur when Django-Q worker processes try to reuse stale SMTP connections.

This is necessary because:
1. InvenTree uses Django-Q for background task processing
2. Django's default SMTP backend tries to reuse connections across sends
3. Worker processes can't share socket connections from the main process
4. The result is SMTPServerDisconnected errors when workers try to send email

By always creating fresh connections, we sacrifice some performance for reliability.
"""

from django.core.mail.backends.smtp import EmailBackend as DjangoSMTPBackend


class EmailBackend(DjangoSMTPBackend):
    """SMTP backend that creates a fresh connection for each send operation."""

    def send_messages(self, email_messages):
        """
        Send emails by creating a fresh connection, sending, and closing.

        This ensures each call gets a new SMTP connection, preventing
        connection reuse issues in multi-process environments like Django-Q.
        """
        if not email_messages:
            return 0

        # Force a fresh connection by ensuring we're not reusing an old one
        self.close()

        # Let the parent class handle the actual sending
        # It will call self.open() which creates a new connection
        try:
            return super().send_messages(email_messages)
        finally:
            # Always close the connection after sending
            self.close()
