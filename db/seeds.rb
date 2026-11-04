admin = User.find_or_initialize_by(email: "admin@masfutbol.com")
admin.password = ENV.fetch("ADMIN_PASSWORD", "changeme123")
admin.admin = true
admin.save!
puts "Admin ready: #{admin.email}"

puts "Clearing jerseys..."
Jersey.destroy_all

kits  = [ "Home", "Away", "Third", "Goalkeeper", "Retro" ]
sizes = %w[S M L XL XXL]

30.times do
  club = Faker::Sports::Football.team
  year = rand(1990..2025)

  Jersey.create!(
    title: "#{club} #{kits.sample} #{year}",
    club: club,
    season: "#{year}/#{(year + 1).to_s[-2..]}",
    size: sizes.sample,
    price: rand(35.0..140.0).round(2),
    description: Faker::Lorem.paragraph(sentence_count: 3)
  )
end

puts "Created #{Jersey.count} jerseys"
