require 'pp'
require 'csv'
require 'bundler/setup'
Bundler.require :default

rows = []

csvs = Dir.glob "db/*.csv"

for csv in csvs
  rows += CSV.read(csv)
end

class Fixnum
  def percent_of(n)
    self.to_f / n.to_f * 100.0
  end
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

total = rows.map(&:amount).inject(:+).round

filters = {
  eat:          /SUSHI|ITSU/,
  # breakfast:    //,
  breakfast_we: /LE PAIN QUOTIDIEN|PAUL UK|BONNE BOUCHE/,
  cafe:         /COSTA COFFEE|STARBUCKS|CAFFE NERO/,
  lunch:        /POD|MIZUNA|WRAP IT UP|LEON RESTAURANTS|SALENTO GREEN|KANADA-YA|PAPAYA|ICCO LONDON|PRET A MANGER|WAHACA|JAPANESE CANTEEN/,
  restaurant:   /COCORO|TOA KITCHEN|NYONYA|MAMUSKA|ROSSO POMODORO|BRICIOLE|TEN TEN TEI/,
  clothes:      /H&M|GAP 2744/,
  cash:         /CASH|ET2JDBYW/,
  kri:          /KRISTINA BUTKUTE/,
  supermarket:  /TESCO|MARKS & SPEN|WAITROSE|SAINSBURYS|SPAR|CO-OP GROUP|CILWORTH FD&WINE|M&S SIMPLY FOOD/,

  phone:        /TOP UP BARCL/,
  transfer_ita: /PAYMENT CHARGE|FRANCESCO CANESSA/,
  tickets:      /SongkickEU|EVENTIM/,
  other:        /RYMAN|BOOTS/,
  tech:         /APPLE STORE|MAPLIN/,
  metro:        /TICKET MACHINE|TL RAILWAY/,
  taxi:         /Uber BV|UBER\.COM/,
  pub:          /Foxcroft \& Gin|THE TIN SHED|CARPENTERS ARMS|FITZROVIA BLOOMSBURY|DUKE OF WELLINGTON|THE CROWN LONDON|THE SLAUGHTERED|PRINCE ALFRED|MELTON MOWBRAY/,
  server:       /PAYPAL \*OVH/,
  income:       /QUILL/,
  # aggregates
  food:         %i(eat breakfast restaurant cafe lunch),
  extra:        %i(pub taxi tech other tickets),
}

categories = filters.map do |name, matcher|
  cat = Hashie::Mash.new
  cat.name    = name
  cat.matcher = matcher
  cat.amount  = 0
  cat.rows    = []
  cat.matches = []
  # cat.amount_last_month = 0
  # cat.amount_last_week  = 0
  # cat.amount_week_avg   = 0
  cat
end



# expand named filters
categories.each do |cat|
  next unless cat.matcher.is_a? Array
  regex = categories.select{ |c| cat.matcher.include? c.name }.map{ |c| c.matcher.source }.join "|"
  cat.matches = cat.matcher
  cat.matcher = /#{regex}/
end


# totals
remaining = rows
categories.each do |category|
  sel = rows.select{ |r| r.name =~ category.matcher }
  category.rows   = sel
  category.amount = sel.map(&:amount).inject(:+) || 0
  remaining = remaining - sel
end

# sorting
categories.sort_by!{ |c| c.amount || 0 }
# categories.select!{ |c| c.name == :cash }
# pp categories


# output

INCOME = categories.find{|c| c.name == :income }.amount

puts "-"*80
categories.each do |category|
  name        = category.name.capitalize
  amount      = category.amount.round
  percentage  = amount.abs.percent_of INCOME
  info        = "[#{category.matches.join(', ')}]" if category.matches.any?
  puts "#{name} #{info}"
  puts "#{amount.abs} (#{percentage.round 1}%)"
  # puts out
  puts "-"*80
end



if remaining.any?
  puts "uncategorized:"
  pp remaining
end

require 'pp'
require 'yaml'
def p(text="")
  if text.is_a?(String)
    puts text
  else
    pp text
  end
end


p "Balance"
p total
p "-"*80
p
p "category: tickets (raw detail)"
p categories.find{|c| c.name == :tickets }.to_yaml
p

# pp rows
