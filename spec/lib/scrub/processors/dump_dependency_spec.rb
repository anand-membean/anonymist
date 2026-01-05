# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Scrub::Processors::Dump do
  let(:config) { Scrub::Config.new }
  let(:processor) { described_class.new(config) }
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }

  before do
    config.table(:users) do |t|
      # Email depends on fullname.
      # If we scrub fullname first, email should use the scrubbed fullname.
      t.column :email, :email, domain: "custom.com", name_column: "fullname", depends_on: "fullname"
      t.column :fullname, :name
    end
  end

  it "scrubs columns in dependency order" do
    # Original: fullname='Bhanu', email='bhanu@example.com'
    # Scrubbed fullname will be something random (e.g. 'John Doe')
    # Scrubbed email should be 'john.doe@custom.com', NOT 'bhanu@custom.com'

    sql = "INSERT INTO `users` (`id`, `fullname`, `email`) VALUES (1, 'Bhanu', 'bhanu@example.com');\n"
    input.write(sql)
    input.rewind

    processor.process(input, output)

    result = output.string

    # Extract values
    # ID might be quoted or unquoted depending on processor implementation
    # Handle escaped quotes in values (e.g. O\'Reilly)
    match = result.match(/VALUES \('?1'?, '((?:[^']|\\')*)', '((?:[^']|\\')*)'\)/)
    scrubbed_fullname = match[1]
    scrubbed_email = match[2]

    puts "Scrubbed Fullname: #{scrubbed_fullname}"
    puts "Scrubbed Email: #{scrubbed_email}"

    expect(scrubbed_fullname).not_to eq("Bhanu")

    # Faker might add numbers or change separators, but usually it's close.
    # Let's just check that it DOES NOT contain 'bhanu'
    expect(scrubbed_email).not_to include("bhanu")

    # And it should contain parts of the new name
    # Handle cases like "Mrs. John Doe" -> "mrs" might be stripped or "mrs." might not match "mrs"
    first_name = scrubbed_fullname.split.first.downcase.gsub(/[^a-z]/, "")
    expect(scrubbed_email.downcase).to include(first_name)
  end
end
