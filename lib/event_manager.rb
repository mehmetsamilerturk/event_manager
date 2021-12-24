require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_homephone(homephone)
  #   If the phone number is less than 10 digits, assume that it is a bad number(done)
  #   If the phone number is 10 digits, assume that it is good(done)
  #   If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits(done)
  #   If the phone number is 11 digits and the first number is not 1, then it is a bad number(done)
  #   If the phone number is more than 11 digits, assume that it is a bad number(done)
  homephone_digits = homephone.gsub(/[^\d]/, "")
  if homephone_digits.size < 10
    homephone_digits.ljust(10, '0')
  elsif homephone_digits.size > 10
    if homephone_digits.size == 11 
      if homephone_digits[0] == '1'
        homephone_digits[1..10]
      else
        homephone_digits[0..9]
      end
    end
  elsif homephone_digits.size == 10
    homephone_digits
  end
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
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

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  homephone = clean_homephone(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts homephone
end
