require "spec"
require "../src/bamboo/settings"
require "../src/bamboo/bam_record"
require "../src/bamboo/bam/record_converter"
require "../src/bamboo/bam/bam_reader"

describe Bamboo::Bam::BamReader do
  it "loads the default index before a region query" do
    path = File.expand_path("fixtures/moo.bam", __DIR__)
    reader = Bamboo::Bam::BamReader.new

    begin
      reader.open(path, limit: 1)
      records = reader.fetch("chr1", 179, 179)

      records.should_not be_empty
      records.all? { |record| record.rname == "chr1" }.should be_true
    ensure
      reader.close
    end
  end
end
