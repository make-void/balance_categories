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

def expand_type(type)
  case type
  when "TFR" then :transfer
  when "BP"  then :bill_payment
  when "CR"  then :credit
  when "DR"  then :fees
  else
    "#{type} (missing type!)"
  end
end


columns = %w(date name amount)

rows = rows.map do |row|
  # ["﻿ Date", "Type", "Merchant/Description", "Debit/Credit", "Balance"]
  next unless row[0]
  next if /Arranged overdraft limit| Date/ =~ row[0]
  date    = Date.parse row[0]
  type    = row[1] # VIS (visa) ...
  type    = expand_type type
  name    = row[2]

  name = name.gsub "INT'L **********  ", ''

  next if row[3][0..1] == "+£"
  amount  = (row[3].gsub(/-£/, '')).to_f
  Hashie::Mash.new(
    date:   date,
    name:   name,
    type:   type,
    amount: amount,
  )
end

rows.compact!

rows.reject!{ |row| row.type == :fees }
rows.reject!{ |row| row.type == :transfer }
# rows.select!{ |row| row.date >= Date.new(2015, 11, 1) }
# rows.select!{ |row| row.date <= Date.new(2016, 1, 1)  }
rows.select!{ |row| row.date >= Date.new(2016, 1, 1) }

rows.each do |row|
  if row.name == "************************************"
    if row.type == :bill_payment
      if row.amount > 300 && row.amount < 1000
        row.name = "bitcoin"
      else
        row.name = "#{row.name} <type:#{row.type}>"
      end
    else
      row.name = "#{row.name} <type:#{row.type}>"
    end
  end
end

total = rows.map(&:amount).inject(:+).round

filters = {
  eat:          /SUSHI|ITSU/,
  # breakfast:    //,
  breakfast_we: /LE PAIN QUOTIDIEN|PAUL UK|BONNE BOUCHE|NORDIC BAKERY|OLD SWAN/,
  cafe:         /COSTA COFFEE|STARBUCKS|CAFFE NERO|ART CAFE|EQUINOX CAFE|PURE MOORGATE|GREGGS S/,
  lunch:        /POD|MIZUNA|WRAP IT UP|LEON RESTAURANTS|SALENTO GREEN|KANADA-YA|PAPAYA|ICCO LONDON|PRET A MANGER|WAHACA|JAPANESE CANTEEN|GOURMET BURGER|PIZZA EXPRESS|CARLUCCIOS LTD|EAST STREET|EAT\s+CANARY WHARF|KRUGER|BANK OF AMERICA|PHO ST PAUL|\* CANARY WHARF|KAMPS TCR/,
  restaurant:   /COCORO|TOA KITCHEN|NYONYA|MAMUSKA|ROSSO POMODORO|BRICIOLE|TEN TEN TEI|BURGER&LOBSTER|EFES \* RESTAURANT|PURE CANARY WHARF|LOTUS CHINESE REST|PEPPER SAINT|PAPA JOHN|ALL STAR LANES|LEVEL \*\* LTD|WILDWOOD CANARY WH|CRUSSH JUBILEE|PP\*MAILINDA|BIG CHILL|DAISY GREEN FOOD|WASABI CANARY|BYRON HAMBURGERS|BLUEBIRD RESTAURAN|BIRLEYS SANDWICHES|INDIGO\s+WESTFIELD|KAPPA RESTAURANT|PIZZA PILGRIMS/,
  cash:         /CASH|ET2JDBYW/,
  kri:          /KRISTINA BUTKUTE/,
  supermarket:  /TESCO STORES|TESCO|MARKS & SPEN|WAITROSE|SAINSBURYS|SPAR|CO-OP GROUP|CILWORTH FD&WINE|M&S SIMPLY FOOD|ASDA SUPERSTORE|ALNOOR SUPERMARKET/,

  phone:        /TOP UP BARCL|THREE-TOPUP|Skype/,
  transfer_ita: /PAYMENT CHARGE|FRANCESCO CANESSA/,
  rent_and_ita: /\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/,
  tickets:      /SongkickEU|EVENTIM|TICKETWEB\.CO\.UK/,
  shopping:     /RYMAN|BOOTS|Amazon UK Marketpl|Amazon UK Retail|ALIEXPRESS|DEBENHAMS|KUSMI TEA|MANGO LONDON|KIKO|GEOX RETAIL|H&M|GAP 2744|GAP \*\*\*\*|PRIMARK/,
  other:        /SpotifyUK|PAYPAL \*SPOTIFY|BANDCAMP|POST OFFICE/,
  tech:         /APPLE STORE|MAPLIN|ITUNES\.COM|LAPTOPSDIRECT|RING\s+\*|INDIEGOGO|APPLE ONLINE STORE|CURRYS\s+CANARY WHARF/,
  metro:        /TFL.GOV.UK|TICKET MACHINE|TL RAILWAY|TRAINLINE\.COM/,
  zipcar:       /ZIPCAR/,
  taxi:         /Uber BV|UBER\.COM/,
  pub:          /Foxcroft \& Gin|THE TIN SHED|CARPENTERS ARMS|FITZROVIA BLOOMSBURY|DUKE OF WELLINGTON|THE CROWN LONDON|THE SLAUGHTERED|PRINCE ALFRED|MELTON MOWBRAY|THE WHEATSHEAF/,
  server:       /PAYPAL \*OVH|Amazon Svcs|OVH\s+ROUBAIX|GITHUB INC/,
  income:       /QUILL/,
  house_bills:  /COUNCIL TAX|RELISH/,
  credit_card:  /HSBC CREDIT/,
  bitcoin:      /bitcoin/,
  dunno:        /NORTHERNSO|JUBILEE PLACE|\* CANARY WHARF|OVERDRAFT INTERESTTO|CABOT PLACE|PAYPAL \*\*PASSWORD|BREAD AHEAD/,
  # aggregates
  food:         %i(eat breakfast restaurant cafe lunch),
  extra:        %i(pub taxi tech shopping other tickets),
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

TOTAL = total # categories.find{|c| c.name == :income }.amount

puts "-"*80
categories.each do |category|
  name        = category.name.capitalize
  amount      = category.amount.round
  percentage  = amount.abs.percent_of TOTAL
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
puts total
p "-"*80
p
# p "category: tickets (raw detail)"
# puts categories.find{|c| c.name == :rent_and_ita }.to_yaml
# p

# pp rows
