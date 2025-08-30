require "hts"
require "./record_converter"

module Bamboo
  module Bam
    class BamReader
      @current_bam : HTS::Bam?

      def initialize
        @current_bam = nil
      end

      def open(file_path : String, limit : Int32 = Settings::INITIAL_RECORD_LIMIT) : Array(Alignment)
        close

        unless File.exists?(file_path)
          raise "BAM file does not exist: #{file_path}"
        end

        @current_bam = HTS::Bam.open(file_path)

        alignments = read_all(limit)

        puts "Successfully loaded #{alignments.size} BAM alignments from #{file_path}"
        alignments
      rescue ex : Exception
        puts "Error loading BAM file #{file_path}: #{ex.class}: #{ex.message}"
        @current_bam = nil
        raise ex
      end

      def read_all(limit : Int32 = Settings::MAX_SEARCH_RESULTS) : Array(Alignment)
        bam = @current_bam
        alignments = [] of Alignment
        return alignments unless bam

        bam.rewind

        idx = 0

        bam.each do |record|
          if idx >= limit
            puts "Warning: Reached record limit of #{limit}, stopping load"
            break
          end

          begin
            bam_record = RecordAdapter.from_hts(record)
            alignments << bam_record
            idx += 1
          rescue ex
            puts "Warning: Failed to process BAM record #{idx}: #{ex.message}"
          end
        end

        alignments
      end

      def contigs : Array(String)
        return [] of String unless (bam = @current_bam)
        return [] of String unless (hdr = bam.header)
        hdr.target_names
      end

      def fetch(contig : String, start_pos : Int32, end_pos : Int32) : Array(Alignment)
        return [] of Alignment unless bam = @current_bam

        # Validate input parameters
        if start_pos < 1 || end_pos < 1 || start_pos > end_pos
          puts "Invalid search coordinates: #{start_pos}-#{end_pos}"
          return [] of Alignment
        end

        # BAM query uses 1-based coordinates with both ends inclusive
        query_string = "#{contig}:#{start_pos}-#{end_pos}"
        puts "BAM Query: #{query_string}"

        alignments = [] of Alignment
        count = 0

        bam.query(query_string) do |record|
          break if count >= Settings::MAX_SEARCH_RESULTS

          begin
            bam_record = RecordAdapter.from_hts(record)
            alignments << bam_record
            count += 1
          rescue ex
            puts "Warning: Failed to process query result #{count}: #{ex.message}"
          end
        end

        puts "BAM Query completed: #{contig}:#{start_pos}-#{end_pos}, found #{alignments.size} alignments"
        alignments
      rescue ex : Exception
        puts "BAM query failed: #{ex.class}: #{ex.message}"
        [] of Alignment
      end

      def close
        @current_bam.try &.close
        @current_bam = nil
      end

      def open?
        !@current_bam.nil?
      end
    end
  end
end
