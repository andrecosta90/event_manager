# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone(phone)
  phone = phone.gsub(/[^0-9]/, "")
  return phone if phone.length == 10
  return phone[1..(phone.length-1)] if (phone.length == 11 && phone[0] == "1")
  'bad_number'
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end

end

def get_contents
  CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
  )
end

def create_letters_from(contents)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new(template_letter)

  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = row[:zipcode]
    phone = row[:homephone]

    zipcode = clean_zipcode(zipcode)
    phone = clean_phone(phone)

    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)
    save_thank_you_letter(id, form_letter)

    puts "#{name} #{zipcode} #{phone}"
  end
  contents.rewind
end

def get_dates_from(contents)
  dates = contents.map{|row| Time.strptime(row[:regdate], "%m/%d/%y %k:%M")}
  contents.rewind
  dates
end

def hour_with_highest_registrations(contents)
  best_hour = get_dates_from(contents).map{|dt| dt.hour}.tally().max_by{ |k,v| v}.first
  puts "Best Hour => #{best_hour}"
end

def dow_with_highest_registrations(contents)
  best_dow = get_dates_from(contents).map{|dt| Date::DAYNAMES[dt.wday]}.tally().max_by{ |k,v| v}.first
  puts "Best Day => #{best_dow}"
end

puts 'Event Manager Initialized!'

contents = get_contents
create_letters_from(contents)
hour_with_highest_registrations(contents)
dow_with_highest_registrations(contents)
