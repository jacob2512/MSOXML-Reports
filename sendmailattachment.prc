/*----------------------------------------------------------------------------
       PROGRAM NAME:  sendmailattachment
            PURPOSE:  Send MIME mail with a CLOB attachment via SMTP
            NOTES:
            CREATED:    Jacob Thomas  07/04/2010
            MODIFIED:
       DATE        AUTHOR         DESCRIPTION
----------------------------------------------------------------------------*/   

CREATE OR REPLACE PROCEDURE sendmailattachment 
(  p_rc_o               OUT     NUMBER,
   p_reason_o           OUT     VARCHAR2,
   p_from_i             IN      VARCHAR2,
   p_recipient_i        IN      VARCHAR2,
   p_subject_i          IN      VARCHAR2,
   p_mail_text_i        IN      VARCHAR2,
   p_mail_host_i        IN      VARCHAR2,
   p_attach_filename_i  IN      VARCHAR2,    
   p_attach_content_i   IN      CLOB
)
is                          
   
   l_attach_name        VARCHAR2(50)     := 'Rep0rt';
   
   l_Mail_Conn      utl_smtp.Connection;   
   
   crlf         VARCHAR2(2)  := chr(13)||chr(10);
   
   l_body_html    CLOB := empty_clob;  --This LOB will be the email message
   l_offset       NUMBER;
   l_amount       NUMBER;
   l_temp         VARCHAR2(32767) DEFAULT NULL;
   
   l_attach_amount NUMBER;
   l_attach_offset NUMBER;
   
