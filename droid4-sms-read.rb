#!/usr/bin/ruby
# encoding: utf-8
#
# Parses SMS messages in PDU format from droid 4 /dev/gsmtty9 device
# and copies them into a Maildir
#
# If called with a PDU format SMS as the parameter, just decodes the PDU
#
# To use, install ruby, then gem install pdu_tools
#
# To read sms with an email reader, you need to create the maildir for
# with maildirmake ~/Maildir/INBOX.sms
#

require "pdu_tools"

$device = "gsmtty9"
$maildir = "#{Dir.home}/Maildir/INBOX.sms"
$aliases = "#{Dir.home}/aliases"
$arg0 = ARGV[0]

def print_help()
  printf "Usage: %s [optionalpdu]\n", $0
  printf "Without options, %s keeps reading /dev/gsmtty9, then\n", $0
  printf "copies SMS into %s if it exists, and then acks the SMS\n",
         $maildir
  exit 0
end

def get_name_by_number(phone_number)
  email = ""

  fd = File.open $aliases, "r:UTF-8"
  fd.each_line { |line|
    if !line.valid_encoding?
      printf "Invalid UTF-8 for %s", line
      next
    end
    first,email = line.split("<")
    if email
      phone,last = email.split(">")
      if phone == phone_number
        first,nick,*elements = line.split(" ")
        email = elements.join(" ")
        break
      end
    end
  }
  fd.close

  return email
end

def handle_message(pdu, save)
  decoder = PDUTools::Decoder.new pdu, :ms_to_sc
  message_part = decoder.decode

  if message_part.timestamp
    seconds = message_part.timestamp.strftime '%c'
  else
    seconds = 0
  end

  name = get_name_by_number(message_part.address)
  decoded = ""
  email = ""

  # Try to get email address in aliases
  if name && name != ""
    first,email = name.split("<")
    if email && email != ""
      email,last = email.split(">")
      decoded = sprintf "From %s@%s  %s\n", email, $device,
                        seconds
      decoded += sprintf "From: %s\n", name
    end
  end

  # Not found in aliases
  if decoded == ""
    decoded = sprintf "From %s@%s  %s\n", message_part.address, $device,
                      seconds
    decoded += sprintf "From: %s\n", message_part.address
  end

  decoded += sprintf "Date: %s\n",  message_part.timestamp
  decoded += sprintf "Subject: SMS received via %s\n", $device
  decoded += sprintf "Message-ID: <%s>\n", pdu
  decoded += sprintf "In-Reply-To: <%s@%s>\n\n",
		     message_part.address, $device
  decoded += message_part.body

  printf "%s\n", decoded

  if save != 1
    return 0
  end

  filename = sprintf "%s/%s/%i-%f.sms.%s,S=%i",
                     $maildir, "new", message_part.timestamp.to_i,
                     Time.now.to_f, $device, decoded.size

  if !Dir.exists?($maildir)
    return -1
  end

  if !File.exists? filename
    printf "Writing SMS to %s\n", filename
    fd = File.open filename, "w"
    fd.write decoded
    fd.sync
    fd.close
  else
    printf "File already exists for %s\n", filename
    return -1
  end

  return decoded.size
end

def handle_modem(fd, data)
  data.each_line "\r" do |line|

    # Remove trailing \r, \n or \r\n
    line.gsub! /\r$/, ''
    line.gsub! /\n$/, ''

    # Remove leading U1234
    line.gsub! /^U\d{4}/, ''

    # Skip empty line?
    if line.size == 0
      next
    end

    # Is it an AT command response?
    if line =~ /^AT\+/ || line =~/^\+/
      printf "Command returned %s\n", line
      return
    end

    # Is it a notification?
    if line =~ /^~/
      printf "Notification: \"%s\"\n", line
      next
    end

    # It's a new SMS
    printf "SMS received:\n"
    error = handle_message line, 1
    if error <= 0
      printf "Error handling message: %i\n", error
    else
      # REVISIT: Why does Android use AT+CNMA=0,0 sometimes?
      printf "Acking received SMS\n"
      fd.write "U1234AT+GCNMA=1\r"
      fd.flush
    end
  end
end

def read_messages()
  new = $maildir + "/new"
  devname = "/dev/" + $device

  printf "Reading SMS from %s into %s..\n", $device, new

  if !Dir.exists?($maildir)
    printf "Error: Missing maildir %s\n", $maildir
    printf "Maybe try: maildirmake %s\n", $maildir
    exit 1
  elsif !Dir.exists? new
    printf "Error: Missing maildir %s\n", new
    exit 1
  end

  if !File.exists? devname
    printf "Error: No %s found\n", devname
    exit 1
  end

  fd = File.open devname, "r+"
  loop do
    rs, ws, es = IO.select([fd], nil, [fd], 10)
    if rs
      rs.each do |f|
        data = f.readpartial 1024
        handle_modem fd, data
      end
    elsif es
      printf "Error reading %s\n", devname
    else
      #printf "Timeout reading %s\n", devname
    end
  end
  fd.close

end

if !$arg0
  read_messages
elsif $arg0 == "--help"
  print_help
else
  handle_message $arg0, 0
end
