CREATE OR REPLACE FUNCTION util.send_email(
    p_to 				 text, 
    p_subject 			 text, 
    p_message 			 text, 
    p_copy 				 text = NULL::text, 
    p_blindcopy 		 text = NULL::text, 
    p_attach_files_name  text[] = NULL::text[], 
    p_attach_files_body  bytea[] = NULL::bytea[], 
    p_attach_files_codec text[] = NULL::text[], 
    p_sender_address 	 text = NULL::text, 
    p_smtp_server 		 text = COALESCE(NULLIF(current_setting('adm.email_smtp_server'::text, true), ''::text), 'mail.company.ru'::text)
    ) RETURNS text
    LANGUAGE plpython3u
    AS $$
# -*- coding: utf-8 -*-

#
# Отправка сообщений через функцию в базе данных.
# список адресатов в p_to p_copy p_blindcopy указывается через , или через ;   
#
# select util.send_email('sergey.grinko@company.ru,grufos@mail.ru','Проверка заголовка','Текст письма','grufos@mail.ru','sergey.grinko@gmail.com');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма','sergey.grinko@gmail.com','grufos@mail.ru');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', NULL, 'grufos@mail.ru');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', NULL, 'grufos@mail.ru,sergey.grinko@gmail.com');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', 'grufos@mail.ru');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', 'sergey.grinko@gmail.com');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', NULL, NULL, ARRAY['file.txt'], ARRAY['содержимое файла file.txt'::bytea]);
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>', NULL, NULL, ARRAY['file.txt'], ARRAY['содержимое файла file.txt'::bytea]);
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>', NULL, NULL, ARRAY['file.txt'], ARRAY['содержимое файла file.txt'::bytea], ARRAY['zip']);

  import io
  import zipfile
  import socket
  import smtplib
  from smtplib                import SMTPException
  from email.mime.multipart   import MIMEMultipart
  from email.mime.text        import MIMEText
  from email.header           import Header
  from email.mime.base        import MIMEBase
  from email.mime.application import MIMEApplication
  from email                  import encoders
  from os.path                import basename

  _sender_address = p_sender_address
  if p_sender_address is None or p_sender_address == '' or p_sender_address.isspace():
    _sender_address = socket.gethostname() + " <" +socket.gethostname() + "@company.ru>"

  _recipients_list = [r.strip() for r in p_to.replace(';',',').split(',')]

  _msg = MIMEMultipart('alternative')
  _msg['From'] = _sender_address
  _msg['To'] = p_to.replace(';',',')
  _msg['Subject'] = Header(p_subject, 'utf-8') 
  if not (p_copy is None or p_copy=='' or p_copy.isspace()):
    _msg['CC'] = p_copy.replace(';',',')
    _recipients_list = _recipients_list + [r.strip() for r in p_copy.replace(';',',').split(',')]
  if not (p_blindcopy is None or p_blindcopy=='' or p_blindcopy.isspace()):
    _msg['BCC'] = p_blindcopy.replace(';',',')
    _recipients_list = _recipients_list + [r.strip() for r in p_blindcopy.replace(';',',').split(',')]

  if p_message:
    if "<html>" in p_message or "<br>" in p_message or "<style>" in p_message or "<table>" in p_message or "<H1>" in p_message or "<head>" in p_message:
      _part = MIMEText(p_message, 'html', 'utf-8')
    else:
      _part = MIMEText(p_message, 'plain', 'utf-8')
    _msg.attach(_part)

  if p_attach_files_name and p_attach_files_body:
    for _i, _f in enumerate(p_attach_files_name):
      _part = MIMEBase('application', "octet-stream")
      if p_attach_files_codec is not None and len(p_attach_files_codec) >= _i and p_attach_files_codec[_i] is not None and p_attach_files_codec[_i]=="zip":
        # применяем архивацию для преобразования данных файла вложения
        mf = io.BytesIO()
        with zipfile.ZipFile(mf, mode='w', compression=zipfile.ZIP_DEFLATED) as zf:
          zf.writestr(_f, p_attach_files_body[_i])
        _part.set_payload(mf.getvalue())
        _f = _f + ".zip"
      else:
        # не нужно применять никакого кодека преобразования данных файла вложения
        _part.set_payload(p_attach_files_body[_i])
      # конвертируем вложение в base64
      encoders.encode_base64(_part)
      _part.add_header('Content-Disposition', 'attachment; filename="%s"' % basename(_f))
      _msg.attach(_part)

  server = smtplib.SMTP(p_smtp_server)
  server.sendmail(_sender_address, _recipients_list, _msg.as_string())
  server.quit()
  return "send mail"
$$;
