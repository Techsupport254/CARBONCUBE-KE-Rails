require "./config/environment"
Category.all.each do |c|
  puts "#{c.name}"
end
