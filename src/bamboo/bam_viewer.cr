require "uing"
require "hts"

module Bamboo
  class BamViewer
    @data : Array(BamRecord)
    @current_bam : HTS::Bam?
    @table_model : UIng::Table::Model?
    @table : UIng::Table?
    @chromosome_names : Array(String)
    @main_window : UIng::Window
    @file_status_label : UIng::Label?

    def initialize
      UIng.init

      # Start with empty data
      @data = [] of BamRecord
      @chromosome_names = ["All"]

      # Create menus first (before any windows)
      create_menus()

      # Create main window with menubar
      @main_window = UIng::Window.new("Bamboo - BAM File Viewer", 1000, 600, menubar: true, margined: true)
      @main_window.on_closing do
        cleanup()
        UIng.quit
        true
      end

      # Create main layout
      vbox = UIng::Box.new :vertical
      vbox.padded = true

      # Create search UI
      search_box = create_search_ui()
      vbox.append(search_box, false)

      # Create table
      table = setup_table()
      vbox.append(table, true)

      # Set up layout
      @main_window.child = vbox
      @main_window.show
    end

    private def create_menus
      # File menu
      UIng::Menu.new("File") do
        append_item("Open BAM File...").on_clicked do |window|
          open_file_from_menu(window)
        end
        append_separator
        append_item("Close File").on_clicked do |window|
          close_current_file()
        end
        append_separator
        append_quit_item
      end

      # View menu
      UIng::Menu.new("View") do
        append_item("Show All Records").on_clicked do |window|
          show_all_records()
        end
        append_separator
        append_item("Refresh").on_clicked do |window|
          refresh_table()
        end
      end

      # Help menu
      UIng::Menu.new("Help") do
        append_about_item.on_clicked do |window|
          window.msg_box("About Bamboo", "Bamboo - BAM File Viewer\nVersion: #{Bamboo::VERSION}\n\nA Crystal application for viewing BAM files in table format.")
        end
      end
    end

    private def open_file_from_menu(window : UIng::Window)
      # Use UIng's built-in file dialog
      if file_path = window.open_file
        load_file(file_path)
      end
    end

    private def close_current_file
      @current_bam.try &.close
      @current_bam = nil
      @data.clear
      @chromosome_names = ["All"]

      update_table_data(@data)
      puts "File closed"
    end

    private def refresh_table
      if table_model = @table_model
        # Refresh all rows
        (0...@data.size).each do |row|
          table_model.row_changed(row)
        end
        puts "Table refreshed"
      end
    end

    private def load_file(file_path : String)
      begin
        records = load_bam_file(file_path)
        update_table_data(records)
        @chromosome_names = extract_chromosome_names()

        file_name = File.basename(file_path)
        puts "Successfully loaded #{@data.size} records from #{file_name}"
      rescue ex : Exception
        puts "Failed to load file: #{ex.class}: #{ex.message}"
      end
    end

    private def setup_table
      model_handler = UIng::Table::Model::Handler.new do
        num_columns do
          11 # QNAME, FLAG, RNAME, POS, MAPQ, CIGAR, RNEXT, PNEXT, TLEN, SEQ, QUAL
        end

        column_type do |column|
          UIng::Table::Value::Type::String
        end

        num_rows do
          @data.size
        end

        cell_value do |row, column|
          record = @data[row]
          value = case column
                  when  0 then record.qname
                  when  1 then record.flag.to_s
                  when  2 then record.rname
                  when  3 then record.pos.to_s
                  when  4 then record.mapq.to_s
                  when  5 then record.cigar
                  when  6 then record.rnext
                  when  7 then record.pnext.to_s
                  when  8 then record.tlen.to_s
                  when  9 then record.seq[0..20] + (record.seq.size > 20 ? "..." : "")   # Truncate long sequences
                  when 10 then record.qual[0..20] + (record.qual.size > 20 ? "..." : "") # Truncate long quality strings
                  else         ""
                  end
          UIng::Table::Value.new(value)
        end

        set_cell_value do |row, column, value|
          # BAM data is read-only, so we do nothing
        end
      end

      table_model = UIng::Table::Model.new(model_handler)

      table = UIng::Table.new(table_model) do
        append_text_column("QNAME", 0, -1)
        append_text_column("FLAG", 1, -1)
        append_text_column("RNAME", 2, -1)
        append_text_column("POS", 3, -1)
        append_text_column("MAPQ", 4, -1)
        append_text_column("CIGAR", 5, -1)
        append_text_column("RNEXT", 6, -1)
        append_text_column("PNEXT", 7, -1)
        append_text_column("TLEN", 8, -1)
        append_text_column("SEQ", 9, -1)
        append_text_column("QUAL", 10, -1)
      end

      table.on_selection_changed do |selection|
        if selection.num_rows > 0
          selected_row = selection.rows[0]
          record = @data[selected_row]
          puts "Selected: #{record.qname} at #{record.rname}:#{record.pos}"
        end
      end

      # Store references for cleanup and updates
      @table_model = table_model
      @table = table

      table
    end

    private def load_bam_file(file_path : String)
      begin
        @current_bam.try &.close # Close existing file if any

        unless File.exists?(file_path)
          raise "BAM file does not exist: #{file_path}"
        end

        bam = HTS::Bam.open(file_path)
        @current_bam = bam

        records = [] of BamRecord
        count = 0

        # Load first 100 records for initial display
        bam.each do |record|
          break if count >= 100

          begin
            bam_record = BamRecord.new(
              qname: record.qname || "unknown",
              flag: record.flag.value.to_i32, # Convert UInt16 to Int32
              rname: record.chrom || "*",
              pos: (record.pos + 1).to_i32,    # Convert to 1-based position and Int32
              mapq: record.mapq.to_i32,        # Convert UInt8 to Int32
              cigar: record.cigar.to_s || "*", # Cigar object has .to_s method
              rnext: record.mate_chrom || "*",
              pnext: (record.mate_pos + 1).to_i32, # Convert to 1-based position and Int32
              tlen: record.insert_size.to_i32,     # Convert to Int32
              seq: record.seq || "*",
              qual: record.qual_string || "*"
            )

            records << bam_record
            count += 1
          rescue ex
            puts "Warning: Failed to process BAM record #{count}: #{ex.message}"
            # Continue with next record
          end
        end

        puts "Successfully loaded #{records.size} BAM records from #{file_path}"
        records
      rescue ex : Exception
        puts "Error loading BAM file #{file_path}: #{ex.class}: #{ex.message}"
        @current_bam = nil
        raise ex
      end
    end

    private def extract_chromosome_names
      names = ["All"]

      if @data.any?
        # Extract chromosome names from loaded data
        @data.map(&.rname).uniq.sort.each do |chr|
          names << chr unless chr == "*"
        end
      end

      names
    end

    private def create_search_ui
      hbox = UIng::Box.new :horizontal
      hbox.padded = true

      # Chromosome selection
      chr_label = UIng::Label.new("Chromosome:")
      hbox.append(chr_label, false)

      chromosome_combo = UIng::Combobox.new(@chromosome_names)
      chromosome_combo.selected = 0 # Select "All" by default
      hbox.append(chromosome_combo, false)

      # Start position
      start_label = UIng::Label.new("Start:")
      hbox.append(start_label, false)

      start_spinbox = UIng::Spinbox.new(1, 1000000, 1)
      hbox.append(start_spinbox, false)

      # End position
      end_label = UIng::Label.new("End:")
      hbox.append(end_label, false)

      end_spinbox = UIng::Spinbox.new(1, 1000000, 1000)
      hbox.append(end_spinbox, false)

      # Search button
      search_button = UIng::Button.new("Search")
      search_button.on_clicked do
        perform_search(chromosome_combo, start_spinbox, end_spinbox)
      end
      hbox.append(search_button, false)

      # Show all button
      show_all_button = UIng::Button.new("Show All")
      show_all_button.on_clicked do
        show_all_records()
      end
      hbox.append(show_all_button, false)

      hbox
    end

    private def perform_search(chromosome_combo : UIng::Combobox, start_spinbox : UIng::Spinbox, end_spinbox : UIng::Spinbox)
      selected_chr = @chromosome_names[chromosome_combo.selected]
      start_pos = start_spinbox.value
      end_pos = end_spinbox.value

      if selected_chr == "All"
        show_all_records()
        return
      end

      # Use BAM query if available, otherwise filter existing data
      if bam = @current_bam
        search_with_bam_query(selected_chr, start_pos, end_pos)
      else
        search_with_filter(selected_chr, start_pos, end_pos)
      end
    end

    private def search_with_bam_query(chromosome : String, start_pos : Int32, end_pos : Int32)
      return unless bam = @current_bam

      begin
        # Validate input parameters
        if start_pos < 1 || end_pos < 1 || start_pos > end_pos
          puts "Invalid search coordinates: #{start_pos}-#{end_pos}"
          return
        end

        # Convert to 0-based coordinates for BAM query
        query_string = "#{chromosome}:#{start_pos - 1}-#{end_pos - 1}"
        puts "BAM Query: #{query_string}"

        records = [] of BamRecord
        count = 0

        bam.query(query_string) do |record|
          break if count >= 1000 # Limit results to prevent UI freeze

          begin
            bam_record = BamRecord.new(
              qname: record.qname || "unknown",
              flag: record.flag.value.to_i32,
              rname: record.chrom || "*",
              pos: (record.pos + 1).to_i32, # Convert back to 1-based
              mapq: record.mapq.to_i32,
              cigar: record.cigar.to_s || "*",
              rnext: record.mate_chrom || "*",
              pnext: (record.mate_pos + 1).to_i32,
              tlen: record.insert_size.to_i32,
              seq: record.seq || "*",
              qual: record.qual_string || "*"
            )

            records << bam_record
            count += 1
          rescue ex
            puts "Warning: Failed to process query result #{count}: #{ex.message}"
            # Continue with next record
          end
        end

        update_table_data(records)
        puts "BAM Query completed: #{chromosome}:#{start_pos}-#{end_pos}, found #{records.size} records"
      rescue ex : Exception
        puts "BAM query failed: #{ex.class}: #{ex.message}"
        puts "Falling back to filter search"
        # Fallback to filtering existing data
        search_with_filter(chromosome, start_pos, end_pos)
      end
    end

    private def search_with_filter(chromosome : String, start_pos : Int32, end_pos : Int32)
      # Filter existing data based on search criteria
      filtered_data = @data.select do |record|
        record.rname == chromosome &&
          record.pos >= start_pos &&
          record.pos <= end_pos
      end

      update_table_data(filtered_data)
      puts "Filter Search: #{chromosome}:#{start_pos}-#{end_pos}, found #{filtered_data.size} records"
    end

    private def show_all_records
      # Show all loaded data (no filtering)
      if bam = @current_bam
        begin
          records = load_bam_file_all_records()
          update_table_data(records)
          puts "Showing all #{@data.size} records"
        rescue ex
          puts "Error reloading all records: #{ex.message}"
        end
      else
        puts "No BAM file loaded"
      end
    end

    private def load_bam_file_all_records
      return [] of BamRecord unless bam = @current_bam

      records = [] of BamRecord
      count = 0

      # Load first 1000 records for "show all"
      bam.each do |record|
        break if count >= 1000

        begin
          bam_record = BamRecord.new(
            qname: record.qname || "unknown",
            flag: record.flag.value.to_i32,
            rname: record.chrom || "*",
            pos: (record.pos + 1).to_i32,
            mapq: record.mapq.to_i32,
            cigar: record.cigar.to_s || "*",
            rnext: record.mate_chrom || "*",
            pnext: (record.mate_pos + 1).to_i32,
            tlen: record.insert_size.to_i32,
            seq: record.seq || "*",
            qual: record.qual_string || "*"
          )

          records << bam_record
          count += 1
        rescue ex
          puts "Warning: Failed to process BAM record #{count}: #{ex.message}"
        end
      end

      records
    end

    private def update_table_data(new_data : Array(BamRecord))
      old_size = @data.size

      # Replace array contents while maintaining reference
      @data.clear
      @data.concat(new_data)

      if table_model = @table_model
        # Handle row count changes
        if @data.size < old_size
          # Remove excess rows
          (@data.size...old_size).reverse_each do |row|
            table_model.row_deleted(row)
          end
        elsif @data.size > old_size
          # Insert new rows
          (old_size...@data.size).each do |row|
            table_model.row_inserted(row)
          end
        end

        # Update all rows
        @data.size.times do |row|
          table_model.row_changed(row)
        end

        puts "Table data updated: #{@data.size} records (was #{old_size})"
      end
    end

    private def cleanup
      @current_bam.try &.close
      @table_model.try &.free
    end

    def run
      UIng.main
      UIng.uninit
    end
  end
end
