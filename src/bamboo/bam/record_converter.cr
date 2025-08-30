require "hts"

module Bamboo
  module Bam
    class RecordAdapter
      def self.from_hts(record) : Alignment
        Alignment.new(
          qname: record.qname || "unknown",
          flag: record.flag.value.to_i32,
          rname: record.chrom || "*",
          pos: (record.pos + 1).to_i32, # Convert to 1-based position
          mapq: record.mapq.to_i32,
          cigar: record.cigar.try(&.to_s) || "*",
          rnext: record.mate_chrom || "*",
          pnext: (record.mate_pos + 1).to_i32, # Convert to 1-based position
          tlen: record.insert_size.to_i32,
          seq: record.seq || "*",
          qual: record.qual_string || "*"
        )
      end

      def self.elide_seq(sequence : String) : String
        if sequence.size > Settings::SEQUENCE_DISPLAY_LENGTH
          sequence[0, Settings::SEQUENCE_DISPLAY_LENGTH] + "..."
        else
          sequence
        end
      end

      def self.elide_qual(quality : String) : String
        if quality.size > Settings::SEQUENCE_DISPLAY_LENGTH
          quality[0, Settings::SEQUENCE_DISPLAY_LENGTH] + "..."
        else
          quality
        end
      end
    end
  end
end
