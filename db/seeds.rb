admin = User.find_or_initialize_by(email: "admin@masfutbol.com")
admin.password = ENV.fetch("ADMIN_PASSWORD", "changeme123")
admin.admin = true
admin.save!
puts "Admin ready: #{admin.email}"

puts "Clearing jerseys..."
Jersey.destroy_all

CLUBS_BY_LEAGUE = {
  "Premier League" => [ "Arsenal", "Chelsea", "Liverpool", "Manchester United", "Manchester City", "Tottenham Hotspur", "Newcastle United" ],
  "La Liga"        => [ "Real Madrid", "FC Barcelona", "Atlético Madrid", "Sevilla", "Real Betis", "Athletic Club" ],
  "Serie A"        => [ "Juventus", "AC Milan", "Inter Milan", "AS Roma", "Napoli", "Lazio" ],
  "Bundesliga"     => [ "Bayern Munich", "Borussia Dortmund", "Bayer 04 Leverkusen", "RB Leipzig", "Schalke 04" ],
  "Ligue 1"        => [ "Paris Saint-Germain", "Olympique de Marseille", "Olympique Lyonnais", "AS Monaco" ],
  "International"  => [ "Brazil", "Argentina", "Mexico", "Chile", "Germany", "France", "Italy", "Netherlands" ]
}

kits  = [ "Home", "Away", "Third", "Goalkeeper", "Retro" ]
sizes = %w[S M L XL XXL]

categories = CLUBS_BY_LEAGUE.keys.index_with { |name| Category.find_or_create_by!(name: name) }

30.times do
  league, clubs = CLUBS_BY_LEAGUE.to_a.sample
  club = clubs.sample
  year = rand(1990..2025)

  Jersey.create!(
    title: "#{club} #{kits.sample} #{year}",
    club: club,
    season: "#{year}/#{(year + 1).to_s[-2..]}",
    size: sizes.sample,
    price: rand(35.0..140.0).round(2),
    description: Faker::Lorem.paragraph(sentence_count: 3),
    category: categories[league]
  )
end

puts "Created #{Jersey.count} jerseys"
