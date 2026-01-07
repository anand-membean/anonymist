require "faker"

Scrub.configure do
  bloom_filter size: 100, hashes: 1

  table :users do
    column :fullname do |row|
      Faker::Config.random = Random.new(row['id'])
      "#{Faker::Name.first_name} #{Faker::Name.last_name}"
    end

    column :email do |row|
      Faker::Config.random = Random.new(row['id'])
      "#{Faker::Name.first_name}.#{Faker::Name.last_name}.#{row['id']}@membean.com".downcase
    end

    column :login do |row|
      Faker::Config.random = Random.new(row['id'])
      "#{Faker::Name.first_name}_#{Faker::Name.last_name}_#{row['id']}"
    end

    column :lfname do |row|
      Faker::Config.random = Random.new(row['id'])
      # Don't change sequence of finding first_name and last_name
      first = Faker::Name.first_name
      last = Faker::Name.last_name
      "#{last}, #{first}"
    end

    # TBD: Do we need to update password for all?
  end

  table :schools do
    column :name do |row|
      Faker::Educator.secondary_school
    end

    column :city do |row|
      Faker::Address.city
    end
  end
end
