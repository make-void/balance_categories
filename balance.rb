require 'pp'
require 'csv'
require 'bundler/setup'
Bundler.require :default

rows = CSV.read "db/statement.csv"

columns = %w(date name amount)

rows = rows.map do |row|
  date    = Date.parse row[0]
  name    = row[1]
  amount  = row[2].to_f
  Hashie::Mash.new(
    date:   date,
    name:   name,
    amount: amount,
  )
end

filters = {
  eat:          /SUSHI|ITSU/,
  breakfast:    /TESCO/,
  breakfast_we: /LE PAIN QUOTIDIEN|STARBUCKS|PAUL UK/,
  lunch:        /POD|MIZUNA|WRAP IT UP/,
  clothes:      /H&M|GAP 2744/,
  cash:         /CASH/,
  murka:        /KRISTINA BUTKUTE/,
  supermarket:  /MARKS & SPEN|WAITROSE|SAINSBURYS|SPAR|CO-OP GROUP/,
  restaurant:   /COCORO/,
  other:        /RYMAN|BOOTS/,
  tech:         /APPLE STORE/,
  metro:        /TICKET MACHINE/,
  taxi:         /Uber BV/,
  pub:          /Foxcroft \& Gin|THE TIN SHED/,
  income:       /QUILL/,
  # aggregates
  food:         %i(eat breakfast supermarket restaurant),
}

categories = filters.map do |name, matcher|
  cat = Hashie::Mash.new
  cat.name    = name
  cat.matcher = matcher
  cat.amount  = 0
  # cat.amount_last_month = 0
  # cat.amount_last_week  = 0
  # cat.amount_week_avg   = 0
  cat
end


# expand named filters
categories.each do |cat|
  next unless cat.matcher.is_a? Array
  regex = categories.select{ |c| cat.matcher.include? c.name }.map{ |c| c.matcher.source }.join "|"
  cat.matcher = /#{regex}/
end


# totals
remaining = rows
categories.each do |category|
  sel = rows.select{ |r| r.name =~ category.matcher }
  category.amount = sel.map(&:amount).inject(:+)
  remaining = remaining - sel
end

# sorting
categories.sort_by!{ |c| c.amount }


# output
puts "-"*80
categories.each do |category|
  puts category.name.capitalize
  puts category.amount.round
  # puts out  
  puts "-"*80
end

if remaining.any?
  puts "uncategorized:"
  pp remaining
end






# pp rows