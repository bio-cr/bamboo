module Bamboo
  # BAM record structure for table display
  struct Alignment
    property qname : String
    property flag : Int32
    property rname : String
    property pos : Int32
    property mapq : Int32
    property cigar : String
    property rnext : String
    property pnext : Int32
    property tlen : Int32
    property seq : String
    property qual : String
    property aux : String

    def initialize(@qname : String, @flag : Int32, @rname : String, @pos : Int32,
                   @mapq : Int32, @cigar : String, @rnext : String, @pnext : Int32,
                   @tlen : Int32, @seq : String, @qual : String, @aux : String)
    end
  end
end
