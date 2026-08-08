# Selects the shared mail transport: SES SMTP when configured, Resend as the
# rollback path, and the local dev inbox (/_studio/local_emails) when
# LOCAL_EMAIL_CAPTURE is set. See studio-engine's mail_transport.rb.
Studio::MailTransport.configure!
