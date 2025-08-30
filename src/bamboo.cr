require "./bamboo/version"
require "./bamboo/config"
require "./bamboo/bam_record"
require "./bamboo/bam/record_converter"
require "./bamboo/bam/file_loader"
require "./bamboo/ui/table_manager"
require "./bamboo/ui/search_panel"
require "./bamboo/ui/menu_builder"
require "./bamboo/bam_viewer"

module Bamboo
  def self.run
    viewer = ViewerApp.new
    viewer.run
  end
end

Bamboo.run
