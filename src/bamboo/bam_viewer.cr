require "uing"
require "./settings"
require "./bam/bam_reader"
require "./ui/table_manager"
require "./ui/search_panel"
require "./ui/menu_builder"

module Bamboo
  class ViewerApp
    @bam_reader : Bam::BamReader
    @alignment_table : UI::AlignmentTable
    @region_search_bar : UI::RegionSearchBar
    @main_window : UIng::Window
    @vbox : UIng::Box

    def initialize
      UIng.init

      # Initialize components
      @bam_reader = Bam::BamReader.new
      @alignment_table = UI::AlignmentTable.new
      @region_search_bar = UI::RegionSearchBar.new

      # Create menus first (before any windows)
      build_menus

      # Create main window with menubar
      @main_window = UIng::Window.new(
        Settings::WINDOW_TITLE,
        Settings::WINDOW_WIDTH,
        Settings::WINDOW_HEIGHT,
        menubar: true,
        margined: false
      )

      @main_window.on_closing do
        close
        UIng.quit
        true
      end

      @vbox = build_ui
      @main_window.show
    end

    def run
      UIng.main
      UIng.uninit
    end

    private def build_menus
      UI::AppMenu.build(
        open_file_callback: ->(window : UIng::Window) { open_file_dialog(window) },
        close_file_callback: -> { close_bam },
        show_all_callback: -> { show_all },
        refresh_callback: -> { refresh_view },
        show_header_callback: -> { show_header }
      )
    end

    private def build_ui : UIng::Box
      vbox = UIng::Box.new :vertical
      vbox.padded = true

      # Create search UI
      search_box = @region_search_bar.build(
        search_callback: ->(contig : String, start : Int32, end_pos : Int32) { search_region(contig, start, end_pos) },
        show_all_callback: -> { show_all }
      )
      vbox.append(search_box, false)

      # Create table
      table = @alignment_table.build
      vbox.append(table, true)

      @main_window.child = vbox
      vbox
    end

    private def open_file_dialog(window : UIng::Window)
      if file_path = window.open_file
        open_bam(file_path)
      end
    end

    private def open_bam(file_path : String)
      alignments = @bam_reader.open(file_path)
      @alignment_table.replace_rows(alignments)
      @region_search_bar.contigs = @bam_reader.contigs

      file_name = File.basename(file_path)
      puts "Successfully loaded #{@alignment_table.size} alignments from #{file_name}"
    rescue ex : Exception
      puts "Failed to load file: #{ex.class}: #{ex.message}"
    end

    private def close_bam
      @bam_reader.close
      @alignment_table.replace_rows([] of Alignment)
      @region_search_bar.reset
      puts "File closed"
    end

    private def show_all
      if @bam_reader.open?
        begin
          alignments = @bam_reader.read_all
          @alignment_table.replace_rows(alignments)
          puts "Showing all #{@alignment_table.size} alignments"
        rescue ex
          puts "Error reloading all alignments: #{ex.message}"
        end
      else
        puts "No BAM file loaded"
      end
    end

    private def refresh_view
      @alignment_table.refresh
    end

    private def search_region(contig : String, start_pos : Int32, end_pos : Int32)
      if @bam_reader.open?
        # Try BAM query first
        alignments = @bam_reader.fetch(contig, start_pos, end_pos)

        # If BAM query fails or returns empty, try filtering existing data
        if alignments.empty?
          alignments = @alignment_table.filter_region(contig, start_pos, end_pos)
          puts "Filter Search: #{contig}:#{start_pos}-#{end_pos}, found #{alignments.size} alignments"
        end

        @alignment_table.replace_rows(alignments)
      else
        puts "No BAM file loaded"
      end
    end

    private def close
      # FIXME: https://github.com/kojix2/uing/issues/6
      @vbox.delete(1)
      @bam_reader.close
      @alignment_table.close
    end

    private def show_header
      header_window = UIng::Window.new(
        "BAM Header",
        600,
        400,
        menubar: false,
        margined: true
      )
      box = UIng::Box.new(:vertical)
      box.padded = true
      header_window.child = box
      header_text = UIng::MultilineEntry.new
      header_text.read_only = true
      header_text.text = @bam_reader.header_string || "No BAM file loaded or header unavailable"
      label = UIng::Label.new(@bam_reader.file_path || "No file loaded")
      box.append(label, false)
      box.append(header_text, stretchy: true)

      header_window.on_closing do
        header_window.destroy
        false
      end
      header_window.show
    end
  end
end
