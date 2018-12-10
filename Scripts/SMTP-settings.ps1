########################## SMTP Settings ################################
$global:emailSmtpServer = "mail.smtp2go.com"
$global:emailSmtpServerPort = "2525"
$global:emailSmtpUser = "takshina"
$global:emailSmtpPass = "bXVpaXFlaXI5amox"
$global:emailFrom = "UAG CD <noreply@cloudbaskets.com>"
$global:emailTo = "shanbhagv@vmware.com"
$emailcc="Aman Srivastava <amansrivasta@vmware.com>, Takshinamurthy A A <taa@vmware.com>, Venkatesh Shindagikar <vshindagikar@vmware.com>, Shajil John <shajilj@vmware.com>, Don Joy <djoy@vmware.com>, Dinesh Upreti <dupreti@vmware.com>, Vivek Vijayakumar <vijayakumarv@vmware.com>, Rajneesh Kesavan <rkesavan@vmware.com>, Parth Shah <parths@vmware.com>, Michael Capo <mcapo@vmware.com>, Pavan Rangain <prangain@vmware.com>, Hemanth Shivanna <hshivanna@vmware.com>, Sruthi Mandha <smandha@vmware.com>"
#$emailcc= "Takshinamurthy A A <taa@vmware.com>"
#$global:emailcc= "shanbhagv@vmware.com"
$global:emailMessage = New-Object System.Net.Mail.MailMessage( $emailFrom , $emailTo )
$global:emailMessage.cc.add($emailcc)
$global:SMTPClient = New-Object System.Net.Mail.SmtpClient( $emailSmtpServer , $emailSmtpServerPort )
$global:SMTPClient.EnableSsl = $False
$global:SMTPClient.Credentials = New-Object System.Net.NetworkCredential( $emailSmtpUser , $emailSmtpPass );