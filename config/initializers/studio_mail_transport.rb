# Selects the shared mail transport: Resend (the only one since SES retired on
# 2026-10-10), or the local dev inbox (/_studio/local_emails) when
# LOCAL_EMAIL_CAPTURE is set. The sender is set in studio.rb. See
# studio-engine's mail_transport.rb.
Studio::MailTransport.configure!
