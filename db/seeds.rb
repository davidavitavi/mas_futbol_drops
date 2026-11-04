#puts "Clearing jerseys..."
Jersey.destroy_all

kits  = ["Home", "Away", "Third", "Goalkeeper", "Retro"]
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

puts "Created #{Jersey.count} jerseys" This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