BEGIN

  utl_tcp.close_all_connections;

  l_mail_conn := utl_smtp.Open_Connection(p_mail_host_i, 25);

  utl_smtp.Helo(l_mail_conn, p_mail_host_i);

  utl_smtp.Mail(l_mail_conn, p_from_i);

  utl_smtp.Rcpt(l_mail_conn, p_recipient_i);

    
    dbms_lob.createtemporary( l_body_html, FALSE, 10 );
  
  
    l_temp := l_temp || 'Date: '   || TO_CHAR(SYSDATE, 'Dy, DD Mon YYYY hh24:mi:ss') || crlf ;
    l_temp := l_temp || 'From: '   || p_from_i || crlf ; 
    l_temp := l_temp || 'Subject: '|| p_subject_i || crlf ;
    l_temp := l_temp || 'To: '     || p_recipient_i || crlf ;
    l_temp := l_temp ||'MIME-Version: 1.0'|| crlf ;                    -- Use MIME mail standard 
    l_temp := l_temp || 'Content-Type: multipart/mixed;'|| crlf ;
    l_temp := l_temp || ' boundary="-----SECBOUND"'|| crlf ;
    l_temp := l_temp || crlf ;
    
    dbms_lob.write(l_body_html,length(l_temp),1,l_temp);     -- Headers    

    l_offset := dbms_lob.getlength(l_body_html) + 1;        
    
    
    
    l_temp   := '-------SECBOUND' || crlf;
    l_temp   := l_temp || 'Content-Type: text/plain;' || crlf ;
    l_temp   := l_temp || 'charset=us-ascii' || crlf ;
    --l_temp   := l_temp || 'Content-Transfer_Encoding: 7bit' || crlf ;    
    l_temp   := l_temp || crlf;
    
    dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp);     -- Text boundary        
    
    l_offset := dbms_lob.getlength(l_body_html) + 1;
    
    
    
    dbms_lob.write(l_body_html,length(p_mail_text_i),l_offset,p_mail_text_i);    -- Message body    

    l_offset := dbms_lob.getlength(l_body_html) + 1;
    
    
    
    l_temp   := crlf || crlf ||'-------SECBOUND' || crlf;
    l_temp   := l_temp || 'Content-Type: text/plain;' || crlf ;
    l_temp   := l_temp || ' name="' ;
    
    dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp);     -- inter    
    
    l_offset := dbms_lob.getlength(l_body_html) + 1;
    
    
    
    dbms_lob.write(l_body_html,length(l_attach_name),l_offset,l_attach_name);    -- Attach name  
  
    l_offset := dbms_lob.getlength(l_body_html) + 1;
    
    
    
    l_temp   := '"'|| crlf ;
    l_temp   := l_temp || 'Content-Transfer_Encoding: 8bit'|| crlf ;
    l_temp   := l_temp ||'Content-Disposition: attachment;'|| crlf ;
    l_temp   := l_temp ||' filename="';
    
    dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp);     -- inter    
    
    l_offset := dbms_lob.getlength(l_body_html) + 1;  
    
    
    
    dbms_lob.write(l_body_html,length(p_attach_filename_i),l_offset,p_attach_filename_i);  -- Attach file name    
    
    l_offset := dbms_lob.getlength(l_body_html) + 1;
    
    
    
    l_temp   := '"'|| crlf ;  
    l_temp   := l_temp || crlf ;

    dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp);     -- inter    
    
    l_offset := dbms_lob.getlength(l_body_html) + 1;  
    
    
    
    ------------append attachment contents in 32k chunks--------------
    l_attach_amount := 30000;
    l_attach_offset := 1;
    
    WHILE l_attach_offset < dbms_lob.getlength(p_attach_content_i)    
    LOOP       
    
        l_temp := DBMS_LOB.SUBSTR(p_attach_content_i,l_attach_amount,l_attach_offset);
    
        dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp); -- Content of attachment
    
        l_attach_offset  := l_attach_offset + length(l_temp);
        
        l_offset := dbms_lob.getlength(l_body_html) + 1;
        
        l_attach_amount := LEAST(l_attach_amount,dbms_lob.getlength(p_attach_content_i) - l_attach_offset);        
    
    END LOOP;
        
    l_offset := dbms_lob.getlength(l_body_html) + 1;
    
    
    
    l_temp   := crlf || crlf ;  
    l_temp   := l_temp ||'-------SECBOUND--';            -- End MIME mail
    
    dbms_lob.write(l_body_html,length(l_temp),l_offset,l_temp);     -- Footers

    

      -- Send the email in 1900 byte chunks to UTL_SMTP
    l_offset  := 1;
    l_amount := 1900;
    
    utl_smtp.open_data(l_mail_conn);
	
    
    WHILE l_offset < dbms_lob.getlength(l_body_html) 
    LOOP
        utl_smtp.write_data(l_mail_conn,
                            dbms_lob.SUBSTR(l_body_html,l_amount,l_offset)
                            );
                            
        l_offset  := l_offset + l_amount ;
        
        l_amount := LEAST(l_amount,dbms_lob.getlength(l_body_html) - l_amount);
    END LOOP;    

    utl_smtp.close_data(l_mail_conn);
 
  utl_smtp.quit(l_mail_conn);
  
  dbms_lob.freetemporary(l_body_html);
  
EXCEPTION

  WHEN utl_smtp.Transient_Error OR utl_smtp.Permanent_Error 
  THEN
    ROLLBACK;
    
    p_rc_o := -1;
    p_reason_o := SQLERRM;
    raise_application_error(-20000, 'Unable to send mail: '||sqlerrm); 
    
  WHEN OTHERS
  THEN
    
    ROLLBACK;
    
      p_rc_o := SQLCODE;
      p_reason_o := SQLERRM;
      
DBMS_OUTPUT.PUT_LINE ( '-----CLOB mail OTHERS-----' );
DBMS_OUTPUT.PUT_LINE ( 'FORMAT_CALL_STACK:' );
DBMS_OUTPUT.PUT_LINE( DBMS_UTILITY.FORMAT_CALL_STACK() );
--
DBMS_OUTPUT.PUT_LINE ( '----------' );
DBMS_OUTPUT.PUT_LINE ( 'FORMAT_ERROR_STACK:' );
DBMS_OUTPUT.PUT_LINE( DBMS_UTILITY.FORMAT_ERROR_STACK() );
--
DBMS_OUTPUT.PUT_LINE ( '----------' );
DBMS_OUTPUT.PUT_LINE ( 'FORMAT_ERROR_BACKTRACE:' );
DBMS_OUTPUT.PUT_LINE( DBMS_UTILITY.FORMAT_ERROR_BACKTRACE() );
--
DBMS_OUTPUT.PUT_LINE ( '----------' );     
    
END sendmailattachment;
/
