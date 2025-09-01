require "hts"

module Bamboo
  module Bam
    class RecordAdapter
      def self.from_hts(record) : Alignment
        cigar = record.cigar.to_s
        qname = record.qname.empty? ? "unknown" : record.qname
        rname = record.chrom.empty? ? "*" : record.chrom
        rnext = record.mate_chrom.empty? ? "*" : record.mate_chrom
        seq = record.seq.empty? ? "*" : record.seq
        qual = record.qual_string.empty? ? "*" : record.qual_string

        Alignment.new(
          qname: qname,
          flag: record.flag.value.to_i32,
          rname: rname,
          pos: (record.pos + 1).to_i32,
          mapq: record.mapq.to_i32,
          cigar: cigar.empty? ? "*" : cigar,
          rnext: rnext,
          pnext: (record.mate_pos + 1).to_i32,
          tlen: record.insert_size.to_i32,
          seq: seq,
          qual: qual
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
