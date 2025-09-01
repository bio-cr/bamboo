require "uing"

module Bamboo
  module UI
    class AppMenu
      def self.build(open_file_callback : Proc(UIng::Window, Nil), close_file_callback : Proc(Nil), show_all_callback : Proc(Nil), refresh_callback : Proc(Nil))
        # File menu
        UIng::Menu.new("File") do
          append_item("Open BAM File...").on_clicked do |window|
            open_file_callback.call(window)
          end
          append_separator
          append_item("Close File").on_clicked do |_window|
            close_file_callback.call
          end
          append_separator
          append_quit_item
        end

        # View menu
        UIng::Menu.new("View") do
          append_item("Show All Records").on_clicked do |_window|
            show_all_callback.call
          end
          append_separator
          append_item("Refresh").on_clicked do |_window|
            refresh_callback.call
          end
        end

        # Help menu
        UIng::Menu.new("Help") do
          append_about_item.on_clicked do |window|
            window.msg_box(
              "About Bamboo",
              [
                "Bamboo - BAM File Viewer",
                "Version: #{Bamboo::VERSION}",
                "Source: #{Bamboo::SOURCE}",
                "",
                "A Crystal application for viewing BAM files in table format.",
              ].join('\n')
            )
          end
        end
      end
    end
  end
end
