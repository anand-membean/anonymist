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
      t.column :email, :email, domain: "custom.com", name_column: "fullname"
    end
  end

  it "scrubs email with custom domain and name from another column" do
    sql = "INSERT INTO `users` (`id`, `fullname`, `email`) VALUES (1, 'John Doe', 'old@example.com');\n"
    input.write(sql)
    input.rewind

    processor.process(input, output)

    result = output.string
    expect(result).to start_with("INSERT INTO `users` (`id`, `fullname`, `email`) VALUES")

    # Extract the email value
    match = result.match(/'([^']*)'\);/)
    email = match[1]

    expect(email).to end_with("@custom.com")
    expect(email).to include("john") # Faker usually lowercases
    expect(email).to include("doe")
  end
end
