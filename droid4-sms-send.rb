#!/usr/bin/ruby
# encoding: utf-8
#
# Send SMS messages in PDU format using droid 4 /dev/gsmtty3 device
#
# Needs gem install mail pdu_tools
#

require "mail"
require "pdu_tools"

$device = "gsmtty3"

def print_help()
  printf "usage: echo message | %s phonenumber\n", $0
  printf "Typically used from an email client like sendmail\n"
end

def send_pdu(pdu)
  devname = "/dev/" + $device

  # Must leave out the first hex byte and write as string
  mot_fmt = sprintf "%s", pdu.pdu_hex[2..-1].downcase

  printf "Sending Motorola GSM format PDU: %s\n", mot_fmt

  if !File.exists? devname
    error = sprintf "Error: No %s found\n", devname
    raise error
  end

  fd = File.open devname, "r+"
  fd.write "U1234AT+GCMGS=\n"
  fd.flush
  cont = sprintf "U%s%c", mot_fmt, 0x1a
  fd.write cont
  fd.flush

  rs, ws, es = IO.select([fd], [fd], [fd], 10)
  if rs
    rs.each do |f|
      data = f.readpartial 1024
      if data =~ /ERROR/
        error = sprintf "Got error: %s\n", data
        raise error
      end
      printf "Got response: %s\n", data
    end
  elsif es
    error = sprintf "Error reading %s\n", devname
    raise error
  else
    error = sprintf "Timeout reading %s\n", devname
    raise error
  end
  fd.close
end

def encode_pdu(phone_number, body)
  encoder = PDUTools::Encoder.new recipient: phone_number, message: body
  pdus = encoder.encode

  pdus.each do |pdu|
    printf "Sending to %s:\n%s\n", phone_number, body
    send_pdu pdu
  end
end

if !ARGV[0]
  print_help
  exit 0
end

input = STDIN.read
mail = Mail.new(input)
body = mail.decoded
if body == ""
  body = input
end

ARGV.each do |arg|
  if arg == "--" || arg =~ /^-t/
    next
  end

  email = arg.split '@'
  phone_number = email.first
  encode_pdu phone_number, body
end

