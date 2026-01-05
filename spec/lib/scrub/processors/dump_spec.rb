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
      t.column :email, type: :email
    end
  end

  it "scrubs configured columns in INSERT statements" do
    sql = "INSERT INTO `users` (`id`, `email`) VALUES (1, 'test@example.com'), (2, 'other@example.com');\n"
    input.write(sql)
    input.rewind

    processor.process(input, output)

    result = output.string
    expect(result).to start_with("INSERT INTO `users` (`id`, `email`) VALUES")
    expect(result).not_to include("'test@example.com'")
    expect(result).not_to include("'other@example.com'")
    # Should contain scrubbed values (emails)
    expect(result).to match(/'[^']+'/)
  end

  it "retries on collision" do
    # Force collision on first attempt
    allow(Faker::Internet).to receive(:email).and_return("collision@example.com", "fresh@example.com")

    # Pre-fill bloom filter with collision
    processor.instance_variable_get(:@bloom).insert("collision@example.com")

    sql = "INSERT INTO `users` (`id`, `email`) VALUES (1, 'test@example.com');\n"
    input.write(sql)
    input.rewind

    processor.process(input, output)

    result = output.string
    # It should fall back to mutation on collision
    expect(result).to match(/'test@example.com_\d+'/)
  end

  it "passes through other lines unchanged" do
    sql = "CREATE TABLE `users` ...;\n"
    input.write(sql)
    input.rewind

    processor.process(input, output)

    expect(output.string).to eq(sql)
  end

  it "passes through INSERT statements that do not match the regex" do
    sql = "INSERT INTO users VALUES (1);\n" # Missing column list
    input.write(sql)
    input.rewind

    processor.process(input, output)

    expect(output.string).to eq(sql)
  end

  it "passes through INSERT statements for unconfigured tables" do
    sql = "INSERT INTO `other_table` (`id`) VALUES (1);\n"
    input.write(sql)
    input.rewind

    processor.process(input, output)

    expect(output.string).to eq(sql)
  end
end
