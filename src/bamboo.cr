require "./bamboo/version"
require "./bamboo/bam_record"
require "./bamboo/bam_viewer"

# TODO: Write documentation for `Bamboo`
module Bamboo
  def self.run
    viewer = BamViewer.new
    viewer.run
  end
end

# Run the application if this file is executed directly
if PROGRAM_NAME.includes?("bamboo")
  Bamboo.run
end
