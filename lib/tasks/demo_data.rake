# frozen_string_literal: true

namespace :bbcx do
  desc "Load reproducible demo dataset from db/seeds.rb"
  task seed_demo: :environment do
    load Rails.root.join("db", "seeds.rb")
    puts "BBC-X demo data loaded."
  end
end
