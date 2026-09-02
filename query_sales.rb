require_relative 'config/environment'

puts "=== Commission Sales Users ==="
users = SalesUser.where("lower(compensation_type) = 'commission'")

users.each do |u|
  code = CarbonCode.find_by(associable: u)
  if code
    sellers = Seller.where(carbon_code_id: code.id)
    puts "SalesUser: #{u.fullname} (#{u.email}) | Code: #{code.code}"
    puts "Total Onboarded: #{sellers.count}"
    puts "Sellers: #{sellers.pluck(:fullname, :email).inspect}"
  else
    puts "SalesUser: #{u.fullname} (#{u.email}) | No carbon code found."
  end
  puts "----------------------"
end
