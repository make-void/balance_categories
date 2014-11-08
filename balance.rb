require 'pp'
require 'csv'
require 'bundler/setup'
Bundler.require :default

rows = []

csvs = Dir.glob "db/*.csv"

for csv in csvs
  rows += CSV.read(csv)
end


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
  # breakfast:    //,
  breakfast_we: /LE PAIN QUOTIDIEN|PAUL UK|BONNE BOUCHE/,
  cafe:         /COSTA COFFEE|STARBUCKS|CAFFE NERO/,
  lunch:        /POD|MIZUNA|WRAP IT UP|LEON RESTAURANTS|SALENTO GREEN|KANADA-YA|PAPAYA|ICCO LONDON|PRET A MANGER|WAHACA/,
  restaurant:   /COCORO|TOA KITCHEN|NYONYA|MAMUSKA|ROSSO POMODORO|BRICIOLE/,
  clothes:      /H&M|GAP 2744/,
  cash:         /CASH|ET2JDBYW/,
  kri:          /KRISTINA BUTKUTE/,
  supermarket:  /TESCO|MARKS & SPEN|WAITROSE|SAINSBURYS|SPAR|CO-OP GROUP|CILWORTH FD&WINE|M&S SIMPLY FOOD/,

  other:        /RYMAN|BOOTS/,
  tech:         /APPLE STORE/,
  metro:        /TICKET MACHINE|TL RAILWAY/,
  taxi:         /Uber BV/,
  pub:          /Foxcroft \& Gin|THE TIN SHED|CARPENTERS ARMS|FITZROVIA BLOOMSBURY|DUKE OF WELLINGTON|THE CROWN LONDON/,
  income:       /QUILL/,
  # aggregates
  food:         %i(eat breakfast restaurant cafe lunch),
}

categories = filters.map do |name, matcher|
  cat = Hashie::Mash.new
  cat.name    = name
  cat.matcher = matcher
  cat.amount  = 0
  cat.rows    = []
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
  category.rows   = sel
  category.amount = sel.map(&:amount).inject(:+)
  remaining = remaining - sel
end

# sorting
categories.sort_by!{ |c| c.amount }
# categories.select!{ |c| c.name == :cash }
# pp categories


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