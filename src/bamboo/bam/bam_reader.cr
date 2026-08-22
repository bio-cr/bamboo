require "hts"
require "./record_converter"

module Bamboo
  module Bam
    class BamReader
      @current_bam : HTS::Bam?
      getter file_path : String?

      def initialize
        @current_bam = nil
      end

      def open(file_path : String, limit : Int32 = Settings::INITIAL_RECORD_LIMIT) : Array(Alignment)
        close

        unless File.exists?(file_path)
          raise "BAM file does not exist: #{file_path}"
        end

        begin
          @current_bam = HTS::Bam.open(file_path)
          @file_path = file_path
          alignments = read_all(limit)
          puts "Successfully loaded #{alignments.size} BAM alignments from #{file_path}"
          alignments
        rescue ex : Exception
          close
          puts "Error loading BAM file #{file_path}: #{ex.class}: #{ex.message}"
          raise ex
        end
      end

      def read_all(limit : Int32 = Settings::MAX_SEARCH_RESULTS) : Array(Alignment)
        bam = @current_bam
        alignments = [] of Alignment
        return alignments unless bam

        bam.rewind

        idx = 0

        # HTS::Bam#each reuses one record for allocation-efficient streaming.
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
        return [] of String unless bam = @current_bam
        return [] of String unless hdr = bam.header
        hdr.target_names
      end

      # Returns BAM header text when available, otherwise nil
      def header_string : String?
        @current_bam.try &.header.try &.to_s
      end

      def fetch(contig : String, start_pos : Int32, end_pos : Int32) : Array(Alignment)
        return [] of Alignment unless bam = @current_bam

        # Indexes are loaded lazily by hts.cr. Probe and load the default
        # index here so a freshly opened BAM with a valid .bai remains queryable.
        unless bam.index_loaded? || bam.try_load_index
          puts "Warning: BAM index not available, cannot perform region query"
          return [] of Alignment
        end

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
        begin
          @current_bam.try &.close
        ensure
          @current_bam = nil
          @file_path = nil
        end
      end

      def open? : Bool
        !@current_bam.nil?
      end
    end
  end
end
