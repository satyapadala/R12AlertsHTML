# R12 Alerts HTML Utility
Utility package to generate rich HTML alerts from Oracle R12. Oracle R12 Alerts traditionally do not support HTML alerts and the format of the emails that we receive are often unreadable. This utility can be used to send HTML formatted emails by still using Alerts framework. 

More details on the functional setups can be found in the below video:

https://www.youtube.com/watch?v=C6qDXIZ7IGM


## Warning
This package won't compile unless you define your own send_mail procedure. You can choose to have simple UTL_MAIL which would only spit out 32K size email body or you can choose UTL_STMP which would send unlimited email body.

## Contributions
You are encouraged to submit pull requests to this repository so that this can further be enhanced which would benefit other developers out there.

## Contact
Please send an email to satya@oraclefusionhub.com if you need any other details.
