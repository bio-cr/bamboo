require "uing"

module Bamboo
  module UI
    class AlignmentTable
      @data : Array(Alignment)
      @table_model : UIng::Table::Model?
      @table : UIng::Table?

      def initialize
        @data = [] of Alignment
      end

      def build : UIng::Table
        model_handler = UIng::Table::Model::Handler.new do
          num_columns do
            Settings::COLUMN_COUNT
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
                    when  9 then Bam::RecordAdapter.elide_seq(record.seq)
                    when 10 then Bam::RecordAdapter.elide_qual(record.qual)
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
          Settings::COLUMN_NAMES.each_with_index do |name, index|
            append_text_column(name, index, -1)
          end
        end

        table.on_selection_changed do |selection|
          on_selection_changed(selection)
        end

        # Store references for cleanup and updates
        @table_model = table_model
        @table = table

        table
      end

      def replace_rows(new_data : Array(Alignment))
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

          puts "Table data updated: #{@data.size} alignments (was #{old_size})"
        end
      end

      def refresh
        if table_model = @table_model
          (0...@data.size).each do |row|
            table_model.row_changed(row)
          end
          puts "Table refreshed"
        end
      end

      def filter_region(contig : String, start_pos : Int32, end_pos : Int32) : Array(Alignment)
        @data.select do |record|
          record.rname == contig &&
            record.pos >= start_pos &&
            record.pos <= end_pos
        end
      end

      def size : Int32
        @data.size
      end

      def close
        @table_model.try &.free
      end

      def on_selection_changed(selection)
        if selection.num_rows > 0
          selected_row = selection.rows[0]
          if selected_row < @data.size
            record = @data[selected_row]
            puts "Selected: #{record.qname} at #{record.rname}:#{record.pos}"
          end
        end
      end
    end
  end
end
