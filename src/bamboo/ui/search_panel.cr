require "uing"

module Bamboo
  module UI
    class RegionSearchBar
      @contigs : Array(String) = [] of String
      @contig_combo : UIng::Combobox?
      @start_spinbox : UIng::Spinbox?
      @end_spinbox : UIng::Spinbox?

      def initialize
      end

      def build(search_callback : Proc(String, Int32, Int32, Nil), show_all_callback : Proc(Nil)) : UIng::Box
        hbox = UIng::Box.new :horizontal
        hbox.padded = true

        # Chromosome selection
        contig_label = UIng::Label.new("Chromosome:")
        hbox.append(contig_label, false)

        contig_combo = UIng::Combobox.new
        hbox.append(contig_combo, false)
        @contig_combo = contig_combo

        # Start position
        start_label = UIng::Label.new("Start:")
        hbox.append(start_label, false)

        start_spinbox = UIng::Spinbox.new(1, 999999999, 1)
        hbox.append(start_spinbox, false)
        @start_spinbox = start_spinbox

        # End position
        end_label = UIng::Label.new("End:")
        hbox.append(end_label, false)

        end_spinbox = UIng::Spinbox.new(1, 999999999, Settings::DEFAULT_REGION_END)
        hbox.append(end_spinbox, false)
        @end_spinbox = end_spinbox

        # Search button
        search_button = UIng::Button.new("Search")
        search_button.on_clicked do
          trigger_search(search_callback)
        end
        hbox.append(search_button, false)

        # Show all button
        show_all_button = UIng::Button.new("Show All")
        show_all_button.on_clicked do
          show_all_callback.call
        end
        hbox.append(show_all_button, false)

        hbox
      end

      def contigs=(@contigs : Array(String))
        if combo = @contig_combo
          combo.clear
          @contigs.each { |name| combo.append(name) }
        end
      end

      def select_contig(contig : String) : Nil
        if combo = @contig_combo
          if idx = @contigs.index(contig)
            combo.selected = idx
          end
        end
      end

      def selected_contig : String?
        if combo = @contig_combo
          idx = combo.selected
          @contigs[idx] unless idx.negative?
        end
      end

      def reset
        if combo = @contig_combo
          combo.clear
        end
        if start_box = @start_spinbox
          start_box.value = 1
        end
        if end_box = @end_spinbox
          end_box.value = 1000
        end
      end

      def trigger_search(search_callback)
        combo = @contig_combo
        start_box = @start_spinbox
        end_box = @end_spinbox

        return unless combo && start_box && end_box

        start_pos = start_box.value
        end_pos = end_box.value

        if contig = selected_contig
          search_callback.call(contig, start_pos, end_pos)
        else
          puts "No contig selected"
        end
      end
    end
  end
end
