CREATE OR REPLACE PACKAGE XX_COMMON_ALERTS_PKG
AS
/*
 *  This package won't compile unless you define your own sendmail 
 *   functionality. Due to time constraints, I couldn't write generic
 *   sendmail procedure. If you would like to contribute, please send 
 *   a pull request.
 */

    PROCEDURE main(po_errbuf  OUT VARCHAR2,
                   po_retcode OUT NUMBER,
                   p_debug    IN  NUMBER,
                   p_alert_name IN VARCHAR2);

END XX_COMMON_ALERTS_PKG;                 
/
SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY XX_COMMON_ALERTS_PKG
AS

  gv_process_name	   CONSTANT VARCHAR2(100) := 'Common Alert Functionality';

  PROCEDURE debug(pi_message IN VARCHAR2)
  IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(pi_message);
    FND_FILE.PUT_LINE(FND_FILE.LOG,pi_message);
  END;

  PROCEDURE main(po_errbuf  OUT VARCHAR2,
                 po_retcode OUT NUMBER,
				 p_debug    IN  NUMBER,
                 p_alert_name IN VARCHAR2)
  IS
    lv_procedure               CONSTANT VARCHAR2(200) := 'XX_COMMON_ALERTS_PKG.main';
    lv_to_recipients           ALR_ACTIONS.to_recipients%TYPE;
    lv_cc_recipients           ALR_ACTIONS.cc_recipients%TYPE;
    lv_bcc_recipients          ALR_ACTIONS.bcc_recipients%TYPE;
    lv_subject                 ALR_ACTIONS.subject%TYPE;
    lv_alert_id                ALR_ALERTS.alert_id%TYPE;
    lv_row_count               ALR_ACTION_SET_CHECKS.row_count%TYPE;
    lv_check_id                ALR_ACTION_SET_CHECKS.alert_check_id%TYPE;
    lv_mail_body_header        VARCHAR2(30000);
    lv_mail_body_lines         VARCHAR2(30000);
    lv_ctxh                    DBMS_XMLGEN.ctxHANDle;
    lv_queryresult             XMLTYPE;
    lv_xslt_transform          XMLTYPE;
    lv_message                 VARCHAR2(30000);
	lv_error_msg               VARCHAR2(3000);
    lv_inst_name               VARCHAR2(50);
    lv_FROM_email              VARCHAR2 (100);
    lv_to_email                VARCHAR2 (100);
    lv_recipients_mail         VARCHAR2 (100);
    lv_status                  VARCHAR2(30000);
    lv_alert_check_id          VARCHAR2(2000);
    lv_list_id                 ALR_ACTIONS.list_id%TYPE;
    lv_list_application_id     ALR_ACTIONS.list_application_id%TYPE;
    lv_body                    ALR_ACTIONS.body%TYPE;
    lv_ret_message             VARCHAR2(2000);
    lv_ret_status              VARCHAR2(2000);

    le_mail_excp               EXCEPTION;

    CURSOR c_get_alert_outputs(pi_alert_id VARCHAR2)
    IS 
      SELECT name,
             title
      FROM  alr_alert_outputs
      WHERE alert_id = pi_alert_id
      AND   end_date_active IS NULL
      ORDER BY name;
    
    CURSOR c_output_lines(pi_check_id NUMBER, pi_row_number NUMBER)
    IS 
      SELECT distinct value,name
      FROM alr_output_history
      WHERE check_id = pi_check_id
      AND   row_number = pi_row_number
      ORDER BY name;
      

  BEGIN	
    
    debug(pi_message => pvg_procedure_delimiter	
                                 );
    debug(pi_message => '++----------------------------Parameters----------------------------------++' ,
                                 );
    debug(pi_message => lv_procedure||' : p_debug       : '||p_debug 
                                 );
    debug(pi_message => lv_procedure||' : p_alert_name   : '||p_alert_name
                                 );
    debug(pi_message => '++-----------------------------------------------------------------------++' 
                                 );
    debug(pi_message => lv_procedure||' : Entered main. Alert Name : '||p_alert_name
                                 );
    
    lv_status := 'Fetching alert details ';

    SELECT  actions.to_recipients,
            actions.cc_recipients,
            actions.bcc_recipients,
            actions.subject,
            alr.alert_id,
            actions.list_id,
            actions.list_application_id,
            actions.body
    INTO    lv_to_recipients,
            lv_cc_recipients,
            lv_bcc_recipients,
            lv_subject,
            lv_alert_id,
            lv_list_id,
            lv_list_application_id,
            lv_body
    FROM ALR_ALERTS alr,
         ALR_ACTIONS actions
    WHERE alr.alert_name = p_alert_name
    AND  alr.alert_id = actions.alert_id
    AND  actions.name = 'HTML Email'
    AND  actions.enabled_flag = 'Y'
    AND  actions.end_date_active IS NULL ; 

    IF lv_list_id IS NOT NULL
    THEN 
        SELECT to_recipients,
               cc_recipients,
               bcc_recipients
          INTO lv_to_recipients,
               lv_cc_recipients,
               lv_bcc_recipients
          FROM alr_distribution_lists
         WHERE list_id = lv_list_id 
           AND application_id = lv_list_application_id
           AND enabled_flag = 'Y'
           AND end_date_active IS NULL;
    END IF;


    lv_status := 'Fetching alert check ID and row counts';
    SELECT row_count,
           check_id,
           alert_check_id
    INTO   lv_row_count,
            lv_check_id,
            lv_alert_check_id
    FROM   ALR_ACTION_SET_CHECKS
    WHERE  alert_id = lv_alert_id
    AND    alert_check_id = (SELECT max(alert_check_id)
                            FROM ALR_ACTION_SET_CHECKS
                            WHERE alert_id = lv_alert_id);


    lv_status := 'Formatting email body';
    lv_mail_body_header := '<html><head> 
								 <style> 
                          table {
                                font-family: arial, sans-serif;
                                border-collapse: collapse;
                                width: 95%;
                             }   
                            td, th {
                                border: 1px solid #dddddd;
                                text-align: left;
                                padding: 8px;
                            }             
                            tr:nth-child(even) {
                                background-color: #dddddd;
                            }
                            </style></head>
                          <body>'||lv_body||'</br></br><table><tr>';

    lv_status := 'Before c_get_alert_outputs loop ';

    FOR rec_alert_outputs IN c_get_alert_outputs(lv_alert_id)
    LOOP
        lv_mail_body_header := lv_mail_body_header||'<th>'||rec_alert_outputs.title||'</th>';
    END LOOP;
    lv_mail_body_header := lv_mail_body_header||'</tr>';
    
    lv_status := 'Before lv_row_count loop: '||lv_row_count;
    FOR i IN 1..lv_row_count
    LOOP
        lv_mail_body_lines := lv_mail_body_lines||'<tr>';
        FOR rec_lines IN c_output_lines(lv_check_id, i)
        LOOP
            lv_mail_body_lines := lv_mail_body_lines||'<td>'||rec_lines.value||'</td>';
        END LOOP;
        lv_mail_body_lines := lv_mail_body_lines||'</tr>';
        
        /* */
        lv_status := i||'Length of string: '||length(lv_mail_body_lines);
        IF mod(i, 80) = 0
        THEN
            lv_message := lv_mail_body_header||lv_mail_body_lines||'</html>';
            
            -- TODO: This won't compile unless you define your own send_mail procedure.
            send_mail(
                    p_in_to          => lv_to_recipients,
                    p_in_cc          => lv_cc_recipients,
                    p_in_subject     => lv_subject,
                    p_in_message     => lv_message,
                    p_out_ret_status => lv_ret_status,
                    p_out_ret_msg    => lv_ret_message
                );
            lv_message := NULL;
            lv_mail_body_lines := NULL;
        END IF;
        /* */
    END LOOP;
	
    lv_status := 'combining mail bodies ';
    lv_message := lv_mail_body_header||lv_mail_body_lines||'</html>';
       
    debug(pi_message => lv_procedure||' : Start Calling UTL_MAIL pkg');
			BEGIN
                lv_status := 'calling send_mail-To:'||lv_to_recipients||'. Cc:'||lv_cc_recipients||'.Sub:'||lv_subject;
				-- TODO: This won't compile unless you define your own send_mail procedure.
                send_mail(
                    p_in_to          => lv_to_recipients,
                    p_in_cc          => lv_cc_recipients,
                    p_in_subject     => lv_subject,
                    p_in_message     => lv_message,
                    p_out_ret_status => lv_ret_status,
                    p_out_ret_msg    => lv_ret_message
                );
                IF lv_ret_status != 'S'
                THEN
                    RAISE le_mail_excp;
                END IF;
                
			 debug(pi_message => lv_procedure||' : Exit main.' 
                                          );
			EXCEPTION
               WHEN le_mail_excp then
				 lv_error_msg := p_alert_name||'-'||lv_status||'. Error: '||lv_ret_message||SQLERRM;
				 debug(pi_message => lv_procedure||':'||lv_error_msg
                                              );
			   WHEN others then
				 lv_error_msg := p_alert_name||'-'||lv_status||': '||SQLERRM;
				 debug(pi_message => lv_error_msg  
                                              );
			END;
  EXCEPTION
    WHEN OTHERS
    THEN
        lv_error_msg := p_alert_name||'-'||lv_status||': '||SQLERRM;
		debug(pi_message => lv_error_msg
                                     );
  END main;
END XX_COMMON_ALERTS_PKG;
/
SHOW ERRORS;
