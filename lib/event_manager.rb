require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def parse_date(date)
  date_split = date.split(' ')[0].split('/')
  date_formatted = date_split.map do |value|
    value.rjust(2, '0')
  end

  date_formatted = date_formatted.reverse.insert(1, date_formatted.reverse.delete_at(2))
  date_formatted.delete_at(-1)
  date_formatted = date_formatted.join('/').concat(" #{date.split(' ')[1]}")

  Time.parse(date_formatted)
end

def clean_homephone(homephone)
  #   If the phone number is less than 10 digits, assume that it is a bad number(done)
  #   If the phone number is 10 digits, assume that it is good(done)
  #   If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits(done)
  #   If the phone number is 11 digits and the first number is not 1, then it is a bad number(done)
  #   If the phone number is more than 11 digits, assume that it is a bad number(done)
  homephone_digits = homephone.gsub(/[^\d]/, '')
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
hours = []
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  homephone = clean_homephone(row[:homephone])
  date = parse_date(row[:regdate])
  legislators = legislators_by_zipcode(zipcode)
  day = Date.parse(date.to_s)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  # puts homephone
  days.push(day.wday)
  hours.push(date.hour)
end
peak_hours = hours.each_with_object(Hash.new(0)) do |hour, result|
  result[hour] += 1
end
peak_hours_sorted = peak_hours.sort_by { |_key, value| value }.reverse.to_h
# p peak_hours
# puts "Hours most people registered: #{peak_hours_sorted.keys[0, 2].join(' and ')}"
peak_days = days.each_with_object(Hash.new(0)) do |day, result|
  result[day] += 1
end

# p peak_days
a = {}
peak_days.each do |day, num|
  case day
  when 0
    a['Sunday'] = num
  when 1
    a['Monday'] = num
  when 2
    a['Tuesday'] = num
  when 3
    a['Wednesday'] = num
  when 4
    a['Thursday'] = num
  when 5
    a['Friday'] = num
  when 6
    a['Saturday'] = num
  end
end

# p a
