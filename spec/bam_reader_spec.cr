require "spec"
require "../src/bamboo/settings"
require "../src/bamboo/bam_record"
require "../src/bamboo/bam/record_converter"
require "../src/bamboo/bam/bam_reader"

describe Bamboo::Bam::BamReader do
  fixture_path = File.expand_path("fixtures/moo.bam", __DIR__)

  it "loads the default index before a region query" do
    reader = Bamboo::Bam::BamReader.new

    begin
      reader.open(fixture_path, limit: 1)
      records = reader.fetch("chr1", 179, 179)

      records.should_not be_empty
      records.all? { |record| record.rname == "chr1" }.should be_true
    ensure
      reader.close
    end
  end

  it "keeps an empty result open and clears its state when closed" do
    reader = Bamboo::Bam::BamReader.new

    begin
      reader.open(fixture_path, limit: 0).should be_empty
      reader.open?.should be_true
      reader.file_path.should eq(fixture_path)

      reader.close
      reader.open?.should be_false
      reader.file_path.should be_nil
    ensure
      reader.close
    end
  end

  it "does not retain a path when opening a missing file fails" do
    reader = Bamboo::Bam::BamReader.new
    missing_path = File.expand_path("fixtures/missing.bam", __DIR__)

    begin
      reader.open(fixture_path, limit: 1)

      expect_raises(Exception, "BAM file does not exist: #{missing_path}") do
        reader.open(missing_path)
      end

      reader.open?.should be_false
      reader.file_path.should be_nil
    ensure
      reader.close
    end
  end
end
